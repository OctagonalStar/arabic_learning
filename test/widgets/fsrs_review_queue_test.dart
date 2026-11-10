import 'package:arabic_learning/models/dict.dart' show DictData, SourceItem, WordItem;
import 'package:arabic_learning/screens/learning/fsrs/fsrs_review_page.dart' show MainFSRSPage;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS, FSRSConfig;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/search.dart' show BKSearch;
import 'package:fsrs/fsrs.dart' show Card, Rating, ReviewLog, Scheduler;
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

/// 复习页不预建队列：每次构建都取当前到期最早的卡片。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const List<WordItem> words = <WordItem>[
    WordItem(arabic: 'لقاء', chinese: '相会', explanation: '见面', className: '第一课', id: 0),
    WordItem(arabic: 'كتاب', chinese: '书', explanation: '书籍', className: '第一课', id: 1),
    WordItem(arabic: 'قلم', chinese: '笔', explanation: '书写工具', className: '第一课', id: 2),
  ];

  /// 卡片与日志按下标一一对应（生产数据的不变式）；占位日志用 again 便于断言。
  FSRSConfig buildConfig(List<Card> cards, {bool reinforce = false, bool scheduler = true}) {
    final DateTime now = DateTime.now();
    return FSRSConfig(
      enabled: true,
      selfEvaluate: true,
      reinforceMemory: reinforce,
      scheduler: scheduler ? Scheduler() : null,
      cards: cards,
      reviewLogs: <ReviewLog>[
        for (final Card card in cards)
          ReviewLog(cardId: card.cardId, rating: Rating.again, reviewDateTime: now),
      ],
    );
  }

  setUpAll(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
  });

  setUp(() {
    AppData().wordData = const DictData(words: words, classes: <SourceItem>[]);
    BKSearch.rebuild(words);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<Global>(
        create: (BuildContext context) => Global(),
        child: MaterialApp(home: MainFSRSPage(fsrs: FSRS())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> swipe(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(0, -700));
    await tester.pumpAndSettle();
  }

  testWidgets('每次下滑取最近到期：未作答的卡片会再次出现，作答后换下一张', (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    FSRS().config = buildConfig(<Card>[
      Card(cardId: 0, due: now.add(const Duration(days: 5))),
      Card(cardId: 1, due: now.subtract(const Duration(days: 2))),
      Card(cardId: 2, due: now.add(const Duration(days: 1))),
    ]);

    await pumpPage(tester);
    expect(find.text('上滑页面开始复习'), findsOneWidget);

    // 唯一逾期的卡片最早到期，先出现。
    await swipe(tester);
    expect(find.textContaining('已逾期 2 天'), findsOneWidget);

    // 没作答就滑走，它仍是最近的一张，下一屏再次出现。
    await swipe(tester);
    expect(find.textContaining('已逾期 2 天'), findsOneWidget);

    // 作答后到期时间推后，下一屏换成「1 天后」的卡片。
    await tester.tap(find.text('记得很清楚'));
    await tester.pumpAndSettle();
    await swipe(tester);
    expect(find.textContaining('1 天后'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('进度条只统计逾期卡片，全部完成后隐藏', (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    FSRS().config = buildConfig(<Card>[
      Card(cardId: 0, due: now.add(const Duration(days: 5))),
      Card(cardId: 1, due: now.subtract(const Duration(days: 2))),
    ]);

    await pumpPage(tester);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await swipe(tester);
    await tester.tap(find.text('记得很清楚'));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // 从不逾期时没有进度条。
    FSRS().config = buildConfig(
      <Card>[Card(cardId: 0, due: now.add(const Duration(days: 2)))],
      scheduler: false,
    );
    await pumpPage(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('强化记忆：第一次 good+ 不提交，第二次 good+ 才提交且用第二次评级', (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    FSRS().config = buildConfig(
      <Card>[Card(cardId: 0, due: now.subtract(const Duration(days: 2)))],
      reinforce: true,
    );
    final DateTime before = FSRS().config.cards.first.due;

    await pumpPage(tester);
    await swipe(tester);
    await tester.tap(find.text('记得很清楚'));
    await tester.pumpAndSettle();

    // 第一次 good+：不提交，卡片仍然逾期、进度条仍在。
    expect(FSRS().config.cards.first.due, before);
    expect(FSRS().config.reviewLogs.single.rating, Rating.again);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // 再次取到同一张卡；第二次 good 才提交，评级取第二次的 good。
    await swipe(tester);
    expect(find.textContaining('已逾期 2 天'), findsOneWidget);
    await tester.tap(find.text('还记得'));
    await tester.pumpAndSettle();

    expect(FSRS().config.cards.first.due.isAfter(before), isTrue);
    expect(FSRS().config.reviewLogs.single.rating, Rating.good);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('强化记忆：第二次未达 good 则两次都不提交', (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    FSRS().config = buildConfig(
      <Card>[Card(cardId: 0, due: now.subtract(const Duration(days: 2)))],
      reinforce: true,
    );
    final DateTime before = FSRS().config.cards.first.due;

    await pumpPage(tester);
    await swipe(tester);
    await tester.tap(find.text('记得很清楚'));
    await tester.pumpAndSettle();
    await swipe(tester);
    await tester.tap(find.text('忘了'));
    await tester.pumpAndSettle();

    expect(FSRS().config.cards.first.due, before);
    expect(FSRS().config.reviewLogs.single.rating, Rating.again);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
