import 'package:arabic_learning/models/reading.dart';
import 'package:arabic_learning/screens/test/reading_test_page.dart'
    show ReadingQuestionPage, ReadingTestAddLeading, readingTextScaler;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 阅读题页面尺寸测试：窄竖屏降级为上下布局、宽屏保持左右分栏，
/// 两种布局下均不得出现 overflow；同时校验自适应文字倍率随宽度增大。
void main() {
  ReadingUnit buildUnit() => const ReadingUnit(
        type: 1,
        title: '测试文章',
        passage: 'هذه فقرة اختبارية طويلة بعض الشيء لاختبار التفاف النص داخل عمود المقالة. '
            'هذه فقرة اختبارية طويلة بعض الشيء لاختبار التفاف النص داخل عمود المقالة. '
            'هذه فقرة اختبارية طويلة بعض الشيء لاختبار التفاف النص داخل عمود المقالة.',
        difficulty: 4,
        tashkeel: false,
        questions: <ReadingQuestion>[
          ReadingQuestion(
            riddle: 'ما معنى الكلمة في السياق؟',
            answers: <String>['معنى أول', 'معنى ثان', 'معنى ثالث', 'معنى رابع'],
            type: '理解',
            analysis: '根据上下文推断词义。',
          ),
        ],
        corrects: <int>[],
        tags: <String>['词汇'],
      );

  Future<void> pumpReadingPage(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: ReadingQuestionPage(unit: buildUnit())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('360x640 窄竖屏：上下布局且无 overflow', (WidgetTester tester) async {
    await pumpReadingPage(tester, const Size(360, 640));

    expect(tester.takeException(), isNull);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('480x420 矮横屏：上下布局且无 overflow', (WidgetTester tester) async {
    await pumpReadingPage(tester, const Size(480, 420));

    expect(tester.takeException(), isNull);
  });

  testWidgets('800x1280 平板竖屏：左右分栏且无 overflow', (WidgetTester tester) async {
    await pumpReadingPage(tester, const Size(800, 1280));

    expect(tester.takeException(), isNull);
    expect(find.byType(PageView), findsOneWidget);
  });

  test('readingTextScaler 随可用宽度分档递增', () {
    final double phone = readingTextScaler(360).scale(10);
    final double tablet = readingTextScaler(800).scale(10);
    final double desktop = readingTextScaler(1280).scale(10);

    expect(phone, lessThan(tablet));
    expect(tablet, lessThan(desktop));
    expect(phone, 18.0);
    expect(tablet, 22.0);
    expect(desktop, 26.0);
  });

  testWidgets('480x420 新增阅读题类型页：两页均无 overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(480, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ReadingTestAddLeading()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 进入第二页（4 张来源卡片，原本 0.2 倍屏高会撑破 Column）
    await tester.tap(find.text('阅读理解'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
