// 复习 / 计划学习的「错选惩罚」接入测试。
//
// 独立成文件：FSRS 是全局单例，`flutter test` 按文件隔离 isolate，
// 这里会大量改写 `FSRS().config`，避免污染其它 FSRS 测试的前提。
import 'dart:math';

import 'package:arabic_learning/models/dict.dart'
    show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/models/plan.dart'
    show PlanChain, PlanScopeRef, StudyPlan;
import 'package:arabic_learning/screens/learning/fsrs/fsrs_review_card_page.dart';
import 'package:arabic_learning/screens/learning/plan/plan_session_page.dart';
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS, FSRSConfig;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/plan_scheduler.dart'
    show dayKeyOf, evaluateNow;
import 'package:arabic_learning/services/plan_store.dart' show PlanStore;
import 'package:arabic_learning/services/search.dart' show BKSearch;
import 'package:arabic_learning/widgets/questions.dart' show ChoiceQuestions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

List<WordItem> _words([int count = 6]) => List<WordItem>.generate(
  count,
  (int i) => WordItem(
    arabic: 'w$i',
    chinese: '释义$i',
    explanation: '说明$i',
    className: 'A',
    id: i,
  ),
  growable: false,
);

DictData _dict([int count = 6]) => DictData(
  words: _words(count),
  classes: <SourceItem>[
    SourceItem(
      sourceJsonFileName: 's.json',
      subClasses: <ClassItem>[
        ClassItem(
          className: 'A',
          wordIndexs: List<int>.generate(count, (int i) => i),
        ),
      ],
    ),
  ],
);

/// 已复习过的卡片（与 [buildTestItem] 的题面无关，只要求有记录且数值一致）。
fsrs.Card _card(int id, DateTime lastReview) => fsrs.Card(
  cardId: id,
  state: fsrs.State.review,
  stability: 12.5,
  difficulty: 6.4,
  due: lastReview.add(const Duration(days: 3)),
  lastReview: lastReview,
);

fsrs.ReviewLog _log(int id, DateTime at) =>
    fsrs.ReviewLog(cardId: id, rating: fsrs.Rating.good, reviewDateTime: at);

/// 让 [ids] 各有一张内容相同的复习卡片；[penalizeWrongOption] 控制新开关。
void _seed({required List<int> ids, required bool penalizeWrongOption}) {
  final DateTime last = DateTime.now().subtract(const Duration(days: 1));
  FSRS().config = FSRSConfig(
    enabled: true,
    scheduler: fsrs.Scheduler(),
    cards: ids.map((int id) => _card(id, last)).toList(),
    reviewLogs: ids.map((int id) => _log(id, last)).toList(),
    // 题型固定为阿译中选择题，选项为中文释义。
    reviewQuestionSections: const <int>[2],
    penalizeWrongOption: penalizeWrongOption,
  );
}

/// 取当前题目的第一个错误选项（选项与词条一一对应，正确项必含测试词）。
({int index, WordItem word}) _wrongOption(WidgetTester tester, int correctId) {
  final ChoiceQuestions question = tester.widget<ChoiceQuestions>(
    find.byType(ChoiceQuestions),
  );
  final List<WordItem> words = question.optionWords!;
  final int correct = words.indexWhere((WordItem w) => w.id == correctId);
  final int index = correct == 0 ? 1 : 0;
  return (index: index, word: words[index]);
}

Future<void> _pumpReviewCard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final PageController controller = PageController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<Global>(
      create: (BuildContext context) => Global(),
      child: MaterialApp(
        home: Scaffold(
          body: FSRSReviewCardPage(
            wordID: 0,
            fsrs: FSRS(),
            rnd: Random(1),
            controller: controller,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
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
    FSRS().init();
  });

  setUp(() async {
    AppData().wordData = _dict();
    BKSearch.rebuild(AppData().wordData.words);
    await PlanStore().clear();
  });

  tearDown(() {
    FSRS().config = FSRS().config.copyWith(
      cards: <fsrs.Card>[],
      reviewLogs: <fsrs.ReviewLog>[],
    );
  });

  group('复习选择题错选惩罚', () {
    testWidgets('开关开 + 错选词已在 FSRS：记一次 again 且卡片保留', (tester) async {
      _seed(ids: <int>[0, 1, 2, 3, 4, 5], penalizeWrongOption: true);
      await _pumpReviewCard(tester);

      final ({int index, WordItem word}) wrong = _wrongOption(tester, 0);
      await tester.tap(find.text(wrong.word.chinese));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(FSRS().logFor(wrong.word.id)!.rating, fsrs.Rating.again);
      expect(FSRS().cardFor(wrong.word.id), isNotNull, reason: '惩罚只是复习，不删卡');
    });

    testWidgets('开关关：错选词的日志不变', (tester) async {
      _seed(ids: <int>[0, 1, 2, 3, 4, 5], penalizeWrongOption: false);
      await _pumpReviewCard(tester);

      final ({int index, WordItem word}) wrong = _wrongOption(tester, 0);
      await tester.tap(find.text(wrong.word.chinese));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(FSRS().logFor(wrong.word.id)!.rating, fsrs.Rating.good);
    });

    testWidgets('错选词不在 FSRS：不新建卡片', (tester) async {
      // 只有测试词本身有卡片，三个干扰词都不在牌组里。
      _seed(ids: <int>[0], penalizeWrongOption: true);
      await _pumpReviewCard(tester);

      final ({int index, WordItem word}) wrong = _wrongOption(tester, 0);
      await tester.tap(find.text(wrong.word.chinese));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(FSRS().isContained(wrong.word.id), isFalse);
    });
  });

  group('计划学习选择题错选惩罚', () {
    testWidgets('同一错选重复点选只惩罚一次', (tester) async {
      _seed(ids: <int>[0, 1, 2, 3, 4, 5], penalizeWrongOption: true);
      await PlanStore().setPlan(
        StudyPlan(
          id: 'plan',
          deadline: DateTime.now().add(const Duration(days: 30)),
          scope: const <PlanScopeRef>[
            PlanScopeRef(sourceFile: 's.json', className: 'A'),
          ],
          groupSize: 1,
          chain: const PlanChain(sections: <int>[2]),
          streakGate: true,
          configuredDayKey: dayKeyOf(DateTime.now()),
        ),
      );
      evaluateNow();

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<Global>(
          create: (BuildContext context) => Global(),
          child: MaterialApp(
            home: PlanSessionPage(
              words: <WordItem>[_words().first],
              chain: const PlanChain(sections: <int>[2]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ({int index, WordItem word}) wrong = _wrongOption(tester, 0);
      // 多选模式下同一选项的重复点选会被 ChooseButtonBox 自身拦截，因此直接
      // 连调两次页面的判题回调，验证页面自身的去重（缺去重会惩罚两次）。
      final ChoiceQuestions question = tester.widget<ChoiceQuestions>(
        find.byType(ChoiceQuestions),
      );
      question.onSelected(wrong.index);
      await tester.pump(const Duration(milliseconds: 10));
      question.onSelected(wrong.index);
      await tester.pump(const Duration(milliseconds: 10));

      // 参照：对一张同样内容的未出现卡片手动惩罚一次，比较调度结果。
      final Set<int> shown = question.optionWords!
          .map((WordItem w) => w.id)
          .toSet();
      final int refId = <int>[1, 2, 3, 4, 5].firstWhere(
        (int id) => !shown.contains(id),
      );
      FSRS().penalizeWrongChoice(refId);

      final fsrs.Card penalized = FSRS().cardFor(wrong.word.id)!;
      final fsrs.Card reference = FSRS().cardFor(refId)!;
      expect(FSRS().logFor(wrong.word.id)!.rating, fsrs.Rating.again);
      expect(penalized.state, reference.state);
      expect(penalized.step, reference.step);
      expect(penalized.stability, reference.stability, reason: '重复点选不应二次惩罚');
      expect(penalized.difficulty, reference.difficulty);

      // 冲掉 700ms / 1s 的作答延时与 FSRS 落盘防抖。
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
