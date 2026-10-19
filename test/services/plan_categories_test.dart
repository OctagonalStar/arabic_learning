// 计划学习的「标签筛选」测试：StudyPlan.categories 归一化 / 序列化，
// 以及 resolveScopeWords、unlearnedScopeWords、evaluateNow 的过滤口径。
import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/models/plan.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/plan_scheduler.dart';
import 'package:arabic_learning/services/plan_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' show Card, State;

import '../helpers/test_env.dart';

typedef _TestWord = ({String arabic, List<String> categories});
typedef _TestGroup = ({
  String source,
  String className,
  List<_TestWord> words,
});

/// 按「词库文件名 / 课程名 / 带标签的单词列表」构造小词库，id 按插入顺序生成。
DictData _dict(List<_TestGroup> groups) {
  final List<WordItem> words = <WordItem>[];
  final Map<String, List<ClassItem>> bySource = <String, List<ClassItem>>{};
  for (final _TestGroup group in groups) {
    final List<int> indexes = <int>[];
    for (final _TestWord word in group.words) {
      indexes.add(words.length);
      words.add(WordItem(
        arabic: word.arabic,
        chinese: "释义${words.length}",
        explanation: "",
        className: group.className,
        id: words.length,
        categories: word.categories,
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
  List<String> categories = const <String>[],
  DateTime? deadline,
  int groupSize = 10,
}) {
  return StudyPlan(
    id: "1",
    deadline: deadline ?? DateTime(2030, 1, 1),
    scope: scope ?? <PlanScopeRef>[_ref("s1.json", "A")],
    categories: categories,
    groupSize: groupSize,
    configuredDayKey: 20261018,
  );
}

FSRSConfig _config({bool enabled = true, List<Card> cards = const <Card>[]}) =>
    FSRSConfig(enabled: enabled, cards: List<Card>.of(cards));

List<String> _arabicOf(List<WordItem> words) =>
    words.map((WordItem word) => word.arabic).toList(growable: false);

List<int> _idsOf(List<WordItem> words) =>
    words.map((WordItem word) => word.id).toList(growable: false);

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
  });

  group('StudyPlan.categories 归一化', () {
    test('去空白、去空串、去重并保持首次出现顺序', () {
      final StudyPlan plan = _plan(
        categories: <String>[
          " 四级 ",
          "",
          "常用词",
          "四级",
          "   ",
          "常用词 ",
          "\t六级\t",
        ],
      );
      expect(plan.categories, <String>["四级", "常用词", "六级"]);
      // 不可变：外部修改会抛错，避免调用方误改缓存的计划。
      expect(
        () => plan.categories.add("临时"),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('toMap / fromMap 往返一致，且 toMap 返回副本', () {
      final StudyPlan plan = _plan(categories: <String>["四级", "常用词"]);
      final Map<String, dynamic> map = plan.toMap();
      expect(map["categories"], <String>["四级", "常用词"]);

      // 修改 toMap 返回的列表不应影响计划本体。
      (map["categories"] as List<String>).add("临时");
      expect(plan.categories, <String>["四级", "常用词"]);

      final StudyPlan restored = StudyPlan.fromMap(plan.toMap());
      expect(restored.categories, plan.categories);
      expect(restored.scope, plan.scope);
      expect(restored.groupSize, plan.groupSize);
      expect(restored.deadline, plan.deadline);
    });

    test('旧数据缺少 categories 字段 → 空列表（不筛选）', () {
      final Map<String, dynamic> legacy = <String, dynamic>{
        "id": "1",
        "deadline": "2030-01-01",
        "scope": <Map<String, dynamic>>[
          <String, dynamic>{"sourceFile": "s1.json", "className": "A"},
        ],
        "groupSize": 10,
      };
      expect(StudyPlan.fromMap(legacy).categories, isEmpty);
    });

    test('categories 类型异常 / 混入非字符串时容错', () {
      Map<String, dynamic> legacy(Object? categories) => <String, dynamic>{
            "id": "1",
            "deadline": "2030-01-01",
            "scope": <Map<String, dynamic>>[
              <String, dynamic>{"sourceFile": "s1.json", "className": "A"},
            ],
            "categories": categories,
          };

      expect(StudyPlan.fromMap(legacy("四级")).categories, isEmpty);
      expect(
        StudyPlan.fromMap(legacy(<dynamic>[" 四级 ", 3, "", "四级", null]))
            .categories,
        <String>["四级"],
      );
    });

    test('copyWith 覆盖 / 保留 categories，并同样归一化', () {
      final StudyPlan plan = _plan(categories: <String>["四级"]);

      expect(plan.copyWith().categories, <String>["四级"]);
      expect(
        plan.copyWith(categories: <String>[" 常用词 ", "常用词", "六级"])
            .categories,
        <String>["常用词", "六级"],
      );
      // 显式传空列表表示「清空筛选」，而不是沿用旧值。
      expect(plan.copyWith(categories: const <String>[]).categories, isEmpty);
    });
  });

  group('resolveScopeWords 标签过滤', () {
    final DictData dict = _dict(<_TestGroup>[
      (
        source: "s1.json",
        className: "A",
        words: <_TestWord>[
          (arabic: "a", categories: <String>["四级"]),
          (arabic: "b", categories: <String>["四级", "常用词"]),
          (arabic: "c", categories: <String>["六级"]),
          (arabic: "d", categories: <String>[]),
        ],
      ),
      (
        source: "s1.json",
        className: "B",
        words: <_TestWord>[
          (arabic: "e", categories: <String>["常用词"]),
          (arabic: "f", categories: <String>["生僻词"]),
        ],
      ),
    ]);

    test('多课程多标签：任一命中即保留，顺序不变', () {
      final StudyPlan plan = _plan(
        scope: <PlanScopeRef>[_ref("s1.json", "A"), _ref("s1.json", "B")],
        categories: <String>["四级", "常用词"],
      );
      expect(_arabicOf(resolveScopeWords(plan, dict)), <String>["a", "b", "e"]);
    });

    test('identityKey 去重仍生效：同词跨课程只保留一次', () {
      final DictData dedupeDict = _dict(<_TestGroup>[
        (
          source: "s1.json",
          className: "A",
          words: <_TestWord>[
            (arabic: "كِتَابٌ", categories: <String>["四级"]),
            (arabic: "قلم", categories: <String>["四级"]),
          ],
        ),
        (
          source: "s1.json",
          className: "B",
          words: <_TestWord>[
            (arabic: "كتاب", categories: <String>["四级"]),
            (arabic: "علم", categories: <String>["四级"]),
          ],
        ),
      ]);
      final StudyPlan plan = _plan(
        scope: <PlanScopeRef>[_ref("s1.json", "A"), _ref("s1.json", "B")],
        categories: <String>["四级"],
      );
      expect(
        _arabicOf(resolveScopeWords(plan, dedupeDict)),
        <String>["كِتَابٌ", "قلم", "علم"],
      );
    });

    test('空 categories = 全部保留（含无标签词）', () {
      final StudyPlan plan = _plan(
        scope: <PlanScopeRef>[_ref("s1.json", "A"), _ref("s1.json", "B")],
      );
      expect(
        _arabicOf(resolveScopeWords(plan, dict)),
        <String>["a", "b", "c", "d", "e", "f"],
      );
    });

    test('标签匹配 0 词 → 空结果（范围本身仍有效）', () {
      AppData().wordData = dict;
      final StudyPlan plan = _plan(
        scope: <PlanScopeRef>[_ref("s1.json", "A"), _ref("s1.json", "B")],
        categories: <String>["不存在的标签"],
      );
      expect(resolveScopeWords(plan, dict), isEmpty);
      expect(activeScopeRefs(plan).length, 2); // 课程可解析，只是没有词命中标签
    });
  });

  group('unlearnedScopeWords / evaluateNow 标签过滤', () {
    final DictData dict = _dict(<_TestGroup>[
      (
        source: "s1.json",
        className: "A",
        words: <_TestWord>[
          (arabic: "w0", categories: <String>["四级"]),
          (arabic: "w1", categories: <String>["六级"]),
          (arabic: "w2", categories: <String>[]),
          (arabic: "w3", categories: <String>["四级"]),
        ],
      ),
    ]);

    test('remaining 与 scopeWords 都按过滤后的词计算', () async {
      AppData().wordData = dict;
      final StudyPlan plan = _plan(categories: <String>["四级"]);
      await PlanStore().setPlan(plan);

      expect(
        _idsOf(unlearnedScopeWords(plan, dict, FSRS())),
        <int>[0, 3],
      );

      final PlanStatus status = evaluateNow(now: DateTime(2026, 10, 18, 9));
      expect(status.scopeWords, 2);
      expect(status.learnedWords, 0);
      expect(status.remainingWords, 2);
      expect(status.minWords, 2); // 2 词 / 7 天 / 每组 10 → 不足一组，取剩余全部
      expect(status.invalidScope, isFalse);
      expect(status.cycleComplete, isFalse);
    });

    test('标签匹配 0 词时 scopeWords == 0、最小量为 0', () async {
      AppData().wordData = dict;
      final StudyPlan plan = _plan(categories: <String>["不存在的标签"]);
      await PlanStore().setPlan(plan);

      expect(unlearnedScopeWords(plan, dict, FSRS()), isEmpty);

      final PlanStatus status = evaluateNow(now: DateTime(2026, 10, 18, 9));
      expect(status.scopeWords, 0);
      expect(status.learnedWords, 0);
      expect(status.remainingWords, 0);
      expect(status.minWords, 0);
      // 课程仍可解析，只是标签没有命中任何词。
      expect(status.invalidScope, isFalse);
      expect(status.cycleComplete, isFalse);
    });
  });

  group('标签与 FSRS 组合', () {
    final DictData dict = _dict(<_TestGroup>[
      (
        source: "s1.json",
        className: "A",
        words: <_TestWord>[
          (arabic: "w0", categories: <String>["四级"]),
          (arabic: "w1", categories: <String>["四级"]),
          (arabic: "w2", categories: <String>["六级"]),
          (arabic: "w3", categories: <String>["六级"]),
          (arabic: "w4", categories: <String>[]),
        ],
      ),
    ]);

    test('已入 FSRS 的命中词不出现在 remaining', () async {
      AppData().wordData = dict;
      FSRS().config = _config(cards: <Card>[
        Card(cardId: 0, state: State.learning), // 四级，命中
        Card(cardId: 2, state: State.learning), // 六级，被过滤
        Card(cardId: 3, state: State.learning), // 六级，被过滤
      ]);
      final StudyPlan plan = _plan(categories: <String>["四级"]);
      await PlanStore().setPlan(plan);

      expect(
        _idsOf(unlearnedScopeWords(plan, dict, FSRS())),
        <int>[1],
      );

      final PlanStatus status = evaluateNow(now: DateTime(2026, 10, 18, 9));
      expect(status.scopeWords, 2);
      expect(status.learnedWords, 1);
      expect(status.remainingWords, 1);
      expect(status.minWords, 1);
    });

    test('过滤范围外的已学词不影响统计', () async {
      AppData().wordData = dict;
      FSRS().config = _config(cards: <Card>[
        Card(cardId: 2, state: State.learning),
      ]);
      final StudyPlan plan = _plan(categories: <String>["四级"]);
      await PlanStore().setPlan(plan);

      final PlanStatus status = evaluateNow(now: DateTime(2026, 10, 18, 9));
      expect(status.scopeWords, 2);
      expect(status.learnedWords, 0);
      expect(status.remainingWords, 2);
    });
  });
}
