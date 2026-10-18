import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/models/plan.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/plan_scheduler.dart';
import 'package:arabic_learning/services/plan_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' show Card, State;

import '../helpers/test_env.dart';

/// 按「词库文件名 / 课程名 / 单词列表」构造小词库，id 按插入顺序生成。
DictData _dict(
  List<({String source, String className, List<String> words})> groups,
) {
  final List<WordItem> words = <WordItem>[];
  final Map<String, List<ClassItem>> bySource = <String, List<ClassItem>>{};
  for (final ({String source, String className, List<String> words}) group in groups) {
    final List<int> indexes = <int>[];
    for (final String arabic in group.words) {
      indexes.add(words.length);
      words.add(WordItem(
        arabic: arabic,
        chinese: "释义${words.length}",
        explanation: "",
        className: group.className,
        id: words.length,
      ));
    }
    (bySource[group.source] ??= <ClassItem>[])
        .add(ClassItem(className: group.className, wordIndexs: indexes));
  }
  return DictData(
    words: words,
    classes: <SourceItem>[
      for (final MapEntry<String, List<ClassItem>> entry in bySource.entries)
        SourceItem(sourceJsonFileName: entry.key, subClasses: entry.value),
    ],
  );
}

PlanScopeRef _ref(String source, String className) =>
    PlanScopeRef(sourceFile: source, className: className);

StudyPlan _plan({
  List<PlanScopeRef>? scope,
  DateTime? deadline,
  int groupSize = 10,
  bool shuffleClasses = false,
  bool streakGate = false,
}) {
  return StudyPlan(
    id: "1",
    deadline: deadline ?? DateTime(2030, 1, 1),
    scope: scope ?? <PlanScopeRef>[_ref("s1.json", "A")],
    groupSize: groupSize,
    shuffleClasses: shuffleClasses,
    streakGate: streakGate,
    configuredDayKey: 20261018,
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
    // 单例 FSRS：先保证 _inited 为真，后续测试再替换 config。
    FSRS().init();
  });

  setUp(() async {
    await PlanStore().clear();
    FSRS().config = _config();
  });

  group('dayKeyOf / daysLeft', () {
    test('dayKeyOf 拼成 yyyyMMdd', () {
      expect(dayKeyOf(DateTime(2026, 9, 23, 23, 59)), 20260923);
      expect(dayKeyOf(DateTime(2026, 1, 2)), 20260102);
    });

    test('daysLeft 按本地日期相减', () {
      final DateTime today = DateTime(2026, 10, 18, 22);
      expect(daysLeft(today, DateTime(2026, 10, 19)), 1);
      expect(daysLeft(today, DateTime(2026, 10, 18)), 0);
      expect(daysLeft(today, DateTime(2026, 10, 17)), -1);
    });
  });

  group('computeDailyMin', () {
    test('240 词 / 14 天 / 每组 10 → 20', () {
      expect(
        computeDailyMin(remaining: 240, daysLeft: 14, groupSize: 10),
        20,
      );
    });

    test('不足一组时以剩余量封顶', () {
      expect(computeDailyMin(remaining: 5, daysLeft: 10, groupSize: 10), 5);
    });

    test('剩余为 0 → 0', () {
      expect(computeDailyMin(remaining: 0, daysLeft: 14, groupSize: 10), 0);
      expect(computeDailyMin(remaining: -3, daysLeft: 14, groupSize: 10), 0);
    });

    test('剩余天数 <= 0 时按 1 天计（今天学完全部）', () {
      expect(computeDailyMin(remaining: 25, daysLeft: 0, groupSize: 10), 25);
      expect(computeDailyMin(remaining: 25, daysLeft: -2, groupSize: 10), 25);
    });
  });

  group('resolveScopeWords', () {
    test('按 scope 顺序拼接多个课程', () {
      final DictData dict = _dict(<({String source, String className, List<String> words})>[
        (source: "s1.json", className: "A", words: <String>["a", "b"]),
        (source: "s1.json", className: "B", words: <String>["c"]),
      ]);
      final StudyPlan plan = _plan(
        scope: <PlanScopeRef>[_ref("s1.json", "B"), _ref("s1.json", "A")],
      );
      expect(
        resolveScopeWords(plan, dict).map((WordItem w) => w.arabic),
        <String>["c", "a", "b"],
      );
    });

    test('按 identityKey 去重（保留首次出现）', () {
      final DictData dict = _dict(<({String source, String className, List<String> words})>[
        (source: "s1.json", className: "A", words: <String>["كِتَابٌ", "قلم"]),
        (source: "s1.json", className: "B", words: <String>["كتاب", "علم"]),
      ]);
      final StudyPlan plan = _plan(
        scope: <PlanScopeRef>[_ref("s1.json", "A"), _ref("s1.json", "B")],
      );
      expect(
        resolveScopeWords(plan, dict).map((WordItem w) => w.arabic),
        <String>["كِتَابٌ", "قلم", "علم"],
      );
    });

    test('失效课程被跳过', () {
      final DictData dict = _dict(<({String source, String className, List<String> words})>[
        (source: "s1.json", className: "A", words: <String>["a"]),
      ]);
      final StudyPlan plan = _plan(
        scope: <PlanScopeRef>[
          _ref("s1.json", "不存在"),
          _ref("other.json", "A"),
          _ref("s1.json", "A"),
        ],
      );
      AppData().wordData = dict;
      expect(resolveScopeWords(plan, dict).length, 1);
      expect(activeScopeRefs(plan).length, 1);
    });
  });

  group('unlearnedScopeWords', () {
    test('有卡即排除', () {
      final DictData dict = _dict(<({String source, String className, List<String> words})>[
        (source: "s1.json", className: "A", words: <String>["a", "b", "c"]),
      ]);
      FSRS().config = _config(cards: <Card>[
        Card(cardId: 1, state: State.learning),
      ]);
      expect(
        unlearnedScopeWords(_plan(), dict, FSRS()).map((WordItem w) => w.id),
        <int>[0, 2],
      );
    });
  });

  group('nextGroupWords', () {
    final DictData twoClasses = _dict(<({String source, String className, List<String> words})>[
      (source: "s1.json", className: "A", words: <String>["a0", "a1"]),
      (source: "s1.json", className: "B", words: <String>["b0", "b1"]),
    ]);

    test('同一天结果稳定', () async {
      AppData().wordData = twoClasses;
      await PlanStore().setPlan(_plan(
        scope: <PlanScopeRef>[_ref("s1.json", "A"), _ref("s1.json", "B")],
        groupSize: 4,
        shuffleClasses: true,
      ));
      final List<int> first = nextGroupWords(now: DateTime(2026, 10, 19, 8))
          .map((WordItem w) => w.id)
          .toList();
      final List<int> second = nextGroupWords(now: DateTime(2026, 10, 19, 23))
          .map((WordItem w) => w.id)
          .toList();
      expect(second, first);
    });

    test('shuffleClasses 打乱课程顺序，组内顺序不变', () async {
      AppData().wordData = twoClasses;
      await PlanStore().setPlan(_plan(
        scope: <PlanScopeRef>[_ref("s1.json", "A"), _ref("s1.json", "B")],
        groupSize: 4,
      ));
      expect(
        nextGroupWords(now: DateTime(2026, 10, 19)).map((WordItem w) => w.id),
        <int>[0, 1, 2, 3],
      );

      await PlanStore().setPlan(_plan(
        scope: <PlanScopeRef>[_ref("s1.json", "A"), _ref("s1.json", "B")],
        groupSize: 4,
        shuffleClasses: true,
      ));
      // 2026-10-19 的日期种子对两个课程恰好交换顺序
      expect(
        nextGroupWords(now: DateTime(2026, 10, 19)).map((WordItem w) => w.id),
        <int>[2, 3, 0, 1],
      );
    });

    test('只取 groupSize 个', () async {
      AppData().wordData = twoClasses;
      await PlanStore().setPlan(_plan(
        scope: <PlanScopeRef>[_ref("s1.json", "A"), _ref("s1.json", "B")],
        groupSize: 2,
      ));
      expect(
        nextGroupWords(now: DateTime(2026, 10, 19)).map((WordItem w) => w.id),
        <int>[0, 1],
      );
    });

    test('FSRS 未启用 / 范围失效时返回空', () async {
      AppData().wordData = twoClasses;
      await PlanStore().setPlan(_plan());
      FSRS().config = _config(enabled: false);
      expect(nextGroupWords(), isEmpty);

      FSRS().config = _config();
      await PlanStore().setPlan(_plan(scope: <PlanScopeRef>[_ref("none.json", "X")]));
      expect(nextGroupWords(), isEmpty);
    });
  });

  group('evaluateNow', () {
    test('周期完成：范围内单词全部有卡', () async {
      AppData().wordData = _dict(<({String source, String className, List<String> words})>[
        (source: "s1.json", className: "A", words: <String>["a", "b"]),
      ]);
      FSRS().config = _config(cards: <Card>[
        Card(cardId: 0, state: State.learning),
        Card(cardId: 1, state: State.learning),
      ]);
      await PlanStore().setPlan(_plan());

      final PlanStatus status = evaluateNow(now: DateTime(2026, 10, 18));
      expect(status.scopeWords, 2);
      expect(status.learnedWords, 2);
      expect(status.remainingWords, 0);
      expect(status.cycleComplete, isTrue);
      expect(status.overdue, isFalse);
      expect(status.minWords, 0);
      expect(status.invalidScope, isFalse);
      expect(status.fsrsDisabled, isFalse);
    });

    test('逾期：仍有剩余且剩余天数 <= 0', () async {
      AppData().wordData = _dict(<({String source, String className, List<String> words})>[
        (source: "s1.json", className: "A", words: <String>["a", "b"]),
      ]);
      await PlanStore().setPlan(_plan(deadline: DateTime(2026, 10, 15)));

      final PlanStatus status = evaluateNow(now: DateTime(2026, 10, 18));
      expect(status.daysLeft, -3);
      expect(status.remainingWords, 2);
      expect(status.minWords, 2); // 剩余天数不足 1 天 → 今天学完全部
      expect(status.overdue, isTrue);
      expect(status.cycleComplete, isFalse);
    });

    test('创建当日快照并持久化，当天内最低量不漂移', () async {
      AppData().wordData = _dict(<({String source, String className, List<String> words})>[
        (
          source: "s1.json",
          className: "A",
          words: List<String>.generate(10, (int i) => "w$i"),
        ),
      ]);
      await PlanStore().setPlan(_plan(deadline: DateTime(2026, 10, 20)));

      final PlanStatus first = evaluateNow(now: DateTime(2026, 10, 18, 9));
      expect(first.minWords, 10);
      expect(first.doneWords, 0);
      expect(first.groupsToday, 1);
      expect(first.todayRemaining, 10);
      expect(first.todayProgress, 0);
      expect(PlanStore().state.today?.dayKey, 20261018);

      await PlanStore().recordProgress(4);
      final PlanStatus second = evaluateNow(now: DateTime(2026, 10, 18, 22));
      expect(second.minWords, 10); // 当天快照固定
      expect(second.doneWords, 4);
      expect(second.todayRemaining, 6);
      expect(second.todayProgress, closeTo(0.4, 1e-9));
    });

    test('跨日重建快照（doneWords 归零）', () async {
      AppData().wordData = _dict(<({String source, String className, List<String> words})>[
        (source: "s1.json", className: "A", words: <String>["a", "b"]),
      ]);
      await PlanStore().setPlan(_plan(deadline: DateTime(2026, 10, 25)));

      evaluateNow(now: DateTime(2026, 10, 18, 9));
      await PlanStore().recordProgress(2);
      expect(PlanStore().state.today?.doneWords, 2);

      final PlanStatus nextDay = evaluateNow(now: DateTime(2026, 10, 19, 9));
      expect(nextDay.dayKey, 20261019);
      expect(nextDay.doneWords, 0);
      expect(PlanStore().state.today?.dayKey, 20261019);
    });
  });

  group('extendPlanDeadline / scopeRefForClass', () {
    test('延期保留当日已完成量，并按新剩余天数重算最低量', () async {
      AppData().wordData = _dict(<({String source, String className, List<String> words})>[
        (
          source: "s1.json",
          className: "A",
          words: <String>[for (int i = 0; i < 100; i++) "w$i"],
        ),
      ]);
      // 100 词 / 2 天 / 每组 10 → 50
      await PlanStore().setPlan(_plan(deadline: DateTime(2026, 10, 20)));
      final PlanStatus before = evaluateNow(now: DateTime(2026, 10, 18, 9));
      expect(before.minWords, 50);

      await PlanStore().recordProgress(3);
      await extendPlanDeadline(7, now: DateTime(2026, 10, 18, 10));

      // 100 词 / 9 天 / 每组 10 → 20
      expect(PlanStore().state.plan?.deadline, DateTime(2026, 10, 27));
      expect(PlanStore().state.today?.dayKey, 20261018);
      expect(PlanStore().state.today?.doneWords, 3);
      expect(PlanStore().state.today?.minWords, 20);
    });

    test('延期不继承昨天的已完成量', () async {
      AppData().wordData = _dict(<({String source, String className, List<String> words})>[
        (source: "s1.json", className: "A", words: <String>["a", "b"]),
      ]);
      await PlanStore().setPlan(_plan(deadline: DateTime(2026, 10, 20)));
      evaluateNow(now: DateTime(2026, 10, 17, 9));
      await PlanStore().recordProgress(1);

      await extendPlanDeadline(7, now: DateTime(2026, 10, 18, 9));
      expect(PlanStore().state.today?.dayKey, 20261018);
      expect(PlanStore().state.today?.doneWords, 0);
      expect(PlanStore().state.today?.minWords, 2);
    });

    test('延期可跨月 / 跨年', () async {
      AppData().wordData = _dict(<({String source, String className, List<String> words})>[
        (source: "s1.json", className: "A", words: <String>["a"]),
      ]);
      await PlanStore().setPlan(_plan(deadline: DateTime(2026, 12, 30)));
      await extendPlanDeadline(5, now: DateTime(2026, 12, 30, 9));
      expect(PlanStore().state.plan?.deadline, DateTime(2027, 1, 4));
    });

    test('daysLeft 跨夏令时切换日仍按日历天计', () {
      expect(daysLeft(DateTime(2026, 3, 7, 23, 30), DateTime(2026, 3, 9)), 2);
      expect(daysLeft(DateTime(2026, 10, 31, 23, 30), DateTime(2026, 11, 2)), 2);
    });

    test('scopeRefForClass 按实例定位词库，同名课程按词库区分', () {
      final DictData dict = _dict(<({String source, String className, List<String> words})>[
        (source: "s1.json", className: "A", words: <String>["a", "b"]),
        (source: "s2.json", className: "A", words: <String>["c", "d"]),
      ]);
      final ClassItem first = dict.classes[0].subClasses[0];
      final ClassItem second = dict.classes[1].subClasses[0];
      expect(scopeRefForClass(dict, first)?.sourceFile, "s1.json");
      expect(scopeRefForClass(dict, second)?.sourceFile, "s2.json");

      // 实例不同时，用「课程名 + 相同下标列表」兜底
      final ClassItem copy =
          ClassItem(className: "A", wordIndexs: second.wordIndexs);
      expect(scopeRefForClass(dict, copy)?.sourceFile, "s2.json");
      expect(
        scopeRefForClass(dict, ClassItem(className: "Z", wordIndexs: <int>[])),
        isNull,
      );
    });
  });
}
