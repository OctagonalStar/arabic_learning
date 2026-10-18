// 应用更新服务：检查 GitHub Release、下载 APK 并触发安装。
//
// 采用项目内常见的 `FSRS()` 风格手写单例，并继承 [ChangeNotifier] 以便 UI 直接监听。
// 网络请求统一走 [createDio]，从而应用用户在设置中配置的 DoH。
// 所有 Android 专属逻辑（文件写入 / 安装）均以 `kIsWeb` / `io.Platform.isAndroid`
// 做平台守卫，并对 `MissingPluginException` 做容错处理，保证 Web / 桌面端正常编译运行。
//
// APK 默认下载到应用支持目录：Android 上解析为 `getFilesDir()`，落在
// FileProvider 的 `<files-path>` 白名单内（见 android/app/src/main/res/xml/file_paths.xml）。
//
// 为了便于测试，Dio、下载目录 provider、APK 校验器均可在
// [UpdateService.forTesting] 中注入，避免测试触网或依赖真实插件。

import 'dart:async';
import 'dart:convert';

import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/core/version.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/http_client.dart';
import 'package:arabic_learning/services/notifications.dart' as notifications;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart'
    if (dart.library.io) 'dart:io'
    as io;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, MethodChannel;
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

/// 更新流程所处的阶段。
enum UpdateStage {
  /// 空闲：未检查或已是最新。
  idle,

  /// 正在请求 GitHub Release 信息。
  checking,

  /// 已发现可更新的新版本。
  available,

  /// 正在下载 APK。
  downloading,

  /// APK 已下载并校验完成，等待安装。
  ready,

  /// 出错（仅在手动检查 / 下载失败时进入）。
  error,
}

class UpdateService extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // 单例
  // ---------------------------------------------------------------------------

  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal()
    : _injectedDio = null,
      _documentsDirectoryProvider = null,
      _injectedApkVerifier = null;

  /// 测试用构造函数：可注入 Dio、下载根目录与 APK 校验器，避免触网 / 依赖真实插件。
  @visibleForTesting
  UpdateService.forTesting({
    Dio? dio,
    Future<io.Directory> Function()? documentsDirectoryProvider,
    Future<bool> Function(String path)? apkVerifier,
  }) : _injectedDio = dio,
       _documentsDirectoryProvider = documentsDirectoryProvider,
       _injectedApkVerifier = apkVerifier;

  // ---------------------------------------------------------------------------
  // 常量
  // ---------------------------------------------------------------------------

  /// GitHub 仓库所有者。
  static const String owner = 'OctagonalStar';

  /// GitHub 仓库名。
  static const String repo = 'arabic_learning';

  /// 最新 Release 接口（`/latest` 已自动排除 draft 与 prerelease）。
  static const String apiLatestUrl =
      'https://api.github.com/repos/$owner/$repo/releases/latest';

  /// 仓库发布页的 `/releases/latest`：会 302 跳转到最新 tag。
  ///
  /// 这是网页请求，**不消耗** GitHub API 的 60 次/小时匿名配额（该配额按 IP
  /// 共享，NAT/CGNAT 下极易被同网用户耗尽并返回 403），因此作为首选探测手段。
  static const String latestReleaseRedirectUrl =
      'https://github.com/$owner/$repo/releases/latest';

  /// 项目自身的 Android 包名，用于校验下载的 APK。
  static const String expectedPackageName = 'com.ayuban.arlearning';

  /// 下载通知使用的固定通知 id（单一来源见 [notifications.updateNotificationId]）。
  static const int updateNotificationId = notifications.updateNotificationId;

  /// 原生桥接通道名（见 android/app/src/main/kotlin/com/ayuban/arlearning/MainActivity.kt）。
  static const String methodChannelName = 'app_update';

  static const MethodChannel _channel = MethodChannel(methodChannelName);

  final Logger logger = Logger('UpdateService');

  // ---------------------------------------------------------------------------
  // 可注入依赖（仅测试使用）
  // ---------------------------------------------------------------------------

  final Dio? _injectedDio;
  final Future<io.Directory> Function()? _documentsDirectoryProvider;
  final Future<bool> Function(String path)? _injectedApkVerifier;

  // ---------------------------------------------------------------------------
  // 状态
  // ---------------------------------------------------------------------------

  UpdateStage _stage = UpdateStage.idle;
  UpdateStage get stage => _stage;

  String? _latestVersionLabel;
  String? get latestVersionLabel => _latestVersionLabel;

  int? _latestVersionInt;
  int? get latestVersionInt => _latestVersionInt;

  /// Release 正文（Markdown）。
  String? _releaseNotes;
  String? get releaseNotes => _releaseNotes;

  String? _downloadUrl;
  String? get downloadUrl => _downloadUrl;

  String? _assetName;
  String? get assetName => _assetName;

  int _assetSize = 0;
  int get assetSize => _assetSize;

  int _downloadedBytes = 0;
  int get downloadedBytes => _downloadedBytes;

  /// 总字节数，未知时为 -1。
  int _totalBytes = -1;
  int get totalBytes => _totalBytes;

  /// 最近一次滑窗估算的下载速度（字节/秒）。
  double _speedBytesPerSec = 0;
  double get speedBytesPerSec => _speedBytesPerSec;

  Object? _error;
  Object? get error => _error;

  bool _needsInstallPermission = false;
  bool get needsInstallPermission => _needsInstallPermission;

  /// 手动检查是「已是最新」时为 true，供 UI 提示。
  bool _lastCheckWasUpToDate = false;
  bool get lastCheckWasUpToDate => _lastCheckWasUpToDate;

  /// 当前进程是否已提示过更新（仅内存，退出进程即失效）。
  int? _dismissedVersion;

  CancelToken? _cancelToken;
  String? _savedPath;

  /// 在飞的检查请求：并发调用 [check] 时复用同一个 Future，避免状态串扰。
  Future<void>? _checkInFlight;

  /// 下载代次：取消下载时自增，用于丢弃仍在飞行中的失效回调（D6）。
  int _downloadGeneration = 0;

  int _lastNotifiedPercent = -1;
  int _lastProgressNotifyMs = 0;

  // 速度滑窗状态。
  int _speedWindowStartMs = 0;
  int _speedWindowBytes = 0;

  // ---------------------------------------------------------------------------
  // 派生状态
  // ---------------------------------------------------------------------------

  /// 当前安装版本（由构建时写入 [StaticsVar.appVersion]）。
  int get currentVersionInt => StaticsVar.appVersion;

  /// 是否存在待安装的新版本（已下载但尚未安装的安装包同样计入）。
  bool get hasPendingUpdate =>
      (_stage == UpdateStage.available &&
          _latestVersionInt != null &&
          isNewerVersion(_latestVersionInt!, currentVersionInt)) ||
      _stage == UpdateStage.ready;

  /// 已下载的安装包是否仍存在于磁盘上。
  ///
  /// 供 [check] 判断是否要跳过检查，避免覆盖已完成的下载（D5）。
  bool get _savedPathExists =>
      _savedPath != null && !kIsWeb && io.File(_savedPath!).existsSync();

  /// 该最新版本是否已被用户「跳过」。
  bool get isSkipped =>
      _latestVersionInt != null &&
      AppData().config.regular.skippedVersion == _latestVersionInt;

  bool get _dismissedForSession =>
      _dismissedVersion != null && _dismissedVersion == _latestVersionInt;

  /// 是否应在启动时自动弹出更新提示。
  bool get shouldPromptOnStartup =>
      !kIsWeb &&
      io.Platform.isAndroid &&
      AppData().config.regular.autoCheckUpdate &&
      hasPendingUpdate &&
      !isSkipped &&
      !_dismissedForSession;

  // ---------------------------------------------------------------------------
  // 检查更新
  // ---------------------------------------------------------------------------

  /// 检查最新 Release。
  ///
  /// [manual] 为 true 时，失败会进入 [UpdateStage.error] 并写入 [error]；
  /// 为 false（启动自动检查）时失败静默回到 [UpdateStage.idle]。
  ///
  /// 下载中或已下载待安装（且安装包仍在）时为空操作；同一时刻只保留一个在飞的
  /// 检查请求，并发调用直接复用同一个 Future，避免卡死或读到陈旧状态（D3/D5）。
  Future<void> check({bool manual = false}) {
    if (_stage == UpdateStage.downloading) return Future<void>.value();
    if (_stage == UpdateStage.ready && _savedPathExists) {
      return Future<void>.value();
    }
    return _checkInFlight ??= _doCheck(manual: manual).whenComplete(() {
      _checkInFlight = null;
    });
  }

  Future<void> _doCheck({required bool manual}) async {
    _error = null;
    _lastCheckWasUpToDate = false;
    _setStage(UpdateStage.checking);

    try {
      final Dio dio = _resolveDio();

      // 首选零配额探测：读取 `/releases/latest` 的 302 Location，正常情况下
      // 无需触碰 GitHub API（见 [latestReleaseRedirectUrl]）。探测本身不抛异常。
      final _ReleaseProbe probe = await _probeLatestRelease(dio);

      if (probe.kind == _ReleaseProbeKind.noReleases) {
        // 仓库尚无 Release：视为已是最新，不请求 API。
        _lastCheckWasUpToDate = true;
        _setStage(UpdateStage.idle);
        return;
      }

      final String? redirectTag = probe.kind == _ReleaseProbeKind.tag
          ? probe.tag
          : null;
      final int? redirectVersion = redirectTag == null
          ? null
          : parseGithubTag(redirectTag);

      if (redirectTag != null && redirectVersion != null) {
        if (!isNewerVersion(redirectVersion, currentVersionInt)) {
          // 正常路径：已是最新，零 API 调用，也不触碰 MethodChannel（ABI）。
          _latestVersionLabel = redirectTag;
          _latestVersionInt = redirectVersion;
          _lastCheckWasUpToDate = true;
          _setStage(UpdateStage.idle);
          return;
        }
        // 确认有新版本：尽力补全 Release 正文与资产信息。
        await _resolveAvailableFromRedirect(dio, redirectTag, redirectVersion);
        return;
      }

      // 探测未知（无重定向 / 缺 location / 异常）或 tag 无法解析为版本号：
      // 回退到原有 API 流程。
      await _checkViaApi(dio);
    } catch (e) {
      _error = _describeError(e);
      logger.warning('检查更新失败: $_error');
      _setStage(manual ? UpdateStage.error : UpdateStage.idle);
    } finally {
      notifyListeners();
    }
  }

  /// 探测 `/releases/latest` 的 302 `Location`，零配额获取最新 Release tag。
  ///
  /// 不跟随重定向：`followRedirects: false` 以便读取 `Location` 头；并将
  /// `validateStatus` 放宽到 `< 400`（默认只接受 2xx，会把 302 判为错误）。
  /// 结果三态见 [_ReleaseProbeKind]；本方法**从不抛异常**。
  Future<_ReleaseProbe> _probeLatestRelease(Dio dio) async {
    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        latestReleaseRedirectUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (int? s) => s != null && s < 400,
          headers: const <String, dynamic>{
            'User-Agent': 'arabic_learning-updater',
          },
        ),
      );

      final String? location = response.headers.value('location');
      if (location == null || location.isEmpty) {
        logger.fine('重定向探测未返回 location，回退 API');
        return const _ReleaseProbe(_ReleaseProbeKind.unknown);
      }

      // `Location` 可能是相对路径，先按请求地址解析为绝对 URL。
      final String resolved = Uri.parse(
        latestReleaseRedirectUrl,
      ).resolve(location).toString();
      final String? tag = parseReleaseRedirectTag(resolved);
      if (tag != null) {
        return _ReleaseProbe(_ReleaseProbeKind.tag, tag);
      }
      // 有重定向但没有 `/releases/tag/` 段（如跳到 `/releases`）→ 尚无 Release。
      if (!resolved.contains('/releases/tag/')) {
        return const _ReleaseProbe(_ReleaseProbeKind.noReleases);
      }
      // 有该段但解析为空 → 视为未知，回退 API。
      return const _ReleaseProbe(_ReleaseProbeKind.unknown);
    } catch (e) {
      logger.fine('重定向探测失败，回退 API: $e');
      return const _ReleaseProbe(_ReleaseProbeKind.unknown);
    }
  }

  /// 原有 API 检查流程（回退路径）：`GET /releases/latest` 获取完整 Release。
  ///
  /// 供重定向探测未知 / tag 非法时使用；也用于为新版本补全信息的一部分。
  Future<void> _checkViaApi(Dio dio) async {
    final Map<dynamic, dynamic> release = await _fetchLatestRelease(dio);

    // 防御性排除 draft / prerelease（/latest 接口通常已排除）。
    if (release['draft'] == true || release['prerelease'] == true) {
      logger.info('最新 Release 为草稿或预发布，忽略');
      _lastCheckWasUpToDate = true;
      _setStage(UpdateStage.idle);
      return;
    }

    final String? tag = release['tag_name']?.toString();
    final int? latest = tag == null ? null : parseGithubTag(tag);
    if (latest == null) {
      throw Exception('无法解析版本号: $tag');
    }

    _latestVersionLabel = tag;
    _latestVersionInt = latest;
    _releaseNotes = release['body']?.toString();
    _assetName = null;
    _downloadUrl = null;
    _assetSize = 0;

    // 按设备实际 ABI 选择拆分包，避免装错 ABI（D1）。
    final _ApkAsset? asset = await _pickAssetForDevice(release['assets']);
    if (asset != null) {
      _assetName = asset.name;
      _downloadUrl = asset.url;
      _assetSize = asset.size;
    }

    if (isNewerVersion(latest, currentVersionInt)) {
      _setStage(UpdateStage.available);
    } else {
      _lastCheckWasUpToDate = true;
      _setStage(UpdateStage.idle);
    }
  }

  /// 重定向已确认有新版本：尽力用 API 补全 Release 正文与资产信息。
  ///
  /// API 可能因配额 403、超时或网络问题失败；此时**不进入错误状态**，而是
  /// 降级为「无正文 + 确定性下载地址」（见 [buildDeterministicAssetUrl]），
  /// 确保用户仍能下载（大小未知，下载界面会显示不确定进度）。
  Future<void> _resolveAvailableFromRedirect(
    Dio dio,
    String tag,
    int version,
  ) async {
    try {
      final Map<dynamic, dynamic> release = await _fetchLatestRelease(dio);
      final _ApkAsset? asset = await _pickAssetForDevice(release['assets']);
      _latestVersionLabel = tag;
      _latestVersionInt = version;
      _releaseNotes = release['body']?.toString();
      _assetName = asset?.name;
      _downloadUrl = asset?.url;
      _assetSize = asset?.size ?? 0;
      _setStage(UpdateStage.available);
    } catch (e) {
      logger.warning('获取 Release 详情失败，降级为确定性下载地址: $e');
      final List<String> abis = await _supportedAbis();
      final String? url = buildDeterministicAssetUrl(tag, abis);
      _latestVersionLabel = tag;
      _latestVersionInt = version;
      _releaseNotes = null;
      _assetName = url == null ? null : Uri.parse(url).pathSegments.last;
      _downloadUrl = url;
      // 大小未知：保持 0，下载时按不确定进度处理，下载后仍会校验包名/版本号。
      _assetSize = 0;
      _setStage(UpdateStage.available);
    }
  }

  /// 请求并解析 `GET /releases/latest` 的 JSON 对象。
  ///
  /// 失败（网络 / 非 Map 响应 / 非 2xx）时抛出异常，由调用方决定如何处理。
  Future<Map<dynamic, dynamic>> _fetchLatestRelease(Dio dio) async {
    final Response<dynamic> response = await dio.get<dynamic>(
      apiLatestUrl,
      options: Options(
        headers: const <String, dynamic>{
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'arabic_learning-updater',
        },
      ),
    );

    final dynamic data = response.data;
    if (data is! Map) {
      throw Exception('无法解析 GitHub 返回的更新信息');
    }
    return data;
  }

  /// 按设备实际 ABI 从 assets 中挑选 APK（会触发 MethodChannel 查询 ABI）。
  ///
  /// 仅应在确实需要下载资产的路径上调用；「已是最新」的快速路径不应触发，
  /// 以免无谓地占用桥接与产生副作用。
  Future<_ApkAsset?> _pickAssetForDevice(dynamic assets) async {
    final List<String> abis = await _supportedAbis();
    return _pickApkAsset(assets, abis);
  }

  /// 从 assets 中挑选与设备 ABI 匹配的 APK。
  ///
  /// 工作流只发布按 ABI 拆分的 APK（armeabi-v7a / arm64-v8a / x86_64），
  /// 因此必须按设备实际 ABI 匹配，否则会装到不兼容的包（D1）。匹配顺序：
  /// (1) 文件名含 `universal` 的通用包；
  /// (2) 按 [abis] 优先级（`Build.SUPPORTED_ABIS` 从优到劣）匹配文件名 ABI 标识；
  /// (3) [abis] 为空（非 Android / 测试）时优先 `arm64-v8a`，否则首个 `.apk`。
  /// 均无法匹配时返回 null，由调用方报「未找到可下载的安装包」。
  _ApkAsset? _pickApkAsset(dynamic assets, List<String> abis) {
    if (assets is! List) return null;

    final List<_ApkAsset> apks = <_ApkAsset>[];
    for (final dynamic raw in assets) {
      final _ApkAsset? asset = _apkAssetFrom(raw);
      if (asset != null) apks.add(asset);
    }
    if (apks.isEmpty) return null;

    // (1) 通用包（包含全部 ABI）。
    for (final _ApkAsset asset in apks) {
      if (asset.name.toLowerCase().contains('universal')) return asset;
    }

    // (2) 按设备 ABI 优先级匹配文件名中的 ABI 标识。
    for (final String abi in abis) {
      final String? token = _abiToken(abi);
      if (token == null) continue;
      for (final _ApkAsset asset in apks) {
        if (asset.name.toLowerCase().contains(token)) return asset;
      }
    }

    // (3) 无 ABI 信息（非 Android / 测试）：优先 arm64-v8a，否则任意 APK。
    if (abis.isEmpty) {
      for (final _ApkAsset asset in apks) {
        if (asset.name.toLowerCase().contains('arm64-v8a')) return asset;
      }
      return apks.first;
    }
    return null;
  }

  /// 解析单个 asset；非 `.apk` 或缺少下载地址时返回 null。
  _ApkAsset? _apkAssetFrom(dynamic raw) {
    if (raw is! Map) return null;
    final String name = raw['name']?.toString() ?? '';
    if (!name.toLowerCase().endsWith('.apk')) return null;
    final String url = raw['browser_download_url']?.toString() ?? '';
    if (url.isEmpty) return null;
    final dynamic size = raw['size'];
    return _ApkAsset(
      name: name,
      url: url,
      size: size is num ? size.toInt() : 0,
    );
  }

  /// 将设备 ABI 名映射为资产文件名中的标识；未知 ABI 返回 null。
  static String? _abiToken(String abi) {
    switch (abi) {
      case 'arm64-v8a':
        return 'arm64-v8a';
      case 'armeabi-v7a':
      case 'armeabi':
        return 'armeabi-v7a';
      case 'x86_64':
        return 'x86_64';
      case 'x86':
        return 'x86';
      default:
        return null;
    }
  }

  /// 按 tag 与设备 ABI 列表拼出确定性的 APK 下载地址（API 不可用时的兜底）。
  ///
  /// 形如
  /// `https://github.com/$owner/$repo/releases/download/<tag>/app-<abiToken>-release.apk`。
  /// 资产名与 ABI 标识以 `.github/workflows/FlutterBuild.yml` 中 `--split-per-abi`
  /// 产出的 `app-armeabi-v7a-release.apk` / `app-arm64-v8a-release.apk` /
  /// `app-x86_64-release.apk` 为准（重命名该工作流时请同步此处）。
  ///
  /// [abis] 按设备优先级排列（`Build.SUPPORTED_ABIS` 从优到劣）；返回首个能映射
  /// 出标识的地址。非 Android / 空列表 / 全部 ABI 无法映射时返回 null。
  static String? buildDeterministicAssetUrl(String tag, List<String> abis) {
    for (final String abi in abis) {
      final String? token = _abiToken(abi);
      if (token == null) continue;
      return 'https://github.com/$owner/$repo/releases/download/$tag/'
          'app-$token-release.apk';
    }
    return null;
  }

  /// 查询设备支持的 ABI 列表（最优在前）。
  ///
  /// 通过原生桥接获取 `Build.SUPPORTED_ABIS`；非 Android / 插件缺失 / 出错时
  /// 返回空列表，由 [_pickApkAsset] 走无 ABI 信息的回退分支。
  Future<List<String>> _supportedAbis() async {
    try {
      final List<dynamic>? raw = await _channel
          .invokeMethod<List<dynamic>>('getSupportedAbis');
      if (raw == null) return const <String>[];
      return raw.map((dynamic e) => e.toString()).toList();
    } on MissingPluginException {
      return const <String>[];
    } catch (e) {
      logger.warning('查询设备 ABI 失败: $e');
      return const <String>[];
    }
  }

  // ---------------------------------------------------------------------------
  // 下载
  // ---------------------------------------------------------------------------

  /// 开始下载最新 APK。重复调用（下载中）为空操作。
  void startDownload() {
    if (_stage == UpdateStage.downloading) return;
    if (_downloadUrl == null || (_assetName ?? '').isEmpty) {
      _error = '未找到可下载的安装包';
      _setStage(UpdateStage.error);
      return;
    }
    if (!_canUseFilesystem) {
      _error = '当前平台不支持应用内更新';
      _setStage(UpdateStage.error);
      return;
    }
    unawaited(_performDownload());
  }

  Future<void> _performDownload() async {
    final int gen = ++_downloadGeneration;
    _cancelToken = CancelToken();
    _downloadedBytes = 0;
    _totalBytes = _assetSize > 0 ? _assetSize : -1;
    _speedBytesPerSec = 0;
    _lastNotifiedPercent = -1;
    _lastProgressNotifyMs = 0;
    _speedWindowStartMs = DateTime.now().millisecondsSinceEpoch;
    _speedWindowBytes = 0;
    _error = null;
    _setStage(UpdateStage.downloading);

    try {
      // 资产名由 GitHub 提供，取安全 basename 后再拼接，避免路径穿越（D8）；
      // 校验在任何文件系统写入之前完成。
      final String safeName = _safeAssetName();
      if (safeName.isEmpty) {
        throw Exception('未找到可下载的安装包');
      }
      final io.Directory dir = await _resolveUpdateDirectory();
      if (gen != _downloadGeneration) return;
      await dir.create(recursive: true);
      if (gen != _downloadGeneration) return;
      final String savePath = '${dir.path}/$safeName';
      _savedPath = savePath;

      final Dio dio = _resolveDio();
      await dio.download(
        _downloadUrl!,
        savePath,
        cancelToken: _cancelToken,
        deleteOnError: true,
        options: Options(
          headers: const <String, dynamic>{
            'Accept': 'application/octet-stream',
            'User-Agent': 'arabic_learning-updater',
          },
        ),
        onReceiveProgress: _onReceiveProgress,
      );
      if (gen != _downloadGeneration) return;

      // 大小校验：被截断的下载直接失败，不进入安装（D7）。
      // 只同步读取长度，避免把整个 APK 读入内存。
      if (_assetSize > 0) {
        final int actualSize = io.File(savePath).lengthSync();
        if (actualSize != _assetSize) {
          throw Exception('安装包大小不符，可能下载不完整');
        }
      }

      // 校验下载的安装包，避免安装到错误 / 降级的包。
      final bool valid = await _verifyApk(savePath);
      if (gen != _downloadGeneration) return;
      if (!valid) {
        throw Exception('安装包校验失败（包名或版本号不匹配）');
      }

      _speedBytesPerSec = 0;
      _setStage(UpdateStage.ready);
      unawaited(_notifyDownloadComplete());
    } on DioException catch (e) {
      if (gen != _downloadGeneration) return;
      if (CancelToken.isCancel(e)) {
        // 用户主动取消：cancelDownload 已负责清理与状态复位，这里不重复处理。
        logger.info('下载已取消');
      } else {
        _error = _describeError(e);
        logger.warning('下载失败: $_error');
        _cleanupFile();
        _setStage(UpdateStage.error);
        unawaited(_notifyDownloadInterrupted());
      }
    } catch (e) {
      if (gen != _downloadGeneration) return;
      _error = e;
      logger.warning('下载失败: $e');
      _cleanupFile();
      _setStage(UpdateStage.error);
      unawaited(_notifyDownloadInterrupted());
    }
  }

  /// 取资产名的安全 basename：去掉任意目录分隔符，去掉首尾空白。
  String _safeAssetName() {
    final String raw = _assetName ?? '';
    final int slash = raw.lastIndexOf('/');
    final int backslash = raw.lastIndexOf('\\');
    final int cut = slash > backslash ? slash : backslash;
    return (cut >= 0 ? raw.substring(cut + 1) : raw).trim();
  }

  void _onReceiveProgress(int count, int total) {
    _downloadedBytes = count;
    _totalBytes = total > 0 ? total : (_assetSize > 0 ? _assetSize : -1);

    final int now = DateTime.now().millisecondsSinceEpoch;

    // 速度：约 2 秒的滑动窗口。
    final int elapsed = now - _speedWindowStartMs;
    if (elapsed >= 2000) {
      _speedBytesPerSec = (count - _speedWindowBytes) * 1000 / elapsed;
      _speedWindowStartMs = now;
      _speedWindowBytes = count;
    }

    // 总量未知时以 -1 表示，避免误报 0% 进度。
    final int percent = _totalBytes > 0
        ? ((count * 100) / _totalBytes).clamp(0, 100).toInt()
        : -1;

    // 节流重绘与通知：整数百分比变化时更新，或最多约 4 次/秒。
    final bool percentChanged = percent != _lastNotifiedPercent;
    if (percentChanged || now - _lastProgressNotifyMs >= 250) {
      _lastNotifiedPercent = percent;
      _lastProgressNotifyMs = now;
      if (percent >= 0) {
        unawaited(_notifyDownloadProgress(percent));
      }
      notifyListeners();
    }
  }

  /// 取消下载：中断请求、删除残包并回到空闲。
  ///
  /// 同时自增下载代次，令仍在飞行中的校验回调失效；并清理常驻的下载通知与错误。
  void cancelDownload() {
    _downloadGeneration++;
    _cancelToken?.cancel('用户取消');
    _cancelToken = null;
    _cleanupFile();
    _downloadedBytes = 0;
    _totalBytes = -1;
    _speedBytesPerSec = 0;
    _error = null;
    _lastNotifiedPercent = -1;
    _setStage(UpdateStage.idle);
    unawaited(notifications.cancelUpdateNotification());
  }

  // ---------------------------------------------------------------------------
  // 安装
  // ---------------------------------------------------------------------------

  /// 触发安装：若缺少「安装未知来源应用」权限，则申请并标记
  /// [needsInstallPermission]（UI 展示引导），否则直接调起系统安装器。
  ///
  /// 返回是否成功调起安装器；失败时保留 [UpdateStage.ready]，用户可重试（D2）。
  Future<bool> install() async {
    if (_stage != UpdateStage.ready || _savedPath == null) return false;
    _needsInstallPermission = false;
    notifyListeners();

    if (!(await _canRequestPackageInstalls())) {
      _needsInstallPermission = true;
      notifyListeners();
      await _requestInstallPermission();
      return false;
    }
    return _launchInstall();
  }

  /// 应用从后台恢复时由 UI 调用：重新检查权限，已授权则继续安装。
  ///
  /// 不再依赖 [needsInstallPermission] 作为前置条件，每次都会重新查询权限；
  /// 返回是否成功调起安装器，权限仍缺失时返回 false（D2）。
  Future<bool> retryInstallIfPermitted() async {
    if (_stage != UpdateStage.ready || _savedPath == null) return false;
    if (await _canRequestPackageInstalls()) {
      _needsInstallPermission = false;
      notifyListeners();
      return _launchInstall();
    }
    return false;
  }

  Future<bool> _canRequestPackageInstalls() async {
    try {
      return (await _channel.invokeMethod<bool>('canRequestPackageInstalls')) ??
          false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      logger.warning('查询安装权限失败: $e');
      return false;
    }
  }

  Future<void> _requestInstallPermission() async {
    try {
      await _channel.invokeMethod<void>('requestInstallPermission');
    } on MissingPluginException {
      logger.warning('当前平台不支持申请安装权限');
    } catch (e) {
      logger.warning('申请安装权限失败: $e');
    }
  }

  /// 调起系统安装器。
  ///
  /// 返回是否成功启动；失败时写入 [error] 但**保留** [UpdateStage.ready]，
  /// 避免一次失败就永久卡死、逼迫用户重新下载（D2）。
  Future<bool> _launchInstall() async {
    try {
      final bool ok =
          (await _channel.invokeMethod<bool>('installApk', <String, dynamic>{
            'path': _savedPath,
          })) ??
          false;
      if (!ok) {
        _error = '安装器启动失败';
        notifyListeners();
        return false;
      }
      // 安装器已启动：下载完成通知的使命结束，撤掉常驻通知（D4）。
      unawaited(notifications.cancelUpdateNotification());
      return true;
    } on MissingPluginException {
      _error = '当前平台不支持应用内安装';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 启动提示 / 跳过
  // ---------------------------------------------------------------------------

  /// 本次进程内不再提示当前最新版本的更新。
  void dismissForSession() {
    _dismissedVersion = _latestVersionInt;
    notifyListeners();
  }

  /// 跳过当前最新版本（持久化到设置）。
  Future<void> skipVersion() async {
    final int? latest = _latestVersionInt;
    if (latest == null) return;
    AppData().config = AppData().config.copyWith(
      regular: AppData().config.regular.copyWith(skippedVersion: latest),
    );
    await _persistSetting();
    notifyListeners();
  }

  /// 恢复被跳过的版本提示（设置页「恢复提示」）。
  Future<void> unskipVersion() async {
    AppData().config = AppData().config.copyWith(
      regular: AppData().config.regular.copyWith(skippedVersion: 0),
    );
    await _persistSetting();
    notifyListeners();
  }

  /// 直接落盘设置。等价于 `Global.updateSetting(refresh: false)` 的持久化部分：
  /// [Global] 是通过 Provider 提供的实例，服务层无法取得，故此处只做存储写入。
  Future<void> _persistSetting() async {
    await AppData().storage.setString(
      'settingData',
      jsonEncode(AppData().config.toMap()),
    );
  }

  // ---------------------------------------------------------------------------
  // 内部工具
  // ---------------------------------------------------------------------------

  /// 解析网络客户端；注入的 Dio 原样返回（测试不设超时），
  /// 自建的 Dio 设置连接 / 接收 / 发送超时，避免黑洞连接使检查永久挂起（D3）。
  Dio _resolveDio() {
    final Dio? injected = _injectedDio;
    if (injected != null) return injected;
    return createDio(
      useDoh: AppData().config.regular.useDoh,
      options: BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
  }

  bool get _canUseFilesystem =>
      !kIsWeb && (_documentsDirectoryProvider != null || io.Platform.isAndroid);

  /// 解析 APK 的存放目录。
  ///
  /// 默认使用应用支持目录（Android 上等价于 `getFilesDir()`），落在 FileProvider
  /// 的 `<files-path>` 白名单内；[documentsDirectoryProvider] 仅为测试注入保留
  /// （历史命名，注入值代表「支持目录」）（D9）。
  Future<io.Directory> _resolveUpdateDirectory() async {
    final Future<io.Directory> Function()? provider =
        _documentsDirectoryProvider;
    final io.Directory base = provider != null
        ? await provider()
        : (await path_provider.getApplicationSupportDirectory())
              as io.Directory;
    return io.Directory('${base.path}/arabicLearning/update');
  }

  /// 校验下载的 APK：确认包名一致且版本号不低于当前安装版本。
  ///
  /// 仅「非 Android / 无插件（如测试）」时因无法校验而放行；其余情况一律
  /// **失败关闭**，避免被截断或包名不符的安装包进入安装流程（D7）。
  Future<bool> _verifyApk(String path) async {
    final Future<bool> Function(String path)? injected = _injectedApkVerifier;
    if (injected != null) return injected(path);
    if (kIsWeb || !io.Platform.isAndroid) return true;
    try {
      final dynamic raw = await _channel.invokeMethod<dynamic>(
        'verifyApk',
        <String, dynamic>{'path': path},
      );
      if (raw is! Map) {
        logger.warning('APK 校验失败：无法解析原生返回信息');
        return false;
      }
      final String pkg = raw['packageName']?.toString() ?? '';
      if (pkg.isEmpty || pkg != expectedPackageName) {
        logger.warning('安装包包名不匹配: $pkg');
        return false;
      }
      final int? apkCode = _asInt(raw['versionCode']);
      final int? currentCode = _asInt(raw['currentVersionCode']);
      if (apkCode == null || currentCode == null || apkCode < currentCode) {
        logger.warning('安装包版本号($apkCode)不合法或低于当前版本($currentCode)');
        return false;
      }
      return true;
    } on MissingPluginException {
      return true;
    } catch (e) {
      logger.warning('APK 校验失败: $e');
      return false;
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _cleanupFile() {
    final String? path = _savedPath;
    if (path == null) return;
    try {
      final io.File file = io.File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (e) {
      logger.warning('清理安装包失败: $e');
    }
  }

  void _setStage(UpdateStage stage) {
    _stage = stage;
    notifyListeners();
  }

  /// 将异常转换为适合展示的文案。
  Object _describeError(Object e) {
    if (e is DioException) {
      final Response<dynamic>? response = e.response;
      if (response != null) {
        if (response.statusCode == 403) {
          final String? remaining = response.headers.value(
            'x-ratelimit-remaining',
          );
          if (remaining == '0') {
            return 'GitHub API 请求次数已达上限，请稍后再试';
          }
          return 'GitHub 拒绝访问（403）';
        }
        return 'GitHub 返回状态码 ${response.statusCode}';
      }
      return '网络请求失败: ${e.message}';
    }
    return e;
  }

  Future<void> _notifyDownloadProgress(int percent) async {
    if (kIsWeb || !io.Platform.isAndroid) return;
    try {
      await notifications.showUpdateDownloadProgress(percent: percent);
    } catch (e) {
      logger.fine('更新下载进度通知失败: $e');
    }
  }

  Future<void> _notifyDownloadComplete() async {
    if (kIsWeb || !io.Platform.isAndroid) return;
    try {
      await notifications.showUpdateDownloadComplete();
    } catch (e) {
      logger.fine('更新完成通知失败: $e');
    }
  }

  Future<void> _notifyDownloadInterrupted() async {
    if (kIsWeb || !io.Platform.isAndroid) return;
    try {
      await notifications.showUpdateDownloadInterrupted();
    } catch (e) {
      logger.fine('更新中断通知失败: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 测试辅助
  // ---------------------------------------------------------------------------

  /// 直接填充发布信息，便于测试在不触网的情况下驱动下载流程。
  @visibleForTesting
  void debugSetRelease({
    String? label,
    int? versionInt,
    String? notes,
    String? url,
    String? name,
    int size = 0,
  }) {
    _latestVersionLabel = label;
    _latestVersionInt = versionInt;
    _releaseNotes = notes;
    _downloadUrl = url;
    _assetName = name;
    _assetSize = size;
  }
}

/// 内部使用的 APK 资源描述。
class _ApkAsset {
  final String name;
  final String url;
  final int size;

  const _ApkAsset({required this.name, required this.url, required this.size});
}

/// 重定向探测的三种结果。
enum _ReleaseProbeKind {
  /// 成功从重定向 `Location` 中解析出 Release tag。
  tag,

  /// 有重定向但没有 `/releases/tag/` 段：仓库尚未发布任何 Release。
  noReleases,

  /// 无重定向 / 缺少 `location` / 任意异常：需回退 API 流程。
  unknown,
}

/// `/releases/latest` 重定向探测结果（见 [_ReleaseProbeKind]）。
class _ReleaseProbe {
  final _ReleaseProbeKind kind;

  /// 探测到的 tag；仅当 [kind] 为 [_ReleaseProbeKind.tag] 时非空。
  final String? tag;

  const _ReleaseProbe([this.kind = _ReleaseProbeKind.unknown, this.tag]);
}
