// 「计划学习」配置页：截止日期、学习范围、每组数量、学习链条与三个开关。
//
// 保存前做完整校验（范围非空且有可学词、链条合法、截止日期晚于今天、
// 复习系统已启用），保存成功后 `pop(true)` 交由首页刷新。

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:arabic_learning/core/extensions.dart' show SemanticColorsContext;
import 'package:arabic_learning/models/dict.dart' show ClassItem, SourceItem;
import 'package:arabic_learning/models/plan.dart'
    show PlanChain, PlanScopeRef, StudyPlan;
import 'package:arabic_learning/models/reading.dart' show ClassSelection;
import 'package:arabic_learning/screens/learning/fsrs_screens.dart'
    show ForeFSRSSettingPage;
import 'package:arabic_learning/screens/learning/plan/plan_shared.dart';
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS;
import 'package:arabic_learning/services/plan_scheduler.dart';
import 'package:arabic_learning/services/plan_store.dart';
import 'package:arabic_learning/theme/tokens.dart';
import 'package:arabic_learning/theme/typography.dart' show withoutColor;
import 'package:arabic_learning/widgets/kit.dart' show Button, popSelectClasses;
import 'package:arabic_learning/widgets/overlays.dart' show showSnackBar;
import 'package:arabic_learning/widgets/question_chain_editor.dart';

/// 题型链条的列表与添加菜单都按 `MediaQuery.size.height` 计算行高；
/// 高度不足时统一按 800 计算，避免矮窗口里 48px 的删除按钮被压进 33px 的行。
const double _kChainEditorReferenceHeight = 800.0;

/// 「配置学习计划」页面。
///
/// [initial] 为空表示新建周期；否则在现有计划上调整（保留 id 以外的配置）。
class PlanConfigPage extends StatefulWidget {
  /// 现有计划；为空时使用默认值（截止日期 = 今天 + 7 天、每组 10 词）。
  final StudyPlan? initial;

  const PlanConfigPage({super.key, this.initial});

  @override
  State<PlanConfigPage> createState() => _PlanConfigPageState();
}

class _PlanConfigPageState extends State<PlanConfigPage> {
  late DateTime _deadline;
  late List<PlanScopeRef> _scope;
  late int _groupSize;
  late List<int> _sections;
  late bool _shuffleWithinSection;
  late bool _shuffleClasses;
  late bool _streakGate;

  bool _fsrsEnabled = false;
  bool _saving = false;
  bool _addMenuOpen = false;

  bool _deadlineError = false;
  bool _scopeError = false;
  bool _chainError = false;

  /// 缓存范围统计，避免在 build 里对大词库反复做 O(词 × 卡片) 的查询。
  int _scopeWords = 0;
  int _unlearnedWords = 0;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    final StudyPlan? initial = widget.initial;
    _deadline = initial?.deadline ??
        DateTime(now.year, now.month, now.day + 7);
    _scope = List<PlanScopeRef>.of(
      initial?.scope ?? const <PlanScopeRef>[],
    );
    _groupSize = initial?.groupSize ?? 10;
    _sections = List<int>.of(initial?.chain.sections ?? const <int>[0, 2]);
    _shuffleWithinSection = initial?.chain.shuffleWithinSection ?? false;
    _shuffleClasses = initial?.shuffleClasses ?? false;
    _streakGate = initial?.streakGate ?? false;
    _fsrsEnabled = _readFsrsEnabled();
    _recountScope();
  }

  bool _readFsrsEnabled() {
    final FSRS fsrs = FSRS();
    return fsrs.inited && fsrs.config.enabled;
  }

  StudyPlan _draftPlan() {
    return StudyPlan(
      id: widget.initial?.id ?? "draft",
      deadline: _deadline,
      scope: _scope,
      groupSize: _groupSize,
      chain: PlanChain(
        sections: List<int>.unmodifiable(_sections),
        shuffleWithinSection: _shuffleWithinSection,
      ),
      shuffleClasses: _shuffleClasses,
      streakGate: _streakGate,
      configuredDayKey: dayKeyOf(DateTime.now()),
    );
  }

  /// 按当前范围重算「共 N 词 / 可学 K 词」。
  void _recountScope() {
    final StudyPlan draft = _draftPlan();
    _scopeWords = resolveScopeWords(draft, AppData().wordData).length;
    _unlearnedWords =
        unlearnedScopeWords(draft, AppData().wordData, FSRS()).length;
  }

  // ---------------------------------------------------------------------------
  // 交互
  // ---------------------------------------------------------------------------

  Future<void> _openFsrsSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            const ForeFSRSSettingPage(forceChoosing: true),
      ),
    );
    if (!mounted) return;
    setState(() {
      _fsrsEnabled = _readFsrsEnabled();
      _recountScope();
    });
  }

  Future<void> _pickDeadline() async {
    final DateTime now = DateTime.now();
    final DateTime first = DateTime(now.year, now.month, now.day + 1);
    final DateTime last = DateTime(now.year, now.month, now.day + 365);
    DateTime initialDate = _deadline;
    if (initialDate.isBefore(first)) initialDate = first;
    if (initialDate.isAfter(last)) initialDate = last;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: first,
      lastDate: last,
      helpText: "选择截止日期",
    );
    if (picked == null || !mounted) return;
    setState(() {
      _deadline = DateTime(picked.year, picked.month, picked.day);
      _deadlineError = false;
    });
  }

  Future<void> _pickCourses() async {
    final ClassSelection selection = await popSelectClasses(
      context,
      withCache: false,
      withReviewChoose: false,
      withCategoryFilter: false,
    );
    if (!mounted || selection.selectedClass.isEmpty) return;
    final List<PlanScopeRef> added = <PlanScopeRef>[
      for (final ClassItem course in selection.selectedClass) _refFor(course),
    ];
    setState(() {
      for (final PlanScopeRef ref in added) {
        if (ref.sourceFile.isEmpty && ref.className.isEmpty) continue;
        if (!_scope.any((PlanScopeRef existing) => existing.key == ref.key)) {
          _scope.add(ref);
        }
      }
      _scopeError = false;
      _recountScope();
    });
  }

  /// 把课程选择页返回的 [ClassItem] 映射为「词库文件名 + 课程名」。
  ///
  /// 映射规则集中在 [scopeRefForClass]；完全找不到时退回只带课程名的引用，
  /// 由保存校验的「可学词 > 0」兜底拦截。
  PlanScopeRef _refFor(ClassItem course) {
    return scopeRefForClass(AppData().wordData, course) ??
        PlanScopeRef(sourceFile: "", className: course.className);
  }

  ClassItem? _findCourse(PlanScopeRef ref) {
    for (final SourceItem source in AppData().wordData.classes) {
      if (source.sourceJsonFileName != ref.sourceFile) continue;
      for (final ClassItem course in source.subClasses) {
        if (course.className == ref.className) return course;
      }
    }
    return null;
  }

  void _removeScopeAt(int index) {
    setState(() {
      _scope.removeAt(index);
      _scopeError = false;
      _recountScope();
    });
  }

  void _addType(int type) {
    setState(() {
      _sections.add(type);
      _chainError = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final bool fsrsReady = _readFsrsEnabled();
    final bool deadlineOk = daysLeft(DateTime.now(), _deadline) > 0;
    final bool scopeOk = _scope.isNotEmpty && _unlearnedWords > 0;
    final bool chainOk = PlanChain(sections: _sections).isValid;
    setState(() {
      _fsrsEnabled = fsrsReady;
      _deadlineError = !deadlineOk;
      _scopeError = !scopeOk;
      _chainError = !chainOk;
    });
    if (!fsrsReady) {
      showSnackBar(context, "请先启用复习系统");
      return;
    }
    if (!deadlineOk || !scopeOk || !chainOk) {
      showSnackBar(context, "请先补全标红的配置项");
      return;
    }

    setState(() {
      _saving = true;
    });
    final StudyPlan plan = StudyPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deadline: _deadline,
      scope: _scope,
      groupSize: _groupSize,
      chain: PlanChain(
        sections: List<int>.unmodifiable(_sections),
        shuffleWithinSection: _shuffleWithinSection,
      ),
      shuffleClasses: _shuffleClasses,
      streakGate: _streakGate,
      configuredDayKey: dayKeyOf(DateTime.now()),
    );
    try {
      await PlanStore().setPlan(plan);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      showSnackBar(context, "保存失败，请稍后重试");
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  // ---------------------------------------------------------------------------
  // 页面
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("配置学习计划")),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth > AppBreakpoints.mobile;
            final double horizontal = wide ? AppSpacing.md : AppSpacing.sm;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                AppSpacing.sm,
                horizontal,
                AppSpacing.md,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (!_fsrsEnabled) ...<Widget>[
                        _buildFsrsBlocker(context),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      _buildPeriodSection(context),
                      const SizedBox(height: AppSpacing.sm),
                      _buildScopeSection(context),
                      const SizedBox(height: AppSpacing.sm),
                      _buildRegularSection(context),
                      const SizedBox(height: AppSpacing.xs),
                      _buildPreview(context),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
      backgroundColor: scheme.surface,
    );
  }

  Widget _buildFsrsBlocker(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color warning = context.semanticColors.warning;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          warning.withValues(alpha: 0.10),
          scheme.surfaceContainerLow,
        ),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: warning.withValues(alpha: 0.40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.history_edu_outlined, size: 20.0, color: warning),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  "复习系统未启用",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            "计划进度以复习系统的已学记录为准，启用后才能保存计划。",
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openFsrsSettings,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18.0),
              label: const Text("前往复习设置"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSection(BuildContext context) {
    return _ConfigSection(
      title: "周期",
      children: <Widget>[
        _buildDeadlineRow(context),
      ],
    );
  }

  Widget _buildDeadlineRow(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: AppRadius.controlBorder,
          child: InkWell(
            borderRadius: AppRadius.controlBorder,
            onTap: _pickDeadline,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 10.0,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.event_outlined,
                    size: 20.0,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text("截止日期", style: theme.textTheme.bodyLarge),
                        Text(
                          "截止日期不含当日，最后学习日为截止日前一天",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    planMonthDay(_deadline),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20.0,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_deadlineError)
          _errorText(context, "截止日期需晚于今天"),
      ],
    );
  }

  Widget _buildScopeSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String summary = !_fsrsEnabled
        ? "共 $_scopeWords 词 · 复习系统未启用"
        : "共 $_scopeWords 词 · 已学 ${math.max(0, _scopeWords - _unlearnedWords)} · 可学 $_unlearnedWords";
    return _ConfigSection(
      title: "学习范围",
      children: <Widget>[
        if (_scope.isEmpty)
          Text(
            "尚未选择课程。计划会按所选课程的顺序依次学习。",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8.0,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (int index = 0; index < _scope.length; index++)
                _ScopeChip(
                  label: _scope[index].className.isEmpty
                      ? "未命名课程"
                      : _scope[index].className,
                  sourceFile: _scope[index].sourceFile,
                  valid: _findCourse(_scope[index]) != null,
                  onRemove: () => _removeScopeAt(index),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _pickCourses,
              icon: const Icon(Icons.add_rounded, size: 18.0),
              label: const Text("选择课程"),
            ),
          ],
        ),
        if (_scopeError)
          _errorText(context, "请选择至少一门还有未学单词的课程"),
      ],
    );
  }

  Widget _buildRegularSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return _ConfigSection(
      title: "常规",
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text("单组数量", style: theme.textTheme.bodyLarge),
                  Text(
                    "每组 $_groupSize 词",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _CountStepper(
              value: _groupSize,
              min: 1,
              max: 50,
              onChanged: (int value) {
                setState(() {
                  _groupSize = value;
                });
              },
            ),
          ],
        ),
        const Divider(height: AppSpacing.md),
        Text(
          "学习链条",
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          "按顺序完成下列题型；至少包含 1 个非单词卡片题型；计划学习不使用自我评级题目。",
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _buildChainEditor(context),
        if (_chainError)
          _errorText(context, "学习链条至少需要包含 1 个非单词卡片题型"),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _addMenuOpen = !_addMenuOpen;
              });
            },
            icon: Icon(
              _addMenuOpen
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.add_rounded,
              size: 18.0,
            ),
            label: Text(_addMenuOpen ? "收起题型" : "添加题型"),
          ),
        ),
        _buildAddMenu(context),
        const Divider(height: AppSpacing.md),
        _SwitchRow(
          title: "组内单词乱序",
          description: "开启后同一组单词按随机顺序出现",
          value: _shuffleWithinSection,
          onChanged: (bool value) {
            setState(() {
              _shuffleWithinSection = value;
            });
          },
        ),
        const Divider(height: AppSpacing.md),
        _SwitchRow(
          title: "打乱课程顺序",
          description: "只打乱课程顺序，不影响组内单词顺序",
          value: _shuffleClasses,
          onChanged: (bool value) {
            setState(() {
              _shuffleClasses = value;
            });
          },
        ),
        const Divider(height: AppSpacing.md),
        _SwitchRow(
          title: "介入连胜",
          description: "开启后，当日未完成最低目标前，任何学习都不会打卡",
          value: _streakGate,
          onChanged: (bool value) {
            setState(() {
              _streakGate = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildChainEditor(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double referenceHeight =
        math.max(media.size.height, _kChainEditorReferenceHeight);
    final double tileHeight = referenceHeight * 0.08;
    final double viewport = _sections.isEmpty
        ? 52.0
        : _sections.length * tileHeight + 2.0;
    return SizedBox(
      height: viewport,
      child: MediaQuery(
        data: media.copyWith(
          size: Size(media.size.width, referenceHeight),
        ),
        child: QuestionChainListView(
          sections: _sections,
          emptyHint: "还没有题型，点下面的「添加题型」开始配置",
          onReorder: (int oldIndex, int newIndex) {
            setState(() {
              final int type = _sections.removeAt(oldIndex);
              _sections.insert(newIndex.clamp(0, _sections.length), type);
              _chainError = false;
            });
          },
          onRemove: (int index) {
            setState(() {
              _sections.removeAt(index);
              _chainError = false;
            });
          },
        ),
      ),
    );
  }

  Widget _buildAddMenu(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double referenceHeight =
        math.max(media.size.height, _kChainEditorReferenceHeight);
    // 展开值固定为 1：QuestionTypeAddMenu 的按钮高度按 expandValue 线性缩放，
    // 中间值会让图标与文字挤进十几像素高的按钮里。这里改用高度裁剪 + 淡入
    // 完成同样的“展开”观感，控件尺寸始终稳定。
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: _addMenuOpen ? 1.0 : 0.0),
      duration: AppMotion.mediumShort,
      curve: AppMotion.standardCurve,
      builder: (BuildContext context, double value, Widget? child) {
        if (value <= 0.001) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topLeft,
            heightFactor: value,
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          ),
        );
      },
      child: Align(
        alignment: Alignment.centerLeft,
        child: MediaQuery(
          data: media.copyWith(
            size: Size(media.size.width, referenceHeight),
          ),
          child: QuestionTypeAddMenu(
            expandValue: 1.0,
            onAdd: _addType,
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color on = scheme.onPrimaryContainer;
    final int days = daysLeft(DateTime.now(), _deadline);
    final int daily = _fsrsEnabled && _unlearnedWords > 0 && days > 0
        ? computeDailyMin(
            remaining: _unlearnedWords,
            daysLeft: days,
            groupSize: _groupSize,
          )
        : 0;
    final int groups = daily <= 0 ? 0 : (daily / _groupSize).ceil();

    Widget body;
    if (!_fsrsEnabled) {
      body = Text(
        "启用复习系统后，这里会显示预计每日学习量。",
        style: theme.textTheme.bodyMedium?.copyWith(color: on),
      );
    } else if (_scope.isEmpty) {
      body = Text(
        "选择学习范围后，这里会显示预计每日学习量。",
        style: theme.textTheme.bodyMedium?.copyWith(color: on),
      );
    } else if (_unlearnedWords == 0) {
      body = Text(
        "范围内已无未学单词，请调整学习范围。",
        style: theme.textTheme.bodyMedium?.copyWith(color: on),
      );
    } else if (days <= 0) {
      body = Text(
        "截止日期需晚于今天，才能计算每日学习量。",
        style: theme.textTheme.bodyMedium?.copyWith(color: on),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            "剩余可学 $_unlearnedWords 词 · 剩余 $days 天",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: on.withValues(alpha: 0.80),
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            "预计每日至少 $daily 词（约 $groups 组）",
            style: theme.textTheme.titleLarge?.copyWith(
              color: on,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.insights_outlined,
                size: 18.0,
                color: on.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 6.0),
              Text(
                "学习节奏预览",
                style: theme.textTheme.labelLarge?.copyWith(
                  color: on.withValues(alpha: 0.80),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          body,
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          10.0,
          AppSpacing.sm,
          10.0,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
        ),
        // heightFactor: 1.0 让底栏只占内容高度；否则 Center 会撑满
        // bottomNavigationBar 可用的整个屏幕高度，把 body 压成 0 高。
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720.0),
            child: SizedBox(
              width: double.infinity,
              height: 52.0,
              child: Button(
                onPressed: (!_fsrsEnabled || _saving) ? null : _save,
                backgroundColor: scheme.primaryContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _saving ? "保存中…" : "保存计划",
                    maxLines: 1,
                    style: withoutColor(
                      theme.textTheme.titleMedium!,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorText(BuildContext context, String text) {
    final ThemeData theme = Theme.of(context);
    final Color error = theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1.0),
            child: Icon(Icons.info_outline_rounded, size: 14.0, color: error),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: error),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分组卡片：标题 + 内容，统一 25 圆角与低层容器色。
class _ConfigSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ConfigSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 2.0, bottom: AppSpacing.xs),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// 已选课程标签：失效课程用错误色标记，仍可手动移除。
class _ScopeChip extends StatelessWidget {
  final String label;
  final String sourceFile;
  final bool valid;
  final VoidCallback onRemove;

  const _ScopeChip({
    required this.label,
    required this.sourceFile,
    required this.valid,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color foreground =
        valid ? scheme.onSecondaryContainer : scheme.error;
    final Color background = valid
        ? scheme.secondaryContainer
        : scheme.error.withValues(alpha: 0.10);
    return Tooltip(
      message: sourceFile.isEmpty ? label : "$sourceFile · $label",
      child: Container(
        padding: const EdgeInsets.only(left: 12.0, right: 2.0),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: valid
              ? null
              : Border.all(color: scheme.error.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!valid)
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 14.0,
                  color: scheme.error,
                ),
              ),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: foreground,
                ),
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 16.0),
              color: foreground,
              tooltip: "移除 $label",
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32.0,
                minHeight: 32.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单组数量步进器（1..50）。
class _CountStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _CountStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.controlBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _stepButton(
            context,
            icon: Icons.remove_rounded,
            enabled: value > min,
            onTap: () => onChanged(value - 1),
          ),
          SizedBox(
            width: 40.0,
            child: Text(
              "$value",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _stepButton(
            context,
            icon: Icons.add_rounded,
            enabled: value < max,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }

  Widget _stepButton(
    BuildContext context, {
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 19.0),
      color: scheme.primary,
      disabledColor: scheme.onSurface.withValues(alpha: 0.30),
      tooltip: icon == Icons.add_rounded ? "增加" : "减少",
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40.0, minHeight: 40.0),
      padding: EdgeInsets.zero,
    );
  }
}

/// 开关行：标题 + 说明 + Switch。
class _SwitchRow extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 2.0),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
