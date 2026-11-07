// 学习 tab：一句一张竖向卡片（原文 + 译文 + 注释），点词弹底部候选词表。
// 卡片本身可在短屏内滚动，底部固定进度条可拖动定位到任意一句。

import 'package:arabic_learning/core/adaptive.dart' show AdaptiveScope;
import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/models/recitation_text.dart';
import 'package:arabic_learning/screens/test/recitation/recitation_progress_bar.dart'
    show RecitationProgressBar;
import 'package:arabic_learning/services/recitation_text.dart'
    show normalizeArabic, lookupStems;
import 'package:arabic_learning/services/search.dart' show BKSearch;
import 'package:arabic_learning/services/tts.dart' show playTextToSpeech;
import 'package:arabic_learning/theme/tokens.dart'
    show AppMotion, AppRadius, AppSpacing;
import 'package:arabic_learning/widgets/overlays.dart' show showWordCardOverlay;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

class RecitationStudyTab extends StatefulWidget {
  final RecitationTextUnit unit;
  // 当前句（从 1 开始），由详情页持有，和「逐句」tab 共用；本页只读写不释放。
  final ValueNotifier<int> position;
  const RecitationStudyTab({
    super.key,
    required this.unit,
    required this.position,
  });

  @override
  State<RecitationStudyTab> createState() => _RecitationStudyTabState();
}

class _RecitationStudyTabState extends State<RecitationStudyTab> {
  late final PageController _pager;

  @override
  void initState() {
    super.initState();
    // 从共用位置恢复页码，切 tab 回来直接停在同一句。
    final int max = widget.unit.sentences.isEmpty
        ? 0
        : widget.unit.sentences.length - 1;
    _pager = PageController(
      initialPage: (widget.position.value - 1).clamp(0, max),
    );
    widget.position.addListener(_syncFromPosition);
  }

  @override
  void dispose() {
    widget.position.removeListener(_syncFromPosition);
    _pager.dispose();
    super.dispose();
  }

  /// 共用位置变了（来自另一个 tab 或进度条）才翻页；自身翻页已同步过，不重复动画。
  void _syncFromPosition() {
    if (!mounted || !_pager.hasClients) return;
    final int target = widget.position.value - 1;
    if ((_pager.page ?? 0).round() == target) return;
    _pager.animateToPage(
      target,
      duration: AppMotion.quick,
      curve: AppMotion.standardCurve,
    );
  }

  void _locate(int index) {
    widget.position.value = index;
  }

  Future<void> _showWordSheet(BuildContext context, String raw) async {
    final ThemeData theme = Theme.of(context);
    // 候选词：本课生词（归一化后命中词干）优先，其余来自词库逐词干查询去重。
    final List<String> stems = lookupStems(raw);
    final Set<String> lessonKeys = <String>{};
    final List<RecitationWord> lessonWords = <RecitationWord>[];
    for (final RecitationSentence sentence in widget.unit.sentences) {
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
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: <Widget>[
            Text(raw,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            if (candidates.isEmpty && lessonWords.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: Text("本地词库未收录",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ),
              )
            else ...[
              for (final RecitationWord word in lessonWords)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.controlBorder,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: AppRadius.controlBorder,
                    ),
                    child: Text("本课生词",
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        )),
                  ),
                  title: Text(word.arabic,
                      textDirection: TextDirection.rtl,
                      style: theme.textTheme.titleLarge),
                  subtitle: word.chinese.isEmpty
                      ? null
                      : Text(word.chinese, style: theme.textTheme.bodyMedium),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    openLessonWord(word);
                  },
                ),
              for (final WordItem item in candidates)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.controlBorder,
                  ),
                  title: Text(item.arabic,
                      textDirection: TextDirection.rtl,
                      style: theme.textTheme.titleLarge),
                  subtitle: Text(item.chinese, style: theme.textTheme.bodyMedium),
                  trailing: Wrap(
                    spacing: AppSpacing.xxs,
                    children: <Widget>[
                      if (item.pos.isNotEmpty)
                        Text(item.pos, style: theme.textTheme.labelLarge),
                      if (item.root.isNotEmpty)
                        Text(item.root,
                            textDirection: TextDirection.rtl,
                            style: theme.textTheme.labelLarge),
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
    final bool wide = AdaptiveScope.of(context).isWide;
    final double width =
        (MediaQuery.sizeOf(context).width * 0.9).clamp(0.0, 760.0);
    final List<RecitationSentence> sentences = widget.unit.sentences;
    // 若本页在切 tab 期间只是被挂起而非销毁，重新显示的这一帧补齐共用位置。
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromPosition());
    return SafeArea(
      top: false,
      // 底部安全区交给进度条自己的 SafeArea，条底色才能铺到手势区。
      bottom: false,
      child: Column(
        children: <Widget>[
          Expanded(
            child: PageView.builder(
              controller: _pager,
              scrollDirection: Axis.vertical,
              itemCount: sentences.length,
              onPageChanged: (int index) => widget.position.value = index + 1,
              itemBuilder: (BuildContext context, int index) => Center(
                child: SizedBox(
                  width: width,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: _SentenceCard(
                      index: index,
                      sentence: sentences[index],
                      wide: wide,
                      onTapWord: (String word) => _showWordSheet(context, word),
                    ),
                  ),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: widget.position,
            builder: (BuildContext context, int value, Widget? child) =>
                RecitationProgressBar(
              current: value,
              count: sentences.length,
              onLocate: _locate,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单句学习卡：句号 / 朗读在卡片顶部，原文为最大字号，
/// 译文与注释各自用更深一层的容器色，与外层卡片拉开层次。
class _SentenceCard extends StatelessWidget {
  final int index;
  final RecitationSentence sentence;
  final bool wide;
  final ValueChanged<String> onTapWord;

  const _SentenceCard({
    required this.index,
    required this.sentence,
    required this.wide,
    required this.onTapWord,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle arabicStyle =
        (wide ? theme.textTheme.headlineMedium : theme.textTheme.headlineSmall)!;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2.0,
      surfaceTintColor: Colors.transparent,
      shadowColor: scheme.shadow,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _Chip(
                  text: "第 ${index + 1} 句",
                  background: scheme.surfaceContainerHighest,
                  foreground: scheme.onSurfaceVariant,
                ),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: "朗读",
                  onPressed: () => playTextToSpeech(sentence.arabic),
                  icon: const Icon(Icons.volume_up),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            _TappableSentence(
              arabic: sentence.arabic,
              style: arabicStyle.copyWith(height: 1.7),
              onTapWord: onTapWord,
            ),
            if (sentence.translation.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: AppRadius.controlBorder,
                ),
                child: Text(
                  sentence.translation,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            if (sentence.note != null && sentence.note!.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              // 注释用左侧强调竖线代替盒子，避免和译文容器抢同一层底色。
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: scheme.primary.withValues(alpha: 0.55),
                      width: 3.0,
                    ),
                  ),
                ),
                child: Text(
                  "注 ${sentence.note}",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            if (index == 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  "点词查看释义",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const _Chip({
    required this.text,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2.0,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.controlBorder,
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: foreground),
      ),
    );
  }
}

/// 整词可点：按空白切分，每个词用 GestureDetector 包裹（框架自动释放手势），
/// 点击回调原文词形；标点等非阿语 token 不可点。
class _TappableSentence extends StatelessWidget {
  final String arabic;
  final TextStyle style;
  final ValueChanged<String> onTapWord;

  const _TappableSentence({
    required this.arabic,
    required this.style,
    required this.onTapWord,
  });

  bool _hasArabic(String token) =>
      token.runes.any((int code) => code >= 0x0600 && code <= 0x06FF);

  @override
  Widget build(BuildContext context) {
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
