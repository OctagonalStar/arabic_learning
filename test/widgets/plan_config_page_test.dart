// 「计划学习」配置页的交互测试：Slider、常驻题型 chips、链条校验、
// 标签筛选后的统计与保存，以及保存失败提示。

import 'package:arabic_learning/models/dict.dart'
    show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/models/plan.dart'
    show PlanChain, PlanScopeRef, StudyPlan;
import 'package:arabic_learning/screens/learning/plan/plan_config_page.dart';
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS, FSRSConfig;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/plan_store.dart' show PlanStore;
import 'package:arabic_learning/theme/app_theme.dart' show buildTheme;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs show Card;
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

/// 单课程小词库：课程 `s1.json / A`，[count] 个词。
///
/// [categoriesOf] 按单词下标返回分类标签，用于标签筛选测试。
DictData _dict({
  int count = 10,
  List<String> Function(int index)? categoriesOf,
}) {
  return DictData(
    words: List<WordItem>.generate(
      count,
      (int i) => WordItem(
        arabic: 'كلمة$i',
        chinese: '释义$i',
        explanation: '',
        className: 'A',
        id: i,
        categories: categoriesOf?.call(i) ?? const <String>[],
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

DateTime _todayPlus(int days) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days);
}

StudyPlan _plan({
  int groupSize = 10,
  List<int> sections = const <int>[0, 2],
}) {
  return StudyPlan(
    id: 'plan',
    deadline: _todayPlus(7),
    scope: const <PlanScopeRef>[
      PlanScopeRef(sourceFile: 's1.json', className: 'A'),
    ],
    groupSize: groupSize,
    chain: PlanChain(sections: sections),
  );
}

ThemeData _theme() => buildTheme(ColorScheme.fromSeed(seedColor: Colors.teal));

/// 先把配置页压在宿主路由之上再打开，保存成功时的 `pop` 不会弹出根路由。
Future<void> _pumpConfig(
  WidgetTester tester, {
  StudyPlan? initial,
  Size size = const Size(800, 1000),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ChangeNotifierProvider<Global>(
      create: (BuildContext context) => Global(),
      child: MaterialApp(
        theme: _theme(),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (BuildContext context) =>
                        PlanConfigPage(initial: initial),
                  ),
                ),
                child: const Text('打开配置页'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('打开配置页'));
  await tester.pumpAndSettle();
}

/// 点击课程选择弹窗：勾选课程 `A`，可选标签，然后确认。
///
/// `lib/widgets/kit.dart` 的课程列表把 `CheckboxListTile` 包在带底色的
/// `Container` 里，Flutter 会因此报一条 debug-only 的「ink 可能不可见」提示。
/// 该文件不在本次改动范围内，这里只过滤这一条已知提示，其余异常照常上报。
Future<void> _chooseCourse(
  WidgetTester tester, {
  String? category,
}) async {
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains(
          'ListTile background color or ink splashes may be invisible',
        )) {
      return;
    }
    previous?.call(details);
  };
  try {
    await tester.tap(find.text('选择课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'A'));
    await tester.pump();
    if (category != null) {
      final Finder chip = find.widgetWithText(FilterChip, category);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pump();
    }
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = previous;
  }
}

/// 点击「保存计划」并等待 SnackBar 渲染完成。
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

  group('配置页控件', () {
    testWidgets('单组数量 Slider 可调 5–30，保存写回 groupSize',
        (WidgetTester tester) async {
      await _pumpConfig(tester, initial: _plan(groupSize: 10));

      final Finder slider = find.byKey(
        const ValueKey<String>('planGroupSizeSlider'),
      );
      expect(slider, findsOneWidget);

      // 拖到最右 → 30。
      await tester.drag(slider, const Offset(1000.0, 0.0));
      await tester.pumpAndSettle();
      expect(find.textContaining('每组 30 词'), findsOneWidget);

      // 拖到最左 → 5。
      await tester.drag(slider, const Offset(-1000.0, 0.0));
      await tester.pumpAndSettle();
      expect(find.textContaining('每组 5 词'), findsOneWidget);

      // 再拖回最右并保存 → 30。
      await tester.drag(slider, const Offset(1000.0, 0.0));
      await tester.pumpAndSettle();
      expect(find.textContaining('每组 30 词'), findsOneWidget);

      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(PlanStore().state.plan?.groupSize, 30);
    });

    testWidgets('旧计划 groupSize 超出区间时按 30 夹紧显示并保存',
        (WidgetTester tester) async {
      await _pumpConfig(tester, initial: _plan(groupSize: 50));

      expect(find.textContaining('每组 30 词'), findsOneWidget);
      final Slider slider = tester.widget<Slider>(
        find.byKey(const ValueKey<String>('planGroupSizeSlider')),
      );
      expect(slider.value, 30.0);

      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(PlanStore().state.plan?.groupSize, 30);
    });

    testWidgets('常驻题型 chips 点击后追加到链条末尾', (WidgetTester tester) async {
      await _pumpConfig(tester, initial: _plan(sections: const <int>[0, 2]));

      expect(find.text('2 个'), findsOneWidget);
      expect(find.byType(ActionChip), findsNWidgets(4));

      await tester.tap(
        find.widgetWithText(ActionChip, '中译阿 拼写题'),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 个'), findsOneWidget);

      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(
        PlanStore().state.plan?.chain.sections,
        <int>[0, 2, 3],
      );
    });

    testWidgets('删除链条中的非卡片题后，保存提示链条校验',
        (WidgetTester tester) async {
      await _pumpConfig(tester, initial: _plan(sections: const <int>[0, 2]));

      // 第 2 行是「阿译中 选择题」，删除后只剩单词卡片 → 链条非法。
      await tester.tap(find.byIcon(Icons.delete).at(1));
      await tester.pumpAndSettle();
      expect(find.text('1 个'), findsOneWidget);

      await _tapSave(tester);

      expect(find.text('请先补全标红的配置项'), findsOneWidget);
      expect(
        find.text('学习链条至少需要包含 1 个非单词卡片题型'),
        findsOneWidget,
      );
    });

    testWidgets('窄屏 + 系统大字号：配置页不溢出', (WidgetTester tester) async {
      await _pumpConfig(
        tester,
        initial: _plan(sections: const <int>[0]),
        size: const Size(360, 640),
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('配置学习计划'), findsOneWidget);
      expect(find.text('学习节奏预览'), findsOneWidget);
    });
  });

  group('标签筛选', () {
    testWidgets('按标签筛选后统计与今日最低量预览使用过滤后的词数',
        (WidgetTester tester) async {
      // 偶数下标为「四级」，奇数下标为「六级」→ 各 5 词。
      AppData().wordData = _dict(
        categoriesOf: (int index) =>
            index.isEven ? const <String>['四级'] : const <String>['六级'],
      );
      await _pumpConfig(tester);

      await _chooseCourse(tester, category: '四级');

      expect(find.text('共 5 词 · 已学 0 · 可学 5'), findsOneWidget);
      expect(find.widgetWithText(InputChip, '四级'), findsOneWidget);
      // 10 词 / 7 天 / 每组 10 → 每天至少 5 词，约 1 组。
      expect(find.text('剩余可学 5 词 · 剩余 7 天'), findsOneWidget);
      expect(find.text('预计每日至少 5 词（约 1 组）'), findsOneWidget);

      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(PlanStore().state.plan?.categories, <String>['四级']);
      expect(PlanStore().state.plan?.scope.length, 1);
    });

    testWidgets('清除标签后恢复完整范围', (WidgetTester tester) async {
      AppData().wordData = _dict(
        categoriesOf: (int index) =>
            index.isEven ? const <String>['四级'] : const <String>['六级'],
      );
      await _pumpConfig(tester);

      await _chooseCourse(tester, category: '四级');
      expect(find.text('共 5 词 · 已学 0 · 可学 5'), findsOneWidget);

      await tester.tap(find.text('清除标签'));
      await tester.pumpAndSettle();

      expect(find.text('共 10 词 · 已学 0 · 可学 10'), findsOneWidget);
      expect(find.widgetWithText(InputChip, '四级'), findsNothing);
    });

    testWidgets('重选课程但未勾选标签时保留原标签', (WidgetTester tester) async {
      AppData().wordData = _dict(
        categoriesOf: (int index) =>
            index.isEven ? const <String>['四级'] : const <String>['六级'],
      );
      await _pumpConfig(tester, initial: _plan());

      // 直接给页面注入标签：先通过弹窗勾选一次。
      await _chooseCourse(tester, category: '四级');
      expect(find.widgetWithText(InputChip, '四级'), findsOneWidget);

      // 再次打开只改课程（弹窗里不勾标签），标签应保留。
      await _chooseCourse(tester);
      expect(find.widgetWithText(InputChip, '四级'), findsOneWidget);
      expect(find.text('共 5 词 · 已学 0 · 可学 5'), findsOneWidget);
    });

    testWidgets('标签过滤后为 0 词：保存提示「所选标签下没有可学单词」',
        (WidgetTester tester) async {
      // 课程 A 只含「四级」；「六级」词不属于 A，但会让筛选区出现该标签。
      AppData().wordData = DictData(
        words: <WordItem>[
          for (int i = 0; i < 11; i++)
            WordItem(
              arabic: 'كلمة$i',
              chinese: '释义$i',
              explanation: '',
              className: 'A',
              id: i,
              categories: i < 10
                  ? const <String>['四级']
                  : const <String>['六级'],
            ),
        ],
        classes: <SourceItem>[
          SourceItem(
            sourceJsonFileName: 's1.json',
            subClasses: <ClassItem>[
              ClassItem(
                className: 'A',
                wordIndexs: List<int>.generate(10, (int i) => i),
              ),
            ],
          ),
        ],
      );
      await _pumpConfig(tester);

      await _chooseCourse(tester, category: '六级');
      expect(find.text('共 0 词 · 已学 0 · 可学 0'), findsOneWidget);

      await _tapSave(tester);

      // SnackBar 提示 + 学习范围内联红字各一处。
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('所选标签下没有可学单词'),
        ),
        findsOneWidget,
      );
      expect(find.text('所选标签下没有可学单词'), findsNWidgets(2));
      expect(PlanStore().state.plan, isNull);
    });
  });
}
