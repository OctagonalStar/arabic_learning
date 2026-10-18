import 'package:arabic_learning/models/dict.dart'
    show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/models/plan.dart'
    show PlanScopeRef, StudyPlan;
import 'package:arabic_learning/screens/learning/plan/plan_config_page.dart';
import 'package:arabic_learning/screens/learning/plan/plan_home_page.dart';
import 'package:arabic_learning/screens/learning/plan/plan_session_page.dart'
    show PlanSessionPage;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS, FSRSConfig;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/plan_scheduler.dart' show evaluateNow;
import 'package:arabic_learning/services/plan_store.dart' show PlanStore;
import 'package:arabic_learning/theme/app_theme.dart' show buildTheme;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs show Card, State;
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

/// 单课程小词库：课程 `s1.json / A`，[count] 个词，id 按插入顺序生成。
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

/// 相对当前日期的截止日期（页面内部用 `DateTime.now()`，故不能写死日期）。
DateTime _todayPlus(int days) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days);
}

StudyPlan _plan({
  List<PlanScopeRef>? scope,
  DateTime? deadline,
  int groupSize = 5,
}) {
  return StudyPlan(
    id: 'plan',
    deadline: deadline ?? _todayPlus(7),
    scope: scope ??
        const <PlanScopeRef>[
          PlanScopeRef(sourceFile: 's1.json', className: 'A'),
        ],
    groupSize: groupSize,
  );
}

/// 全部 [count] 个词都已进入 FSRS 的配置。
FSRSConfig _allLearned(int count) {
  return FSRSConfig(
    enabled: true,
    cards: <fsrs.Card>[
      for (int i = 0; i < count; i++)
        fsrs.Card(cardId: i, state: fsrs.State.learning),
    ],
  );
}

ThemeData _theme() => buildTheme(ColorScheme.fromSeed(seedColor: Colors.teal));

/// 以 800×600 渲染计划首页（宽屏阈值 600 以上，内容居中限宽 720）。
Future<void> _pumpHome(
  WidgetTester tester, {
  Size size = const Size(800, 600),
  double textScale = 1.0,
  Key? key,
  bool withGlobal = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final Widget home = PlanHomePage(key: key);
  final Widget app = MaterialApp(theme: _theme(), home: home);
  await tester.pumpWidget(
    // 会话页是 push 出来的新路由，Provider 必须放在 MaterialApp 之上。
    withGlobal
        ? ChangeNotifierProvider<Global>(
            create: (BuildContext context) => Global(),
            child: app,
          )
        : app,
  );
  await tester.pumpAndSettle();
}

/// 渲染配置页；`showSnackBar` 依赖 `context.read<Global>()`，需提供 Provider。
Future<void> _pumpConfig(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<Global>(
      create: (BuildContext context) => Global(),
      child: MaterialApp(
        theme: _theme(),
        home: const PlanConfigPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 点击「保存计划」并等待 SnackBar 渲染完成。
///
/// 不在测试里吞掉异常：若底栏再次撑满页面，floating SnackBar 会被判定为
/// 移出屏幕并抛错，这里应让测试直接失败。
Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.text('保存计划'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
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
    FSRS().config = FSRSConfig(enabled: true, cards: <fsrs.Card>[]);
  });

  group('计划首页六态', () {
    testWidgets('无计划：显示配置引导与「建立学习计划」', (WidgetTester tester) async {
      await _pumpHome(tester);

      expect(find.text('计划学习'), findsOneWidget); // AppBar 标题
      expect(find.text('还没有学习计划'), findsOneWidget);
      expect(find.text('建立学习计划'), findsOneWidget);
      expect(find.text('开始今日学习'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('复习系统未启用：提示启用且不提供开始学习', (WidgetTester tester) async {
      await PlanStore().setPlan(_plan());
      FSRS().config = FSRSConfig(enabled: false, cards: <fsrs.Card>[]);

      await _pumpHome(tester);

      expect(find.text('计划学习需要复习系统'), findsOneWidget);
      expect(find.text('前往复习设置'), findsOneWidget);
      expect(find.text('开始今日学习'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('进行中：显示周期概览、今日 X/Y、剩余天数与开始按钮', (WidgetTester tester) async {
      await PlanStore().setPlan(_plan(deadline: _todayPlus(7), groupSize: 5));

      await _pumpHome(tester);

      // 10 词 / 7 天 / 每组 5 → 今日最低 5 词（1 组）
      expect(find.text('本周期'), findsOneWidget);
      expect(find.text('剩 7 天'), findsOneWidget);
      expect(find.text('/ 10 词'), findsOneWidget); // 周期卡
      expect(find.text('/ 5 词'), findsOneWidget); // 今日卡
      expect(find.text('待学 10 词'), findsOneWidget);
      expect(find.text('今日任务'), findsOneWidget);
      expect(find.text('第 1/1 组'), findsOneWidget);
      expect(find.text('开始今日学习'), findsOneWidget);
      expect(find.text('每组 5 词 · 每日至少 1 组'), findsOneWidget);
      expect(find.text('调整计划'), findsOneWidget);
      // 进度条统一改用 Material 原生组件：周期概览 + 今日任务。
      expect(
        find.byType(LinearProgressIndicator),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('进行中：学习范围、学习链条与计划设置区块都有内容', (WidgetTester tester) async {
      await PlanStore().setPlan(_plan(deadline: _todayPlus(7), groupSize: 5));

      await _pumpHome(tester);

      expect(find.text('学习范围'), findsOneWidget);
      expect(find.text('共 10 词'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'A'), findsOneWidget);
      expect(find.text('学习链条'), findsOneWidget);
      expect(find.text('1. 单词卡片学习'), findsOneWidget);
      expect(find.text('2. 阿译中 选择题'), findsOneWidget);
      expect(find.text('组内顺序'), findsOneWidget);
      expect(find.text('计划设置'), findsOneWidget);
      expect(find.text('每组词数'), findsOneWidget);
      expect(find.text('组内单词乱序'), findsOneWidget);
      expect(find.text('打乱课程顺序'), findsOneWidget);
      expect(find.text('介入连胜'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('多尺寸 + 系统大字号：进行中页面不溢出', (WidgetTester tester) async {
      for (final Size size in const <Size>[
        Size(360, 640),
        Size(480, 420),
        Size(800, 600),
        Size(1280, 800),
      ]) {
        await PlanStore().setPlan(_plan(deadline: _todayPlus(7), groupSize: 5));
        evaluateNow();
        await PlanStore().recordProgress(2);

        await _pumpHome(
          tester,
          size: size,
          textScale: 2.0,
          key: ValueKey<Size>(size),
        );

        expect(
          tester.takeException(),
          isNull,
          reason: '$size / 2 倍字号下计划首页溢出',
        );
        expect(find.text('今日任务'), findsOneWidget);
      }
    });

    testWidgets('多尺寸 + 系统大字号：空状态不溢出', (WidgetTester tester) async {
      for (final Size size in const <Size>[
        Size(360, 640),
        Size(480, 420),
        Size(800, 600),
        Size(1280, 800),
      ]) {
        await PlanStore().clear();
        await _pumpHome(
          tester,
          size: size,
          textScale: 2.0,
          key: ValueKey<Size>(size),
        );

        expect(
          tester.takeException(),
          isNull,
          reason: '$size / 2 倍字号下空状态溢出',
        );
        expect(find.text('还没有学习计划'), findsOneWidget);
      }
    });

    testWidgets('逾期：显示延期入口，点击弹出延期对话框', (WidgetTester tester) async {
      // 截止日期为今天且仍有剩余 → 逾期
      await PlanStore().setPlan(_plan(deadline: _todayPlus(0)));

      await _pumpHome(tester);

      expect(find.text('已逾期'), findsOneWidget);
      expect(find.text('已逾期，仍有 10 词未学'), findsOneWidget);
      expect(find.text('延期 7 天'), findsOneWidget);
      expect(find.text('仍要学习（剩 10 词）'), findsOneWidget);

      await tester.tap(find.text('延期 7 天'));
      await tester.pumpAndSettle();

      expect(find.text('延期截止日期'), findsOneWidget);
      expect(find.text('延期 3 天'), findsOneWidget);
      expect(find.text('延期 14 天'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('全部学完：显示周期完成态', (WidgetTester tester) async {
      FSRS().config = _allLearned(10);
      await PlanStore().setPlan(_plan(deadline: _todayPlus(7)));

      await _pumpHome(tester);

      expect(find.text('本周期已完成'), findsOneWidget);
      expect(find.text('配置下一周期'), findsOneWidget);
      expect(find.text('开始今日学习'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('开始学习只传入一组单词', (WidgetTester tester) async {
      // 15 词 / 剩 2 天 / 每组 5 → 今日最低 10 词（2 组）；首次只应取 1 组。
      AppData().wordData = _dict(15);
      await PlanStore().setPlan(_plan(deadline: _todayPlus(2), groupSize: 5));

      await _pumpHome(tester, withGlobal: true);
      expect(find.text('第 1/2 组'), findsOneWidget);

      await tester.tap(find.text('开始今日学习'));
      await tester.pumpAndSettle();

      final PlanSessionPage session = tester.widget<PlanSessionPage>(
        find.byType(PlanSessionPage),
      );
      expect(session.words.length, 5);
      expect(find.textContaining('第 1/2 组'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('范围失效：提示重新配置', (WidgetTester tester) async {
      await PlanStore().setPlan(_plan(
        scope: const <PlanScopeRef>[
          PlanScopeRef(sourceFile: 'missing.json', className: 'X'),
        ],
      ));

      await _pumpHome(tester);

      expect(find.text('学习范围已失效'), findsOneWidget);
      expect(find.text('重新配置'), findsOneWidget);
      expect(find.text('开始今日学习'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('配置页保存校验', () {
    testWidgets('布局：底栏不吞掉正文，内容区高度正常', (WidgetTester tester) async {
      await _pumpConfig(tester);

      // 回归保护：bottomNavigationBar 里的 Center 若不限制 heightFactor，
      // 会撑满整屏并把正文压成 0 高（配置页完全不可用）。
      final Size viewport = tester.getSize(
        find.byType(SingleChildScrollView).first,
      );
      expect(viewport.height, greaterThan(300));

      expect(find.text('截止日期'), findsOneWidget);
      final Rect saveRect = tester.getRect(
        find.widgetWithText(ElevatedButton, '保存计划'),
      );
      expect(saveRect.height, lessThan(80));
      expect(tester.takeException(), isNull);
    });

    testWidgets('复习系统未启用：保存按钮禁用并显示阻断卡', (WidgetTester tester) async {
      FSRS().config = FSRSConfig(enabled: false, cards: <fsrs.Card>[]);

      await _pumpConfig(tester);

      expect(find.text('复习系统未启用'), findsOneWidget);
      final ElevatedButton save = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '保存计划'),
      );
      expect(save.enabled, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('保存时复习系统被停用：提示「请先启用复习系统」', (WidgetTester tester) async {
      await _pumpConfig(tester);
      // 页面 initState 时已启用（按钮可点），保存前被外部停用 → 走保存内兜底校验
      FSRS().config = FSRSConfig(enabled: false, cards: <fsrs.Card>[]);

      await _tapSave(tester);

      expect(find.text('请先启用复习系统'), findsOneWidget);
    });

    testWidgets('没有学习范围：提示「请先补全标红的配置项」', (WidgetTester tester) async {
      await _pumpConfig(tester);

      await _tapSave(tester);

      expect(find.text('请先补全标红的配置项'), findsOneWidget);
      expect(find.text('请选择至少一门还有未学单词的课程'), findsOneWidget);
    });
  });
}
