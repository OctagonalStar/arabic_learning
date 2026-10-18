import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/models/plan.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/plan_scheduler.dart';
import 'package:arabic_learning/services/plan_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' show Card, State;

import '../helpers/test_env.dart';

DictData _dict(int wordCount) {
  return DictData(
    words: List<WordItem>.generate(
      wordCount,
      (int i) => WordItem(
        arabic: "w$i",
        chinese: "释义$i",
        explanation: "",
        className: "A",
        id: i,
      ),
      growable: false,
    ),
    classes: <SourceItem>[
      SourceItem(
        sourceJsonFileName: "s1.json",
        subClasses: <ClassItem>[
          ClassItem(
            className: "A",
            wordIndexs: List<int>.generate(wordCount, (int i) => i),
          ),
        ],
      ),
    ],
  );
}

StudyPlan _plan({
  DateTime? deadline,
  bool streakGate = true,
  List<PlanScopeRef>? scope,
}) {
  return StudyPlan(
    id: "gate",
    deadline: deadline ?? DateTime.now().add(const Duration(days: 30)),
    scope: scope ?? <PlanScopeRef>[const PlanScopeRef(sourceFile: "s1.json", className: "A")],
    groupSize: 10,
    streakGate: streakGate,
    configuredDayKey: dayKeyOf(DateTime.now()),
  );
}

FSRSConfig _config({bool enabled = true, List<Card> cards = const <Card>[]}) =>
    FSRSConfig(enabled: enabled, cards: List<Card>.of(cards));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
    FSRS().init();
  });

  setUp(() async {
    await PlanStore().clear();
    FSRS().config = _config();
    AppData().wordData = _dict(10);
  });

  group('planBlocksStreak', () {
    test('无计划 → 不拦截', () {
      expect(PlanStore().state.plan, isNull);
      expect(planBlocksStreak(), isFalse);
    });

    test('未开启 streakGate → 不拦截', () async {
      await PlanStore().setPlan(_plan(streakGate: false));
      expect(planBlocksStreak(), isFalse);
    });

    test('已达标（done >= min）→ 不拦截', () async {
      await PlanStore().setPlan(_plan());
      final PlanStatus status = evaluateNow();
      expect(status.minWords, 10);
      await PlanStore().recordProgress(10);
      expect(planBlocksStreak(), isFalse);
    });

    test('未达标 → 拦截', () async {
      await PlanStore().setPlan(_plan());
      expect(planBlocksStreak(), isTrue);
      expect(PlanStore().state.today?.minWords, 10);
    });

    test('周期完成 → 不拦截', () async {
      FSRS().config = _config(cards: <Card>[
        for (int i = 0; i < 10; i++) Card(cardId: i, state: State.learning),
      ]);
      await PlanStore().setPlan(_plan());
      expect(evaluateNow().cycleComplete, isTrue);
      expect(planBlocksStreak(), isFalse);
    });

    test('逾期 → 不拦截', () async {
      await PlanStore().setPlan(
        _plan(deadline: DateTime.now().subtract(const Duration(days: 2))),
      );
      expect(evaluateNow().overdue, isTrue);
      expect(planBlocksStreak(), isFalse);
    });

    test('范围失效 → 不拦截', () async {
      await PlanStore().setPlan(_plan(
        scope: <PlanScopeRef>[const PlanScopeRef(sourceFile: "none.json", className: "X")],
      ));
      expect(evaluateNow().invalidScope, isTrue);
      expect(planBlocksStreak(), isFalse);
    });

    test('FSRS 未启用 → 不拦截', () async {
      FSRS().config = _config(enabled: false);
      await PlanStore().setPlan(_plan());
      expect(planBlocksStreak(), isFalse);
    });
  });
}
