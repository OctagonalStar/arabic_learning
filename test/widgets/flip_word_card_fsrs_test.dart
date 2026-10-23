// 反面「记忆状态」区的行为测试：有 FSRS 记录时显示，无记录时完全省略。
//
// 独立成文件：FSRS 是全局单例，flutter test 按文件隔离 isolate，
// 避免污染 `flip_word_card_test.dart` 里「FSRS 未初始化」的前提。
import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/widgets/flip_word_card.dart' show FlipWordCard;
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

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

  tearDown(() {
    // 防止 FSRS 记录泄漏到同文件内的其它用例。
    FSRS().config = FSRS().config.copyWith(cards: <fsrs.Card>[], reviewLogs: <fsrs.ReviewLog>[]);
  });

  const WordItem word = WordItem(
    arabic: 'كِتَابٌ',
    chinese: '书',
    explanation: '',
    className: '第二课',
    id: 42,
  );

  Future<void> pumpCard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<Global>(
        create: (BuildContext context) => Global(),
        child: const MaterialApp(home: Scaffold(body: Center(child: FlipWordCard(word: word, enableFlip: false, startOnBack: true)))),
      ),
    );
  }

  testWidgets('FSRS 有记录时背面显示记忆状态：难度 / 可提取率 / 下次复习 / 上次复习', (WidgetTester tester) async {
    FSRS().config = FSRSConfig(
      cards: <fsrs.Card>[
        fsrs.Card(
          cardId: word.id,
          state: fsrs.State.review,
          stability: 12.5,
          difficulty: 6.4,
          due: DateTime.now().add(const Duration(days: 3)),
          lastReview: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
      reviewLogs: <fsrs.ReviewLog>[
        fsrs.ReviewLog(
          cardId: word.id,
          rating: fsrs.Rating.good,
          reviewDateTime: DateTime.now().subtract(const Duration(days: 1)),
          reviewDuration: 4200,
        ),
      ],
    );

    await pumpCard(tester);

    expect(find.text('记忆状态'), findsOneWidget);
    expect(find.text('难度'), findsOneWidget);
    expect(find.text('6.4'), findsOneWidget);
    expect(find.text('可提取率'), findsOneWidget);
    // 可提取率随 now/lastReview 浮动：只断言存在以 % 结尾的整数百分比。
    final double? expected = FSRS().retrievabilityFor(word.id);
    expect(expected, isNotNull);
    final String expectedPct = '${(expected! * 100).round()}%';
    expect(find.text(expectedPct), findsOneWidget, reason: '可提取率应为整数百分比 $expectedPct');
    expect(
      find.byWidgetPredicate((Widget w) => w is Text && (w.data ?? '').endsWith('%')),
      findsOneWidget,
    );
    expect(find.text('下次复习'), findsOneWidget);
    expect(find.text('3 天后'), findsOneWidget);
    expect(find.textContaining('2026'), findsAtLeastNWidgets(1), reason: '下次复习块内附绝对日期 yyyy-MM-dd');
    expect(find.textContaining('上次复习'), findsOneWidget);
    expect(find.textContaining('一般'), findsOneWidget, reason: 'Rating.good → 一般（Text.rich 内联，非独立 Text）');
    expect(find.textContaining('4.2 秒'), findsOneWidget, reason: '复习用时随行展示');
    expect(tester.takeException(), isNull);
  });

  testWidgets('记忆状态位于归属课程之前，且三块 tile 严格等高', (WidgetTester tester) async {
    FSRS().config = FSRSConfig(
      cards: <fsrs.Card>[
        fsrs.Card(
          cardId: word.id,
          state: fsrs.State.review,
          stability: 12.5,
          difficulty: 6.4,
          due: DateTime.now().add(const Duration(days: 3)),
          lastReview: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
      reviewLogs: <fsrs.ReviewLog>[
        fsrs.ReviewLog(
          cardId: word.id,
          rating: fsrs.Rating.good,
          reviewDateTime: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
    );

    await pumpCard(tester);

    // 记忆状态标题在归属课程标题上方。
    final double memoryDy = tester.getTopLeft(find.text('记忆状态')).dy;
    final double courseDy = tester.getTopLeft(find.text('归属课程')).dy;
    expect(memoryDy, lessThan(courseDy), reason: '记忆状态应排在归属课程之前');

    // 三枚数值块（含多一行日期小注的「下次复习」）高度严格一致。
    final double h1 = tester.getSize(find.text('难度')).height;
    final double h2 = tester.getSize(find.text('可提取率')).height;
    final double h3 = tester.getSize(find.text('下次复习')).height;
    expect(h1, h2);
    expect(h2, h3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FSRS 无记录时记忆状态区完全省略', (WidgetTester tester) async {
    await pumpCard(tester);

    expect(find.text('记忆状态'), findsNothing);
    expect(find.text('难度'), findsNothing);
    expect(find.text('可提取率'), findsNothing);
    expect(find.text('下次复习'), findsNothing);
    expect(find.textContaining('上次复习'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('难度 / 稳定度为空时以「—」占位，逾期下次复习用相对文案', (WidgetTester tester) async {
    FSRS().config = FSRSConfig(
      cards: <fsrs.Card>[
        fsrs.Card(
          cardId: word.id,
          state: fsrs.State.review,
          due: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ],
      reviewLogs: const <fsrs.ReviewLog>[],
    );

    await pumpCard(tester);

    expect(find.text('记忆状态'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2), reason: '难度与稳定度均为空');
    expect(find.text('已逾期 2 天'), findsOneWidget);
    expect(find.textContaining('上次复习'), findsNothing, reason: '无日志时不渲染最近复习行');
    expect(tester.takeException(), isNull);
  });
}
