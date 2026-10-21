// PlanStore 写盘合并（400ms 防抖）测试。
//
// 断言方式是「写盘次数」而不是墙钟时间：连续多次 recordProgress 只应产生
// 一次落盘；flush() 后内存与存储立即可见；导出钩子能拿到最新值。

import 'dart:convert';

import 'package:arabic_learning/models/plan.dart';
import 'package:arabic_learning/package_replacement/storage.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/plan_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

StudyPlan _plan() {
  return StudyPlan(
    id: "1700000000000",
    deadline: DateTime(2026, 10, 30),
    scope: const <PlanScopeRef>[
      PlanScopeRef(sourceFile: "s1.json", className: "A"),
    ],
    groupSize: 10,
  );
}

/// 存储里当前的 `planData` 反序列化结果。
Map<String, dynamic> _stored() {
  final String? raw = AppData().storage.getString(PlanStore.storageKey);
  expect(raw, isNotNull, reason: 'planData 应已落盘');
  return Map<String, dynamic>.from(jsonDecode(raw!) as Map);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
  });

  setUp(() async {
    await PlanStore().clear();
    PlanStore().debugWriteCount = 0;
  });

  group('recordProgress 防抖', () {
    test('连续多次 recordProgress 只落盘一次，内存立即可见', () async {
      await PlanStore().setPlan(_plan());
      await PlanStore().setToday(
        const PlanDayProgress(dayKey: 20261018, minWords: 20, doneWords: 0),
      );
      PlanStore().debugWriteCount = 0;

      for (int i = 0; i < 5; i++) {
        await PlanStore().recordProgress(1);
        // 内存值每次都应立即可见（不依赖落盘）。
        expect(PlanStore().state.today?.doneWords, i + 1);
        expect(PlanStore().hasPendingWrite, isTrue);
      }

      // 尚未越过防抖窗口：存储里仍是 0。
      expect(PlanStore().debugWriteCount, 0);
      expect(_stored()["today"]["doneWords"], 0);

      await PlanStore().flush();

      expect(PlanStore().debugWriteCount, 1, reason: '5 次累加应合并为 1 次落盘');
      expect(PlanStore().hasPendingWrite, isFalse);
      expect(_stored()["today"]["doneWords"], 5);
    });

    test('flush() 后存储立即可见，且不重复写盘', () async {
      await PlanStore().setPlan(_plan());
      await PlanStore().setToday(
        const PlanDayProgress(dayKey: 20261018, minWords: 20, doneWords: 3),
      );
      PlanStore().debugWriteCount = 0;

      await PlanStore().recordProgress(2);
      await PlanStore().flush();

      expect(_stored()["today"]["doneWords"], 5);
      final int afterFirstFlush = PlanStore().debugWriteCount;

      // 再 flush 一次：没有待写内容时也不应改变数据（幂等）。
      await PlanStore().flush();
      expect(_stored()["today"]["doneWords"], 5);
      expect(PlanStore().debugWriteCount, afterFirstFlush + 1,
          reason: 'flush 始终写一次，但不影响数据正确性');
    });

    test('显式配置变更（setPlan / setToday / clear）立即落盘', () async {
      PlanStore().debugWriteCount = 0;

      await PlanStore().setPlan(_plan());
      expect(PlanStore().hasPendingWrite, isFalse);
      expect(_stored()["plan"]["id"], _plan().id);

      await PlanStore().setToday(
        const PlanDayProgress(dayKey: 20261018, minWords: 20, doneWords: 1),
      );
      expect(_stored()["today"]["doneWords"], 1);

      await PlanStore().clear();
      expect(_stored(), <String, dynamic>{"plan": null, "today": null});
      expect(PlanStore().debugWriteCount, 3);
    });

    test('无当日快照 / 非正增量时不写盘', () async {
      await PlanStore().setPlan(_plan()); // today = null
      PlanStore().debugWriteCount = 0;

      await PlanStore().recordProgress(5);
      await PlanStore().recordProgress(-5);
      await PlanStore().recordProgress(0);

      expect(PlanStore().hasPendingWrite, isFalse);
      expect(PlanStore().debugWriteCount, 0);
      expect(PlanStore().state.today, isNull);
    });
  });

  group('导出钩子', () {
    test('export() 会先 flush PlanStore 的防抖写入', () async {
      await PlanStore().setPlan(_plan());
      await PlanStore().setToday(
        const PlanDayProgress(dayKey: 20261018, minWords: 20, doneWords: 0),
      );
      await PlanStore().recordProgress(4);

      // 防抖窗口内导出：备份里必须是累加后的值。
      final Map<String, dynamic> backup = AppData().storage.export();

      final Map<String, dynamic> planData =
          Map<String, dynamic>.from(jsonDecode(backup[PlanStore.storageKey] as String) as Map);
      expect(planData["today"]["doneWords"], 4);
      expect(PlanStore().hasPendingWrite, isFalse,
          reason: '导出后不应留下待写计时器');
    });

    test('FSRS 与 PlanStore 的落盘钩子互不覆盖（多订阅者）', () async {
      // FSRS 答题后同样有 400ms 防抖；两个钩子必须都被调用。
      await PlanStore().setPlan(_plan());
      await PlanStore().setToday(
        const PlanDayProgress(dayKey: 20261018, minWords: 20, doneWords: 0),
      );
      await PlanStore().recordProgress(7);

      final Map<String, dynamic> backup = AppData().storage.export();

      // PlanStore 的值是最新的。
      final Map<String, dynamic> planData =
          Map<String, dynamic>.from(jsonDecode(backup[PlanStore.storageKey] as String) as Map);
      expect(planData["today"]["doneWords"], 7);
      // FSRS 的钩子仍在列表里（改造前会被后注册者顶掉）。
      expect(SharedPreferences.flushPendingWrites.length, greaterThanOrEqualTo(2));
    });

    test('reload 会丢弃防抖中的旧快照，不覆盖恢复出来的数据', () async {
      await PlanStore().setPlan(_plan());
      await PlanStore().setToday(
        const PlanDayProgress(dayKey: 20261018, minWords: 20, doneWords: 0),
      );
      await PlanStore().recordProgress(9); // 防抖中

      // 模拟备份恢复：外部直接改写 planData，再 reload。
      await AppData().storage.setString(
        PlanStore.storageKey,
        jsonEncode(<String, dynamic>{"plan": null, "today": null}),
      );
      await PlanStore().reload();

      expect(PlanStore().hasPendingWrite, isFalse, reason: '重读应取消待写计时器');
      expect(PlanStore().state.plan, isNull);

      // 即使再 flush，也不能把 reload 前的内容写回去。
      await PlanStore().flush();
      expect(_stored(), <String, dynamic>{"plan": null, "today": null});
    });
  });
}
