// 向导里的大号类型选择卡片：图标 + 标题 + 说明 + 右向箭头。
//
// [width] / [height] 都给时锁定为固定尺寸；副标题在空间不足时等比缩小，
// 而不是撑破按钮。阅读题与课文背诵共用。

import 'package:arabic_learning/theme/tokens.dart' show AppRadius, AppSpacing;
import 'package:arabic_learning/widgets/app_button.dart';
import 'package:material_ui/material_ui.dart';

class TypeChooseCard extends StatelessWidget {
  final Widget mainTitle;
  final Widget? subTitle;
  final IconData? icon;

  /// 主操作用强调底色与描边，其余保持中性。
  final bool emphasized;

  final double? width;
  final double? height;
  final VoidCallback onTap;

  const TypeChooseCard({
    super.key,
    required this.mainTitle,
    required this.onTap,
    this.subTitle,
    this.icon,
    this.emphasized = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background =
        emphasized ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final Color foreground =
        emphasized ? scheme.onPrimaryContainer : scheme.onSurface;

    return Button(
      size: width != null && height != null ? Size(width!, height!) : null,
      padding: const EdgeInsets.all(AppSpacing.sm),
      backgroundColor: background,
      foregroundColor: foreground,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(
          color: emphasized ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      onPressed: onTap,
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: emphasized
                    ? scheme.primary
                    : scheme.primaryContainer,
                borderRadius: AppRadius.controlBorder,
              ),
              child: Icon(
                icon,
                size: 32,
                color: emphasized
                    ? scheme.onPrimary
                    : scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                mainTitle,
                if (subTitle != null)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: subTitle!,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.arrow_forward_ios, color: foreground),
        ],
      ),
    );
  }
}
