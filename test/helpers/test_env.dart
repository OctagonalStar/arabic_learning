import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 测试环境用的临时目录（mock 后的 path_provider 返回值）。
const String testDocumentsPath = '/tmp/arabic_learning_test_docs';

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
}
