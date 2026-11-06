// 背诵结果展示：分数 + 等级、可解释指标与按类型分组的问题列表。
// 只展示 scorer 给出的词级指标，不做发音/音素层面的任何表述。

import 'package:arabic_learning/services/recitation_scorer.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppRadius, AppSpacing;
import 'package:arabic_learning/widgets/kit.dart' show Button, TextContainer;
import 'package:flutter/material.dart';

/// 各问题类型的分组标题。
const Map<RecitationIssueType, String> _issueTitles = <RecitationIssueType, String>{
  RecitationIssueType.missing: '漏读',
  RecitationIssueType.extra: '多读',
  RecitationIssueType.order: '顺序',
  RecitationIssueType.pause: '停顿',
  RecitationIssueType.tooFast: '偏快',
  RecitationIssueType.tooSlow: '偏慢',
  RecitationIssueType.unclear: '没听清',
};

/// 结果视图。[onRetry] 保留原文重录，[onNewText] 为空时不显示「换一段」。
class RecitationResultView extends StatelessWidget {
  final RecitationOutcome outcome;
  final VoidCallback onRetry;
  final VoidCallback? onNewText;

  const RecitationResultView({
    super.key,
    required this.outcome,
    required this.onRetry,
    required this.onNewText,
  });

  Widget _metricRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (!outcome.scoreable) {
      // 门禁命中（没听清/太短等）：不给任何数字，只给结论与重录入口。
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextContainer(
            text: outcome.summary,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.error,
              height: 1.5,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Button(onPressed: onRetry, child: const Text("再录一次")),
              ),
              if (onNewText != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Button(
                    onPressed: onNewText,
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: const Text("换一段"),
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    }

    final Map<RecitationIssueType, List<RecitationIssue>> grouped =
        <RecitationIssueType, List<RecitationIssue>>{};
    for (final RecitationIssue issue in outcome.issues) {
      grouped.putIfAbsent(issue.type, () => <RecitationIssue>[]).add(issue);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "${outcome.score}",
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text("成绩 / ${outcome.grade}", style: theme.textTheme.titleLarge),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: Center(
            child: Text(
              outcome.summary,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: AppRadius.controlBorder,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: <Widget>[
                _metricRow(theme, "覆盖率", "${(outcome.coverage * 100).round()}%"),
                _metricRow(theme, "顺序", "${(outcome.orderRate * 100).round()}%"),
                _metricRow(theme, "多读", "${(outcome.insertionRate * 100).round()}%"),
                _metricRow(theme, "时长", "${outcome.durationRatio.toStringAsFixed(2)}×"),
              ],
            ),
          ),
        ),
        if (grouped.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text("可改进之处", style: theme.textTheme.titleLarge),
          ),
          for (final MapEntry<RecitationIssueType, List<RecitationIssue>> group
              in grouped.entries)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _issueTitles[group.key] ?? group.key.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  for (final RecitationIssue issue in group.value)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: AppSpacing.xxs),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: AppRadius.controlBorder,
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(issue.text,
                              style: theme.textTheme.headlineSmall,
                              textDirection: TextDirection.rtl),
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xxs),
                            child: Text(issue.detail,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                )),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Button(onPressed: onRetry, child: const Text("再录一次")),
              ),
              if (onNewText != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Button(
                    onPressed: onNewText,
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: const Text("换一段"),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
