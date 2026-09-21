// 共享控件库
//
// 本文件集中存放多个页面中重复出现的纯展示型控件（统计卡片、参数卡片、
// 结果卡片、计分行、揭示式双按钮栏、按钮标签、输入框装饰）。
// 所有控件均从原有调用处直接抽取，decoration / padding / margin / 颜色 /
// 尺寸 / 动画时长 / 曲线与抽取前完全一致，仅消除重复代码。

import 'dart:math' as math;

import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:flutter/material.dart';

/// 首页统计卡片
///
/// [width] / [height] 为卡片的实际尺寸（调用方按屏幕比例计算后传入）；
/// [spacing] 为标题与数值之间的间距（原实现为屏幕高度的 0.03 倍）；
/// [label] 为标题文本；[value] 为展示数值；
/// [statusIcon] 非空时标题行变为 label + 图标的居中 Row，与原实现一致。
class StatCard extends StatelessWidget {
  final double width;
  final double height;
  final double spacing;
  final String label;
  final String value;
  final Widget? statusIcon;

  const StatCard({
    super.key,
    required this.width,
    required this.height,
    required this.spacing,
    required this.label,
    required this.value,
    this.statusIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.all(4.0),
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withAlpha(51),
            offset: Offset(2, 4),
            blurRadius: 8.0,
          ),
        ],
        borderRadius: StaticsVar.br,
      ),
      child: Column(
        children: [
          if (statusIcon == null)
            Text(label, style: Theme.of(context).textTheme.labelMedium)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                statusIcon!,
              ],
            ),
          SizedBox(height: spacing),
          // 矮横屏等极端高度下卡片内部空间不足时按比例缩放数值，
          // 正常尺寸下 FittedBox 尺寸等于文本固有尺寸，显示效果不变。
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置页参数卡片
///
/// [color] 为卡片背景色（调用方传入 `surfaceContainerHighest` /
/// `surfaceContainerLow` 等容器色，配合默认 `onSurface` 文字保证对比度）；
/// [child] 为卡片内容；[padding] 默认 8.0；[margin] 默认不设置（null），
/// 调用处按原代码显式传入，保证与抽取前完全一致。
class SettingCard extends StatelessWidget {
  final Color color;
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;

  const SettingCard({
    super.key,
    required this.color,
    required this.child,
    this.margin,
    this.padding = const EdgeInsets.all(8.0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: StaticsVar.br,
        color: color,
      ),
      margin: margin,
      padding: padding,
      child: child,
    );
  }
}

/// 学习结果卡片
///
/// 由 [visible] 驱动滑入位置与内容数值动画；[slideFromLeft] 控制滑入方向
/// （左滑：-0.2 / -1.5，右滑：0.2 / 1.5）；[color] 为卡片背景色；
/// [contentBuilder] 接收动画进度 value 构建卡片内容行，内部动画时长
/// （AnimatedSlide 1 秒、数值 4 秒）与曲线均保持原样。
/// [width] / [height] 可选：调用方按可用约束推导尺寸时传入；省略时沿用
/// 屏幕宽 0.8 / 高 0.2 的旧行为，保持既有调用点语义不变。
class ConclusionCard extends StatelessWidget {
  final bool visible;
  final bool slideFromLeft;
  final Color color;
  final double? width;
  final double? height;
  final Widget Function(BuildContext context, double value) contentBuilder;

  const ConclusionCard({
    super.key,
    required this.visible,
    required this.slideFromLeft,
    required this.color,
    this.width,
    this.height,
    required this.contentBuilder,
  });

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return AnimatedSlide(
      offset: visible
        ? (slideFromLeft ? Offset(-0.2, 0) : Offset(0.2, 0))
        : (slideFromLeft ? Offset(-1.5, 0.2) : Offset(1.5, 0.2)),
      duration: AppMotion.slow,
      curve: AppMotion.standardCurve,
      child: Container(
        width: width ?? mediaQuery.size.width * 0.8,
        height: height ?? mediaQuery.size.height * 0.2,
        padding: EdgeInsets.all(16.0),
        margin: EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: StaticsVar.br,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withAlpha(51),
              spreadRadius: 5,
              blurRadius: 7,
              offset: Offset(0, 3),
            )
          ]
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: visible ? 1.0 : 0.0),
          duration: AppMotion.ultraSlow,
          curve: AppMotion.standardCurve,
          builder: (context, value, child) => contentBuilder(context, value),
        ),
      ),
    );
  }
}

/// 联机对战计分行（双 Container 对比条）
///
/// [duration] 为该行的动画时长；[scoreBias] 为 0.25 倍前的原始差值因子
/// （例如 (selfCorrect - sideCorrect) / 题目数）；[leftText] / [rightText]
/// 按动画进度生成左右文本。
/// 左条宽度 = min(value*2, 1) * 屏宽 * (0.5 + 0.25*bias)，右条为
/// 0.5 - 0.25*bias，颜色与对齐方式保持原实现。
/// 注意：当原式为左 0.5 - 0.25*X（如"回答用时"行）时，调用方需传入
/// 反向差值（side - self）以维持原有加号方向。
class PKScoreRow extends StatelessWidget {
  final Duration duration;
  final double scoreBias;
  final String Function(double value) leftText;
  final String Function(double value) rightText;

  const PKScoreRow({
    super.key,
    required this.duration,
    required this.scoreBias,
    required this.leftText,
    required this.rightText,
  });

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    // 差值因子夹在 [-2, 2]：保证 0.5 ± 0.25*bias 始终落在 [0, 1]，
    // 避免极端时间差 / 得分差在窄屏算出负宽度或两栏总和超过屏宽。
    final double bias = scoreBias.clamp(-2.0, 2.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: 0,
        end: 1
      ),
      curve: AppMotion.standardCurve,
      duration: duration,
      builder: (context, value, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(16.0),
              height: mediaQuery.size.height * 0.1,
              width: math.min(value*2, 1) * mediaQuery.size.width * (0.5 + 0.25*bias),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(leftText(value), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer), textAlign: TextAlign.end),
              ),
            ),
            Container(
              padding: EdgeInsets.all(16.0),
              height: mediaQuery.size.height * 0.1,
              width: math.min(value*2, 1) * mediaQuery.size.width * (0.5 - 0.25*bias),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(rightText(value), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.onSecondaryContainer), textAlign: TextAlign.start),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 可揭示的底部双按钮栏（"查看详解 / 下一题" 风格）
///
/// [revealed] 驱动 0→1 动画；[showTipButton] 控制左侧按钮是否出现；
/// [tipWidth] / [nextWidth] 按动画进度计算按钮宽度，[gapWidth] 计算间距宽度，
/// [gapHeight] 为间距高度（可为 null）；[nextThreshold] 控制右侧按钮出现的
/// 进度阈值；[tipLabel] 按进度生成左侧文案；[nextLabel] 为右侧文案并自动包
/// 裹为 Expanded + FittedBox([nextFit])；[tipLabelExpanded] 控制左侧文案是否
/// 同样包裹；[tipIcon] / [nextIcon] / [nextIconDirection] 与
/// [tipBackgroundColor] / [nextBackgroundColor] 原样传递给 [Button]。
/// 动画时长固定为 AppMotion.medium，曲线为 AppMotion.standardCurve。
class RevealableActionBar extends StatelessWidget {
  final bool revealed;
  final bool showTipButton;
  final double Function(double value) tipWidth;
  final String Function(double value) tipLabel;
  final bool tipLabelExpanded;
  final Color? tipBackgroundColor;
  final Widget tipIcon;
  final VoidCallback onTipClicked;
  final double Function(double value) gapWidth;
  final double? gapHeight;
  final double nextThreshold;
  final double Function(double value) nextWidth;
  final Widget nextIcon;
  final AxisDirection nextIconDirection;
  final String nextLabel;
  final BoxFit nextFit;
  final Color? nextBackgroundColor;
  final VoidCallback onNextClicked;

  const RevealableActionBar({
    super.key,
    required this.revealed,
    this.showTipButton = true,
    required this.tipWidth,
    required this.tipLabel,
    this.tipLabelExpanded = false,
    this.tipBackgroundColor,
    this.tipIcon = const Icon(Icons.tips_and_updates),
    required this.onTipClicked,
    required this.gapWidth,
    this.gapHeight,
    this.nextThreshold = 0.0,
    required this.nextWidth,
    required this.nextIcon,
    this.nextIconDirection = AxisDirection.left,
    required this.nextLabel,
    this.nextFit = BoxFit.scaleDown,
    this.nextBackgroundColor,
    required this.onNextClicked,
  });

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: 0.0,
        end: revealed ? 1.0 : 0.0
      ),
      duration: AppMotion.medium,
      curve: AppMotion.standardCurve,
      builder: (context, value, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showTipButton) Button(
              size: Size(tipWidth(value), mediaQuery.size.height * 0.1),
              backgroundColor: tipBackgroundColor,
              onPressed: onTipClicked,
              icon: tipIcon,
              child: tipLabelExpanded
                ? ButtonLabel(child: Text(tipLabel(value)))
                : Text(tipLabel(value)),
            ),
            SizedBox(width: gapWidth(value), height: gapHeight),
            if (value > nextThreshold) Button(
              size: Size(nextWidth(value), mediaQuery.size.height * 0.1),
              backgroundColor: nextBackgroundColor,
              onPressed: onNextClicked,
              icon: nextIcon,
              iconDirection: nextIconDirection,
              child: ButtonLabel(fit: nextFit, child: Text(nextLabel)),
            )
          ],
        );
      },
    );
  }
}

/// 按钮标签（Expanded + FittedBox 惯用法）
///
/// 与直接书写 `Expanded(child: FittedBox(fit: ..., child: child))` 完全等价，
/// [fit] 默认 [BoxFit.scaleDown]，需要默认的 [BoxFit.contain] 时显式传入。
class ButtonLabel extends StatelessWidget {
  final Widget child;
  final BoxFit fit;

  const ButtonLabel({super.key, required this.child, this.fit = BoxFit.scaleDown});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FittedBox(
        fit: fit,
        child: child,
      ),
    );
  }
}

/// 统一的输入框装饰
///
/// 边框固定为 `OutlineInputBorder(borderRadius: StaticsVar.br,
/// borderSide: BorderSide(color: colorScheme.outline))`，
/// 通过 [labelText] / [hintText] / [icon] / [suffix] / [filled] / [fillColor]
/// 参数化各调用处的差异，未传入的字段保持 InputDecoration 默认值。
InputDecoration appInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  Widget? icon,
  Widget? suffix,
  bool? filled,
  Color? fillColor,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    icon: icon,
    suffix: suffix,
    filled: filled,
    fillColor: fillColor,
    border: OutlineInputBorder(
      borderRadius: StaticsVar.br,
      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
  );
}
