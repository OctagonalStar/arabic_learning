// 导入课文：选择来源 → 粘贴 AI 返回的 JSON，或复制提示词到外部 AI 使用。

import 'package:arabic_learning/core/ai_prompt.dart' show recitationPrompt;
import 'package:arabic_learning/models/recitation_text.dart';
import 'package:arabic_learning/widgets/type_choose_card.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppRadius, AppSpacing;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/overlays.dart' show showSnackBar;
import 'package:arabic_learning/widgets/shared.dart' show appInputDecoration;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';

import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/global_state.dart';

enum _Pane { source, paste, prompt }

class RecitationAddPage extends StatefulWidget {
  const RecitationAddPage({super.key});

  @override
  State<RecitationAddPage> createState() => _RecitationAddPageState();
}

class _RecitationAddPageState extends State<RecitationAddPage> {
  final TextEditingController _jsonController = TextEditingController();
  _Pane _pane = _Pane.source;
  String? _error;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  String get _paneTitle => switch (_pane) {
        _Pane.source => "选择课文来源",
        _Pane.paste => "粘贴 JSON",
        _Pane.prompt => "复制提示词",
      };

  Future<void> _import() async {
    final Global global = context.read<Global>();
    final RecitationTextUnit? unit =
        RecitationTextUnit.buildFromMap(_jsonController.text, strict: false);
    if (unit == null) {
      setState(() => _error = "无法解析，请确认是完整的 JSON");
      return;
    }
    final List<RecitationTextUnit> units =
        AppData().recitationTextData.units;
    final String hash = unit.getHash();
    if (units.any((RecitationTextUnit u) => u.getHash() == hash)) {
      setState(() => _error = "这篇课文已存在");
      return;
    }
    units.add(unit);
    await AppData().saveRecitationTextData();
    global.uiLogger.info("导入背诵课文: ${unit.title}");
    if (!mounted) return;
    Navigator.pop(context, unit);
  }

  Widget _pastePane(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _jsonController,
          keyboardType: TextInputType.multiline,
          maxLines: 10,
          style: const TextStyle(fontFamily: "monospace"),
          decoration: appInputDecoration(
            context,
            hintText: "粘贴 AI 返回的 JSON",
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              _error!,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Button(
            onPressed: _import,
            child: const Text("导入"),
          ),
        ),
      ],
    );
  }

  Widget _promptPane(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "① 把提示词连同课文图片或阿语文本发给任意 AI\n② 把它返回的 JSON 粘回「粘贴 JSON」",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.controlBorder,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  recitationPrompt,
                  style: const TextStyle(fontFamily: "monospace"),
                ),
              ),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Button(
                onPressed: () async {
                  await Clipboard.setData(
                      const ClipboardData(text: recitationPrompt));
                  if (!mounted) return;
                  showSnackBar(context, "已复制提示词");
                },
                child: const Text("复制提示词"),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Button(
                onPressed: () => setState(() {
                  _pane = _Pane.paste;
                  _error = null;
                }),
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: const Text("去粘贴"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double cardHeight =
        (MediaQuery.sizeOf(context).height * 0.2).clamp(140.0, 220.0);
    final double cardWidth = MediaQuery.sizeOf(context).width * 0.8;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _paneTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_pane == _Pane.source) ...[
                    SizedBox(height: AppSpacing.lg),
                    TypeChooseCard(
                      mainTitle: Text("粘贴 JSON",
                          style: theme.textTheme.headlineMedium),
                      subTitle: Text(
                          "把整理好的课文 JSON 直接粘贴导入",
                          style: theme.textTheme.bodyLarge),
                      width: cardWidth,
                      height: cardHeight,
                      onTap: () => setState(() {
                        _pane = _Pane.paste;
                        _error = null;
                      }),
                    ),
                    SizedBox(height: AppSpacing.md),
                    TypeChooseCard(
                      mainTitle: Text("复制提示词",
                          style: theme.textTheme.headlineMedium),
                      subTitle: Text(
                          "复制整理提示词，发给任意聊天 AI 整理课文，再把返回的 JSON 粘回来",
                          style: theme.textTheme.bodyLarge),
                      width: cardWidth,
                      height: cardHeight,
                      onTap: () => setState(() => _pane = _Pane.prompt),
                    ),
                    SizedBox(height: AppSpacing.lg),
                  ],
                  if (_pane == _Pane.paste) _pastePane(theme),
                  if (_pane == _Pane.prompt) _promptPane(theme),
                  SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
