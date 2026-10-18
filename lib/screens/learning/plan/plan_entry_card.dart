// 学习页顶部的「计划学习」入口。
//
// 视觉上与学习页其余入口同族：直接复用 `widgets/kit.dart` 的 [Button]，
// 沿用大色块 + 卡片圆角（Button 默认 `AppRadius.card`）+ 左侧图标 + 两行
// 文案 + 按压缩放，不引入独立卡片、图标气泡、chevron、阴影或渐变。
//
// 高度很紧（60..72），所以文案保持两行；当日进度作为磁贴**底边**画在按钮
// 内部：随按钮自身的圆角裁切、随按压一起缩放，与底色连成一体，而不是浮在
// 卡片上的独立仪表条。

import 'package:flutter/material.dart';

import 'package:arabic_learning/models/plan.dart' show StudyPlan;
import 'package:arabic_learning/screens/learning/plan/plan_home_page.dart';
import 'package:arabic_learning/screens/learning/plan/plan_shared.dart'
    show PlanProgressBar;
import 'package:arabic_learning/services/plan_scheduler.dart';
import 'package:arabic_learning/services/plan_store.dart';
import 'package:arabic_learning/theme/tokens.dart';
import 'package:arabic_learning/theme/typography.dart' show withoutColor;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/shared.dart' show ButtonLabel;

/// 学习页的计划入口。
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
    final StudyPlan? plan = PlanStore().state.plan;

    final bool hasPlan = plan != null;
    final bool invalidScope =
        hasPlan &&
        !_status.fsrsDisabled &&
        (_status.invalidScope || _status.scopeWords == 0);
    final bool complete =
        hasPlan &&
        !_status.fsrsDisabled &&
        !invalidScope &&
        _status.cycleComplete;
    final bool overdue =
        hasPlan && !_status.fsrsDisabled && !invalidScope && _status.overdue;
    final bool met =
        hasPlan &&
        !_status.fsrsDisabled &&
        !invalidScope &&
        !complete &&
        !overdue &&
        _status.minWords > 0 &&
        _status.doneWords >= _status.minWords;

    // 各状态只靠「容器色 + 图标 + 文案」区分，全部取自当前 ColorScheme，
    // 不额外叠加透明色块或边框；进度线属于磁贴本身，只在计划生效时出现。
    final Color background;
    final Color foreground;
    final IconData icon;
    final String statusText;
    final double progress;
    final bool showProgress;

    if (!hasPlan) {
      background = scheme.primaryContainer;
      foreground = scheme.onPrimaryContainer;
      icon = Icons.event_note_outlined;
      progress = 0.0;
      showProgress = false;
      statusText = "设定截止日期，自动规划每日学习量";
    } else if (_status.fsrsDisabled) {
      background = scheme.secondaryContainer;
      foreground = scheme.onSecondaryContainer;
      icon = Icons.history_edu_outlined;
      progress = 0.0;
      showProgress = false;
      statusText = "需先启用复习系统";
    } else if (invalidScope) {
      background = scheme.errorContainer;
      foreground = scheme.onErrorContainer;
      icon = Icons.link_off_rounded;
      progress = 0.0;
      showProgress = false;
      statusText = "学习范围已失效，需重新配置";
    } else if (complete) {
      background = scheme.tertiaryContainer;
      foreground = scheme.onTertiaryContainer;
      icon = Icons.task_alt_rounded;
      progress = 1.0;
      showProgress = true;
      statusText = "本周期已完成";
    } else if (overdue) {
      background = scheme.errorContainer;
      foreground = scheme.onErrorContainer;
      icon = Icons.warning_amber_rounded;
      progress = 0.0;
      showProgress = false;
      statusText = "已逾期 · 剩 ${_status.remainingWords} 词";
    } else if (met) {
      background = scheme.tertiaryContainer;
      foreground = scheme.onTertiaryContainer;
      icon = Icons.check_circle_outline_rounded;
      progress = 1.0;
      showProgress = true;
      statusText = "今日已达标 · 可继续学习";
    } else {
      background = scheme.primaryContainer;
      foreground = scheme.onPrimaryContainer;
      icon = Icons.event_available_outlined;
      progress = _status.todayProgress;
      showProgress = true;
      statusText =
          "今日 ${_status.doneWords}/${_status.minWords} · 剩 ${_status.daysLeft} 天";
    }

    // 与学习页的次级磁贴同宽：页面内单列大按钮都占 0.8 宽并居中，
    // 入口不再作为一条横贯页面的独立横幅出现。
    return SizedBox(
      width: double.infinity,
      child: FractionallySizedBox(
        widthFactor: 0.8,
        child: SizedBox(
          height: widget.height,
          child: Button(
            backgroundColor: background,
            foregroundColor: foreground,
            // 进度线要贴到磁贴底边，因此由子级自行铺满按钮并控制内边距。
            padding: EdgeInsets.zero,
            onPressed: _open,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Row(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Icon(icon, size: 24.0, color: foreground),
                      ),
                      ButtonLabel(
                        // 两行文字整体按需等比缩小（只缩不放），系统放大字号时
                        // 也不会撑破磁贴；与页面其余按钮共用同一套居中缩放假定。
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              "计划学习",
                              maxLines: 1,
                              style: withoutColor(
                                theme.textTheme.titleMedium!,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              statusText,
                              maxLines: 1,
                              style: withoutColor(theme.textTheme.bodySmall!)
                                  .copyWith(
                                    color: foreground.withValues(alpha: 0.85),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 进度与磁贴嵌合：宽度铺满、贴住底边，由 Button 的圆角裁切，
                // 颜色取自磁贴前景色，不另设轨道卡片或填充块。
                if (showProgress)
                  Positioned(
                    left: 0.0,
                    right: 0.0,
                    bottom: 0.0,
                    height: 3.0,
                    // 纯展示，不拦截磁贴底边的点击。
                    child: IgnorePointer(
                      child: PlanProgressBar(
                        value: progress,
                        color: foreground,
                        trackColor: foreground.withValues(alpha: 0.12),
                        height: 3.0,
                      ),
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
