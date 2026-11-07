// 课文详情页的翻句交互回归：竖向翻卡、底部进度条定位、短屏用上下箭头翻句，
// 「学习 / 逐句」共用同一份当前句位置、「整篇」独立，以及模型未下载门禁。

import 'package:arabic_learning/models/recitation_text.dart';
import 'package:arabic_learning/screens/test/recitation/recitation_detail_page.dart';
import 'package:arabic_learning/screens/test/recitation/recitation_progress_bar.dart';
import 'package:arabic_learning/screens/test/recitation/recitation_recite_tab.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

RecitationTextUnit _unit() => const RecitationTextUnit(
      title: '问候与自我介绍',
      difficulty: 40,
      tags: <String>['问候', '课本'],
      sentences: <RecitationSentence>[
        RecitationSentence(
          arabic: 'السَّلَامُ عَلَيْكُمْ وَرَحْمَةُ اللهِ وَبَرَكَاتُهُ',
          translation: '愿平安、怜悯与吉庆降临于你们',
          note: '见面时的问候语，回答用 وعليكم السلام',
          words: <RecitationWord>[
            RecitationWord(arabic: 'السلام', chinese: '平安'),
          ],
        ),
        RecitationSentence(
          arabic: 'أَنَا طَالِبٌ فِي الجَامِعَةِ وَأَدْرُسُ اللُّغَةَ العَرَبِيَّةَ',
          translation: '我是大学里的一名学生，正在学习阿拉伯语',
        ),
        RecitationSentence(arabic: 'كَيْفَ حَالُكَ؟', translation: '你好吗？'),
      ],
    );

int _barCurrent(WidgetTester tester) => tester
    .widget<RecitationProgressBar>(find.byType(RecitationProgressBar))
    .current;

int _blurCount(WidgetTester tester) =>
    find.byType(ImageFiltered).evaluate().length;

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(400, 700),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider<Global>(
      create: (BuildContext context) => Global(),
      child: MaterialApp(home: RecitationDetailPage(unit: _unit())),
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
  });

  setUp(() {
    AppData().recitationTextData.units.clear();
  });

  testWidgets('学习页：竖向翻卡，进度条可拖动定位', (WidgetTester tester) async {
    await _pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('点词查看释义'), findsOneWidget);
    expect(_barCurrent(tester), 1);

    await tester.drag(find.byType(PageView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(_barCurrent(tester), 2);

    await tester.drag(find.byType(Slider), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(_barCurrent(tester), 1);
  });

  testWidgets('学习页阿语按 RTL 逐词排版', (WidgetTester tester) async {
    await _pump(tester);
    // 每个词是独立 Text，未声明 RTL 时词尾标点会被排到词前，看着像提前一个词。
    final Text token = tester.widget<Text>(find.text('السَّلَامُ'));
    expect(token.textDirection, TextDirection.rtl);
  });

  testWidgets('短屏卡片溢出时用箭头翻句，且不溢出', (WidgetTester tester) async {
    await _pump(tester, size: const Size(480, 420));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('下一句'));
    await tester.pumpAndSettle();
    expect(_barCurrent(tester), 2);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('上一句'));
    await tester.pumpAndSettle();
    expect(_barCurrent(tester), 1);
  });

  testWidgets('逐句 / 整篇：各自独立翻页与模型门禁', (WidgetTester tester) async {
    await _pump(tester);
    await tester.tap(find.text('逐句'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 逐句：每句一张卡片，各有录音入口；模型未下载时给出模型管理入口。
    expect(find.text('录这一句'), findsOneWidget);
    expect(find.text('前往模型管理'), findsOneWidget);
    expect(_barCurrent(tester), 1);
    // 「统一显示中文」开关在底部进度条里。
    expect(
      find.descendant(
        of: find.byType(RecitationProgressBar),
        matching: find.byTooltip('统一显示中文'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('下一句'));
    await tester.pumpAndSettle();
    expect(_barCurrent(tester), 2);

    await tester.tap(find.text('整篇'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('显示原文'), findsOneWidget);
    expect(find.text('开始背诵'), findsOneWidget);
    expect(find.text('录这一句'), findsNothing);
    // 整篇不做逐句定位，不再显示底部进度条；开关移到「原文」标题行。
    expect(find.byType(RecitationProgressBar), findsNothing);
    expect(find.byTooltip('统一显示中文'), findsOneWidget);

    // 整篇有自己的一套滚动位置，「逐句」仍停在原句。
    await tester.tap(find.text('逐句'));
    await tester.pumpAndSettle();
    expect(_barCurrent(tester), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('逐句：320 宽进度条里的统一显示中文只解除译文模糊', (WidgetTester tester) async {
    // 直接挂逐句 tab：320 宽是底部进度条最挤的情况，同时避开「学习」页。
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<Global>(
        create: (BuildContext context) => Global(),
        child: MaterialApp(
          home: Scaffold(
            body: RecitationReciteTab(
              unit: _unit(),
              mode: RecitationReciteMode.sentence,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 开关压在底部进度条里，320 宽也不溢出。
    final Finder toggle = find.byTooltip('统一显示中文');
    expect(toggle, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RecitationProgressBar),
        matching: toggle,
      ),
      findsOneWidget,
    );

    final int blurred = _blurCount(tester);
    expect(blurred, greaterThan(0));

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    // 译文全部解除模糊，原文仍然保持模糊。
    final int zhShown = _blurCount(tester);
    expect(zhShown, lessThan(blurred));
    expect(zhShown, greaterThan(0));

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(_blurCount(tester), blurred);
    expect(tester.takeException(), isNull);
  });

  testWidgets('学习与逐句共用当前句位置', (WidgetTester tester) async {
    await _pump(tester);

    await tester.drag(find.byType(PageView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(_barCurrent(tester), 2);

    // 切到逐句：应从第 2 句开始，而不是重置为第 1 句。
    await tester.tap(find.text('逐句'));
    await tester.pumpAndSettle();
    expect(_barCurrent(tester), 2);

    await tester.tap(find.byTooltip('下一句'));
    await tester.pumpAndSettle();
    expect(_barCurrent(tester), 3);

    // 回到学习：停在逐句推进到的第 3 句。
    await tester.tap(find.text('学习'));
    await tester.pumpAndSettle();
    expect(_barCurrent(tester), 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('背诵页宽屏不溢出', (WidgetTester tester) async {
    await _pump(tester, size: const Size(1100, 900));
    await tester.tap(find.text('逐句'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
