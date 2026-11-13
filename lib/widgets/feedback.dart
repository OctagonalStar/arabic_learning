// 统一的反馈类控件（T-3.8）。
//
// 包含不确定进度的 [LoadingIndicator] 与确定进度的 [ProgressBar]。
// 说明：圆形进度（`CircularProgressIndicator`）表达的是真实进度，保留原生控件与各页参数不变。

import 'package:arabic_learning/theme/tokens.dart' show AppMotion, AppRadius;
import 'package:flutter/material.dart';

/// 不确定进度加载指示器：`CircularProgressIndicator` 的统一封装。
///
/// 颜色解析顺序与原生控件一致：显式 [color] → `ProgressIndicatorTheme.color`
/// → 当前 `ColorScheme.primary`。尺寸保持各处差异：默认沿用 Material 的
/// 36×36，传入 [size] 时以正方形盒约束直径。
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.size, this.strokeWidth, this.color});

  /// 直径（宽高相等）；为 null 时沿用 Material 默认尺寸（36）。
  final double? size;

  /// 线宽；为 null 时沿用 `ProgressIndicatorTheme` 或 Material 默认线宽。
  final double? strokeWidth;

  /// 指示器颜色；为 null 时取主题色（先 `ProgressIndicatorTheme.color`，
  /// 再回退 `ColorScheme.primary`）。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ProgressIndicatorThemeData progressTheme =
        ProgressIndicatorTheme.of(context);
    final Widget indicator = CircularProgressIndicator(
      strokeWidth: strokeWidth,
      color: color ?? progressTheme.color ?? Theme.of(context).colorScheme.primary,
    );
    if (size == null) return indicator;
    return SizedBox(width: size, height: size, child: indicator);
  }
}

/// 下载 / 解压等线性进度条：`LinearProgressIndicator` 的统一封装。
///
/// [value] 为 0.0~1.0；为 null 表示总大小未知，显示不确定动画。
/// 确定进度按 `AppMotion.quick` 插值推进（`Tween.begin` 只在首帧生效）；
/// 系统「减弱动态效果」下退化为静态，保证动画能结束（测试可 `pumpAndSettle`）。
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.animationsDisabled,
    this.minHeight = 6.0,
  });

  /// 进度 0.0~1.0；null 表示总大小未知（不确定进度）。
  final double? value;

  /// 是否禁用动画；为 null 时读 `MediaQuery.disableAnimations`。
  final bool? animationsDisabled;

  /// 进度条高度。
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final bool disabled = animationsDisabled ?? (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final double? target = value;
    if (target == null) {
      return LinearProgressIndicator(
        value: disabled ? 0.0 : null,
        minHeight: minHeight,
        borderRadius: AppRadius.controlBorder,
      );
    }
    if (disabled) {
      return LinearProgressIndicator(
        value: target,
        minHeight: minHeight,
        borderRadius: AppRadius.controlBorder,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: target),
      duration: AppMotion.quick,
      curve: AppMotion.standardCurve,
      builder: (BuildContext context, double animated, Widget? child) {
        return LinearProgressIndicator(
          value: animated,
          minHeight: minHeight,
          borderRadius: AppRadius.controlBorder,
        );
      },
    );
  }
}
