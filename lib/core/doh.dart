// DoH 引擎的平台选择入口：设备端用 `doh_io.dart`，Web 端用 `doh_web.dart`。
// 具体实现请勿直接 import 分支文件，统一从这里引入。
export 'doh_web.dart' if (dart.library.io) 'doh_io.dart';
