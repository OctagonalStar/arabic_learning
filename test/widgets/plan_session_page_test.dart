import 'package:arabic_learning/models/dict.dart'
    show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/models/plan.dart'
    show PlanChain, PlanScopeRef, StudyPlan;
import 'package:arabic_learning/screens/learning/plan/plan_question_builder.dart'
    show countNewLearnedWords;
import 'package:arabic_learning/screens/learning/plan/plan_session_page.dart';
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS, FSRSConfig;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/plan_scheduler.dart'
    show dayKeyOf, evaluateNow;
import 'package:arabic_learning/services/plan_store.dart' show PlanStore;
import 'package:arabic_learning/services/search.dart' show BKSearch;
import 'package:arabic_learning/widgets/questions.dart'
    show ChoiceQuestions, WordCardQuestion;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

/// 6 个释义互不相同的单词：保证选择题干扰项充足。
List<WordItem> _words([int count = 6]) {
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

DictData _dict([int count = 6]) {
  return DictData(
    words: _words(count),
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

StudyPlan _plan({List<int> sections = const <int>[0, 2]}) {
  return StudyPlan(
    id: 'plan',
    deadline: DateTime.now().add(const Duration(days: 30)),
    scope: const <PlanScopeRef>[
      PlanScopeRef(sourceFile: 's1.json', className: 'A'),
    ],
    groupSize: 2,
    chain: PlanChain(sections: sections),
    streakGate: true,
    configuredDayKey: dayKeyOf(DateTime.now()),
  );
}

Future<void> _pumpSession(
  WidgetTester tester, {
  required List<WordItem> words,
  required PlanChain chain,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<Global>(
      create: (BuildContext context) => Global(),
      child: MaterialApp(
        home: PlanSessionPage(words: words, chain: chain),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 等待题目内部的「作答后 700ms 揭示下一步」计时器。
Future<void> _revealNext(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 800));
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
    await PlanStore().clear();
    AppData().wordData = _dict();
    BKSearch.rebuild(AppData().wordData.words);
    FSRS().config = FSRSConfig(enabled: true);
  });

  group('出题与统计辅助函数', () {
    test('countNewLearnedWords 只统计作答前未学、作答后已学的词', () {
      final List<WordItem> words = _words(4);
      expect(
        countNewLearnedWords(
          words: words,
          beforeIds: const <int>{0},
          isLearned: (int id) => id < 3,
        ),
        2,
      );
      expect(
        countNewLearnedWords(
          words: words,
          beforeIds: const <int>{0, 1, 2, 3},
          isLearned: (int id) => true,
        ),
        0,
      );
    });
  });

  group('PlanSessionPage 前置守卫', () {
    testWidgets('FSRS 未启用时阻断且不生成题目', (WidgetTester tester) async {
      FSRS().config = FSRSConfig(enabled: false);

      await _pumpSession(
        tester,
        words: _words().take(2).toList(),
        chain: const PlanChain(sections: <int>[2]),
      );

      expect(find.textContaining('计划学习依赖复习系统的已学记录'), findsOneWidget);
      expect(find.text('返回'), findsOneWidget);
      expect(find.byType(ChoiceQuestions), findsNothing);
      expect(find.byType(WordCardQuestion), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('本组单词为空时阻断', (WidgetTester tester) async {
      await _pumpSession(
        tester,
        words: const <WordItem>[],
        chain: const PlanChain(sections: <int>[2]),
      );

      expect(find.textContaining('本组没有可学习的单词'), findsOneWidget);
      expect(find.byType(ChoiceQuestions), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('PlanSessionPage 作答', () {
    testWidgets('非卡片题作答会生成 FSRS 卡片', (WidgetTester tester) async {
      await PlanStore().setPlan(_plan(sections: const <int>[2]));
      evaluateNow();

      await _pumpSession(
        tester,
        words: <WordItem>[_words().first],
        chain: const PlanChain(sections: <int>[2]),
      );

      expect(find.byType(ChoiceQuestions), findsOneWidget);
      await tester.tap(find.text('释义0'));
      await tester.pump();

      expect(
        FSRS().config.cards.any((card) => card.cardId == 0),
        isTrue,
        reason: '选择题作答后应写入 FSRS',
      );
      await _revealNext(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('完成一组后 delta 与今日 doneWords 增加', (WidgetTester tester) async {
      await PlanStore().setPlan(_plan());
      final int minWords = evaluateNow().minWords;
      expect(minWords, 2);

      await _pumpSession(
        tester,
        words: _words().take(2).toList(),
        chain: const PlanChain(sections: <int>[0, 2]),
      );

      // section-major：先两张单词卡（word0、word1）
      expect(find.byType(WordCardQuestion), findsOneWidget);
      await tester.tap(find.text('下一题'));
      await tester.pumpAndSettle();
      expect(find.byType(WordCardQuestion), findsOneWidget);
      await tester.tap(find.text('下一题'));
      await tester.pumpAndSettle();

      // 再两道阿译中选择题（word0、word1）
      expect(find.byType(ChoiceQuestions), findsOneWidget);
      await tester.tap(find.text('释义0'));
      await _revealNext(tester);
      await tester.tap(find.text('下一个'));
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceQuestions), findsOneWidget);
      await tester.tap(find.text('释义1'));
      await _revealNext(tester);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 完成页
      expect(find.text('学习完成'), findsOneWidget);
      expect(find.text('今日最低目标已完成'), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(PlanStore().state.today?.doneWords, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('完成页在 480×420 不 overflow', (WidgetTester tester) async {
      await PlanStore().setPlan(_plan(sections: const <int>[0]));
      evaluateNow();

      await _pumpSession(
        tester,
        words: <WordItem>[_words().first],
        chain: const PlanChain(sections: <int>[0]),
        size: const Size(480, 420),
      );

      await tester.tap(find.text('下一题'));
      await tester.pumpAndSettle();

      expect(find.text('学习完成'), findsOneWidget);
      expect(find.text('再来一组'), findsOneWidget);
      expect(find.text('返回'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
