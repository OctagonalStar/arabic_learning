// 课文详情页的翻句交互回归：竖向翻卡、底部进度条定位、短屏用上下箭头翻句，
// 以及背诵页「逐句 / 整篇」切换与模型未下载门禁。

import 'package:arabic_learning/models/recitation_text.dart';
import 'package:arabic_learning/screens/test/recitation/recitation_detail_page.dart';
import 'package:arabic_learning/screens/test/recitation/recitation_progress_bar.dart';
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

  testWidgets('背诵页：逐句 / 整篇切换与模型门禁', (WidgetTester tester) async {
    await _pump(tester);
    await tester.tap(find.text('背诵'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 逐句：每句一张卡片，各有录音入口；模型未下载时给出模型管理入口。
    expect(find.text('录这一句'), findsOneWidget);
    expect(find.text('前往模型管理'), findsOneWidget);

    await tester.tap(find.text('整篇'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('显示原文'), findsOneWidget);
    expect(find.text('开始背诵'), findsOneWidget);

    // 整篇滚动后底部进度条跟随当前句。
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(_barCurrent(tester), greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('背诵页宽屏不溢出', (WidgetTester tester) async {
    await _pump(tester, size: const Size(1100, 900));
    await tester.tap(find.text('背诵'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
