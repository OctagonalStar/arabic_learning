// 学习 tab：逐句展示阿语原文 + 译文 + 注释，点词弹底部候选词表。

import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/models/recitation_text.dart';
import 'package:arabic_learning/services/recitation_text.dart' show normalizeArabic, lookupStems;
import 'package:arabic_learning/services/search.dart' show BKSearch;
import 'package:arabic_learning/services/tts.dart' show playTextToSpeech;
import 'package:arabic_learning/theme/tokens.dart' show AppRadius, AppSpacing;
import 'package:arabic_learning/widgets/overlays.dart' show showWordCardOverlay;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

class RecitationStudyTab extends StatelessWidget {
  final RecitationTextUnit unit;
  const RecitationStudyTab({super.key, required this.unit});

  Future<void> _showWordSheet(BuildContext context, String raw) async {
    final ThemeData theme = Theme.of(context);
    // 候选词：本课生词（归一化后命中词干）优先，其余来自词库逐词干查询去重。
    final List<String> stems = lookupStems(raw);
    final Set<String> lessonKeys = <String>{};
    final List<RecitationWord> lessonWords = <RecitationWord>[];
    for (final RecitationSentence sentence in unit.sentences) {
      for (final RecitationWord word in sentence.words) {
        final String key = normalizeArabic(word.arabic);
        if (stems.contains(key) && lessonKeys.add(key)) lessonWords.add(word);
      }
    }
    final Map<String, WordItem> byKey = <String, WordItem>{};
    final List<WordItem> candidates = <WordItem>[];
    final Set<int> seen = <int>{};
    for (final String stem in stems) {
      for (final WordItem item in BKSearch.lookup(stem)) {
        final String key = normalizeArabic(item.arabic);
        byKey.putIfAbsent(key, () => item);
        if (lessonKeys.contains(key)) continue; // 已作为「本课生词」列出
        if (seen.add(item.id)) candidates.add(item);
      }
    }
    // 生词表里的词若本地词库没有，就只用它自己的释义开卡片（id -1 仅占位）。
    void openLessonWord(RecitationWord word) {
      final String key = normalizeArabic(word.arabic);
      showWordCardOverlay(
        context,
        byKey[key] ??
            WordItem(
              arabic: word.arabic,
              chinese: word.chinese,
              explanation: "",
              className: "",
              id: -1,
            ),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: <Widget>[
            Text(raw,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            if (candidates.isEmpty && lessonWords.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text("本地词库未收录", style: theme.textTheme.bodyMedium),
              )
            else ...[
              for (final RecitationWord word in lessonWords)
                ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: AppRadius.controlBorder,
                    ),
                    child: Text("本课生词",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        )),
                  ),
                  title: Text(word.arabic, textDirection: TextDirection.rtl),
                  subtitle: word.chinese.isEmpty
                      ? null
                      : Text(word.chinese),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    openLessonWord(word);
                  },
                ),
              for (final WordItem item in candidates)
                ListTile(
                  dense: true,
                  title: Text(item.arabic, textDirection: TextDirection.rtl),
                  subtitle: Text(item.chinese),
                  trailing: Wrap(
                    spacing: AppSpacing.xxs,
                    children: <Widget>[
                      if (item.pos.isNotEmpty)
                        Text(item.pos, style: theme.textTheme.labelSmall),
                      if (item.root.isNotEmpty)
                        Text(item.root,
                            textDirection: TextDirection.rtl,
                            style: theme.textTheme.labelSmall),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showWordCardOverlay(context, item);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double width = MediaQuery.sizeOf(context).width * 0.9;
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: <Widget>[
          for (int i = 0; i < unit.sentences.length; i++)
            Center(
              child: SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: _TappableSentence(
                            arabic: unit.sentences[i].arabic,
                            onTapWord: (String word) =>
                                _showWordSheet(context, word),
                          ),
                        ),
                        IconButton(
                          tooltip: "朗读",
                          onPressed: () =>
                              playTextToSpeech(unit.sentences[i].arabic),
                          icon: const Icon(Icons.volume_up),
                        ),
                      ],
                    ),
                    if (unit.sentences[i].translation.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          unit.sentences[i].translation,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (unit.sentences[i].note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          "注 ${unit.sentences[i].note}",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 整词可点：按空白切分，每个词用 GestureDetector 包裹（框架自动释放手势），
/// 点击回调原文词形；标点等非阿语 token 不可点。
class _TappableSentence extends StatelessWidget {
  final String arabic;
  final ValueChanged<String> onTapWord;

  const _TappableSentence({
    required this.arabic,
    required this.onTapWord,
  });

  bool _hasArabic(String token) =>
      token.runes.any((int code) => code >= 0x0600 && code <= 0x06FF);

  @override
  Widget build(BuildContext context) {
    final TextStyle style = Theme.of(context).textTheme.titleLarge!;
    return Wrap(
      textDirection: TextDirection.rtl,
      children: <Widget>[
        for (final String token in arabic.split(RegExp(r'\s+')))
          if (token.isNotEmpty)
            GestureDetector(
              onTap: _hasArabic(token)
                  ? () {
                      HapticFeedback.selectionClick();
                      onTapWord(token);
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Text(token, style: style),
              ),
            ),
      ],
    );
  }
}
