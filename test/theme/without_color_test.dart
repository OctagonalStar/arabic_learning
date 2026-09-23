import 'package:arabic_learning/theme/app_theme.dart' show buildTheme;
import 'package:arabic_learning/theme/typography.dart' show withoutColor;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('withoutColor', () {
    test('强制 inherit:true，保证剥离颜色后仍继承外层前景色', () {
      // 模拟 MaterialApp 下 `Theme.of(context).textTheme.*` 常见的 inherit:false。
      const TextStyle themeStyle = TextStyle(
        inherit: false,
        fontSize: 36.0,
        color: Color(0xFF123456),
      );
      final TextStyle stripped = withoutColor(themeStyle);
      expect(stripped.color, isNull);
      expect(stripped.inherit, isTrue);
      expect(stripped.fontSize, 36.0);
    });
  });

  group('按钮内 withoutColor 文本（浅色模式可读性回归）', () {
    testWidgets('文字继承按钮前景色 onPrimaryContainer，而不是回退成白色', (WidgetTester tester) async {
      final ThemeData theme =
          buildTheme(ColorScheme.fromSeed(seedColor: Colors.teal));
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                final ColorScheme scheme = Theme.of(context).colorScheme;
                final TextTheme text = Theme.of(context).textTheme;
                return Button(
                  backgroundColor: scheme.primaryContainer,
                  onPressed: () {},
                  child: Text('标签', style: withoutColor(text.displaySmall!)),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final RenderParagraph p =
          tester.renderObject<RenderParagraph>(find.text('标签'));
      expect(p.text.style?.color, theme.colorScheme.onPrimaryContainer,
          reason: '按钮文字应使用 onPrimaryContainer（浅色模式下为深色）');
      expect(p.text.style?.color, isNot(Colors.white));
    });
  });
}
