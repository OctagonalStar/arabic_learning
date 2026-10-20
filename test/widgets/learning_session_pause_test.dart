import 'package:arabic_learning/models/config.dart' show QuizConfig;
import 'package:arabic_learning/models/dict.dart'
    show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/screens/learning/learning_pages_build.dart'
    show InLearningPage;
import 'package:arabic_learning/screens/learning/learning_screen.dart'
    show shiftToStudy;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/learning_session.dart'
    show LearningSessionCheckpoint, LearningSessionStore;
import 'package:arabic_learning/widgets/questions.dart' show WordCardQuestion;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

List<WordItem> _words([int count = 3]) {
  return List<WordItem>.generate(
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
}

DictData _dict([int count = 3]) {
  final List<WordItem> words = _words(count);
  return DictData(
    words: words,
    classes: <SourceItem>[
      SourceItem(
        sourceJsonFileName: 's1.json',
        subClasses: <ClassItem>[
          ClassItem(
            className: 'A',
            wordIndexs: List<int>.generate(count, (int i) => i),
          ),
        ],
      ),
    ],
  );
}

const QuizConfig _cardOnlyQuiz = QuizConfig(
  questionSections: <int>[0],
  shuffleGlobally: false,
  shuffleInternaly: false,
  shuffleExternaly: false,
  preferSimilar: false,
);

const QuizConfig _shuffledCardQuiz = QuizConfig(
  questionSections: <int>[0],
  shuffleGlobally: true,
  shuffleInternaly: false,
  shuffleExternaly: false,
  preferSimilar: false,
);

LearningSessionCheckpoint _checkpoint({
  required List<WordItem> words,
  int pageIndex = 0,
  int correctCount = 0,
  int elapsedSeconds = 0,
  QuizConfig quiz = _cardOnlyQuiz,
}) {
  return LearningSessionCheckpoint(
    seed: 20261020,
    wordKeys: words
        .map((WordItem word) => LearningSessionCheckpoint.wordKey(word))
        .toList(growable: false),
    quiz: quiz,
    countInReview: false,
    itemIndices: List<int>.generate(words.length, (int i) => i),
    pageIndex: pageIndex,
    correctCount: correctCount,
    elapsedSeconds: elapsedSeconds,
    savedAtMillis: 1760000000000,
  );
}

/// 从入口页 push 学习页，便于验证暂存退出后能正常返回。
Future<void> _pumpLearning(
  WidgetTester tester, {
  required List<WordItem> words,
  required LearningSessionCheckpoint? checkpoint,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<Global>(
      create: (BuildContext context) => Global(),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => InLearningPage(
                        words: words,
                        countInReview: false,
                        resume: checkpoint,
                      ),
                    ),
                  );
                },
                child: const Text('start'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('start'));
  await tester.pumpAndSettle();
}

double? _currentPage(WidgetTester tester) {
  final PageView pageView = tester.widget<PageView>(find.byType(PageView));
  return pageView.controller?.page;
}

/// 当前屏幕上可见的单词卡片对应的阿拉伯语，用于读取题目顺序。
String _visibleCardWord(WidgetTester tester) {
  final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (final Element element in find.byType(WordCardQuestion).evaluate()) {
    final RenderBox box = element.renderObject! as RenderBox;
    if (!box.hasSize) continue;
    final Rect rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.overlaps(Offset.zero & screen)) {
      return (element.widget as WordCardQuestion).word.arabic;
    }
  }
  fail('当前页面没有可见的单词卡片');
}

/// 逐页跳转，按顺序读取全部卡片题对应的单词。
Future<List<String>> _collectCardOrder(WidgetTester tester, int count) async {
  final PageView pageView = tester.widget<PageView>(find.byType(PageView));
  final PageController controller = pageView.controller!;
  final List<String> order = <String>[];
  for (int i = 0; i < count; i++) {
    controller.jumpToPage(i);
    await tester.pumpAndSettle();
    order.add(_visibleCardWord(tester));
  }
  return order;
}

Future<void> _pauseFromClose(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.close));
  await tester.pumpAndSettle();
  expect(find.text('结束学习？'), findsOneWidget);
  await tester.tap(find.text('暂存并退出'));
  await tester.pumpAndSettle();
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
    await LearningSessionStore.clear();
    AppData().wordData = _dict();
  });

  testWidgets('恢复暂存后从保存的题目继续', (WidgetTester tester) async {
    final List<WordItem> words = _words();
    final LearningSessionCheckpoint checkpoint = _checkpoint(
      words: words,
      pageIndex: 1,
      correctCount: 1,
      elapsedSeconds: 30,
    );

    await _pumpLearning(tester, words: words, checkpoint: checkpoint);

    expect(_currentPage(tester), 1.0);
    // 剩余 1 题，AppBar 不应误显示为完成。
    expect(find.text('学习完成'), findsNothing);
    expect(find.text('1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('返回时暂存并退出会写入断点', (WidgetTester tester) async {
    final List<WordItem> words = _words();
    final LearningSessionCheckpoint checkpoint = _checkpoint(words: words);

    await _pumpLearning(tester, words: words, checkpoint: checkpoint);
    await _pauseFromClose(tester);

    // 已退回到入口页。
    expect(find.text('start'), findsOneWidget);

    final LearningSessionCheckpoint? saved = LearningSessionStore.load();
    expect(saved, isNotNull);
    expect(saved!.seed, checkpoint.seed);
    expect(saved.pageIndex, 0);
    expect(saved.correctCount, 0);
    expect(saved.itemIndices.length, words.length);
    expect(saved.quiz.questionSections, <int>[0]);
    expect(saved.remaining, words.length);
  });

  testWidgets('已作答的卡片题在暂存时前进到下一题', (WidgetTester tester) async {
    final List<WordItem> words = _words();
    final LearningSessionCheckpoint checkpoint = _checkpoint(words: words);

    await _pumpLearning(tester, words: words, checkpoint: checkpoint);
    await tester.tap(find.text('下一题'));
    await tester.pumpAndSettle();
    expect(_currentPage(tester), 1.0);

    await _pauseFromClose(tester);

    final LearningSessionCheckpoint? saved = LearningSessionStore.load();
    expect(saved, isNotNull);
    expect(saved!.pageIndex, 1);
    expect(saved.correctCount, 1);
    expect(saved.remaining, words.length - 1);
  });

  testWidgets('全局乱序下恢复断点仍保持原题目顺序', (WidgetTester tester) async {
    final List<WordItem> words = _words(6);
    final LearningSessionCheckpoint checkpoint = _checkpoint(
      words: words,
      quiz: _shuffledCardQuiz,
    );

    await _pumpLearning(tester, words: words, checkpoint: checkpoint);
    final List<String> before = await _collectCardOrder(tester, words.length);
    expect(before.toSet().length, words.length);

    // 回到第一题并完成它，然后暂存退出。
    final PageView pageView = tester.widget<PageView>(find.byType(PageView));
    pageView.controller!.jumpToPage(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一题'));
    await tester.pumpAndSettle();
    expect(_currentPage(tester), 1.0);
    await _pauseFromClose(tester);

    final LearningSessionCheckpoint? saved = LearningSessionStore.load();
    expect(saved, isNotNull);
    expect(saved!.pageIndex, 1);

    // 恢复后必须重建出完全相同的顺序，否则已完成的题目会被重新排到后面。
    await _pumpLearning(tester, words: words, checkpoint: saved);
    expect(_currentPage(tester), 1.0);
    final List<String> after = await _collectCardOrder(tester, words.length);
    expect(after, before, reason: '恢复后题目顺序必须与暂存前一致，否则已完成题目会重复出现');
    expect(after[1], before[1]);
    expect(after[1], isNot(before[0]));
  });

  testWidgets('学习入口检测到断点时可继续上次学习', (WidgetTester tester) async {
    final List<WordItem> words = _words();
    final LearningSessionCheckpoint checkpoint = _checkpoint(
      words: words,
      pageIndex: 1,
      correctCount: 1,
    );
    await LearningSessionStore.save(checkpoint);

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<Global>(
        create: (BuildContext context) => Global(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => Center(
                child: TextButton(
                  onPressed: () => shiftToStudy(context),
                  child: const Text('学习'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('学习'));
    await tester.pumpAndSettle();
    expect(find.text('继续上次学习？'), findsOneWidget);
    expect(find.textContaining('还剩 2 题'), findsOneWidget);

    await tester.tap(find.text('继续学习'));
    await tester.pumpAndSettle();
    expect(find.byType(InLearningPage), findsOneWidget);
    expect(_currentPage(tester), 1.0);
  });

  testWidgets('直接退出会清空暂存断点', (WidgetTester tester) async {
    final List<WordItem> words = _words();
    final LearningSessionCheckpoint checkpoint = _checkpoint(words: words);
    await LearningSessionStore.save(checkpoint);

    await _pumpLearning(tester, words: words, checkpoint: checkpoint);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('直接退出'));
    await tester.pumpAndSettle();

    expect(find.text('start'), findsOneWidget);
    expect(LearningSessionStore.load(), isNull);
  });
}
