// Markdown 样式表：把应用主题（`material_ui`）翻译成 `flutter_markdown_plus`
// 的 `MarkdownStyleSheet`。
//
// 必须显式传入，不能依赖 `MarkdownBody` 的默认样式：插件内部用 SDK 的
// `package:flutter/material.dart` 的 `Theme.of`，而本应用的主题由
// `package:material_ui` 提供（两套独立的 `Theme`/`ThemeData` 类型），插件查不到
// 主题就回退 `ThemeData.fallback()`（亮色），导致深色模式下 Markdown 正文仍是黑字。

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_ui/material_ui.dart';

/// 按当前主题构建 Markdown 样式表（颜色取自 `ColorScheme`，字号取自 `TextTheme`）。
///
/// 非文本字段（间距、边框、引用块与代码块背景）也一并给出，避免插件与
/// 亮色回退样式合并后留下亮色装饰。
MarkdownStyleSheet markdownStyleSheet(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  final TextTheme text = theme.textTheme;
  final ColorScheme scheme = theme.colorScheme;
  final TextStyle body = text.bodyMedium!;
  final BorderRadius codeRadius = BorderRadius.circular(2.0);

  return MarkdownStyleSheet(
    a: TextStyle(color: scheme.primary),
    p: body,
    pPadding: EdgeInsets.zero,
    code: body.copyWith(
      backgroundColor: theme.cardTheme.color,
      fontFamily: 'monospace',
      fontSize: body.fontSize! * 0.85,
    ),
    h1: text.headlineSmall,
    h1Padding: EdgeInsets.zero,
    h2: text.titleLarge,
    h2Padding: EdgeInsets.zero,
    h3: text.titleMedium,
    h3Padding: EdgeInsets.zero,
    h4: text.bodyLarge,
    h4Padding: EdgeInsets.zero,
    h5: text.bodyLarge,
    h5Padding: EdgeInsets.zero,
    h6: text.bodyLarge,
    h6Padding: EdgeInsets.zero,
    em: const TextStyle(fontStyle: FontStyle.italic),
    strong: const TextStyle(fontWeight: FontWeight.bold),
    del: const TextStyle(decoration: TextDecoration.lineThrough),
    blockquote: body,
    img: body,
    checkbox: body.copyWith(color: scheme.primary),
    blockSpacing: 8.0,
    listIndent: 24.0,
    listBullet: body,
    listBulletPadding: const EdgeInsets.only(right: 4),
    tableHead: const TextStyle(fontWeight: FontWeight.w600),
    tableBody: body,
    tableHeadAlign: TextAlign.center,
    tablePadding: const EdgeInsets.only(bottom: 4.0),
    tableBorder: TableBorder.all(color: theme.dividerColor),
    tableColumnWidth: const FlexColumnWidth(),
    tableCellsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    tableCellsDecoration: const BoxDecoration(),
    blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    blockquoteDecoration: BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(3),
      border: Border(
        left: BorderSide(color: scheme.primary, width: 3),
      ),
    ),
    codeblockPadding: const EdgeInsets.all(8.0),
    codeblockDecoration: BoxDecoration(
      color: theme.cardTheme.color,
      borderRadius: codeRadius,
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(width: 5.0, color: theme.dividerColor)),
    ),
  );
}
