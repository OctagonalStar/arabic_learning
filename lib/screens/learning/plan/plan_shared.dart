// 「计划学习」页面共用的小组件：日期文案与细进度条。
//
// 只放纯展示逻辑，不读取任何服务单例，方便首页 / 配置页 / 学习页入口卡共用。

import 'package:flutter/material.dart';

import 'package:arabic_learning/theme/tokens.dart' show AppMotion;

/// `MM月dd日` 日期文案（配置页右侧、首页截止日期）。
String planMonthDay(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return "$month月$day日";
}

/// `yyyy年MM月dd日` 日期文案（逾期提示里带年份，避免跨年歧义）。
String planFullDate(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return "${date.year}年$month月$day日";
}

/// 细进度条：圆角轨道 + 动画填充。
///
/// [value] 会被夹到 0..1；首次构建从 0 长到目标值，之后数值变化时从当前值过渡，
/// 时长与曲线统一走 [AppMotion]。
class PlanProgressBar extends StatelessWidget {
  /// 进度（0..1）。
  final double value;

  /// 填充色。
  final Color color;

  /// 轨道色；为空时使用前景色 8% 透明度。
  final Color? trackColor;

  /// 条高。
  final double height;

  const PlanProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.trackColor,
    this.height = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final double target =
        value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    final Color track = trackColor ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: target),
          duration: AppMotion.medium,
          curve: AppMotion.standardCurve,
          builder: (BuildContext context, double animated, Widget? child) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ColoredBox(color: track),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: animated,
                    heightFactor: 1.0,
                    child: ColoredBox(color: color),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
