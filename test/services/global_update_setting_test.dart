// `Global.updateSetting` 的写盘策略测试。
//
// 启动路径上 `updateSetting()` 原本每次都会把配置整份重新 `setString`：
// 而 `shared_preferences` 的每次写入都会重写整个偏好文件（里面还有 2~6MB 的
// `wordData`）。这里锁定「内容没变就不写、内容变了必须写」两条不变量。

import 'dart:convert';

import 'package:arabic_learning/models/config.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    mockPathProvider();
  });

  setUp(() async {
    mockStorage(<String, Object>{
      'settingData': jsonEncode(const Config().toMap()),
    });
    AppData().debugResetForInit();
    await AppData().init();
  });

  test('配置未变化时写回的内容与原有内容一致（幂等）', () async {
    final String before = AppData().storage.getString('settingData')!;

    await Global().updateSetting(refresh: false);
    final String afterFirst = AppData().storage.getString('settingData')!;
    await Global().updateSetting(refresh: false);
    final String afterSecond = AppData().storage.getString('settingData')!;

    // 语义不变，且多次调用结果稳定（不会累积差异）
    expect(Config.buildFromMap(jsonDecode(afterFirst)).toMap(),
        Config.buildFromMap(jsonDecode(before)).toMap());
    expect(afterSecond, afterFirst);
  });

  test('真实启动路径（conveySetting + updateSetting）不再重写配置', () async {
    // 完整复现 Global._initOnce 的非首启分支：conveySetting 从存储重建配置，
    // 然后 updateSetting() 把它写回去 —— 内容没变，应被跳过。
    final String before = AppData().storage.getString('settingData')!;
    final int writesBefore = Global.debugSettingWriteCount;

    Global().conveySetting();
    await Global().updateSetting(refresh: false);

    expect(Global.debugSettingWriteCount, writesBefore,
        reason: '启动路径上没有配置变化就不该写盘');
    expect(AppData().storage.getString('settingData'), before);
  });

  test('版本升级（lastVersion 变化）时启动路径仍会写盘', () async {
    // 旧版本留下的配置：lastVersion 与当前不同 → conveySetting 会改写它，
    // 此时内容确实变了，必须落盘。
    final Map<String, dynamic> old = const Config(lastVersion: -1).toMap();
    AppData().storage.setString('settingData', jsonEncode(old));
    final int writesBefore = Global.debugSettingWriteCount;

    Global().conveySetting();
    await Global().updateSetting(refresh: false);

    expect(Global.debugSettingWriteCount, writesBefore + 1);
    final dynamic decoded = jsonDecode(
        AppData().storage.getString('settingData')!) as Map<String, dynamic>;
    expect(decoded['LastVersion'], AppData().config.lastVersion);
    expect(decoded['LastVersion'], isNot(-1));
  });

  test('配置内容变化时仍会真正写盘（不会被跳过逻辑吞掉）', () async {
    // 旧数据的「部分键」形态：缺 `LastTermVersion`，解码后 toMap() 会补齐
    // 默认值 → 内容确实与存储里的原文不同，必须写盘。
    final Map<String, dynamic> legacy = const Config().toMap()
      ..remove('LastTermVersion');
    AppData().storage.setString('settingData', jsonEncode(legacy));
    final String before = AppData().storage.getString('settingData')!;

    AppData().config = Config.buildFromMap(jsonDecode(before));
    await Global().updateSetting(refresh: false);

    final String after = AppData().storage.getString('settingData')!;
    expect(after, isNot(before), reason: '内容变了就必须写盘');
    final dynamic decoded = jsonDecode(after) as Map<String, dynamic>;
    expect(decoded.containsKey('LastTermVersion'), isTrue,
        reason: '补齐后的完整形态应落盘');
  });

  test('显式传入 settingData 时按新配置写盘', () async {
    final Map<String, dynamic> changed = const Config().toMap()
      ..['User'] = 'from-map';

    await Global().updateSetting(settingData: changed, refresh: false);

    final dynamic decoded =
        jsonDecode(AppData().storage.getString('settingData')!) as Map<String, dynamic>;
    expect(decoded['User'], 'from-map');
    expect(AppData().config.user, 'from-map');
  });
}
