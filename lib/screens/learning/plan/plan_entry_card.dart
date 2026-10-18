// 学习页顶部的「计划学习」入口卡。
//
// 高度很紧（学习页可用的纵向空间有限），因此采用单行图标 + 两行文字 +
// 底部 3px 细进度条的紧凑结构；点击进入计划首页，返回后自行刷新状态。

import 'package:flutter/material.dart';

import 'package:arabic_learning/core/extensions.dart' show SemanticColorsContext;
import 'package:arabic_learning/models/plan.dart' show StudyPlan;
import 'package:arabic_learning/screens/learning/plan/plan_home_page.dart';
import 'package:arabic_learning/screens/learning/plan/plan_shared.dart';
import 'package:arabic_learning/services/plan_scheduler.dart';
import 'package:arabic_learning/services/plan_store.dart';
import 'package:arabic_learning/theme/tokens.dart';

/// 学习页的计划入口卡。
///
/// [height] 由父级按可用高度传入（建议 60..72），内部布局按该高度自适应，
/// 不做滚动，保证学习页原有按钮排布不被挤动。
class PlanEntryCard extends StatefulWidget {
  final double height;

  const PlanEntryCard({super.key, this.height = 64.0});

  @override
  State<PlanEntryCard> createState() => _PlanEntryCardState();
}

class _PlanEntryCardState extends State<PlanEntryCard> {
  late PlanStatus _status;

  @override
  void initState() {
    super.initState();
    _status = evaluateNow();
  }

  Future<void> _open() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const PlanHomePage(),
      ),
    );
    if (!mounted) return;
    setState(() {
      _status = evaluateNow();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color success = context.semanticColors.success;
    final Color warning = context.semanticColors.warning;
    final StudyPlan? plan = PlanStore().state.plan;

    final bool hasPlan = plan != null;
    final bool invalidScope = hasPlan &&
        !_status.fsrsDisabled &&
        (_status.invalidScope || _status.scopeWords == 0);
    final bool complete =
        hasPlan && !_status.fsrsDisabled && !invalidScope && _status.cycleComplete;
    final bool overdue =
        hasPlan && !_status.fsrsDisabled && !invalidScope && _status.overdue;
    final bool met = hasPlan &&
        !_status.fsrsDisabled &&
        !invalidScope &&
        !complete &&
        !overdue &&
        _status.minWords > 0 &&
        _status.doneWords >= _status.minWords;

    final Color foreground;
    final Color background;
    final Color accent;
    final IconData icon;
    final double progress;
    final String statusText;

    if (!hasPlan) {
      background = scheme.surfaceContainerLow;
      foreground = scheme.onSurface;
      accent = scheme.primary;
      icon = Icons.event_note_outlined;
      progress = 0.0;
      statusText = "设定截止日期，自动规划每日学习量";
    } else if (_status.fsrsDisabled) {
      background = scheme.surfaceContainerLow;
      foreground = scheme.onSurface;
      accent = warning;
      icon = Icons.history_edu_outlined;
      progress = 0.0;
      statusText = "需先启用复习系统";
    } else if (invalidScope) {
      background = scheme.surfaceContainerLow;
      foreground = scheme.onSurface;
      accent = context.semanticColors.error;
      icon = Icons.link_off_rounded;
      progress = 0.0;
      statusText = "学习范围已失效，需重新配置";
    } else if (complete) {
      background = Color.alphaBlend(
        success.withValues(alpha: 0.12),
        scheme.surfaceContainerLow,
      );
      foreground = scheme.onSurface;
      accent = success;
      icon = Icons.task_alt_rounded;
      progress = 1.0;
      statusText = "本周期已完成";
    } else if (overdue) {
      background = Color.alphaBlend(
        warning.withValues(alpha: 0.12),
        scheme.surfaceContainerLow,
      );
      foreground = scheme.onSurface;
      accent = warning;
      icon = Icons.warning_amber_rounded;
      progress = 0.0;
      statusText = "已逾期";
    } else if (met) {
      background = Color.alphaBlend(
        success.withValues(alpha: 0.12),
        scheme.surfaceContainerLow,
      );
      foreground = scheme.onSurface;
      accent = success;
      icon = Icons.check_circle_outline_rounded;
      progress = _status.todayProgress;
      statusText = "今日已完成 · 可继续学习";
    } else {
      background = scheme.primaryContainer;
      foreground = scheme.onPrimaryContainer;
      accent = scheme.onPrimaryContainer;
      icon = Icons.event_available_outlined;
      progress = _status.todayProgress;
      statusText =
          "今日 ${_status.doneWords}/${_status.minWords} · 剩 ${_status.daysLeft} 天";
    }

    return SizedBox(
      height: widget.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Material(
          color: background,
          borderRadius: AppRadius.cardBorder,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _open,
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14.0, 8.0, 10.0, 10.0),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 32.0,
                        height: 32.0,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 18.0, color: accent),
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        // 卡片高度固定且很紧：两行文字整体按需等比缩小，
                        // 系统放大字号时也不会撑破卡片（只缩不放）。
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                "计划学习",
                                maxLines: 1,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 1.0),
                              Text(
                                statusText,
                                maxLines: 1,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: foreground.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18.0,
                        color: foreground.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0.0,
                  right: 0.0,
                  bottom: 0.0,
                  child: PlanProgressBar(
                    value: progress,
                    color: accent,
                    trackColor: foreground.withValues(alpha: 0.10),
                    height: 3.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
