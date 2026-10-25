// `Global.patchConfig` 的行为测试。
//
// 这个入口把「读当前配置 → copyWith → 写回 → 落盘」收敛成一处，取代了散落
// 各页面约 25 处手写样板。这里锁定三条不变量：
//   1. patch 的返回值真的写进了 `AppData().config`；
//   2. 内容未变时不写盘（复用 updateSetting 的跳过逻辑，避免整份重写偏好文件）；
//   3. 连续 patch 中只有真正改变了内容的那次写盘（等价于「合并多次写为一次」）。

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
    // `AppData` 是单例且 `init()` 不重建 `config`（那由 `Global.conveySetting`
    // 负责），这里显式复位，避免上一个用例的配置泄漏到下一个。
    AppData().config = const Config();
    await AppData().init();
    Global.debugSettingWriteCount = 0;
  });

  test('patch 生效：顶层与子配置的改动都写回 AppData().config', () async {
    await Global().patchConfig(
      (Config config) => config.copyWith(
        user: '阿里',
        regular: config.regular.copyWith(theme: 3, font: 1),
        learning: config.learning.copyWith(wordLookupRealtime: false),
      ),
      refresh: false,
    );

    expect(AppData().config.user, '阿里');
    expect(AppData().config.regular.theme, 3);
    expect(AppData().config.regular.font, 1);
    expect(AppData().config.learning.wordLookupRealtime, isFalse);
  });

  test('patch 生效：改动已落盘，重新读取存储可见', () async {
    await Global().patchConfig(
      (Config config) => config.copyWith(
        regular: config.regular.copyWith(font: 2),
      ),
      refresh: false,
    );

    final Config stored = Config.buildFromMap(
      jsonDecode(AppData().storage.getString('settingData')!)
          as Map<String, dynamic>,
    );
    expect(stored.regular.font, 2);
    expect(Global.debugSettingWriteCount, 1);
  });

  test('内容未变不写盘：patch 返回等价配置时 debugSettingWriteCount 不增加', () async {
    // 先写一次，把存储内容对齐到当前 config 的序列化形态。
    await Global().patchConfig(
      (Config config) => config.copyWith(regular: config.regular.copyWith(theme: 1)),
      refresh: false,
    );
    final int writesAfterFirst = Global.debugSettingWriteCount;
    expect(writesAfterFirst, 1);

    // 幂等 patch：把 theme 重新设成同一个值，序列化结果完全相同。
    await Global().patchConfig(
      (Config config) => config.copyWith(regular: config.regular.copyWith(theme: 1)),
      refresh: false,
    );

    expect(Global.debugSettingWriteCount, writesAfterFirst,
        reason: '内容没变就不该重写整个偏好文件');
  });

  test('连续 patch 合并为一次写盘：只有内容真的变了才写', () async {
    final int writesBefore = Global.debugSettingWriteCount;

    // 模拟弹层里连续改两个字段（列数 + 实时查找）：两次 patch 都改变了内容，
    // 但每次都是「当前完整配置」的快照，不会出现中途快照覆盖最终结果。
    await Global().patchConfig(
      (Config config) => config.copyWith(
        learning: config.learning.copyWith(overviewForceColumn: 2),
      ),
      refresh: false,
    );
    await Global().patchConfig(
      (Config config) => config.copyWith(
        learning: config.learning.copyWith(
          overviewForceColumn: 2,
          wordLookupRealtime: false,
        ),
      ),
      refresh: false,
    );
    final int writesAfterTwo = Global.debugSettingWriteCount;
    expect(writesAfterTwo, writesBefore + 2,
        reason: '两次 patch 各自改变了内容，各自落盘');

    // 后续重复 patch 同一个终态：内容不变，一律跳过写盘（等价于合并成一次写）。
    for (int i = 0; i < 3; i++) {
      await Global().patchConfig(
        (Config config) => config.copyWith(
          learning: config.learning.copyWith(
            overviewForceColumn: 2,
            wordLookupRealtime: false,
          ),
        ),
        refresh: false,
      );
    }
    expect(Global.debugSettingWriteCount, writesAfterTwo,
        reason: '连续 patch 到同一终态只写盘一次');

    // 落盘内容是最终状态（没有中途快照覆盖）。
    final Config stored = Config.buildFromMap(
      jsonDecode(AppData().storage.getString('settingData')!)
          as Map<String, dynamic>,
    );
    expect(stored.learning.overviewForceColumn, 2);
    expect(stored.learning.wordLookupRealtime, isFalse);
  });

  test('单次 patch 内改多个字段只写盘一次', () async {
    final int writesBefore = Global.debugSettingWriteCount;

    await Global().patchConfig(
      (Config config) => config.copyWith(
        regular: config.regular.copyWith(theme: 5, font: 2),
        learning: config.learning.copyWith(overviewForceColumn: 4),
      ),
      refresh: false,
    );

    expect(Global.debugSettingWriteCount, writesBefore + 1);
    expect(AppData().config.regular.theme, 5);
    expect(AppData().config.regular.font, 2);
    expect(AppData().config.learning.overviewForceColumn, 4);
  });

  test('patch 抛错时不改动配置（读-改-写是原子的）', () async {
    final Config before = AppData().config;

    await expectLater(
      Global().patchConfig((Config config) => throw StateError('boom')),
      throwsStateError,
    );

    expect(identical(AppData().config, before), isTrue);
  });
}
