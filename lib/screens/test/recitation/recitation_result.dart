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

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          child: Center(child: Text(outcome.summary, style: theme.textTheme.bodyMedium)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Column(
            children: [
              _metricRow("覆盖率", "${(outcome.coverage * 100).round()}%"),
              _metricRow("顺序", "${(outcome.orderRate * 100).round()}%"),
              _metricRow("多读", "${(outcome.insertionRate * 100).round()}%"),
              _metricRow("时长", "${outcome.durationRatio.toStringAsFixed(2)}×"),
            ],
          ),
        ),
        if (grouped.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text("可改进之处", style: theme.textTheme.titleMedium),
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  for (final RecitationIssue issue in group.value)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: AppSpacing.xxs),
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: AppRadius.controlBorder,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(issue.text,
                              style: theme.textTheme.bodyLarge,
                              textDirection: TextDirection.rtl),
                          Text(issue.detail,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              )),
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
