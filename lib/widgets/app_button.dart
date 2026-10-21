// 基础按钮（原 widgets/kit.dart 拆分）。
// 承载全局通用的 [Button]：M3 填充色调配色、按压缩放反馈与图标排布。
// 由 widgets/kit.dart 统一 export，调用方仍从 kit.dart 导入。

import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:flutter/material.dart';

class Button extends StatefulWidget {
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
    this.alignment = MainAxisAlignment.spaceEvenly
  });

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  /// 指针按压中：仅做视觉缩放反馈，不改变布局尺寸与命中区域。
  bool _pressed = false;

  void _setPressed(bool value) {
    if(_pressed == value) return;
    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // 默认采用 M3 填充色调按钮配色（primaryContainer / onPrimaryContainer）；
    // 显式指定容器背景色时自动匹配对应的 onXxx 前景色，未知背景回退 onSurface，
    // 需要更精确对比度的调用方仍可传入 [foregroundColor] 覆盖。
    final Color background = widget.backgroundColor ?? scheme.primaryContainer;
    final Color foreground = widget.foregroundColor ??
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
    final Widget button = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        shadowColor: widget.shadowColor,
        fixedSize: widget.size,
        padding: widget.padding,
        shape: widget.shape ?? RoundedRectangleBorder(borderRadius: StaticsVar.br),
        // 按压 / 悬停的 Material state layer（即时视觉反馈）。
        overlayColor: overlayBase.withValues(alpha: 0.10),
        animationDuration: AppMotion.quick,
      ),
      clipBehavior: Clip.hardEdge,
      onPressed: widget.onPressed,
      child: widget.icon==null 
          ? widget.child
          : [AxisDirection.left, AxisDirection.right].contains(widget.iconDirection)
          ? Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: widget.alignment,
            children: [
              if(widget.iconDirection == AxisDirection.left) Padding(
                padding: const EdgeInsets.all(8.0),
                child: widget.icon!,
              ),
              ?widget.child,
              if(widget.iconDirection == AxisDirection.right) Padding(
                padding: const EdgeInsets.all(8.0),
                child: widget.icon!,
              )
            ],
          )
          : Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: widget.alignment,
            children: [
              if(widget.iconDirection == AxisDirection.up) Padding(
                padding: const EdgeInsets.all(8.0),
                child: widget.icon!,
              ),
              ?widget.child,
              if(widget.iconDirection == AxisDirection.down) Padding(
                padding: const EdgeInsets.all(8.0),
                child: widget.icon!,
              )
            ],
          )
    );
    // 禁用态与“减弱动态效果”下保持纯 ElevatedButton，不引入额外包装。
    if(widget.onPressed == null ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      return button;
    }
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: AppMotion.quick,
        curve: AppMotion.standardCurve,
        child: button,
      ),
    );
  }
}
