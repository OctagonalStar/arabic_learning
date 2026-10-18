import 'dart:convert';

import 'package:arabic_learning/models/plan.dart';
import 'package:arabic_learning/package_replacement/storage.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/plan_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

StudyPlan _samplePlan({
  String id = "1700000000000",
  DateTime? deadline,
  List<PlanScopeRef>? scope,
  int groupSize = 10,
}) {
  return StudyPlan(
    id: id,
    deadline: deadline ?? DateTime(2026, 10, 30),
    scope: scope ?? <PlanScopeRef>[const PlanScopeRef(sourceFile: "s1.json", className: "A")],
    groupSize: groupSize,
    chain: const PlanChain(sections: <int>[0, 2], shuffleWithinSection: true),
    shuffleClasses: true,
    streakGate: true,
    configuredDayKey: 20261018,
  );
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
  });

  group('数据模型序列化', () {
    test('PlanScopeRef：toMap / fromMap / key', () {
      const PlanScopeRef ref = PlanScopeRef(sourceFile: "s1.json", className: "A");
      expect(ref.toMap(), <String, dynamic>{"sourceFile": "s1.json", "className": "A"});
      expect(ref.key, "s1.json\u0000A");

      final PlanScopeRef restored = PlanScopeRef.fromMap(ref.toMap());
      expect(restored, ref);
      // 坏类型回退为空串，不抛异常
      expect(PlanScopeRef.fromMap(<String, dynamic>{"sourceFile": 1}).sourceFile, "");
    });

    test('PlanChain：清洗越界题型 / 空链条回退默认', () {
      expect(const PlanChain().isValid, isTrue);
      expect(const PlanChain().hasNonCardType, isTrue);

      final PlanChain cleaned = PlanChain.fromMap(<String, dynamic>{
        "sections": <int>[9, 2, -1, 3],
        "shuffleWithinSection": true,
      });
      expect(cleaned.sections, <int>[2, 3]);
      expect(cleaned.shuffleWithinSection, isTrue);

      final PlanChain fallback = PlanChain.fromMap(<String, dynamic>{
        "sections": <int>[7, 8],
      });
      expect(fallback.sections, <int>[0, 2]);

      const PlanChain onlyCard = PlanChain(sections: <int>[0]);
      expect(onlyCard.hasNonCardType, isFalse);
      expect(onlyCard.isValid, isFalse);
    });

    test('StudyPlan：toMap / fromMap 往返一致', () {
      final StudyPlan plan = _samplePlan();
      final Map<String, dynamic> map = plan.toMap();
      expect(map["deadline"], "2026-10-30");
      expect(map["groupSize"], 10);

      final StudyPlan restored = StudyPlan.fromMap(map);
      expect(restored.id, plan.id);
      expect(restored.deadline, DateTime(2026, 10, 30));
      expect(restored.scope, plan.scope);
      expect(restored.groupSize, plan.groupSize);
      expect(restored.chain.sections, <int>[0, 2]);
      expect(restored.chain.shuffleWithinSection, isTrue);
      expect(restored.shuffleClasses, isTrue);
      expect(restored.streakGate, isTrue);
      expect(restored.configuredDayKey, 20261018);
    });

    test('StudyPlan：字段清洗（组大小 1..50、scope 去重、deadline 取零点）', () {
      final StudyPlan tooSmall = StudyPlan(
        id: "1",
        deadline: DateTime(2026, 10, 30, 15, 30),
        scope: <PlanScopeRef>[
          const PlanScopeRef(sourceFile: "s1.json", className: "A"),
          const PlanScopeRef(sourceFile: "s1.json", className: "A"),
        ],
        groupSize: 0,
      );
      expect(tooSmall.groupSize, 1);
      expect(tooSmall.scope.length, 1);
      expect(tooSmall.deadline, DateTime(2026, 10, 30));

      expect(_samplePlan(groupSize: 99).groupSize, 50);
    });

    test('PlanDayProgress：toMap / fromMap 往返一致', () {
      const PlanDayProgress progress =
          PlanDayProgress(dayKey: 20261018, minWords: 20, doneWords: 5);
      final Map<String, dynamic> map = progress.toMap();
      expect(map, <String, dynamic>{"dayKey": 20261018, "minWords": 20, "doneWords": 5});

      final PlanDayProgress restored = PlanDayProgress.fromMap(map);
      expect(restored.dayKey, 20261018);
      expect(restored.minWords, 20);
      expect(restored.doneWords, 5);
    });

    test('PlanState：toMap / fromMap 往返一致', () {
      final PlanState state = PlanState(
        plan: _samplePlan(),
        today: const PlanDayProgress(dayKey: 20261018, minWords: 20, doneWords: 3),
      );
      final Map<String, dynamic> map = state.toMap();
      expect(map["plan"], isA<Map<String, dynamic>>());
      expect(map["today"], isA<Map<String, dynamic>>());

      final PlanState restored = PlanState.fromMap(map);
      expect(restored.plan?.id, state.plan?.id);
      expect(restored.today?.doneWords, 3);
    });

    test('PlanState：缺字段 / 坏类型 / 坏日期返回 empty', () {
      expect(PlanState.fromMap(<String, dynamic>{}).plan, isNull);
      expect(
        PlanState.fromMap(<String, dynamic>{"plan": "bad", "today": 1}).plan,
        isNull,
      );
      final PlanState badDate = PlanState.fromMap(<String, dynamic>{
        "plan": <String, dynamic>{
          "id": "1",
          "deadline": "2026-13-40",
          "scope": <dynamic>[],
        },
      });
      expect(badDate.plan, isNull);
    });
  });

  group('PlanStore 持久化', () {
    test('planData 已加入备份白名单', () {
      expect(SharedPreferences.usedKeys.contains(PlanStore.storageKey), isTrue);
    });

    test('init 在键缺失时写入默认空 JSON', () async {
      await AppData().storage.prefs.remove(PlanStore.storageKey);
      expect(AppData().storage.containsKey(PlanStore.storageKey), isFalse);

      await PlanStore().init();
      expect(PlanStore().inited, isTrue);
      expect(PlanStore().state.plan, isNull);
      expect(PlanStore().state.today, isNull);

      final String? raw = AppData().storage.getString(PlanStore.storageKey);
      expect(raw, isNotNull);
      expect(jsonDecode(raw!), <String, dynamic>{"plan": null, "today": null});
    });

    test('坏 JSON 回退 empty 并清空内存', () async {
      await PlanStore().setPlan(_samplePlan());
      expect(PlanStore().state.plan, isNotNull);

      await AppData().storage.setString(PlanStore.storageKey, '{not json');
      await PlanStore().reload();
      expect(PlanStore().inited, isTrue);
      expect(PlanStore().state.plan, isNull);
      expect(PlanStore().state.today, isNull);

      await AppData().storage.setString(PlanStore.storageKey, '[1,2,3]');
      await PlanStore().reload();
      expect(PlanStore().state.plan, isNull);
    });

    test('setPlan 保存计划并清空当日快照', () async {
      await PlanStore().setToday(
        const PlanDayProgress(dayKey: 20261018, minWords: 10, doneWords: 4),
      );
      expect(PlanStore().state.today, isNotNull);

      final StudyPlan plan = _samplePlan();
      await PlanStore().setPlan(plan);
      expect(PlanStore().state.plan?.id, plan.id);
      expect(PlanStore().state.today, isNull);

      final dynamic decoded = jsonDecode(
        AppData().storage.getString(PlanStore.storageKey)!,
      );
      expect(decoded["plan"]["id"], plan.id);
      expect(decoded["today"], isNull);
    });

    test('recordProgress 累加且忽略负数；无快照时忽略', () async {
      await PlanStore().recordProgress(5); // 无 today
      expect(PlanStore().state.today, isNull);

      await PlanStore().setToday(
        const PlanDayProgress(dayKey: 20261018, minWords: 10, doneWords: 1),
      );
      await PlanStore().recordProgress(3);
      expect(PlanStore().state.today?.doneWords, 4);
      await PlanStore().recordProgress(-5);
      expect(PlanStore().state.today?.doneWords, 4);
      expect(PlanStore().state.today?.minWords, 10);
    });

    test('clear 清空内存并写入默认空 JSON', () async {
      await PlanStore().setPlan(_samplePlan());
      await PlanStore().clear();

      expect(PlanStore().state.plan, isNull);
      expect(
        jsonDecode(AppData().storage.getString(PlanStore.storageKey)!),
        <String, dynamic>{"plan": null, "today": null},
      );
    });
  });
}
