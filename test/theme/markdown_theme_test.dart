import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:arabic_learning/theme/app_theme.dart';
import 'package:arabic_learning/theme/markdown_theme.dart';
import 'package:arabic_learning/theme/theme_resolver.dart';
import 'package:arabic_learning/models/config.dart' show RegularConfig;

void main() {
  testWidgets('Markdown 正文颜色跟随深色主题', (WidgetTester tester) async {
    final ThemeData theme = buildTheme(
      ThemeResolver.seedScheme(const RegularConfig(), Brightness.dark),
    );
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: MarkdownBody(
            data: '# 标题\n\n正文',
            styleSheet: markdownStyleSheet(context),
          ),
        ),
      ),
    ));

    final Iterable<Color?> colors = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((RichText text) => text.text.style?.color);
    expect(colors, isNotEmpty);
    // 插件默认走 SDK Theme.of，在本应用里取不到主题会回退亮色；显式样式表必须
    // 让正文与标题都用深色主题的 onSurface。
    for (final Color? color in colors) {
      expect(color, theme.colorScheme.onSurface);
    }
  });
}
