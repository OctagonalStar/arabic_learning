import 'package:arabic_learning/widgets/kit.dart' show TextContainer;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double opacityOf(WidgetTester tester) => tester
      .widget<Opacity>(find.descendant(
        of: find.byType(TextContainer),
        matching: find.byType(Opacity),
      ))
      .opacity;

  Widget build(String text, {bool animated = true}) => MaterialApp(
        home: Scaffold(
          body: Center(child: TextContainer(text: text, animated: animated)),
        ),
      );

  Finder background() => find.descendant(
        of: find.byType(TextContainer),
        matching: find.byType(DecoratedBox),
      );

  testWidgets('入场淡入；文本变化后重新播放', (WidgetTester tester) async {
    await tester.pumpWidget(build('已逾期 2 天'));
    expect(opacityOf(tester), lessThan(1.0));

    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1.0);

    // 复习答题后 hint 追加用时：同一个 TextContainer 位置换了文本
    await tester.pumpWidget(build('已逾期 2 天 用时: 1234毫秒'));
    expect(opacityOf(tester), lessThan(1.0));

    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1.0);
  });

  testWidgets('背景从略小长到完整，且不影响布局尺寸', (WidgetTester tester) async {
    await tester.pumpWidget(build('已逾期 2 天'));
    final Size layout = tester.getSize(background());
    final Size outer = tester.getSize(find.byType(TextContainer));
    final Rect firstFrame = tester.getRect(background());
    // 布局尺寸自始至终不变，只有绘制被缩放。
    expect(firstFrame.width, lessThan(layout.width));
    expect(firstFrame.height, lessThan(layout.height));

    await tester.pumpAndSettle();
    expect(tester.getRect(background()).size, layout);
    expect(tester.getSize(find.byType(TextContainer)), outer);

    // animated: false 走静态分支：没有入场包装，尺寸与动画结束后一致。
    await tester.pumpWidget(build('已逾期 2 天', animated: false));
    expect(find.byType(Opacity), findsNothing);
    expect(tester.getSize(find.byType(TextContainer)), outer);
    expect(tester.getSize(background()), layout);
  });
}
