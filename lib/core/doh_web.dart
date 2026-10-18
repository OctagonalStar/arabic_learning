// DoH（DNS over HTTPS）解析引擎（Web 端空实现）。
//
// Web 端运行在浏览器沙箱内，无法自定义 DNS / 建立裸 socket，因此此处仅提供
// 与设备端相同的公开名称，调用时统一抛出 [UnsupportedError]。
// 真正的实现见 `doh_io.dart`，由 `doh.dart` 条件导出选择。

/// Web 端 DoH 解析器占位实现：不支持自定义 DNS。
class DohResolver {
  DohResolver._();

  /// 全局单例（与设备端名称一致）。
  static final DohResolver instance = DohResolver._();

  /// 解析结果缓存有效期（占位常量）。
  static const Duration cacheTtl = Duration(seconds: 60);

  /// 解析失败（负缓存）有效期（占位常量，与设备端公开名称一致）。
  static Duration negativeCacheTtl = const Duration(seconds: 30);

  /// DoH 失败时是否回退系统 DNS（占位开关，Web 端无实际 DoH 实现）。
  static bool fallbackToSystemDns = true;

  /// Web 端不支持 DoH 解析。
  Future<List<dynamic>> lookup(String host) {
    throw UnsupportedError('Web 端不支持 DoH 域名解析');
  }

  /// Web 端不支持 DoH 解析。
  Future<dynamic> resolve(String host) {
    throw UnsupportedError('Web 端不支持 DoH 域名解析');
  }

  /// 无缓存可清理。
  void clearCache() {}
}

/// Web 端没有 `HttpClient` 类型，无法构建自定义 DNS 的客户端；
/// 该名称仅为与设备端保持一致，调用即抛出 [UnsupportedError]。
/// Web 端应直接使用 Dart 默认的网络栈（见 `services/http_client_web.dart`）。
Never buildDohHttpClient() {
  throw UnsupportedError('Web 端不支持自定义 DNS 的 HttpClient');
}
