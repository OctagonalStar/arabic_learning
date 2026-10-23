// FSRS 个性化校准测试：评分档位、结果页、展示/强制等待/答题流程与应用落盘。
import 'package:arabic_learning/models/dict.dart' show DictData, SourceItem, WordItem;
import 'package:arabic_learning/screens/learning/fsrs/fsrs_calibration_page.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

const List<String> _chinese = <String>['书', '笔', '太阳', '月亮'];
const List<String> _arabic = <String>['كِتَابٌ', 'قَلَمٌ', 'شَمْسٌ', 'قَمَرٌ'];

WordItem _word(int id, String arabic, String chinese) => WordItem(
      arabic: arabic,
      chinese: chinese,
      explanation: '',
      className: '测试课',
      id: id,
    );

/// 4 个未学词（id 0–3）——刚好够 4 选 1，也方便逐题点答案。
Future<void> _setupSmallPool() async {
  AppData().wordData = DictData(
    words: <WordItem>[
      for (int i = 0; i < 4; i++) _word(i, _arabic[i], _chinese[i]),
    ],
    classes: <SourceItem>[],
  );
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<Global>(
      create: (BuildContext context) => Global(),
      child: const MaterialApp(home: FsrsCalibrationPage()),
    ),
  );
  await tester.pump();
}

/// 从「开始校准」推进到答题阶段：点掉 4 张展示卡，再等满 60 秒。
Future<void> _enterQuiz(WidgetTester tester) async {
  await tester.tap(find.text('开始校准'));
  await tester.pump();
  // Ticker 的第一个 tick 只记录起点（elapsed=0），每段动画先 1ms 启表再走满时长。
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 61));
  await tester.pump();
}

/// 当前题面的中文（ChoiceQuestions 里的主词）。
String _currentChinese(WidgetTester tester) {
  for (final String chinese in _chinese) {
    if (find.text(chinese).evaluate().isNotEmpty) return chinese;
  }
  fail('未找到当前题面');
}

/// 作答当前题并进入下一题（`correct=false` 时随便点一个错误选项）。
Future<void> _answer(WidgetTester tester, {required bool correct, bool last = false}) async {
  final String chinese = _currentChinese(tester);
  final String right = _arabic[_chinese.indexOf(chinese)];
  final String target = correct ? right : _arabic.firstWhere((String a) => a != right);
  await tester.tap(find.textContaining(target).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(last ? '查看结果' : '下一题'));
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

  tearDown(() {
    FSRS().config = FSRS().config.copyWith(
      cards: <fsrs.Card>[],
      reviewLogs: <fsrs.ReviewLog>[],
      personalFactor: 1.0,
    );
  });

  group('personalFactorForScore 五档边界', () {
    const Map<int, double> expected = <int, double>{
      0: 0.75, 1: 0.75, 2: 0.75, 3: 0.75,
      4: 0.9, 5: 0.9,
      6: 1.0, 7: 1.0,
      8: 1.1, 9: 1.1,
      10: 1.25,
    };
    expected.forEach((int score, double factor) {
      test('$score 分 → $factor', () => expect(personalFactorForScore(score), factor));
    });
  });

  group('结果视图', () {
    Future<void> pumpResult(WidgetTester tester, int score, {int questionCount = 10}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FsrsCalibrationResultView(
              score: score,
              questionCount: questionCount,
              onApply: () {},
              onRetake: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('8 分：1.10×、记忆较强、延长说明', (WidgetTester tester) async {
      await pumpResult(tester, 8);
      expect(find.text('1.10×'), findsOneWidget);
      expect(find.text('记忆较强'), findsOneWidget);
      expect(find.text('新词的初始复习间隔会相应延长'), findsOneWidget);
      expect(find.text('应用系数'), findsOneWidget);
      expect(find.text('再测一次'), findsOneWidget);
    });

    testWidgets('3 分：0.75×、记忆较弱、缩短说明', (WidgetTester tester) async {
      await pumpResult(tester, 3);
      expect(find.text('0.75×'), findsOneWidget);
      expect(find.text('记忆较弱'), findsOneWidget);
      expect(find.text('新词的初始复习间隔会相应缩短'), findsOneWidget);
    });

    testWidgets('10 分：1.25×、记忆很强、无折算法文', (WidgetTester tester) async {
      await pumpResult(tester, 10);
      expect(find.text('1.25×'), findsOneWidget);
      expect(find.text('记忆很强'), findsOneWidget);
      expect(find.textContaining('已按比例折算'), findsNothing);
    });

    testWidgets('不足 10 题时显示折算法文', (WidgetTester tester) async {
      await pumpResult(tester, 8, questionCount: 8);
      expect(find.textContaining('本次共 8 题'), findsOneWidget);
    });
  });

  group('流程', () {
    testWidgets('每词 5 秒自动前进；60 秒等待强制且不可跳过', (WidgetTester tester) async {
      await _setupSmallPool();
      await _pumpPage(tester);
      expect(find.text('先测一测你的记忆起点'), findsOneWidget);

      await tester.tap(find.text('开始校准'));
      await tester.pump();
      // Ticker 的第一个 tick 只记录起点（elapsed=0），先用 1ms 启表。
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('1 / 4'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.text('2 / 4'), findsOneWidget);

      // 剩余展示卡继续自动前进。
      for (int i = 1; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
      }
      expect(find.text('让记忆沉淀一下'), findsOneWidget);
      expect(find.text('等待期间无法跳过'), findsOneWidget);
      expect(find.text('跳过等待'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      // 剩余不到 60 秒时仍在等待。
      await tester.pump(const Duration(seconds: 58));
      expect(find.text('答对 0'), findsNothing);
      expect(find.text('等待期间无法跳过'), findsOneWidget);

      // 满 60 秒自动进入答题。
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('答对 0'), findsOneWidget);
      expect(find.text('1 / 4'), findsOneWidget);
    });

    testWidgets('全对折算 10 分并显示 1.25×', (WidgetTester tester) async {
      await _setupSmallPool();
      await _pumpPage(tester);
      await _enterQuiz(tester);

      for (int i = 0; i < 4; i++) {
        await _answer(tester, correct: true, last: i == 3);
      }

      expect(find.text('校准完成'), findsNothing); // 结果页用得分环，不再有该标题
      expect(find.text('10'), findsOneWidget);
      expect(find.text('/ 10'), findsOneWidget);
      expect(find.text('记忆很强'), findsOneWidget);
      expect(find.text('1.25×'), findsOneWidget);
      expect(find.textContaining('本次共 4 题'), findsOneWidget);
    });

    testWidgets('应用后写入 personalFactor 并返回', (WidgetTester tester) async {
      await _setupSmallPool();
      await tester.pumpWidget(
        ChangeNotifierProvider<Global>(
          create: (BuildContext context) => Global(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) => Center(
                  child: OutlinedButton(
                    onPressed: () async {
                      final double? result = await Navigator.push<double>(
                        context,
                        MaterialPageRoute<double>(
                          builder: (BuildContext context) => const FsrsCalibrationPage(),
                        ),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('系数 $result')),
                        );
                      }
                    },
                    child: const Text('打开校准'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开校准'));
      await tester.pumpAndSettle();
      await _enterQuiz(tester);

      // 全错 → 0 分 → 0.75×。
      for (int i = 0; i < 4; i++) {
        await _answer(tester, correct: false, last: i == 3);
      }
      await tester.pumpAndSettle();
      expect(find.text('0.75×'), findsOneWidget);

      await tester.tap(find.text('应用系数'));
      await tester.pumpAndSettle();
      expect(FSRS().config.personalFactor, 0.75);
      expect(find.text('系数 0.75'), findsOneWidget);
    });
  });
}
