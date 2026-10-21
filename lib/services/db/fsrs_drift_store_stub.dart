// Web 端的 drift 存储空实现。
//
// Web 不能引入 drift/wasm：`fsrs_store_factory.dart` 通过条件导入在 Web 上
// 选择本文件，`openFsrsDriftStore()` 恒返回 null，调用方回退 `JsonFsrsStore`
// （即原来的 IndexedDB / shared_preferences 路径），行为与改造前一致。
//
// 写法参考 `lib/package_replacement/` 下的 `fake_*.dart`。

import 'package:arabic_learning/services/db/fsrs_store.dart' show FsrsStore;

/// Web 恒为 null：表示当前平台不使用 SQLite。
///
/// 保留与原生实现一致的签名（含仅测试用的 [databasePath]），
/// 这样 `fsrs_store_factory.dart` 的条件导入两侧可以直接互换。
Future<FsrsStore?> openFsrsDriftStore({
  String? legacyJson,
  Map<String, String>? legacyHotKv,
  String? databasePath,
}) async => null;
