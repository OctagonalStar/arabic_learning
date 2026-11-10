// 首页「未来复习量」折线图卡片
//
// 数据来自 `FSRS().getForecastCounts(days)`（下标 0 = 今天，逾期卡片已并入今天）。
// 项目无图表依赖，这里用 CustomPainter 直接绘制；切换天数时用一次性的
// `TweenAnimationBuilder`（约 250ms）让折线从基线生长出来，动画有限、可收敛。

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble, listEquals;
import 'package:flutter/material.dart';

import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/theme/tokens.dart'
    show AppMotion, AppRadius, AppSpacing;

/// 未来复习量折线图卡片（含 7 / 14 / 30 / 60 天切换）。
class ReviewForecastChart extends StatefulWidget {
  const ReviewForecastChart({
    super.key,
    required this.width,
    required this.height,
  });

  /// 卡片总宽度，由首页按可用宽度推导。
  final double width;

  /// 卡片总高度（含标题行），由首页按可用高度推导并保证不溢出。
  final double height;

  /// 可切换的天数档位。
  static const List<int> dayOptions = <int>[7, 14, 30, 60];

  @override
  State<ReviewForecastChart> createState() => _ReviewForecastChartState();
}

class _ReviewForecastChartState extends State<ReviewForecastChart> {
  int _days = ReviewForecastChart.dayOptions.first;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<int> counts = FSRS().getForecastCounts(_days);
    final bool hasPlan = counts.any((int c) => c > 0);

    return Container(
      width: widget.width,
      height: widget.height,
      margin: const EdgeInsets.all(4.0),
      padding: const EdgeInsets.fromLTRB(14.0, 8.0, 10.0, 8.0),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withAlpha(51),
            offset: const Offset(2, 4),
            blurRadius: 8.0,
          ),
        ],
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  '未来复习（天）',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _DaySelector(
                options: ReviewForecastChart.dayOptions,
                selected: _days,
                onChanged: (int d) {
                  if (d != _days) setState(() => _days = d);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Expanded(
            // 图形只有像素，这里补一句可读的说明，读屏能拿到关键数值。
            child: Semantics(
              label: counts.isEmpty
                  ? '未来 $_days 天暂无复习计划'
                  : '未来 $_days 天复习计划，今天 ${counts.first} 个，单日最多 ${counts.reduce(math.max)} 个',
              child: hasPlan
                  ? TweenAnimationBuilder<double>(
                      key: ValueKey<int>(_days),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: AppMotion.mediumShort,
                      curve: AppMotion.decelerateCurve,
                      builder: (BuildContext context, double t, Widget? _) {
                        return CustomPaint(
                          size: Size.infinite,
                          painter: _ForecastPainter(
                            counts: counts,
                            progress: t,
                            lineColor: scheme.primary,
                            gridColor: scheme.outlineVariant,
                            labelStyle: (theme.textTheme.labelSmall ??
                                    const TextStyle(fontSize: 10.0))
                                .copyWith(color: scheme.onSurfaceVariant),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        '暂无复习计划',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 紧凑的天数切换控件：比 `SegmentedButton` / `FilterChip` 窄很多，
/// 放在卡片标题行右侧不会挤掉标题。
class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<int> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final BorderRadius itemRadius = BorderRadius.circular(AppRadius.control - 2.0);
    return Container(
      padding: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.controlBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final int d in options)
            InkWell(
              onTap: () => onChanged(d),
              borderRadius: itemRadius,
              child: AnimatedContainer(
                duration: AppMotion.quick,
                curve: AppMotion.standardCurve,
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: d == selected ? scheme.primary : Colors.transparent,
                  borderRadius: itemRadius,
                ),
                child: Text(
                  '$d',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: d == selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                    fontWeight: d == selected ? FontWeight.bold : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ForecastPainter extends CustomPainter {
  _ForecastPainter({
    required this.counts,
    required this.progress,
    required this.lineColor,
    required this.gridColor,
    required this.labelStyle,
  });

  /// 每天到期数量，下标 0 = 今天。
  final List<int> counts;

  /// 0→1 的入场进度，仅缩放折线高度。
  final double progress;

  final Color lineColor;
  final Color gridColor;
  final TextStyle labelStyle;

  // 左侧留给 y 轴最大值、底部留给 x 标签。
  static const double _leftPad = 22.0;
  static const double _rightPad = 6.0;
  static const double _topPad = 8.0;
  static const double _bottomPad = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final double plotW = size.width - _leftPad - _rightPad;
    final double plotH = size.height - _topPad - _bottomPad;
    if (counts.isEmpty || plotW <= 0 || plotH <= 0) return;

    final int maxVal = counts.reduce(math.max);
    final double bottom = _topPad + plotH;
    // maxVal 为 0 时不会进入绘制（外层显示空状态）；这里再兜一次除零。
    final double scale = maxVal <= 0 ? 0.0 : plotH / maxVal;

    // 网格提示线 + 底部基线。
    final Paint grid = Paint()
      ..color = gridColor.withValues(alpha: 0.7)
      ..strokeWidth = 1.0;
    for (final double f in <double>[0.5, 1.0]) {
      final double y = bottom - plotH * f;
      canvas.drawLine(Offset(_leftPad, y), Offset(_leftPad + plotW, y), grid);
    }
    canvas.drawLine(
      Offset(_leftPad, bottom),
      Offset(_leftPad + plotW, bottom),
      grid,
    );

    // y 轴最大值。
    final TextPainter yLabel = _layoutText('$maxVal');
    yLabel.paint(canvas, Offset(0, _topPad - yLabel.height / 2));

    // 折线坐标（只有一个点时水平居中，避免退化到左边缘）。
    final int n = counts.length;
    final double step = n > 1 ? plotW / (n - 1) : 0.0;
    final List<Offset> points = <Offset>[
      for (int i = 0; i < n; i++)
        Offset(
          n > 1 ? _leftPad + step * i : _leftPad + plotW / 2,
          bottom - counts[i] * scale * progress,
        ),
    ];

    if (n > 1) {
      // 每段用水平切线的三次贝塞尔连接：折线变平滑，且控制点与端点同高，
      // 曲线不会越出相邻两点的范围（无需额外图表依赖）。
      final Path line = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final Offset prev = points[i - 1];
        final Offset cur = points[i];
        final double midX = (prev.dx + cur.dx) / 2.0;
        line.cubicTo(midX, prev.dy, midX, cur.dy, cur.dx, cur.dy);
      }

      // 折线下方渐隐填充。
      final Path fill = Path.from(line)
        ..lineTo(points.last.dx, bottom)
        ..lineTo(points.first.dx, bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              lineColor.withValues(alpha: 0.28),
              lineColor.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTRB(_leftPad, _topPad, _leftPad + plotW, bottom)),
      );

      canvas.drawPath(
        line,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // 数据点：天数多时不画点，避免糊成一团。
    if (n <= 30) {
      final Paint dot = Paint()..color = lineColor;
      for (final Offset p in points) {
        canvas.drawCircle(p, 2.6, dot);
      }
    }

    // x 标签：60 天过密，直接省略。
    if (n > 1 && n <= 30) {
      final Set<int> ticks = <int>{0, n ~/ 2, n - 1};
      for (final int i in ticks) {
        final TextPainter tp = _layoutText(i == 0 ? '今天' : '+$i天');
        final double maxX = math.max(_leftPad, _leftPad + plotW - tp.width);
        final double x =
            clampDouble(points[i].dx - tp.width / 2, _leftPad, maxX);
        tp.paint(canvas, Offset(x, bottom + 1.0));
      }
    }
  }

  TextPainter _layoutText(String text) {
    return TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant _ForecastPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelStyle != labelStyle ||
        !listEquals(oldDelegate.counts, counts);
  }
}
