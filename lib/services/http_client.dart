// Dio 客户端平台选择入口：设备端用 `http_client_io.dart`，Web 端用
// `http_client_web.dart`。业务代码统一从这里 `createDio()` 获取实例。
export 'http_client_web.dart' if (dart.library.io) 'http_client_io.dart';
