// 课文详情底部固定进度条：「第 N 句」+ 可拖动定位（无附加控件时还显示总句数与百分比）。
// 「学习 / 逐句」共用（整篇不显示）；[onLocate] 由各自映射到翻页，
// 「逐句」通过 [trailing] 在条内放「统一显示中文」开关。

import 'package:arabic_learning/theme/tokens.dart' show AppSpacing;
import 'package:flutter/material.dart';

class RecitationProgressBar extends StatefulWidget {
  /// 当前句（从 1 开始）。
  final int current;

  /// 总句数。
  final int count;

  /// 定位到第 [index] 句（从 1 开始）。
  final ValueChanged<int> onLocate;

  /// 右侧附加控件（如「统一显示中文」开关）。有值时不再显示百分比，避免窄屏溢出。
  final Widget? trailing;

  const RecitationProgressBar({
    super.key,
    required this.current,
    required this.count,
    required this.onLocate,
    this.trailing,
  });

  @override
  State<RecitationProgressBar> createState() => _RecitationProgressBarState();
}

class _RecitationProgressBarState extends State<RecitationProgressBar> {
  // 拖动期间只更新本地标签，松手才真正定位，避免连续 animateToPage 互相打断。
  int? _dragIndex;

  @override
  Widget build(BuildContext context) {
    final int count = widget.count;
    if (count < 1) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int safeCurrent = widget.current.clamp(1, count);
    final int shown = _dragIndex ?? safeCurrent;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.xxs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  // 卡片内容在短屏上会自己滚动（吃掉竖向滑动），这里给固定翻句入口。
                  _stepButton(
                    icon: Icons.keyboard_arrow_up,
                    tooltip: "上一句",
                    onPressed: safeCurrent > 1
                        ? () => widget.onLocate(safeCurrent - 1)
                        : null,
                  ),
                  _stepButton(
                    icon: Icons.keyboard_arrow_down,
                    tooltip: "下一句",
                    onPressed: safeCurrent < count
                        ? () => widget.onLocate(safeCurrent + 1)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    "第 $shown 句",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // 有附加控件时省掉总句数与百分比，320 宽的手机也放得下。
                  if (widget.trailing == null)
                    Text(
                      " / 共 $count 句",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  const Spacer(),
                  if (widget.trailing != null)
                    widget.trailing!
                  else
                    Text(
                      "${(shown / count * 100).round()}%",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (count > 1)
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4.0,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8.0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16.0,
                    ),
                    showValueIndicator: ShowValueIndicator.onDrag,
                  ),
                  child: Slider(
                    value: (shown - 1).toDouble(),
                    max: (count - 1).toDouble(),
                    divisions: count - 1,
                    label: "第 $shown 句",
                    onChanged: (double value) =>
                        setState(() => _dragIndex = value.round() + 1),
                    onChangeEnd: (double value) {
                      final int index = value.round() + 1;
                      setState(() => _dragIndex = null);
                      widget.onLocate(index);
                    },
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2.0),
                    child: const LinearProgressIndicator(
                      value: 1.0,
                      minHeight: 4.0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36.0, height: 36.0),
      padding: EdgeInsets.zero,
    );
  }
}
