// 「计划学习」首页：按计划状态展示进度、今日目标与下一步操作。
//
// 状态判断全部来自 `evaluateNow()`（有写盘副作用），因此只在 initState、
// 从子页面返回以及按钮回调里调用，绝不在 build 内调用。

import 'package:flutter/material.dart';

import 'package:arabic_learning/core/extensions.dart' show SemanticColorsContext;
import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/models/plan.dart' show PlanScopeRef, StudyPlan;
import 'package:arabic_learning/screens/learning/fsrs_screens.dart'
    show ForeFSRSSettingPage;
import 'package:arabic_learning/screens/learning/plan/plan_config_page.dart';
import 'package:arabic_learning/screens/learning/plan/plan_session_page.dart';
import 'package:arabic_learning/screens/learning/plan/plan_shared.dart';
import 'package:arabic_learning/services/plan_scheduler.dart';
import 'package:arabic_learning/services/plan_store.dart';
import 'package:arabic_learning/theme/tokens.dart';
import 'package:arabic_learning/theme/typography.dart' show withoutColor;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/overlays.dart' show showSnackBar;

/// 「计划学习」首页。
///
/// 无计划 / 复习系统未启用 / 范围失效 / 逾期 / 周期完成 / 进行中六种状态
/// 各自对应一块主卡片，宽屏内容居中限宽 720。
class PlanHomePage extends StatefulWidget {
  const PlanHomePage({super.key});

  @override
  State<PlanHomePage> createState() => _PlanHomePageState();
}

enum _PlanView { empty, fsrsDisabled, invalidScope, overdue, complete, active }

class _PlanHomePageState extends State<PlanHomePage> {
  late PlanStatus _status;

  /// 会话页跳转中：避免连续点击重复入栈。
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _status = evaluateNow();
  }

  /// 重新评估状态（只在 initState / 返回页面 / 按钮回调中调用）。
  void _refresh() {
    if (!mounted) return;
    setState(() {
      _status = evaluateNow();
    });
  }

  _PlanView _resolveView(StudyPlan? plan) {
    if (plan == null) return _PlanView.empty;
    if (_status.fsrsDisabled) return _PlanView.fsrsDisabled;
    if (_status.invalidScope || _status.scopeWords == 0) {
      return _PlanView.invalidScope;
    }
    if (_status.cycleComplete) return _PlanView.complete;
    if (_status.overdue) return _PlanView.overdue;
    return _PlanView.active;
  }

  Future<void> _openConfig({StudyPlan? initial}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => PlanConfigPage(initial: initial),
      ),
    );
    // 配置页可能同时改变复习系统状态，返回后一律重算。
    _refresh();
  }

  Future<void> _openFsrsSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            const ForeFSRSSettingPage(forceChoosing: true),
      ),
    );
    _refresh();
  }

  /// 开始（或继续）今日学习；返回后刷新当日进度。
  Future<void> _startGroup() async {
    if (_starting) return;
    final StudyPlan? plan = PlanStore().state.plan;
    if (plan == null) return;
    final List<WordItem> words = nextGroupWords();
    if (words.isEmpty) {
      showSnackBar(context, "当前没有可学习的单词，请检查学习范围或复习系统");
      _refresh();
      return;
    }
    setState(() {
      _starting = true;
    });
    // 会话页以 bool 告知本组是否新增了已学词；首页统一重算，不区分结果。
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => PlanSessionPage(
          words: words,
          chain: plan.chain,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _starting = false;
      _status = evaluateNow();
    });
  }

  /// 延期截止日期：3 / 7 / 14 天三档。
  Future<void> _askExtend() async {
    final StudyPlan? plan = PlanStore().state.plan;
    if (plan == null) return;
    final DateTime deadline = plan.deadline;
    final int? days = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        Widget option(int value) {
          final DateTime moved =
              DateTime(deadline.year, deadline.month, deadline.day + value);
          return SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(value),
            child: Row(
              children: <Widget>[
                const Icon(Icons.fast_forward_rounded, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text("延期 $value 天")),
                Text(
                  planMonthDay(moved),
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }

        return SimpleDialog(
          title: const Text("延期截止日期"),
          children: <Widget>[option(3), option(7), option(14)],
        );
      },
    );
    if (days == null || !mounted) return;
    await extendPlanDeadline(days);
    if (!mounted) return;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final StudyPlan? plan = PlanStore().state.plan;
    final _PlanView view = _resolveView(plan);
    return Scaffold(
      appBar: AppBar(title: const Text("计划学习")),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth > AppBreakpoints.mobile;
            final double horizontal = wide ? AppSpacing.md : AppSpacing.sm;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                AppSpacing.md,
                horizontal,
                AppSpacing.lg,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720.0),
                  child: AnimatedSwitcher(
                    duration: AppMotion.mediumShort,
                    switchInCurve: AppMotion.decelerateCurve,
                    switchOutCurve: AppMotion.accelerateCurve,
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.02),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<_PlanView>(view),
                      child: _buildView(context, plan, view),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildView(BuildContext context, StudyPlan? plan, _PlanView view) {
    switch (view) {
      case _PlanView.empty:
        return _buildEmpty(context);
      case _PlanView.fsrsDisabled:
        return _buildFsrsBlocked(context);
      case _PlanView.invalidScope:
        return _buildInvalidScope(context, plan!);
      case _PlanView.overdue:
        return _buildOverdue(context, plan!);
      case _PlanView.complete:
        return _buildComplete(context);
      case _PlanView.active:
        return _buildActive(context, plan!);
    }
  }

  // ---------------------------------------------------------------------------
  // 状态 1：还没有计划
  // ---------------------------------------------------------------------------

  Widget _buildEmpty(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return _PlanPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _RoundIcon(icon: Icons.event_note_outlined, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  "还没有学习计划",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoLine(
            icon: Icons.calendar_month_outlined,
            text: "设定截止日期，应用会按剩余天数拆出每天的最低学习量。",
          ),
          _InfoLine(
            icon: Icons.auto_stories_outlined,
            text: "进度以复习系统的已学记录为准，学完的单词会同时进入复习。",
          ),
          const SizedBox(height: AppSpacing.md),
          _cta(
            context,
            label: "建立学习计划",
            onPressed: () => _openConfig(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 状态 2：复习系统未启用
  // ---------------------------------------------------------------------------

  Widget _buildFsrsBlocked(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color warning = context.semanticColors.warning;
    return _PlanPanel(
      color: Color.alphaBlend(
        warning.withValues(alpha: 0.08),
        scheme.surfaceContainerLow,
      ),
      borderColor: warning.withValues(alpha: 0.38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _RoundIcon(icon: Icons.history_edu_outlined, color: warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  "计划学习需要复习系统",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "计划进度以复习系统的已学记录为准。停用复习系统后，学习记录不会进入计划，"
            "进度也无法计算。",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _cta(
            context,
            label: "前往复习设置",
            onPressed: _openFsrsSettings,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 状态 3：学习范围失效
  // ---------------------------------------------------------------------------

  Widget _buildInvalidScope(BuildContext context, StudyPlan plan) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color error = context.semanticColors.error;
    return _PlanPanel(
      borderColor: error.withValues(alpha: 0.36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _RoundIcon(icon: Icons.link_off_rounded, color: error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  "学习范围已失效",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "原计划中的课程已不在当前词库中，需要重新选择学习范围。"
            "截止日期、每组数量与学习链条会保留。",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _cta(
            context,
            label: "重新配置",
            onPressed: () => _openConfig(initial: plan),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 状态 4：逾期
  // ---------------------------------------------------------------------------

  Widget _buildOverdue(BuildContext context, StudyPlan plan) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color warning = context.semanticColors.warning;
    return _PlanPanel(
      color: Color.alphaBlend(
        warning.withValues(alpha: 0.10),
        scheme.surfaceContainerLow,
      ),
      borderColor: warning.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _RoundIcon(icon: Icons.warning_amber_rounded, color: warning),
              const SizedBox(width: AppSpacing.sm),
              Text(
                "已逾期",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "已逾期，仍有 ${_status.remainingWords} 词未学",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            "截止日期为 ${planFullDate(plan.deadline)}。可以延期，或重新配置范围与节奏。",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _cta(context, label: "延期 7 天", onPressed: _askExtend),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _cta(
                  context,
                  label: "重新配置",
                  onPressed: () => _openConfig(initial: plan),
                  background: scheme.secondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _starting ? null : _startGroup,
              icon: const Icon(Icons.play_arrow_rounded, size: 18.0),
              label: Text("仍要学习（剩 ${_status.remainingWords} 词）"),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 状态 5：本周期完成
  // ---------------------------------------------------------------------------

  Widget _buildComplete(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color success = context.semanticColors.success;
    return _PlanPanel(
      color: Color.alphaBlend(
        success.withValues(alpha: 0.12),
        scheme.surfaceContainerLow,
      ),
      borderColor: success.withValues(alpha: 0.40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _RoundIcon(icon: Icons.task_alt_rounded, color: success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  "本周期已完成",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "本周期已学 ${_status.learnedWords} 词，学习范围 ${_status.scopeWords} 词已全部完成。",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _cta(
            context,
            label: "配置下一周期",
            onPressed: () => _openConfig(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 状态 6：进行中
  // ---------------------------------------------------------------------------

  Widget _buildActive(BuildContext context, StudyPlan plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildCycleCard(context, plan),
        const SizedBox(height: AppSpacing.sm),
        _buildTodayCard(context, plan),
      ],
    );
  }

  Widget _buildCycleCard(BuildContext context, StudyPlan plan) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color on = scheme.onPrimaryContainer;
    final int scope = _status.scopeWords;
    final double progress = scope == 0 ? 0.0 : _status.learnedWords / scope;
    final List<PlanScopeRef> refs = activeScopeRefs(plan);
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            scheme.primaryContainer,
            Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.12),
              scheme.primaryContainer,
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color: on.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Text(
                  "本周期进度",
                  style: theme.textTheme.labelMedium?.copyWith(color: on),
                ),
              ),
              const Spacer(),
              Text(
                "剩 ${_status.daysLeft} 天",
                style: theme.textTheme.titleMedium?.copyWith(
                  color: on,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                "${_status.learnedWords}",
                style: theme.textTheme.displaySmall?.copyWith(
                  color: on,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6.0, bottom: 4.0),
                child: Text(
                  "/ $scope 词",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: on.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          PlanProgressBar(
            value: progress,
            color: on,
            trackColor: on.withValues(alpha: 0.16),
            height: 8.0,
          ),
          const SizedBox(height: 6.0),
          Row(
            children: <Widget>[
              Text(
                "待学 ${_status.remainingWords} 词",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: on.withValues(alpha: 0.72),
                ),
              ),
              const Spacer(),
              Text(
                "截止 ${planMonthDay(plan.deadline)}",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: on.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
          if (refs.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Icon(
                  Icons.menu_book_outlined,
                  size: 14.0,
                  color: on.withValues(alpha: 0.72),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  "学习范围",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: on.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6.0),
            _buildScopeChips(context, refs, on),
          ],
        ],
      ),
    );
  }

  Widget _buildScopeChips(
    BuildContext context,
    List<PlanScopeRef> refs,
    Color foreground,
  ) {
    const int limit = 3;
    final List<String> names = refs
        .map((PlanScopeRef ref) =>
            ref.className.isEmpty ? "未命名课程" : ref.className)
        .toList(growable: false);
    final int hidden = names.length - limit;
    return Wrap(
      spacing: 6.0,
      runSpacing: 6.0,
      children: <Widget>[
        for (final String name in names.take(limit))
          _MiniChip(label: name, foreground: foreground),
        if (hidden > 0)
          Tooltip(
            message: names.skip(limit).join("、"),
            child: _MiniChip(label: "+$hidden", foreground: foreground),
          ),
      ],
    );
  }

  Widget _buildTodayCard(BuildContext context, StudyPlan plan) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color success = context.semanticColors.success;
    final bool met = _status.minWords > 0 && _status.doneWords >= _status.minWords;
    final Color accent = met ? success : scheme.primary;
    return _PlanPanel(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                "今日",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (met)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _Pill(
                      label: "今日最低目标已完成",
                      foreground: success,
                      background: success.withValues(alpha: 0.12),
                    ),
                  ),
                )
              else
                const Spacer(),
              Text(
                "共 ${_status.groupsToday} 组",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      "${_status.doneWords}",
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                      child: Text(
                        "/ ${_status.minWords} 词",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    met ? "已达标" : "还差 ${_status.todayRemaining} 词",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: met ? success : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          PlanProgressBar(
            value: _status.todayProgress,
            color: accent,
            height: 8.0,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          if (met)
            _cta(
              context,
              label: _starting ? "正在准备…" : "再学一组",
              onPressed: _starting ? null : _startGroup,
              background: scheme.secondaryContainer,
            )
          else
            _cta(
              context,
              label: _starting
                  ? "正在准备…"
                  : _status.doneWords == 0
                      ? "开始今日学习"
                      : "继续学习（还差 ${_status.todayRemaining} 词）",
              onPressed: _starting ? null : _startGroup,
            ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  "每组 ${_status.groupSize} 词 · 每日至少 ${_status.groupsToday} 组",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openConfig(initial: plan),
                child: const Text("调整计划"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 共用小部件
  // ---------------------------------------------------------------------------

  Widget _cta(
    BuildContext context, {
    required String label,
    required VoidCallback? onPressed,
    Color? background,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 52.0,
      child: Button(
        onPressed: onPressed,
        backgroundColor: background ?? scheme.primaryContainer,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        // 只缩不放：窄屏上「继续学习（还差 N 词）」这类长标签自动整体缩小，
        // 不会被折行或裁切。
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: withoutColor(
              Theme.of(context).textTheme.titleMedium!,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// 统一卡片容器：25 圆角、扁平底色，可选描边。
class _PlanPanel extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  const _PlanPanel({
    required this.child,
    this.color,
    this.borderColor,
    this.padding = const EdgeInsets.all(20.0),
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLow,
        borderRadius: AppRadius.cardBorder,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 1.0),
      ),
      child: child,
    );
  }
}

/// 圆形图标底：同色 12% 透明背景。
class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _RoundIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44.0,
      height: 44.0,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 23.0, color: color),
    );
  }
}

/// 空状态里的说明行。
class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(icon, size: 17.0, color: color),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 小胶囊：达标徽章、周期标签等。
class _Pill extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;

  const _Pill({
    required this.label,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// 课程名小标签。
class _MiniChip extends StatelessWidget {
  final String label;
  final Color foreground;

  const _MiniChip({required this.label, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
              ),
        ),
      ),
    );
  }
}
