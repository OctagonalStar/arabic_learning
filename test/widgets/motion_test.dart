import 'package:arabic_learning/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 动效控件的行为测试：延迟封顶、动画有限可结束、减弱动态效果下跳过动画。
void main() {
  group('StaggeredEntrance.delayFor', () {
    test('按 index 线性递增并以 maxDelay 封顶', () {
      expect(StaggeredEntrance.delayFor(0), Duration.zero);
      expect(
        StaggeredEntrance.delayFor(4),
        const Duration(milliseconds: 100),
      );
      expect(
        StaggeredEntrance.delayFor(100),
        StaggeredEntrance.defaultMaxDelay,
      );
    });
  });

  testWidgets('FadeSlideIn 延迟期间保持起始态，动画有限且可 pumpAndSettle', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FadeSlideIn(
          delay: Duration(milliseconds: 250),
          child: Text('入场'),
        ),
      ),
    );

    final Finder opacityFinder = find.descendant(
      of: find.byType(FadeSlideIn),
      matching: find.byType(Opacity),
    );
    expect(opacityFinder, findsOneWidget);
    expect(tester.widget<Opacity>(opacityFinder).opacity, 0.0);

    await tester.pumpAndSettle();
    expect(find.text('入场'), findsOneWidget);
    // 终态直接渲染 child，不残留 Opacity 图层。
    expect(opacityFinder, findsNothing);
  });

  testWidgets('StaggeredEntrance 超出动画上限后直接渲染 child', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StaggeredEntrance(
          index: StaggeredEntrance.defaultMaxAnimatedItems,
          child: Text('late'),
        ),
      ),
    );

    expect(find.text('late'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });

  testWidgets('StaggeredEntrance 首屏项创建有限入场动画', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StaggeredEntrance(index: 0, child: Text('first')),
      ),
    );

    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
  });

  testWidgets('减弱动态效果时 FadeSlideIn 不做动画', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: FadeSlideIn(child: Text('静态')),
        ),
      ),
    );

    expect(find.text('静态'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });

  testWidgets('CrossFadeSwitcher 在 key 变化后完成交叉淡入', (WidgetTester tester) async {
    Widget build(bool loading) => MaterialApp(
          home: CrossFadeSwitcher(
            child: loading
                ? const SizedBox(key: ValueKey<String>('loading'))
                : const SizedBox(key: ValueKey<String>('content')),
          ),
        );

    await tester.pumpWidget(build(true));
    await tester.pumpWidget(build(false));
    await tester.pumpAndSettle();

    expect(find.byType(AnimatedSwitcher), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('content')),
      findsOneWidget,
    );
  });
}
