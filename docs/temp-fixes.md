# 临时修复表

记录为了绕过**上游依赖**缺陷而写的临时代码。每条都要写清「触发条件 / 现状 / 删除条件」，
上游修好并升级后，按表逐条删掉对应代码与这里的条目。

新增条目请追加到表格末尾，删除后整行移除。

| # | 位置 | 上游问题 | 我们的绕法 | 删除条件 |
| --- | --- | --- | --- | --- |
| 1 | `lib/theme/markdown_theme.dart`（`markdownStyleSheet`），及 8 个 `MarkdownBody`/`Markdown` 调用点的 `styleSheet:` 参数 | `flutter_markdown_plus` 1.0.12 内部用 SDK 的 `package:flutter/material.dart` 的 `Theme.of`；本应用主题由 `package:material_ui` 提供，两套 `ThemeData` 是不同类型，插件查不到主题就回退 `ThemeData.fallback()`（亮色），深色模式下 Markdown 全是黑字 | 显式构造 `MarkdownStyleSheet` 传入，颜色/字号/装饰全部取自 `material_ui` 的 `Theme` | 上游改用 `material_ui`（或不再读 `Theme.of`、默认样式改由调用方提供）并升级 `flutter_markdown_plus` 后，先删 8 处 `styleSheet:` 参数、跑 `test/theme/markdown_theme_test.dart` 确认默认样式已跟随深色主题，再删 `lib/theme/markdown_theme.dart`、该测试文件与 `docs/shared-api.md` 里的对应行 |
