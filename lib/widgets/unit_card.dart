// 测试板块三类文章列表共用的卡片：难度、标题、摘要、标签、打开/删除。
//
// 课文背诵、阅读理解、听抄训练都复用它，避免三份外观各自漂移。

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/theme/tokens.dart'
    show AppRadius, AppSpacing, AppSemanticColors;
import 'package:arabic_learning/widgets/hero_title.dart';
import 'package:material_ui/material_ui.dart';

class UnitCard extends StatelessWidget {
  final String title;

  /// 展示在左侧徽标里的数值。
  final int difficulty;

  /// 计算颜色用的难度值（0-100）；为空时使用 [difficulty]。
  /// 阅读题的难度是 0-10，可传 `difficulty * 10` 保持同一套色阶。
  final int? difficultyColorValue;

  final String subtitle;
  final List<String> tags;
  final VoidCallback onOpen;

  /// 非空时显示右侧菜单，并允许长按删除。
  final VoidCallback? onDelete;
  final String deleteLabel;

  /// 列表 → 详情页共享的 Hero tag；为空时不注册 Hero。
  final Object? heroTag;
  final TextStyle? titleStyle;
  final bool heroEnabled;
  final bool flightShuttleEnabled;

  const UnitCard({
    super.key,
    required this.title,
    required this.difficulty,
    required this.subtitle,
    required this.onOpen,
    this.difficultyColorValue,
    this.tags = const <String>[],
    this.onDelete,
    this.deleteLabel = "删除",
    this.heroTag,
    this.titleStyle,
    this.heroEnabled = true,
    this.flightShuttleEnabled = true,
  });

  Color _difficultyColor(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppSemanticColors semantic = context.semanticColors;
    switch (difficultyColorValue ?? difficulty) {
      case >= 90:
        return scheme.error;
      case >= 70:
        return scheme.tertiary;
      case >= 50:
        return semantic.warning;
      case >= 30:
        return semantic.success;
      case >= 10:
        return scheme.primary;
      default:
        return scheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color difficultyColor = _difficultyColor(context);
    final TextStyle? effectiveTitleStyle =
        titleStyle ?? theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      elevation: 2.0,
      surfaceTintColor: Colors.transparent,
      shadowColor: scheme.shadow,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: onOpen,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: difficultyColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.controlBorder,
                ),
                child: Text(
                  "$difficulty",
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: difficultyColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (heroTag == null)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: effectiveTitleStyle,
                      )
                    else
                      HeroTitle(
                        tag: heroTag!,
                        text: title,
                        style: effectiveTitleStyle,
                        scaleDown: true,
                        maxLines: 1,
                        heroEnabled: heroEnabled,
                        flightShuttleEnabled: flightShuttleEnabled,
                        flightStyle: effectiveTitleStyle,
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Wrap(
                          spacing: AppSpacing.xxs,
                          runSpacing: AppSpacing.xxs,
                          children: [
                            for (final String tag in tags)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.secondaryContainer,
                                  borderRadius: AppRadius.controlBorder,
                                ),
                                child: Text(
                                  tag,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: scheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (onDelete != null)
                PopupMenuButton<String>(
                  onSelected: (String value) {
                    if (value == "delete") onDelete!();
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem(value: "delete", child: Text(deleteLabel)),
                  ],
                )
              else
                Icon(Icons.arrow_forward_ios, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
