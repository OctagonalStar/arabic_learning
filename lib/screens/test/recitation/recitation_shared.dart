// 课文详情「学习 / 逐句」两页共用的卡片外框、标签与译文块。
//
// 三个控件原本在两个 tab 里各写了一份完全相同的样式，改这里即可同时生效。

import 'package:arabic_learning/theme/tokens.dart' show AppRadius, AppSpacing;
import 'package:flutter/material.dart';

/// 句子卡外框：低层底色 + outlineVariant 描边，内边距由调用方决定。
class RecitationCard extends StatelessWidget {
  final Widget child;

  const RecitationCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
      child: child,
    );
  }
}

/// 小标签（句序、评分等）。
class RecitationChip extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const RecitationChip({
    super.key,
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

/// 译文块：与原文层次拉开的中性底色，逐句页会再套一层模糊。
class RecitationTranslation extends StatelessWidget {
  final String text;

  const RecitationTranslation({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.controlBorder,
      ),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
    );
  }
}
