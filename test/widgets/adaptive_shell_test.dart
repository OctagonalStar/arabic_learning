import 'dart:convert';

import 'package:arabic_learning/app.dart' show MyApp;
import 'package:arabic_learning/models/config.dart';
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/core/statics.dart' show StaticsVar;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

/// 应用外壳在多尺寸下的冒烟测试：验证响应式布局选择正确且无 overflow。
///
/// 尺寸覆盖：手机竖屏、平板竖屏、桌面横屏与桌面最小尺寸（矮横屏）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    mockPathProvider();
    mockStorage(<String, Object>{
      // 非首次启动，且条款版本与当前版本一致，直接进入主页
      'settingData': jsonEncode(
        const Config(lastTermVersion: StaticsVar.termVersion).toMap(),
      ),
      'wordData': jsonEncode(<String, dynamic>{
        'Words': <dynamic>[],
        'Classes': <String, dynamic>{},
      }),
    });
  });

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<Global>(
        create: (BuildContext context) => Global(),
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // 未选中状态下导航项的图标（NavigationBar 与 NavigationRail 共用）
  const List<IconData> unselectedNavIcons = <IconData>[
    Icons.home_outlined,
    Icons.book_outlined,
    Icons.edit_outlined,
    Icons.settings_applications_outlined,
  ];

  /// 依次切换到 4 个顶层 Tab，并在每次切换后断言无布局异常。
  Future<void> switchThroughTabs(WidgetTester tester, Size size) async {
    for (int tab = 0; tab < unselectedNavIcons.length; tab++) {
      if (tab != 0) {
        final Finder destination = find.byIcon(unselectedNavIcons[tab]);
        expect(destination, findsWidgets, reason: '$size 下找不到第 $tab 个导航目标');
        await tester.tap(destination.first);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: '$size 下第 $tab 个 Tab 溢出');
    }
  }

  testWidgets('手机 360x640：移动布局且无 overflow', (WidgetTester tester) async {
    await pumpShell(tester, const Size(360, 640));

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('主页'), findsOneWidget);
  });

  testWidgets('平板 800x1280：宽度断点走桌面布局且无 overflow', (WidgetTester tester) async {
    await pumpShell(tester, const Size(800, 1280));

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('桌面 1280x800：桌面布局且无 overflow', (WidgetTester tester) async {
    await pumpShell(tester, const Size(1280, 800));

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('桌面最小尺寸 480x420（矮横屏）：可用且无 overflow', (WidgetTester tester) async {
    await pumpShell(tester, const Size(480, 420));

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  group('四个顶层 Tab 在多尺寸下切换无 overflow', () {
    testWidgets('360x640 手机竖屏', (WidgetTester tester) async {
      await pumpShell(tester, const Size(360, 640));
      await switchThroughTabs(tester, const Size(360, 640));
    });

    testWidgets('480x420 矮横屏', (WidgetTester tester) async {
      await pumpShell(tester, const Size(480, 420));
      await switchThroughTabs(tester, const Size(480, 420));
    });

    testWidgets('1280x800 桌面横屏', (WidgetTester tester) async {
      await pumpShell(tester, const Size(1280, 800));
      await switchThroughTabs(tester, const Size(1280, 800));
    });

    testWidgets('1280x600 矮桌面横屏', (WidgetTester tester) async {
      await pumpShell(tester, const Size(1280, 600));
      await switchThroughTabs(tester, const Size(1280, 600));
    });

    testWidgets('800x1280 平板竖屏', (WidgetTester tester) async {
      await pumpShell(tester, const Size(800, 1280));
      await switchThroughTabs(tester, const Size(800, 1280));
    });
  });
}
