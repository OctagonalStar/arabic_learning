// 轻量复用动效控件：入场淡入位移、列表/网格交错入场与加载→内容交叉淡入。
//
// 设计约束：
// - 全部基于隐式动画（`TweenAnimationBuilder` / `AnimatedSwitcher`），时长有限，
//   不使用 `AnimationController` 与无限循环动画，`pumpAndSettle` 可正常结束；
// - 遵循系统“减弱动态效果”（`MediaQuery.disableAnimations`）：开启时直接呈现终态；
// - 交错入场只为有限个元素创建动画，长列表（数百项）不会首屏迟滞。

import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:flutter/material.dart';

/// 单元素入场：淡入 + 轻微位移。
///
/// [delay] 通过 `Interval` 折算进同一条隐式动画时间轴，不引入额外计时器；
/// 动画结束后直接渲染 [child]，不残留 `Opacity` / `Transform` 图层。
class FadeSlideIn extends StatelessWidget {
  /// 动画时长（不含 [delay]）。
  final Duration duration;

  /// 位移的缓动曲线。
  final Curve curve;

  /// 动画开始前的静默延迟。
  final Duration delay;

  /// 初始位移（逻辑像素），动画结束时归零。
  final Offset slideOffset;

  /// 是否启用；为 false 时不做任何动画。
  final bool enabled;

  /// 需要入场的子组件（动画期间不会随进度重建）。
  final Widget child;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = AppMotion.medium,
    this.curve = AppMotion.decelerateCurve,
    this.delay = Duration.zero,
    this.slideOffset = const Offset(0.0, 12.0),
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // 无障碍“减弱动态效果”或显式关闭时，直接呈现终态。
    if (!enabled ||
        duration <= Duration.zero ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      return child;
    }
    final Duration total = duration + delay;
    final double delayFraction = total.inMicroseconds == 0
        ? 0.0
        : delay.inMicroseconds / total.inMicroseconds;
    final Curve effectiveCurve = delayFraction <= 0.0
        ? curve
        : Interval(delayFraction, 1.0, curve: curve);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: total,
      curve: effectiveCurve,
      child: child,
      builder: (BuildContext context, double value, Widget? child) {
        if (value >= 1.0) return child!;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              slideOffset.dx * (1.0 - value),
              slideOffset.dy * (1.0 - value),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// 列表 / 网格项的交错入场包装。
///
/// 仅为前 [maxAnimatedItems] 项创建入场动画：延迟按 `step * index` 计算并以
/// [maxDelay] 封顶，其余项（长列表滚动出来的元素）直接渲染，避免为全部元素
/// 各建一个动画控制器造成首屏迟滞。
class StaggeredEntrance extends StatelessWidget {
  /// 默认参与交错入场的最大元素个数（覆盖首屏及少量滚动项）。
  static const int defaultMaxAnimatedItems = 20;

  /// 相邻元素的基础延迟步长。
  static const Duration defaultStep = Duration(milliseconds: 25);

  /// 单项延迟上限，保证整批入场总时长可控。
  static const Duration defaultMaxDelay = Duration(milliseconds: 250);

  /// 默认初始位移。
  static const Offset defaultSlideOffset = Offset(0.0, 12.0);

  /// 元素在列表 / 网格中的位置。
  final int index;

  /// 需要入场的子组件。
  final Widget child;

  /// 参与交错入场的元素个数上限。
  final int maxAnimatedItems;

  /// 相邻元素延迟步长。
  final Duration step;

  /// 单项延迟上限。
  final Duration maxDelay;

  /// 单项动画时长。
  final Duration duration;

  /// 初始位移（逻辑像素）。
  final Offset slideOffset;

  /// 是否启用；为 false 时全部直接渲染。
  final bool enabled;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.maxAnimatedItems = defaultMaxAnimatedItems,
    this.step = defaultStep,
    this.maxDelay = defaultMaxDelay,
    this.duration = AppMotion.medium,
    this.slideOffset = defaultSlideOffset,
    this.enabled = true,
  });

  /// 第 [index] 项的交错延迟：线性递增并以 [maxDelay] 封顶。
  static Duration delayFor(
    int index, {
    Duration step = defaultStep,
    Duration maxDelay = defaultMaxDelay,
  }) {
    if (index <= 0) return Duration.zero;
    final Duration raw = step * index;
    return raw <= maxDelay ? raw : maxDelay;
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled || index < 0 || index >= maxAnimatedItems) return child;
    return FadeSlideIn(
      delay: delayFor(index, step: step, maxDelay: maxDelay),
      duration: duration,
      slideOffset: slideOffset,
      child: child,
    );
  }
}

/// 加载 → 内容的交叉淡入（`AnimatedSwitcher` 统一封装）。
///
/// [child] 必须在不同状态间携带不同的 `Key`（如 `ValueKey('loading')` /
/// `ValueKey('content')`），否则 `AnimatedSwitcher` 不会触发切换动画。
class CrossFadeSwitcher extends StatelessWidget {
  /// 切换时长。
  final Duration duration;

  /// 由调用方按状态提供不同 `Key` 的子组件。
  final Widget child;

  const CrossFadeSwitcher({
    super.key,
    required this.child,
    this.duration = AppMotion.medium,
  });

  @override
  Widget build(BuildContext context) {
    final bool animationsDisabled =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedSwitcher(
      duration: animationsDisabled ? Duration.zero : duration,
      switchInCurve: AppMotion.decelerateCurve,
      switchOutCurve: AppMotion.accelerateCurve,
      child: child,
    );
  }
}
