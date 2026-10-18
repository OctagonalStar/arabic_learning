import 'package:arabic_learning/models/dict.dart'
    show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/models/plan.dart' show PlanScopeRef, StudyPlan;
import 'package:arabic_learning/screens/learning/plan/plan_entry_card.dart';
import 'package:arabic_learning/screens/learning/plan/plan_home_page.dart';
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS, FSRSConfig;
import 'package:arabic_learning/services/plan_scheduler.dart' show evaluateNow;
import 'package:arabic_learning/services/plan_store.dart' show PlanStore;
import 'package:arabic_learning/theme/app_theme.dart' show buildTheme;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs show Card, State;

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

StudyPlan _plan({
  int groupSize = 5,
  DateTime? deadline,
  List<PlanScopeRef>? scope,
}) {
  return StudyPlan(
    id: 'plan',
    deadline: deadline ?? _todayPlus(7),
    scope:
        scope ??
        const <PlanScopeRef>[
          PlanScopeRef(sourceFile: 's1.json', className: 'A'),
        ],
    groupSize: groupSize,
  );
}

Future<void> _pumpCard(
  WidgetTester tester, {
  Size size = const Size(800, 600),
  double height = 64.0,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: PlanEntryCard(height: height),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(PlanEntryCard))).colorScheme;

/// 磁贴容器色（Button 内部 ElevatedButton 的 backgroundColor）。
Color? _tileBackground(WidgetTester tester) {
  final ElevatedButton button = tester.widget<ElevatedButton>(
    find.byType(ElevatedButton),
  );
  return button.style?.backgroundColor?.resolve(const <WidgetState>{});
}

/// 入口卡底边的进度条（Material `LinearProgressIndicator`）。
LinearProgressIndicator? _progressBar(WidgetTester tester) {
  final Finder finder = find.byType(LinearProgressIndicator);
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<LinearProgressIndicator>(finder);
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

  testWidgets('无计划：磁贴显示引导文案，点击进入计划首页', (WidgetTester tester) async {
    await _pumpCard(tester);

    expect(find.text('计划学习'), findsOneWidget);
    expect(find.text('设定截止日期，自动规划每日学习量'), findsOneWidget);
    expect(find.byType(Button), findsOneWidget);
    // 与学习页其余按钮同族：没有 chevron；无计划时也没有底部进度线。
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(_tileBackground(tester), _scheme(tester).primaryContainer);
    expect(find.byType(PlanHomePage), findsNothing);
    // 与页面其余 0.8 宽磁贴同宽并居中。
    expect(tester.getCenter(find.byType(Button)).dx, closeTo(400.0, 0.5));

    await tester.tap(find.byType(PlanEntryCard));
    await tester.pumpAndSettle();

    expect(find.byType(PlanHomePage), findsOneWidget);
    expect(find.text('还没有学习计划'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('复习系统未启用：次级容器色 + 提示启用', (WidgetTester tester) async {
    await PlanStore().setPlan(_plan());
    FSRS().config = FSRSConfig(enabled: false);

    await _pumpCard(tester);

    expect(find.text('需先启用复习系统'), findsOneWidget);
    expect(find.byIcon(Icons.history_edu_outlined), findsOneWidget);
    expect(_tileBackground(tester), _scheme(tester).secondaryContainer);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('范围失效：错误容器色 + 重新配置提示', (WidgetTester tester) async {
    await PlanStore().setPlan(
      _plan(
        scope: const <PlanScopeRef>[
          PlanScopeRef(sourceFile: 'missing.json', className: 'X'),
        ],
      ),
    );

    await _pumpCard(tester);

    expect(find.text('学习范围已失效，需重新配置'), findsOneWidget);
    expect(find.byIcon(Icons.link_off_rounded), findsOneWidget);
    expect(_tileBackground(tester), _scheme(tester).errorContainer);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('进行中：今日进度与剩余天数，进度线嵌在磁贴底边', (WidgetTester tester) async {
    await PlanStore().setPlan(_plan());
    evaluateNow(); // 建立当日快照（最低 5 词）
    await PlanStore().recordProgress(2);

    await _pumpCard(tester);

    expect(find.text('今日 2/5 · 剩 7 天'), findsOneWidget);
    expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
    expect(_tileBackground(tester), _scheme(tester).primaryContainer);

    final LinearProgressIndicator? bar = _progressBar(tester);
    expect(bar, isNotNull);
    expect(bar!.value, closeTo(0.4, 1e-9));
    expect(bar.minHeight, 16.0);
    // 进度线贴住磁贴底边、铺满宽度、高 16，而不是浮在内容区的独立条。
    final Rect tile = tester.getRect(find.byType(Button));
    final Rect line = tester.getRect(find.byType(LinearProgressIndicator));
    expect(line.bottom, closeTo(tile.bottom, 0.5));
    expect(line.left, closeTo(tile.left, 0.5));
    expect(line.right, closeTo(tile.right, 0.5));
    expect(line.height, closeTo(16.0, 0.5));
    // 正文让出底边进度带，状态文案不会压在进度带上。
    final Rect statusRect = tester.getRect(find.text('今日 2/5 · 剩 7 天'));
    expect(statusRect.bottom, lessThanOrEqualTo(line.top));

    await tester.tap(find.byType(PlanEntryCard));
    await tester.pumpAndSettle();

    expect(find.byType(PlanHomePage), findsOneWidget);
    expect(find.text('继续学习（还差 3 词）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('今日达标：完成容器色 + 满分底边进度', (WidgetTester tester) async {
    await PlanStore().setPlan(_plan());
    evaluateNow();
    await PlanStore().recordProgress(5);

    await _pumpCard(tester);

    expect(find.text('今日已达标 · 可继续学习'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(_tileBackground(tester), _scheme(tester).tertiaryContainer);
    expect(_progressBar(tester)?.value, 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('周期完成：完成容器色 + 满分底边进度', (WidgetTester tester) async {
    FSRS().config = FSRSConfig(
      enabled: true,
      cards: <fsrs.Card>[
        for (int i = 0; i < 10; i++)
          fsrs.Card(cardId: i, state: fsrs.State.learning),
      ],
    );
    await PlanStore().setPlan(_plan());

    await _pumpCard(tester);

    expect(find.text('本周期已完成'), findsOneWidget);
    expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
    expect(_tileBackground(tester), _scheme(tester).tertiaryContainer);
    expect(_progressBar(tester)?.value, 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('逾期：错误容器色 + 剩余词数', (WidgetTester tester) async {
    await PlanStore().setPlan(_plan(deadline: _todayPlus(0)));

    await _pumpCard(tester);

    expect(find.text('已逾期 · 剩 10 词'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(_tileBackground(tester), _scheme(tester).errorContainer);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('紧凑高度（横屏小窗口）：标题完整、不溢出', (WidgetTester tester) async {
    await PlanStore().setPlan(_plan());
    evaluateNow();
    await PlanStore().recordProgress(2);

    await _pumpCard(tester, size: const Size(480, 420), height: 40.0);

    expect(find.text('计划学习'), findsOneWidget);
    expect(_progressBar(tester), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('多尺寸 + 系统大字号：磁贴不溢出', (WidgetTester tester) async {
    for (final Size size in const <Size>[
      Size(360, 640),
      Size(480, 420),
      Size(800, 600),
      Size(1280, 800),
    ]) {
      for (final double height in const <double>[60.0, 72.0]) {
        await _pumpCard(tester, size: size, height: height, textScale: 2.0);
        expect(
          tester.takeException(),
          isNull,
          reason: '$size / 高度 $height / 2 倍字号下磁贴溢出',
        );
        expect(find.text('计划学习'), findsOneWidget);
      }
    }
  });
}
