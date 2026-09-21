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
}
