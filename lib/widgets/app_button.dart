// 基础按钮（原 widgets/kit.dart 拆分）。
// [Button] 是既有调用点的兼容层：内部使用 Material 的 [FilledButton]，
// 只保留图标排布、固定尺寸与容器色推导等调用方需要的参数。
// 由 widgets/kit.dart 统一 export，调用方仍从 kit.dart 导入。

import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:material_ui/material_ui.dart';

class Button extends StatelessWidget {
  final Widget? child;
  final void Function()? onPressed;
  final Widget? icon;
  final AxisDirection iconDirection;
  final Size? size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? shadowColor;
  final EdgeInsetsGeometry padding;
  final OutlinedBorder? shape;
  final MainAxisAlignment alignment;

  const Button({
    super.key,
    this.child,
    this.icon,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.shape,
    this.size,
    this.shadowColor,
    this.iconDirection = AxisDirection.left,
    this.padding = const EdgeInsetsGeometry.all(16.0),
    this.alignment = MainAxisAlignment.spaceEvenly,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // 默认采用 M3 填充色调按钮配色（primaryContainer / onPrimaryContainer）；
    // 显式指定容器背景色时自动匹配对应的 onXxx 前景色，未知背景回退 onSurface，
    // 需要更精确对比度的调用方仍可传入 [foregroundColor] 覆盖。
    final Color background = backgroundColor ?? scheme.primaryContainer;
    final Color foreground =
        foregroundColor ??
        (background == scheme.primaryContainer
            ? scheme.onPrimaryContainer
            : background == scheme.secondaryContainer
            ? scheme.onSecondaryContainer
            : background == scheme.errorContainer
            ? scheme.onErrorContainer
            : scheme.onSurface);
    // 透明背景按钮（如 WordCardArabicButton 发音、ChooseButtonBox 选项）没有容器色，
    // 以前景色作为 state layer 底色；前景也透明时回退 onSurface，保证亮暗模式可读。
    final Color overlayBase = foreground.a == 0 ? scheme.onSurface : foreground;

    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        shadowColor: shadowColor,
        fixedSize: size,
        padding: padding,
        shape: shape ?? RoundedRectangleBorder(borderRadius: StaticsVar.br),
        overlayColor: overlayBase.withValues(alpha: 0.10),
        animationDuration: AppMotion.quick,
      ),
      clipBehavior: Clip.hardEdge,
      onPressed: onPressed,
      child: icon == null ? child : _withIcon(),
    );
  }

  Widget _withIcon() {
    if (iconDirection == AxisDirection.left ||
        iconDirection == AxisDirection.right) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignment,
        children: <Widget>[
          if (iconDirection == AxisDirection.left)
            Padding(padding: const EdgeInsets.all(8.0), child: icon!),
          ?child,
          if (iconDirection == AxisDirection.right)
            Padding(padding: const EdgeInsets.all(8.0), child: icon!),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: <Widget>[
        if (iconDirection == AxisDirection.up)
          Padding(padding: const EdgeInsets.all(8.0), child: icon!),
        ?child,
        if (iconDirection == AxisDirection.down)
          Padding(padding: const EdgeInsets.all(8.0), child: icon!),
      ],
    );
  }
}
