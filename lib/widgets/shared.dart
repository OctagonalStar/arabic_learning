// 共享控件库
//
// 本文件集中存放多个页面中重复出现的纯展示型控件（统计卡片、参数卡片、
// 结果卡片、计分行、揭示式双按钮栏、按钮标签、输入框装饰）。
// 所有控件均从原有调用处直接抽取，decoration / padding / margin / 颜色 /
// 尺寸 / 动画时长 / 曲线与抽取前完全一致，仅消除重复代码。

import 'dart:math' as math;

import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion, AppRadius, AppSpacing;
import 'package:material_ui/material_ui.dart';

/// 状态标签：M3 [Chip] 的紧凑封装，统一圆角、内边距与文字样式。
class StatusChip extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final TextStyle? textStyle;

  const StatusChip({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text),
      labelStyle: (textStyle ?? Theme.of(context).textTheme.labelLarge)
          ?.copyWith(color: foreground),
      backgroundColor: background,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.controlBorder),
    );
  }
}

/// 统计卡片（M3 filled card）：标题 + 数值，尺寸由父级网格决定。
///
/// [statusIcon] 非空时紧跟在标题后；[valueColor] 用于强调异常数值（如逾期）。
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Widget? statusIcon;
  final Color? valueColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.statusIcon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (statusIcon != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.xxs),
                  statusIcon!,
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // 大字号或窄卡片下缩放数值，避免溢出。
            Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
              ),
            ),
          ],
        ),
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
    return Card(
      color: color,
      margin: margin,
      child: Padding(padding: padding, child: child),
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
            ),
          ],
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
      tween: Tween(begin: 0, end: 1),
      curve: AppMotion.standardCurve,
      duration: duration,
      builder: (context, value, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(16.0),
              height: mediaQuery.size.height * 0.1,
              width:
                  math.min(value * 2, 1) *
                  mediaQuery.size.width *
                  (0.5 + 0.25 * bias),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  leftText(value),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(16.0),
              height: mediaQuery.size.height * 0.1,
              width:
                  math.min(value * 2, 1) *
                  mediaQuery.size.width *
                  (0.5 - 0.25 * bias),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  rightText(value),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  textAlign: TextAlign.start,
                ),
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
/// 裹为 Expanded + FittedBox([nextFit])（默认 scaleDown 只缩不放，禁止 contain）；[tipLabelExpanded] 控制左侧文案是否
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
      tween: Tween(begin: 0.0, end: revealed ? 1.0 : 0.0),
      duration: AppMotion.medium,
      curve: AppMotion.standardCurve,
      builder: (context, value, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showTipButton)
              Button(
                size: Size(tipWidth(value), mediaQuery.size.height * 0.1),
                backgroundColor: tipBackgroundColor,
                onPressed: onTipClicked,
                icon: tipIcon,
                child: tipLabelExpanded
                    ? ButtonLabel(child: Text(tipLabel(value)))
                    : Text(tipLabel(value)),
              ),
            SizedBox(width: gapWidth(value), height: gapHeight),
            if (value > nextThreshold)
              Button(
                size: Size(nextWidth(value), mediaQuery.size.height * 0.1),
                backgroundColor: nextBackgroundColor,
                onPressed: onNextClicked,
                icon: nextIcon,
                iconDirection: nextIconDirection,
                child: ButtonLabel(fit: nextFit, child: Text(nextLabel)),
              ),
          ],
        );
      },
    );
  }
}

/// 按钮标签（Expanded + FittedBox 惯用法）
///
/// 与直接书写 `Expanded(child: FittedBox(fit: ..., child: child))` 完全等价，
/// [fit] 默认且推荐 [BoxFit.scaleDown]（只在放不下时缩小）。
///
/// 按钮文本**禁止**传入 [BoxFit.contain]：`Expanded` 会给 FittedBox 一个紧
/// 宽度约束，`contain` 会把短文本放大到填满按钮，导致「文字特大」以及同组
/// 按钮因文案长度不同而字号不一。开发期由构造函数断言拦截。
class ButtonLabel extends StatelessWidget {
  final Widget child;
  final BoxFit fit;

  const ButtonLabel({
    super.key,
    required this.child,
    this.fit = BoxFit.scaleDown,
  }) : assert(
         fit != BoxFit.contain,
         '按钮标签禁止使用 BoxFit.contain：FittedBox 会把文本放大填满按钮，'
         '请使用默认的 BoxFit.scaleDown（只缩不放）。',
       );

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FittedBox(fit: fit, child: child),
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

/// 空状态提示卡：分区或整页无数据时的统一占位。
class EmptyHintCard extends StatelessWidget {
  final String text;

  const EmptyHintCard(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
