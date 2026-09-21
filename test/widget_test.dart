import 'dart:convert';

import 'package:arabic_learning/main.dart' show MyApp;
import 'package:arabic_learning/vars/config_structure.dart';
import 'package:arabic_learning/vars/global.dart' show Global;
import 'package:arabic_learning/vars/statics_var.dart' show StaticsVar;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // path_provider 与 shared_preferences 均为平台插件，测试进程需在测试侧
    // mock，避免触发 MissingPluginException（不修改生产代码）。
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

  testWidgets('应用冒烟：Global 初始化完成后展示主框架与首页', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<Global>(
        create: (BuildContext context) => Global(),
        child: const MyApp(),
      ),
    );

    // MyApp 用 FutureBuilder 等待 Global.init()，需要等待 loading 结束。
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text(StaticsVar.appName), findsOneWidget);
    expect(find.text('主页'), findsOneWidget);
    expect(find.text('每日一词'), findsOneWidget);
  });
}
