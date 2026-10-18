// Dio 客户端工厂（Web 端实现）。
//
// 浏览器没有自定义 DNS / DoH 的能力，因此 [useDoh] 被忽略，始终返回默认 [Dio]。
// 设备端对应 `http_client_io.dart`，由 `http_client.dart` 条件导出选择。

import 'package:dio/dio.dart';

/// 创建 [Dio] 实例。
///
/// Web 端无法自定义 DNS，[useDoh] 参数仅用于与设备端保持签名一致，会被忽略。
Dio createDio({bool? useDoh, BaseOptions? options}) {
  return Dio(options);
}
