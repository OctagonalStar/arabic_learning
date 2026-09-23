import 'dart:math';

import 'package:arabic_learning/models/dict.dart' show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/screens/learning/fsrs_screens.dart' show FSRSLearningPage, FSRSReviewCardPage;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS, FSRSConfig;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/search.dart' show BKSearch;
import 'package:arabic_learning/widgets/questions.dart' show ChoiceQuestions, ListeningQuestion, SelfRatingQuestion, SpellQuestion;
import 'package:arabic_learning/widgets/flip_word_card.dart' show FlipWordCard;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

/// FSRSReviewCardPage 回归测试。
///
/// 锁定 `_FSRSReviewCardPage` 的两个历史崩溃：
/// 1. `correct` 曾以 `late final` 声明、只在首次 build（`options == null`
///    分支）赋值；作答触发 setState 重建后，新闭包读取它会抛
///    LateInitializationError（修复后每次 build 重新计算）。
/// 2. `end` 曾是 `late final DateTime`，作答赋值一次、点击详解再赋值一次，
///    第二次抛 `Field 'end' has already been initialized`（修复后改为可空、
///    可重复赋值的 `DateTime?`）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 单课程 6 词、释义互不相同：保证选择题干扰项充足，
  /// 且不会触发 `getRandomWords` 的词库过小兜底。
  List<WordItem> buildWords() => const <WordItem>[
        WordItem(arabic: 'لقاء', chinese: '相会', explanation: '见面', className: '第一课', id: 0, root: 'ل ق ي'),
        WordItem(arabic: 'كتاب', chinese: '书', explanation: '书籍', className: '第一课', id: 1, root: 'ك ت ب'),
        WordItem(arabic: 'قلم', chinese: '笔', explanation: '书写工具', className: '第一课', id: 2, root: 'ق ل م'),
        WordItem(arabic: 'مدرسة', chinese: '学校', explanation: '教育机构', className: '第一课', id: 3, root: 'د ر س'),
        WordItem(arabic: 'طالب', chinese: '学生', explanation: '学习者', className: '第一课', id: 4, root: 'ط ل ب'),
        WordItem(arabic: 'بيت', chinese: '房子', explanation: '住所', className: '第一课', id: 5, root: 'ب ي ت'),
      ];

  DictData buildDict() => DictData(
        words: buildWords(),
        classes: const <SourceItem>[
          SourceItem(
            sourceJsonFileName: 'test.json',
            displayName: '测试词库',
            subClasses: <ClassItem>[
              ClassItem(className: '第一课', wordIndexs: <int>[0, 1, 2, 3, 4, 5]),
            ],
          ),
        ],
      );

  /// 捕获父级 [StatefulBuilder] 的 setState，用于在不作答的情况下强制页面重建
  /// （`_FSRSReviewCardPageState.build` 再次执行），单独隔离 `correct` 回归。
  late StateSetter rebuildPage;

  /// 泵起非自我评级的复习卡片页。
  Future<void> pumpReviewCard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final PageController pageController = PageController();
    addTearDown(pageController.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<Global>(
        create: (BuildContext context) => Global(),
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                rebuildPage = setState;
                return FSRSReviewCardPage(
                  wordID: 0,
                  fsrs: FSRS(),
                  rnd: Random(1),
                  controller: pageController,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  /// 泵起推送学习页（[words] 个新词），可继续通过 UI 推进。
  Future<void> pumpLearningPage(WidgetTester tester, List<WordItem> words) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<Global>(
        create: (BuildContext context) => Global(),
        child: MaterialApp(
          home: FSRSLearningPage(words: words, fsrs: FSRS()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  setUpAll(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    // AppData 为单例：初始化一次（storage/basePath），随后每个用例重置词库与 FSRS。
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
  });

  setUp(() {
    AppData().wordData = buildDict();
    BKSearch.rebuild(AppData().wordData.words);
    // 非自我评级模式；重置 FSRS 单例，避免用例间卡片与配置串扰。
    FSRS().config = FSRSConfig(preferSimilar: false);
  });

  testWidgets('作答重建后点击详解：不抛异常且详解弹层打开', (WidgetTester tester) async {
    await pumpReviewCard(tester);

    // 作答正确项（选项包含目标词释义），触发页面 setState 重建。
    await tester.tap(find.text('相会'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '作答重建本身不应抛异常');
    expect(find.textContaining('用时:'), findsOneWidget);

    // 重建后「详解」按钮已揭示；修复前 onTipClicked 会读取未初始化的 correct
    // 或对 late final end 二次赋值。
    expect(find.text('详解'), findsOneWidget);
    await tester.tap(find.text('详解'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('我知道了'), findsOneWidget);
  });

  testWidgets('重建后作答：correct 重新计算，不抛 LateInitializationError', (WidgetTester tester) async {
    await pumpReviewCard(tester);

    // 强制 build 再次执行（等价于作答后的重建）：修复前 onSelected 闭包中的
    // correct 保持未初始化。
    rebuildPage(() {});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '重建本身不应抛异常');

    await tester.tap(find.text('相会'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('用时:'), findsOneWidget);
  });

  testWidgets('默认配置仍为阿译中选择题（题型 2）', (WidgetTester tester) async {
    await pumpReviewCard(tester);

    expect(find.byType(ChoiceQuestions), findsOneWidget);
    // 阿译中：题面为阿拉伯语，选项为中文释义
    expect(find.text('相会'), findsOneWidget);
  });

  testWidgets('reviewQuestionSections: [3] 渲染拼写题且不抛异常', (WidgetTester tester) async {
    FSRS().config = FSRSConfig(reviewQuestionSections: const [3]);
    await pumpReviewCard(tester);

    expect(find.byType(SpellQuestion), findsOneWidget);
    // 拼写题展示中文释义作为提示
    expect(find.text('相会'), findsOneWidget);
  });

  testWidgets('reviewQuestionSections: [1] 渲染中译阿选择题（中文题面）', (WidgetTester tester) async {
    FSRS().config = FSRSConfig(reviewQuestionSections: const [1]);
    await pumpReviewCard(tester);

    expect(find.byType(ChoiceQuestions), findsOneWidget);
    // 中译阿：题面为中文释义
    expect(find.text('相会'), findsOneWidget);
  });

  testWidgets('听力题重复跳过只记录一次复习（Bug 1 回归）', (WidgetTester tester) async {
    FSRS().config = FSRSConfig(reviewQuestionSections: const [4]);
    await pumpReviewCard(tester);

    expect(find.byType(ListeningQuestion), findsOneWidget);

    // 首次跳过：新卡片被加入复习
    await tester.tap(find.text('跳过听力题目'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(FSRS().config.cards.length, 1);

    // 第二次跳过必须是 no-op；否则 scheduler 为 null 会抛异常并重复记录
    await tester.tap(find.text('跳过听力题目'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(FSRS().config.cards.length, 1);
  });

  testWidgets('推送单词卡片题在最后一题可进入完成页（Bug 2 回归）', (WidgetTester tester) async {
    FSRS().config = FSRSConfig(reviewQuestionSections: const [0]);
    await pumpLearningPage(tester, <WordItem>[buildWords().first]);

    // 学习阶段 -> 开始答题
    await tester.tap(find.text('开始答题'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 单词卡片题：最后一题应显示「完成学习」并切到完成页
    expect(find.text('完成学习'), findsOneWidget);
    await tester.tap(find.text('完成学习'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('该课程学习已完成'), findsOneWidget);
  });

  testWidgets('推送学习做题阶段点击「提示」打开详解（Scaffold 上下文回归）', (WidgetTester tester) async {
    // 回归：_bottomBar 曾用 State.context 调 viewAnswer，而 FSRSLearningPage 的
    // Scaffold 在 build 内创建，State.context 位于其上层，导致 showBottomSheet
    // 抛 "No Scaffold widget found"、点击详解无反应。修复后传入 itemBuilder 的
    // context（Scaffold 之下）。
    FSRS().config = FSRSConfig(reviewQuestionSections: const [2]);
    await pumpLearningPage(tester, <WordItem>[buildWords().first]);

    await tester.tap(find.text('开始答题'));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceQuestions), findsOneWidget);

    expect(find.text('提示'), findsOneWidget);
    await tester.tap(find.text('提示'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('我知道了'), findsOneWidget, reason: '详解弹层应打开');
  });

  testWidgets('自我评级复习卡可翻卡揭示释义', (WidgetTester tester) async {
    // 回归：selfEvaluate 模式下卡片曾设 enableFlip:false，点击无法翻开。
    FSRS().config = FSRSConfig(selfEvaluate: true);
    await pumpReviewCard(tester);

    expect(find.byType(SelfRatingQuestion), findsOneWidget);
    expect(find.text('释义已隐藏'), findsOneWidget);
    expect(find.text('点击查看释义'), findsOneWidget);

    await tester.tap(find.byType(FlipWordCard));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('释义已隐藏'), findsNothing);
    expect(find.text('词根'), findsOneWidget, reason: '翻卡后应展示详情');
  });

  testWidgets('自我评级后正面揭晓释义，且重复评级被锁定', (WidgetTester tester) async {
    FSRS().config = FSRSConfig(selfEvaluate: true);
    await pumpReviewCard(tester);

    expect(find.byType(SelfRatingQuestion), findsOneWidget);
    expect(find.text('释义已隐藏'), findsOneWidget);

    // 评级后正面遮罩消失并展示中文释义。
    await tester.tap(find.text('记得很清楚'));
    await tester.pumpAndSettle();
    expect(find.text('释义已隐藏'), findsNothing);
    expect(find.text('相会'), findsOneWidget);

    // 已锁定：再点其它评级不再作答，只弹出「不允许多次选择」提示。
    await tester.tap(find.text('忘了'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('该页面不允许多次选择'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
