import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'package:arabic_learning/core/adaptive.dart' show AdaptiveTabBody;
import 'package:arabic_learning/core/date_utils.dart';
import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/navigation.dart';
import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/screens/setting/dict_manage_page.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/tts.dart';
import 'package:arabic_learning/services/words.dart' show getStrokeDays;
import 'package:arabic_learning/theme/tokens.dart' show AppSpacing;
import 'package:arabic_learning/theme/typography.dart';
import 'package:arabic_learning/widgets/overlays.dart' show alert;
import 'package:arabic_learning/widgets/review_forecast_chart.dart'
    show ReviewForecastChart;
import 'package:arabic_learning/widgets/shared.dart'
    show EmptyHintCard, StatCard;

/// 首页：每日一词 + 学习统计 + 未来复习量。
///
/// 宽屏两栏（左每日一词、右统计与图表），窄屏单列；内容居中且最宽 960，
/// 页面本身可滚动，不再按屏高比例计算卡片尺寸。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const double _wideBreakpoint = 900.0;
  static const double _maxContentWidth = 960.0;

  @override
  Widget build(BuildContext context) {
    final AppData appData = AppData();
    final FSRS fsrs = FSRS();
    final bool enabled = fsrs.config.enabled;
    final bool todayDone = appData.config.learning.lastDate == daysSinceEpoch();
    final int overdue = enabled ? fsrs.getOverdueCount() : 0;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Widget stats = _StatsGrid(
      cards: <Widget>[
        StatCard(
          label: '连胜天数',
          value: getStrokeDays(appData.config.learning).toString(),
          statusIcon: Tooltip(
            message: todayDone ? '今天已学习' : '今天尚未学习',
            child: Icon(
              todayDone ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 15.0,
              color: todayDone
                  ? context.semanticColors.success
                  : context.semanticColors.disabled,
            ),
          ),
        ),
        StatCard(
          label: '已学词汇',
          value: enabled ? fsrs.config.cards.length.toString() : '未启用',
        ),
        StatCard(
          label: '规律性学习',
          value: enabled ? '$overdue个已逾期' : '未启用',
          valueColor: overdue > 0 ? scheme.error : null,
        ),
        StatCard(label: '单词总数', value: appData.wordCount.toString()),
      ],
    );

    final Widget forecast = enabled
        ? const SizedBox(
            height: 220.0,
            child: ReviewForecastChart(height: 220.0),
          )
        : const EmptyHintCard('启用 FSRS 后可查看未来复习量');

    return AdaptiveTabBody(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= _wideBreakpoint;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 5,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: 420.0),
                            child: DailyWord(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              stats,
                              const SizedBox(height: AppSpacing.md),
                              forecast,
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const DailyWord(),
                        const SizedBox(height: AppSpacing.sm),
                        stats,
                        const SizedBox(height: AppSpacing.sm),
                        forecast,
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// 2×2 统计网格；卡片等宽，间距统一用 [AppSpacing]。
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _row(cards[0], cards[1]),
        const SizedBox(height: AppSpacing.sm),
        _row(cards[2], cards[3]),
      ],
    );
  }

  Widget _row(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: left),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: right),
      ],
    );
  }
}

/// 每日一词卡片：整卡点击朗读，空词库时引导导入。
class DailyWord extends StatefulWidget {
  const DailyWord({super.key});

  @override
  State<DailyWord> createState() => _DailyWordState();
}

class _DailyWordState extends State<DailyWord> {
  bool playing = false;

  /// 按日期做种子，同一天内始终展示同一个词。
  WordItem? _dailyWord(AppData appData) {
    if (appData.wordCount == 0) return null;
    final DateTime now = DateTime.now();
    final int seed = now.year * 10000 + now.month * 100 + now.day;
    return appData.wordData.words[Random(seed).nextInt(appData.wordCount)];
  }

  Future<void> _speak(String text) async {
    if (playing) return;
    setState(() => playing = true);
    try {
      await playTextToSpeech(text);
    } catch (e) {
      if (mounted) alert(context, e.toString());
    } finally {
      if (mounted) setState(() => playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppData appData = AppData();
    final WordItem? word = _dailyWord(appData);
    final bool hasWords = word != null;

    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasWords
            ? () => _speak(word.arabic)
            : () => pushPage(context, const DictManagePage()),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '每日一词',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  if (hasWords)
                    IconButton.filledTonal(
                      onPressed: playing ? null : () => _speak(word.arabic),
                      tooltip: '朗读',
                      icon: Icon(playing ? Icons.graphic_eq : Icons.volume_up),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if(hasWords) ...[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      word.arabic,
                      textAlign: TextAlign.center,
                      style: arabicStyle(
                        context,
                        base: theme.textTheme.displayMedium!,
                      ).copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    word.chinese,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
              ] else ...[
                Icon(
                  Icons.library_books_outlined,
                  size: 40.0,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '当前未导入词库数据',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: () => pushPage(context, const DictManagePage()),
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('导入词库'),
                ),
              ],
            ]
          ),
        ),
      ),
    );
  }
}
