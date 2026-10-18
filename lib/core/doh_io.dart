// DoH（DNS over HTTPS）解析引擎（设备端实现）。
//
// Web 端没有自定义 DNS 的能力，对应的空实现见 `doh_web.dart`，两者通过
// `doh.dart` 的 `if (dart.library.io)` 条件导出选择。
//
// 本文件通过把 DoH 端点固定连接到硬编码的引导 IP，并在 TLS 握手时用真实
// 域名做 SNI 与证书校验，从而在系统 DNS 被污染时仍可正确解析域名。
// 每个端点自带 JSON 查询路径（Cloudflare/Google/dnspod 为 RFC 8484 的
// `/dns-query`，阿里为 `/resolve`）。
//
// 解析策略为「并发竞速，优先 DoH，失败可回退系统 DNS」：
// - 所有端点同时发起查询，第一个返回非空结果者胜出；端点顺序仅作并列时的
//   打破平手（tie-break），整体耗时被 [DohResolver._overallTimeout]（8 秒）封顶；
// - 先查 AAAA（type 28）再查 A（type 1），使 IPv6 结果优先；
// - 全部 DoH 端点均无应答时，若 [DohResolver.fallbackToSystemDns] 为 true
//   （默认），[buildDohHttpClient] 会回退到平台解析器，避免 DoH 不可用导致
//   所有 HTTP 消费者集体断网；
// - 失败结果按 [DohResolver.negativeCacheTtl] 负缓存，避免失败域名每次调用
//   都重跑全部端点。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

/// DoH 模块日志。
final Logger _log = Logger('DohResolver');

/// 单个 DoH 端点：JSON 查询路径 + 真实域名（SNI / 证书校验）+ 引导 IP 列表。
class _DohEndpoint {
  final String host;
  final String path;
  final List<String> ips;
  const _DohEndpoint(this.host, this.path, this.ips);
}

/// DNS 解析缓存项；[addresses] 为空表示负缓存（解析失败）。
class _CacheEntry {
  final List<InternetAddress> addresses;
  final DateTime at;
  const _CacheEntry(this.addresses, this.at);
}

/// 基于 JSON API 的 DoH 解析器（单例）。
///
/// 并发竞速所有端点，第一个成功者胜出；
/// 结果按 [cacheTtl] 缓存在内存中，失败结果按 [negativeCacheTtl] 负缓存。
class DohResolver {
  DohResolver._();

  /// 全局单例。
  static final DohResolver instance = DohResolver._();

  /// 可用的 DoH 端点（顺序用于并列时的 tie-break）。
  static const List<_DohEndpoint> _endpoints = <_DohEndpoint>[
    _DohEndpoint('cloudflare-dns.com', '/dns-query', <String>[
      '1.1.1.1',
      '2606:4700:4700::1111',
    ]),
    _DohEndpoint('dns.google', '/dns-query', <String>[
      '8.8.8.8',
      '2001:4860:4860::8888',
    ]),
    _DohEndpoint('dns.alidns.com', '/resolve', <String>[
      '223.5.5.5',
      '223.6.6.6',
    ]),
    _DohEndpoint('doh.pub', '/dns-query', <String>[
      '1.12.12.12',
      '120.53.53.53',
    ]),
  ];

  /// 依次查询的记录类型：先 AAAA（28）再 A（1），使 IPv6 结果优先。
  static const List<int> _queryTypes = <int>[28, 1];

  /// 解析结果缓存有效期。
  static const Duration cacheTtl = Duration(seconds: 60);

  /// 解析失败（负缓存）的有效期，避免失败域名每次调用都重跑全部端点。
  static Duration negativeCacheTtl = const Duration(seconds: 30);

  /// DoH 全部失败时是否回退到平台 DNS 解析器。
  ///
  /// 默认开启：DoH 端点常被网络封锁，若因一次失败就抛异常，会导致所有
  /// `createDio()` 消费者集体断网。关闭此项可让失败直接抛出。
  static bool fallbackToSystemDns = true;

  /// 与 DoH 端点建立 TCP 连接的超时。
  static const Duration _connectTimeout = Duration(seconds: 5);

  /// 单次 DoH 请求（含 TLS）的超时。
  static const Duration _requestTimeout = Duration(seconds: 6);

  /// 单次 [lookup] 的总超时上限（并发竞速的整体耗时不得超过此值）。
  static const Duration _overallTimeout = Duration(seconds: 8);

  /// 域名 -> 解析结果缓存。
  final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};

  /// 解析 [host] 的全部 A/AAAA 记录；命中缓存时直接返回。
  ///
  /// 返回结果 IPv6 优先。全部端点均失败时抛出 [SocketException]，并写入
  /// [negativeCacheTtl] 负缓存。
  Future<List<InternetAddress>> lookup(String host) async {
    final String name = host.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(host, 'host', '域名为空');
    }

    // IP 字面量与 localhost 无需走 DoH。
    final InternetAddress? literal = InternetAddress.tryParse(name);
    if (literal != null) return <InternetAddress>[literal];
    if (name == 'localhost') {
      return <InternetAddress>[InternetAddress.loopbackIPv4];
    }

    final _CacheEntry? cached = _cache[name];
    final DateTime now = DateTime.now();
    if (cached != null) {
      if (cached.addresses.isEmpty) {
        if (now.difference(cached.at) < negativeCacheTtl) {
          throw SocketException('DoH 解析失败（负缓存）: $name');
        }
      } else if (now.difference(cached.at) < cacheTtl) {
        return cached.addresses;
      }
    }

    // 并发竞速：所有端点同时查询，第一个返回非空结果者胜出；整体 8 秒封顶。
    final DateTime deadline = now.add(_overallTimeout);
    final List<Future<List<InternetAddress>>> attempts =
        <Future<List<InternetAddress>>>[
          for (final _DohEndpoint endpoint in _endpoints)
            _resolveEndpoint(name, endpoint, deadline),
        ];
    List<InternetAddress> found;
    Object? lastError;
    try {
      found = await _raceFirstNonEmpty(attempts).timeout(_overallTimeout);
    } catch (e) {
      lastError = e;
      found = const <InternetAddress>[];
    }
    if (found.isNotEmpty) {
      _cache[name] = _CacheEntry(found, now);
      return found;
    }

    // 记录负缓存，避免失败域名在短时间内反复重跑全部端点。
    _cache[name] = _CacheEntry(const <InternetAddress>[], now);
    throw SocketException(
      'DoH 解析失败: $name${lastError == null ? '' : ' ($lastError)'}',
    );
  }

  /// 解析 [host] 并返回第一个地址（优先 IPv6）。
  Future<InternetAddress> resolve(String host) async {
    final List<InternetAddress> addresses = await lookup(host);
    if (addresses.isEmpty) {
      throw SocketException('DoH 未返回可用地址: $host');
    }
    return addresses.first;
  }

  /// 清空解析缓存。
  void clearCache() => _cache.clear();

  /// 在单个端点上依次尝试其引导 IP 与记录类型，返回非空结果或抛出异常。
  ///
  /// 每种记录类型一旦在某个引导 IP 上查询成功（即便该类型无记录）即不再
  /// 尝试该端点的其它 IP；两种类型均返回空且至少有一次失败时抛错。
  /// [deadline] 之后不再发起新的查询（竞速落败后及时止损）。
  Future<List<InternetAddress>> _resolveEndpoint(
    String name,
    _DohEndpoint endpoint,
    DateTime deadline,
  ) async {
    final List<InternetAddress> found = <InternetAddress>[];
    Object? lastError;
    for (final int type in _queryTypes) {
      for (final String ip in endpoint.ips) {
        if (DateTime.now().isAfter(deadline)) return found;
        try {
          final List<InternetAddress> result = await _query(
            name,
            type,
            ip,
            endpoint,
          ).timeout(_requestTimeout);
          found.addAll(result);
          break; // 该记录类型已成功查询（可能为空），无需再试其它引导 IP。
        } catch (e) {
          lastError = e;
        }
      }
    }
    if (found.isEmpty && lastError != null) {
      throw SocketException('DoH 端点 ${endpoint.host} 失败: $lastError');
    }
    return found;
  }

  /// 竞速一组解析尝试：第一个非空结果胜出；全部为空/失败时以空列表或最后一个
  /// 错误结束。按传入顺序挂接回调，使完成时机并列时靠前的端点优先。
  Future<List<InternetAddress>> _raceFirstNonEmpty(
    List<Future<List<InternetAddress>>> attempts,
  ) {
    final Completer<List<InternetAddress>> completer =
        Completer<List<InternetAddress>>();
    int pending = attempts.length;
    Object? lastError;
    void finishEmpty() {
      if (lastError != null) {
        completer.completeError(lastError!);
      } else {
        completer.complete(const <InternetAddress>[]);
      }
    }

    for (final Future<List<InternetAddress>> attempt in attempts) {
      attempt.then<void>(
        (List<InternetAddress> value) {
          if (completer.isCompleted) return;
          if (value.isNotEmpty) {
            completer.complete(value);
          } else if (--pending == 0) {
            finishEmpty();
          }
        },
        onError: (Object e) {
          lastError = e;
          if (completer.isCompleted) return;
          if (--pending == 0) {
            finishEmpty();
          }
        },
      );
    }
    return completer.future;
  }

  /// 向单个 DoH 端点（指定引导 [ip]）发起 JSON 查询。
  ///
  /// `type` 1 为 A，28 为 AAAA。返回体为 dns-json，仅读取 `Answer` 数组，
  /// 不假设 `Question` 的形状（阿里返回对象、其余返回数组）。
  Future<List<InternetAddress>> _query(
    String hostname,
    int type,
    String ip,
    _DohEndpoint endpoint,
  ) async {
    final HttpClient client = HttpClient();
    // 固定连接到硬编码引导 IP，TLS 握手时用真实域名做 SNI / 证书校验。
    client.connectionFactory =
        (Uri uri, String? proxyHost, int? proxyPort) async {
          final Socket plain = await Socket.connect(
            ip,
            uri.port,
            timeout: _connectTimeout,
          );
          final Future<Socket> secure = SecureSocket.secure(
            plain,
            host: endpoint.host,
          );
          return _secureConnectionTask(secure, plain);
        };

    try {
      final Uri uri = Uri(
        scheme: 'https',
        host: endpoint.host,
        port: 443,
        path: endpoint.path,
        queryParameters: <String, String>{
          'name': hostname,
          'type': type.toString(),
        },
      );
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/dns-json');
      final HttpClientResponse response = await request.close().timeout(
        _requestTimeout,
      );
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('DoH HTTP ${response.statusCode}', uri: uri);
      }
      final String body = await response.transform(utf8.decoder).join();
      return _parseAnswers(body);
    } finally {
      client.close(force: true);
    }
  }

  /// 解析 DoH JSON 响应中的 A（`type == 1`）与 AAAA（`type == 28`）记录。
  List<InternetAddress> _parseAnswers(String body) {
    final dynamic decoded = jsonDecode(body);
    if (decoded is! Map) return const <InternetAddress>[];
    final dynamic answers = decoded['Answer'];
    if (answers is! List) return const <InternetAddress>[];
    final List<InternetAddress> addresses = <InternetAddress>[];
    for (final dynamic entry in answers) {
      if (entry is! Map) continue;
      final dynamic type = entry['type'];
      final InternetAddressType family;
      if (type == 1) {
        family = InternetAddressType.IPv4;
      } else if (type == 28) {
        family = InternetAddressType.IPv6;
      } else {
        continue;
      }
      final dynamic data = entry['data'];
      if (data is! String || data.isEmpty) continue;
      try {
        addresses.add(InternetAddress(data, type: family));
      } catch (_) {
        // 忽略无法解析的记录。
      }
    }
    return addresses;
  }
}

/// 用 [SecureSocket.secure] 的握手 [handshake] 构建连接任务。
///
/// [onCancel] 会在尝试被取消且握手尚未完成时销毁底层明文 socket，避免取消后
/// 仍悬挂一个等待 OS 超时的连接；销毁已关闭 socket 抛出的错误予以忽略。
ConnectionTask<Socket> _secureConnectionTask(
  Future<Socket> handshake,
  Socket plain,
) {
  bool settled = false;
  final Future<Socket> tracked = handshake.whenComplete(() {
    settled = true;
  });
  return ConnectionTask.fromSocket<Socket>(tracked, () {
    if (settled) return;
    try {
      plain.destroy();
    } catch (_) {
      // 忽略关闭已关闭 socket 产生的错误。
    }
  });
}

/// 用 DoH 解析出的 [address] 建立连接。
Future<ConnectionTask<Socket>> _connectResolved(
  Uri uri,
  InternetAddress address,
  int port,
  bool secure,
) async {
  if (!secure) {
    return Socket.startConnect(address, port);
  }
  final Socket plain = await Socket.connect(
    address,
    port,
    timeout: DohResolver._connectTimeout,
  );
  final Future<Socket> secureSocket = SecureSocket.secure(
    plain,
    host: uri.host,
  );
  return _secureConnectionTask(secureSocket, plain);
}

/// 按 [scheme] 推断默认端口：`https`/`wss` 为 443，其余为 80。
int _defaultPortForScheme(String scheme) {
  if (scheme == 'https' || scheme == 'wss') return 443;
  return 80;
}

/// 构建一个使用 DoH 解析域名的 [HttpClient]。
///
/// 其 `connectionFactory` 会：
/// - 有代理时直接连接代理；
/// - 否则优先通过 [DohResolver] 解析目标域名后用解析出的地址连接，
///   `https:` 连接会在明文 socket 上执行 [SecureSocket.secure] 升级，
///   保留 SNI 与证书校验（**不使用** `badCertificateCallback`）；
/// - 当 DoH 解析或连接失败且 [DohResolver.fallbackToSystemDns] 为 true 时，
///   回退到平台解析器（`Socket.startConnect(uri.host, port)`）。
///
/// 注意：对于直接的 `https:` 连接，工厂必须返回 `SecureSocket`，返回普通
/// `Socket` 会破坏 TLS（见 Dart SDK 中 `HttpClient.connectionFactory` 的约定）。
HttpClient buildDohHttpClient() {
  final HttpClient client = HttpClient();
  client.connectionFactory =
      (Uri uri, String? proxyHost, int? proxyPort) async {
        // 走代理时不解析域名，交给代理解析。
        // 注意：此分支在当前代码路径中并未被触发（HttpClient 默认不启用代理），
        // 保留为防御性实现。
        if (proxyHost != null) {
          return Socket.startConnect(
            proxyHost,
            proxyPort ?? _defaultPortForScheme(uri.scheme),
          );
        }

        final int port = uri.port;
        final bool secure = uri.scheme == 'https';

        // 优先 DoH 解析；失败时按策略回退到系统解析器。
        List<InternetAddress>? addresses;
        try {
          addresses = await DohResolver.instance.lookup(uri.host);
        } catch (e) {
          if (!DohResolver.fallbackToSystemDns) rethrow;
          _log.warning('DoH 解析失败，回退系统 DNS: ${uri.host} ($e)');
        }

        if (addresses != null && addresses.isNotEmpty) {
          Object? connectError;
          for (final InternetAddress address in addresses) {
            try {
              return await _connectResolved(uri, address, port, secure);
            } catch (e) {
              connectError = e;
            }
          }
          if (!DohResolver.fallbackToSystemDns) {
            throw connectError ?? SocketException('无法连接: ${uri.host}');
          }
          _log.warning('DoH 地址连接失败，回退系统 DNS: ${uri.host} ($connectError)');
        }

        // 系统解析回退：`Socket.startConnect` / `Socket.connect` 会走平台 DNS。
        if (secure) {
          final Socket plain = await Socket.connect(
            uri.host,
            port,
            timeout: DohResolver._connectTimeout,
          );
          final Future<Socket> secureSocket = SecureSocket.secure(
            plain,
            host: uri.host,
          );
          return _secureConnectionTask(secureSocket, plain);
        }
        return Socket.startConnect(uri.host, port);
      };
  return client;
}
