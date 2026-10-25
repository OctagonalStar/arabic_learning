import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 测试环境用的临时目录（mock 后的 path_provider 返回值）。
const String testDocumentsPath = '/tmp/arabic_learning_test_docs';

/// SQLite 测试库文件的专用目录。
///
/// 必须显式传给 `openDriftStore(databasePath: ...)`：drift 的数据库在后台
/// isolate 里打开，拿不到 `flutter test` 中 mock 的 `path_provider` 通道，
/// 否则会落到开发机的真实应用文档目录（仓库外，且跨测试文件互相污染）。
/// 统一放在 `/tmp/opencode` 这个已批准的临时区。
const String testDbDir = '/tmp/opencode/arabic_learning_db_test';

/// mock `path_provider` 的平台通道。
///
/// `AppData.init()` 在非 Web 平台会调用
/// `getApplicationDocumentsDirectory()`；测试进程（Linux VM）没有真实平台
/// 实现，若不在测试侧拦截会抛出 `MissingPluginException`。
/// 仅影响测试，生产代码路径不变。
void mockPathProvider() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall call) async => testDocumentsPath,
  );
}

/// mock `shared_preferences`（本地包装 `package_replacement/storage.dart`
/// 底层使用的插件实现）。
void mockStorage(Map<String, Object> values) {
  SharedPreferences.setMockInitialValues(values);
  // 首次启动会自动导入内置词库（1.7 万词），那属于生产行为；
  // 测试统一关掉，让每个用例从空词库开始，断言才有确定性。
  AppData.seedBuiltinDicts = false;
}
