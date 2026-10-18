import 'package:arabic_learning/models/dict.dart'
    show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/models/plan.dart' show PlanScopeRef, StudyPlan;
import 'package:arabic_learning/screens/learning/plan/plan_entry_card.dart';
import 'package:arabic_learning/screens/learning/plan/plan_home_page.dart';
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS, FSRSConfig;
import 'package:arabic_learning/services/plan_store.dart' show PlanStore;
import 'package:arabic_learning/theme/app_theme.dart' show buildTheme;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

DictData _dict([int count = 10]) {
  return DictData(
    words: List<WordItem>.generate(
      count,
      (int i) => WordItem(
        arabic: 'كلمة$i',
        chinese: '释义$i',
        explanation: '',
        className: 'A',
        id: i,
      ),
      growable: false,
    ),
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

/// 相对当前日期的截止日期（页面内部用 `DateTime.now()`）。
DateTime _todayPlus(int days) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days);
}

StudyPlan _plan({int groupSize = 5}) {
  return StudyPlan(
    id: 'plan',
    deadline: _todayPlus(7),
    scope: const <PlanScopeRef>[
      PlanScopeRef(sourceFile: 's1.json', className: 'A'),
    ],
    groupSize: groupSize,
  );
}

Future<void> _pumpCard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: const PlanEntryCard(),
        ),
      ),
    ),
  );
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
    FSRS().config = FSRSConfig(enabled: true);
  });

  testWidgets('无计划：显示引导文案，点击进入计划首页', (WidgetTester tester) async {
    await _pumpCard(tester);

    expect(find.text('计划学习'), findsOneWidget);
    expect(find.text('设定截止日期，自动规划每日学习量'), findsOneWidget);
    expect(find.byType(PlanHomePage), findsNothing);

    await tester.tap(find.byType(PlanEntryCard));
    await tester.pumpAndSettle();

    expect(find.byType(PlanHomePage), findsOneWidget);
    expect(find.text('还没有学习计划'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('进行中：显示今日进度与剩余天数，点击进入计划首页', (WidgetTester tester) async {
    await PlanStore().setPlan(_plan());

    await _pumpCard(tester);

    // 10 词 / 7 天 / 每组 5 → 今日最低 5 词
    expect(find.text('今日 0/5 · 剩 7 天'), findsOneWidget);

    await tester.tap(find.byType(PlanEntryCard));
    await tester.pumpAndSettle();

    expect(find.byType(PlanHomePage), findsOneWidget);
    expect(find.text('开始今日学习'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
