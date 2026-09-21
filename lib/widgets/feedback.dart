// 统一的反馈类控件（T-3.8）。
//
// 当前仅包含不确定进度（indeterminate）的 [LoadingIndicator]。
// 说明：确定进度（`value` 非空）的 `CircularProgressIndicator` /
// `LinearProgressIndicator` 表达的是真实进度，保留原生控件与各页参数不变。

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
