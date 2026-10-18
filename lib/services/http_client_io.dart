// Dio 客户端工厂（设备端实现）：可按配置启用 DoH 解析域名。
//
// Web 端对应 `http_client_web.dart`，由 `http_client.dart` 条件导出选择。

import 'package:arabic_learning/core/doh.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// 创建 [Dio] 实例，启用 DoH 时使用自定义 DNS 的 [HttpClient]。
///
/// [useDoh] 解析顺序：显式传入 -> `AppData().config.regular.useDoh`
/// （`AppData` 尚未就绪时回退 `false`）。启用时通过 [buildDohHttpClient]
/// 设置 [IOHttpClientAdapter]；否则保留 Dio 默认适配器。
Dio createDio({bool? useDoh, BaseOptions? options}) {
  final Dio dio = Dio(options);
  final bool effective = useDoh ?? _configUseDoh();
  if (effective) {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => buildDohHttpClient(),
    );
  }
  return dio;
}

/// 从全局配置读取 DoH 开关；`AppData` 未初始化时安全回退 `false`。
bool _configUseDoh() {
  try {
    return AppData().config.regular.useDoh;
  } catch (_) {
    return false;
  }
}
