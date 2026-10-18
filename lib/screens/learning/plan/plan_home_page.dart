// 「计划学习」首页：按计划状态展示进度、今日目标与下一步操作。
//
// 状态判断全部来自 `evaluateNow()`（有写盘副作用），因此只在 initState、
// 从子页面返回以及按钮回调里调用，绝不在 build 内调用。
//
// 界面统一使用 Material 原生组件（Card / FilledButton / Chip / ListTile /
// Divider / LinearProgressIndicator），本文件不再定义通用容器或进度条类，
// 只保留按状态组织布局的方法。

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
import 'package:arabic_learning/widgets/overlays.dart' show showSnackBar;
import 'package:arabic_learning/widgets/question_chain_editor.dart'
    show kQuestionTypeLabels;

/// 「计划学习」首页。
///
/// 无计划 / 复习系统未启用 / 范围失效 / 逾期 / 周期完成 / 进行中六种状态
/// 各自对应一块主卡片；进行中还会继续展开今日任务、学习内容与计划设置，
/// 宽屏内容居中限宽 720，窄屏单列滚动。
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
        return _buildComplete(context, plan!);
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
    return _panel(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _headline(
            context,
            icon: Icons.event_note_outlined,
            color: scheme.primary,
            title: "还没有学习计划",
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "设定截止日期与学习范围后，应用会把范围内的未学单词拆成每天的最低学习量。",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _infoTile(
            context,
            icon: Icons.flag_outlined,
            title: "设定截止日期",
            subtitle: "按剩余天数计算每天至少要学多少词。",
          ),
          _infoTile(
            context,
            icon: Icons.auto_stories_outlined,
            title: "选择学习范围",
            subtitle: "课程按选择顺序依次学习，也可以打乱课程顺序。",
          ),
          _infoTile(
            context,
            icon: Icons.history_edu_outlined,
            title: "进度取自复习系统",
            subtitle: "学完的单词会进入复习，计划只看这部分已学记录。",
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
    return _panel(
      context,
      color: Color.alphaBlend(
        warning.withValues(alpha: 0.08),
        scheme.surfaceContainerLow,
      ),
      borderColor: warning.withValues(alpha: 0.38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _headline(
            context,
            icon: Icons.history_edu_outlined,
            color: warning,
            title: "计划学习需要复习系统",
          ),
          const SizedBox(height: AppSpacing.xs),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _panel(
          context,
          borderColor: error.withValues(alpha: 0.36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _headline(
                context,
                icon: Icons.link_off_rounded,
                color: error,
                title: "学习范围已失效",
              ),
              const SizedBox(height: AppSpacing.xs),
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
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildSettingsCard(context, plan),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 状态 4：逾期
  // ---------------------------------------------------------------------------

  Widget _buildOverdue(BuildContext context, StudyPlan plan) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color warning = context.semanticColors.warning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _panel(
          context,
          color: Color.alphaBlend(
            warning.withValues(alpha: 0.10),
            scheme.surfaceContainerLow,
          ),
          borderColor: warning.withValues(alpha: 0.45),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _headline(
                context,
                icon: Icons.warning_amber_rounded,
                color: warning,
                title: "已逾期",
                titleColor: warning,
              ),
              const SizedBox(height: AppSpacing.xs),
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
                    child: _cta(
                      context,
                      label: "延期 7 天",
                      onPressed: _askExtend,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _cta(
                      context,
                      label: "重新配置",
                      onPressed: () => _openConfig(initial: plan),
                      tonal: true,
                    ),
                  ),
                ],
              ),
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
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildContentCard(context, plan),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 状态 5：本周期完成
  // ---------------------------------------------------------------------------

  Widget _buildComplete(BuildContext context, StudyPlan plan) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color success = context.semanticColors.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _panel(
          context,
          color: Color.alphaBlend(
            success.withValues(alpha: 0.12),
            scheme.surfaceContainerLow,
          ),
          borderColor: success.withValues(alpha: 0.40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _headline(
                context,
                icon: Icons.task_alt_rounded,
                color: success,
                title: "本周期已完成",
              ),
              const SizedBox(height: AppSpacing.xs),
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
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildContentCard(context, plan),
      ],
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
        const SizedBox(height: AppSpacing.sm),
        _buildContentCard(context, plan),
        const SizedBox(height: AppSpacing.sm),
        _buildSettingsCard(context, plan),
      ],
    );
  }

  /// 周期概览：截止日期、剩余天数、已学 / 总词数与整体进度。
  Widget _buildCycleCard(BuildContext context, StudyPlan plan) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color on = scheme.onPrimaryContainer;
    final int scope = _status.scopeWords;
    final double progress =
        scope <= 0 ? 0.0 : (_status.learnedWords / scope).clamp(0.0, 1.0);
    return _panel(
      context,
      color: scheme.primaryContainer,
      gradient: <Color>[
        scheme.primaryContainer,
        Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.12),
          scheme.primaryContainer,
        ),
      ],
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.flag_outlined,
                size: 18.0,
                color: on.withValues(alpha: 0.80),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  "本周期",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: on.withValues(alpha: 0.80),
                  ),
                ),
              ),
              Chip(
                label: Text("剩 ${_status.daysLeft} 天"),
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: on,
                  fontWeight: FontWeight.w600,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                backgroundColor: on.withValues(alpha: 0.12),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xxs,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                "${(progress * 100).round()}%",
                style: theme.textTheme.titleLarge?.copyWith(
                  color: on,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8.0,
            color: on,
            backgroundColor: on.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(4.0),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  "待学 ${_status.remainingWords} 词",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: on.withValues(alpha: 0.72),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  "截止 ${planMonthDay(plan.deadline)}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: on.withValues(alpha: 0.72),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 今日任务：今日完成量、第几组、主操作与节奏说明。
  Widget _buildTodayCard(BuildContext context, StudyPlan plan) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color success = context.semanticColors.success;
    final bool met =
        _status.minWords > 0 && _status.doneWords >= _status.minWords;
    final Color accent = met ? success : scheme.primary;
    final int groups = _status.groupsToday;
    final int finishedGroups = _status.groupSize <= 0
        ? 0
        : _status.doneWords ~/ _status.groupSize;
    final String groupText = groups <= 0
        ? "今日无最低要求"
        : met
            ? "已完成 $groups 组"
            : "第 ${(finishedGroups + 1).clamp(1, groups)}/$groups 组";

    return _panel(
      context,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.today_outlined, size: 18.0, color: scheme.primary),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  "今日任务",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                groupText,
                maxLines: 1,
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
              Expanded(
                child: FittedBox(
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
              ),
              const SizedBox(width: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: met
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16.0,
                            color: success,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            "已达标",
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        "还差 ${_status.todayRemaining} 词",
                        maxLines: 1,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          LinearProgressIndicator(
            value: _status.todayProgress.clamp(0.0, 1.0),
            minHeight: 8.0,
            color: accent,
            backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4.0),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          if (met)
            _cta(
              context,
              label: _starting ? "正在准备…" : "再学一组",
              onPressed: _starting ? null : _startGroup,
              tonal: true,
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
          Text(
            "每组 ${_status.groupSize} 词 · 每日至少 ${_status.groupsToday} 组",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 学习内容：范围课程与学习链条。
  Widget _buildContentCard(BuildContext context, StudyPlan plan) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<PlanScopeRef> refs = activeScopeRefs(plan);
    const int limit = 6;
    final int hidden = refs.length - limit;
    final List<int> sections = plan.chain.sections;

    return _panel(
      context,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.folder_open_outlined,
                size: 18.0,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  "学习范围",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                "共 ${_status.scopeWords} 词",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (refs.isEmpty)
            Text(
              "计划中的课程都不在当前词库里。",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final PlanScopeRef ref in refs.take(limit))
                  _courseChip(
                    context,
                    ref.className.isEmpty ? "未命名课程" : ref.className,
                  ),
                if (hidden > 0)
                  _courseChip(context, "+$hidden 门课程"),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1.0, thickness: 1.0),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Icon(
                Icons.linear_scale_rounded,
                size: 18.0,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  "学习链条",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                plan.chain.shuffleWithinSection ? "组内乱序" : "组内顺序",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (int index = 0; index < sections.length; index++)
                _chainChip(context, index + 1, sections[index]),
            ],
          ),
        ],
      ),
    );
  }

  /// 计划设置：每组数量、乱序开关与连胜门禁的当前状态。
  Widget _buildSettingsCard(BuildContext context, StudyPlan plan) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    TextStyle? stateStyle(bool active) => theme.textTheme.labelLarge?.copyWith(
          color: active ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );

    Widget tile({
      required IconData icon,
      required String title,
      String? subtitle,
      required Widget trailing,
    }) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        // 与分区标题的左缘对齐：图标 18 + 间隙 4 = 标题文字缩进 22。
        minLeadingWidth: 0.0,
        horizontalTitleGap: AppSpacing.xxs,
        leading: Icon(icon, size: 18.0, color: scheme.primary),
        title: Text(title, style: theme.textTheme.bodyLarge),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
        trailing: trailing,
      );
    }

    return _panel(
      context,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.tune_rounded, size: 18.0, color: scheme.primary),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  "计划设置",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openConfig(initial: plan),
                child: const Text("调整计划"),
              ),
            ],
          ),
          const Divider(height: 1.0, thickness: 1.0),
          tile(
            icon: Icons.layers_outlined,
            title: "每组词数",
            trailing: Text("${plan.groupSize} 词", style: stateStyle(true)),
          ),
          const Divider(height: 1.0, thickness: 1.0),
          tile(
            icon: Icons.shuffle_rounded,
            title: "组内单词乱序",
            trailing: Text(
              plan.chain.shuffleWithinSection ? "已开启" : "已关闭",
              style: stateStyle(plan.chain.shuffleWithinSection),
            ),
          ),
          const Divider(height: 1.0, thickness: 1.0),
          tile(
            icon: Icons.swap_horiz_rounded,
            title: "打乱课程顺序",
            trailing: Text(
              plan.shuffleClasses ? "已开启" : "已关闭",
              style: stateStyle(plan.shuffleClasses),
            ),
          ),
          const Divider(height: 1.0, thickness: 1.0),
          tile(
            icon: Icons.local_fire_department_outlined,
            title: "介入连胜",
            subtitle: plan.streakGate
                ? "当日未完成最低目标前，学习不会计入连胜。"
                : "未介入：任何一天学习后都会计入连胜。",
            trailing: Text(
              plan.streakGate ? "已开启" : "已关闭",
              style: stateStyle(plan.streakGate),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 共用布局
  // ---------------------------------------------------------------------------

  /// 统一卡片容器：25 圆角、扁平底色，可选描边与渐变。
  Widget _panel(
    BuildContext context, {
    required Widget child,
    Color? color,
    Color? borderColor,
    List<Color>? gradient,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20.0),
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    Widget body = Padding(padding: padding, child: child);
    if (gradient != null) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
        ),
        child: body,
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0.0,
      color: color ?? scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor, width: 1.0),
      ),
      child: body,
    );
  }

  /// 状态卡标题：圆形图标底 + 标题。
  Widget _headline(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    Color? titleColor,
  }) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 22.0,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, size: 22.0, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
        ),
      ],
    );
  }

  /// 空状态里的说明行（Material `ListTile`）。
  Widget _infoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 24.0,
      leading: Icon(icon, size: 20.0, color: scheme.primary),
      title: Text(title, style: theme.textTheme.bodyLarge),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    );
  }

  /// 课程名标签。
  Widget _courseChip(BuildContext context, String label) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220.0),
      child: Chip(
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSecondaryContainer,
          ),
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
        backgroundColor: scheme.secondaryContainer,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs,
          vertical: 2.0,
        ),
      ),
    );
  }

  /// 学习链条里的题型标签（序号 + 题型名）。
  Widget _chainChip(BuildContext context, int order, int type) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220.0),
      child: Chip(
        label: Text(
          "$order. ${kQuestionTypeLabels[type] ?? "未知题型"}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurface,
          ),
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs,
          vertical: 2.0,
        ),
      ),
    );
  }

  /// 主操作按钮（Material `FilledButton`）；[tonal] 为次级色调。
  Widget _cta(
    BuildContext context, {
    required String label,
    required VoidCallback? onPressed,
    bool tonal = false,
  }) {
    final ThemeData theme = Theme.of(context);
    const EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    );
    // 只缩不放：窄屏上「继续学习（还差 N 词）」这类长标签自动整体缩小，
    // 不会被折行或裁切。颜色留给 FilledButton 的默认前景色，去掉主题里的
    // 文字颜色，避免深色文字压在深色按钮上。
    final Widget child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        style: withoutColor(
          theme.textTheme.titleMedium!,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
    );
    return SizedBox(
      width: double.infinity,
      height: 52.0,
      child: tonal
          ? FilledButton.tonal(
              onPressed: onPressed,
              style: FilledButton.styleFrom(padding: padding),
              child: child,
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(padding: padding),
              child: child,
            ),
    );
  }
}
