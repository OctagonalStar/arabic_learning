// 「计划学习」配置页：截止日期、学习范围（课程 + 标签）、每组数量、
// 学习链条与三个开关。
//
// 保存前做完整校验（范围非空且有可学词、链条合法、截止日期晚于今天、
// 复习系统已启用），保存成功后 `pop(true)` 交由首页刷新。
//
// 版式与设置页一致：分组标题 + `SettingItem` / `SettingRow`，行内需要点击
// 时用 `InkWell` 包住；课程与标签使用 Material `InputChip`，题型使用常驻
// `ActionChip`，单组数量使用 Material `Slider`。

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
import 'package:arabic_learning/screens/setting/dict_manage_page.dart'
    show DictManagePage;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS;
import 'package:arabic_learning/services/plan_scheduler.dart';
import 'package:arabic_learning/services/plan_store.dart';
import 'package:arabic_learning/theme/tokens.dart';
import 'package:arabic_learning/theme/typography.dart' show withoutColor;
import 'package:arabic_learning/widgets/kit.dart'
    show Button, SettingItem, SettingRow, popSelectClasses;
import 'package:arabic_learning/widgets/overlays.dart' show showSnackBar;
import 'package:arabic_learning/widgets/question_chain_editor.dart'
    show QuestionChainListView, kQuestionTypeLabels;

/// 题型链条的列表与添加按钮都按 `MediaQuery.size.height` 计算行高；
/// 高度不足时统一按 800 计算，避免矮窗口里 48px 的删除按钮被压进 33px 的行。
const double _kChainEditorReferenceHeight = 800.0;

/// 单组数量允许范围（与 Slider 的 min / max / divisions 保持一致）。
const int _kGroupSizeMin = 5;
const int _kGroupSizeMax = 30;
const int _kGroupSizeDivisions = _kGroupSizeMax - _kGroupSizeMin;

/// 可选题型（与 `kQuestionTypeLabels` 的键一致）。
const List<int> _kQuestionTypes = <int>[0, 1, 2, 3];

/// 题型编号 → 添加 chip 的图标。
const Map<int, IconData> _kQuestionTypeIcons = <int, IconData>{
  0: Icons.style_outlined,
  1: Icons.translate,
  2: Icons.abc,
  3: Icons.keyboard_outlined,
};

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
  late List<String> _categories;
  late int _groupSize;
  late List<int> _sections;
  late bool _shuffleWithinSection;
  late bool _shuffleClasses;
  late bool _streakGate;

  bool _fsrsEnabled = false;
  bool _saving = false;

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
    _categories = List<String>.of(
      initial?.categories ?? const <String>[],
    );
    // 旧计划的 groupSize 可能不在 5..30 内：统一夹到 Slider 区间，
    // 显示与保存都用夹紧后的值，避免滑块与文案对不上。
    _groupSize = math.min(
      _kGroupSizeMax,
      math.max(_kGroupSizeMin, initial?.groupSize ?? 10),
    );
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
      categories: _categories,
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

  /// 按当前范围与标签重算「共 N 词 / 可学 K 词」。
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
    // 提前取出 NavigatorState：onImportDict 在弹窗关闭后才执行，届时
    // 直接用 State.context 可能已失效。
    final NavigatorState navigator = Navigator.of(context);
    final ClassSelection selection = await popSelectClasses(
      context,
      withCache: false,
      withReviewChoose: false,
      // 与常规学习一致的标签筛选（多选，或逻辑）。
      withCategoryFilter: true,
      onImportDict: () => navigator.push(
        MaterialPageRoute(builder: (BuildContext context) => const DictManagePage()),
      ),
    );
    if (!mounted) return;
    final List<ClassItem> pickedClasses = selection.selectedClass;
    final Set<String> pickedCategories = selection.selectedCategories;
    setState(() {
      for (final ClassItem course in pickedClasses) {
        final PlanScopeRef ref = _refFor(course);
        if (ref.sourceFile.isEmpty && ref.className.isEmpty) continue;
        if (!_scope.any((PlanScopeRef existing) => existing.key == ref.key)) {
          _scope.add(ref);
        }
      }
      // 重选课程时筛选区默认为空：只有在用户明确勾选标签时才替换，
      // 避免「只想换课程」却把已有标签清空。
      if (pickedCategories.isNotEmpty) {
        _categories = List<String>.of(pickedCategories);
      }
      if (pickedClasses.isNotEmpty) _scopeError = false;
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

  void _removeCategory(String category) {
    setState(() {
      _categories = List<String>.of(_categories)..remove(category);
      _recountScope();
    });
  }

  void _clearCategories() {
    setState(() {
      _categories = <String>[];
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
    // 标签筛选把范围过滤到 0 词时给出更准确的提示。
    if (_scope.isNotEmpty && _unlearnedWords == 0 && _categories.isNotEmpty) {
      showSnackBar(context, "所选标签下没有可学单词");
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
      categories: _categories,
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
    final MediaQueryData media = MediaQuery.of(context);
    // `SettingItem` 的卡片宽度固定为屏幕宽度的 90%。宽屏下把内容区的
    // MediaQuery 宽度夹到 800，既能让卡片落在 720 的阅读宽度内，
    // 又不用修改设置页共用的组件。
    final double cappedWidth = math.min(media.size.width, 800.0);
    return Scaffold(
      appBar: AppBar(title: const Text("配置学习计划")),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide =
                constraints.maxWidth > AppBreakpoints.mobile;
            final double horizontal = wide ? AppSpacing.md : AppSpacing.sm;
            return MediaQuery(
              data: media.copyWith(
                size: Size(cappedWidth, media.size.height),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  AppSpacing.sm,
                  horizontal,
                  AppSpacing.md,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (!_fsrsEnabled) ...<Widget>[
                          _buildFsrsBlocker(context),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        _buildPeriodSection(context),
                        const SizedBox(height: AppSpacing.xs),
                        _buildScopeSection(context),
                        const SizedBox(height: AppSpacing.xs),
                        _buildRegularSection(context),
                        const SizedBox(height: AppSpacing.xs),
                        _buildPreview(context),
                      ],
                    ),
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return SettingItem(
      title: "周期",
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: AppRadius.controlBorder,
                onTap: _pickDeadline,
                child: SettingRow(
                  leading: "截止日期",
                  icon: Icons.event_outlined,
                  note: "截止日期不含当日，最后学习日为截止日前一天",
                  end: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
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
        ),
      ],
    );
  }

  Widget _buildScopeSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String summary = !_fsrsEnabled
        ? "共 $_scopeWords 词 · 复习系统未启用"
        : "共 $_scopeWords 词 · 已学 ${math.max(0, _scopeWords - _unlearnedWords)} · 可学 $_unlearnedWords";
    return SettingItem(
      title: "学习范围",
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      children: <Widget>[
        SettingRow(
          leading: "课程",
          icon: Icons.menu_book_outlined,
          note: summary,
          end: TextButton.icon(
            onPressed: _pickCourses,
            icon: const Icon(Icons.add_rounded, size: 18.0),
            label: const Text("选择课程"),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    _buildScopeChip(context, index),
                ],
              ),
            if (_scopeError)
              _errorText(
                context,
                // 课程本身有词、只是被标签过滤到 0 时，提示标签而不是课程。
                _categories.isNotEmpty &&
                        _scope.isNotEmpty &&
                        _unlearnedWords == 0
                    ? "所选标签下没有可学单词"
                    : "请选择至少一门还有未学单词的课程",
              ),
          ],
        ),
        SettingRow(
          leading: "标签筛选",
          icon: Icons.label_outline,
          note: _categories.isEmpty
              ? "未筛选 · 选课时可勾选标签"
              : "只学习命中任一标签的单词（多选，或逻辑）",
          end: _categories.isEmpty
              ? Text(
                  "未筛选",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : TextButton.icon(
                  onPressed: _clearCategories,
                  icon: const Icon(Icons.close_rounded, size: 18.0),
                  label: const Text("清除标签"),
                ),
        ),
        if (_categories.isNotEmpty)
          Wrap(
            spacing: 6.0,
            runSpacing: AppSpacing.xxs,
            children: <Widget>[
              for (final String category in _categories)
                InputChip(
                  key: ValueKey<String>("planCategory-$category"),
                  label: Text(category),
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                  backgroundColor: scheme.secondaryContainer,
                  side: BorderSide.none,
                  deleteIcon: Icon(
                    Icons.close_rounded,
                    size: 16.0,
                    color: scheme.onSecondaryContainer,
                  ),
                  onDeleted: () => _removeCategory(category),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
      ],
    );
  }

  /// 已选课程标签：失效课程用错误色标记，仍可手动移除。
  Widget _buildScopeChip(BuildContext context, int index) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final PlanScopeRef ref = _scope[index];
    final String label = ref.className.isEmpty ? "未命名课程" : ref.className;
    final bool valid = _findCourse(ref) != null;
    final Color foreground = valid ? scheme.onSecondaryContainer : scheme.error;
    return Tooltip(
      message: ref.sourceFile.isEmpty ? label : "${ref.sourceFile} · $label",
      child: InputChip(
        key: ValueKey<String>("planScope-${ref.key}"),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        avatar: valid
            ? null
            : Icon(
                Icons.error_outline_rounded,
                size: 16.0,
                color: scheme.error,
              ),
        labelStyle: theme.textTheme.labelMedium?.copyWith(color: foreground),
        backgroundColor: valid
            ? scheme.secondaryContainer
            : scheme.error.withValues(alpha: 0.10),
        side:
            valid ? BorderSide.none : BorderSide(color: scheme.error.withValues(alpha: 0.35)),
        deleteIcon: Icon(Icons.close_rounded, size: 16.0, color: foreground),
        onDeleted: () => _removeScopeAt(index),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildRegularSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return SettingItem(
      title: "常规",
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      children: <Widget>[
        SettingRow(
          leading: "单组数量",
          icon: Icons.view_agenda_outlined,
          note: "每组 $_groupSize 词 · 可设置 $_kGroupSizeMin–$_kGroupSizeMax 词",
          end: SizedBox(
            width: 180.0,
            child: Slider(
              key: const ValueKey<String>("planGroupSizeSlider"),
              value: _groupSize.toDouble(),
              min: _kGroupSizeMin.toDouble(),
              max: _kGroupSizeMax.toDouble(),
              divisions: _kGroupSizeDivisions,
              label: "$_groupSize 词",
              onChanged: (double value) {
                setState(() {
                  _groupSize = value.round();
                });
              },
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SettingRow(
              leading: "学习链条",
              icon: Icons.reorder,
              note: "按顺序完成下列题型；长按拖动排序；"
                  "至少包含 1 个非单词卡片题型；计划学习不使用自我评级题目。",
              end: Text(
                "${_sections.length} 个",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _buildChainEditor(context),
            if (_chainError)
              _errorText(context, "学习链条至少需要包含 1 个非单词卡片题型"),
            const SizedBox(height: AppSpacing.xs),
            Text(
              "添加题型",
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: 8.0,
              runSpacing: AppSpacing.xxs,
              children: <Widget>[
                for (final int type in _kQuestionTypes)
                  ActionChip(
                    key: ValueKey<String>("planAddType-$type"),
                    avatar: Icon(
                      _kQuestionTypeIcons[type] ?? Icons.add_rounded,
                      size: 18.0,
                    ),
                    label: Text(kQuestionTypeLabels[type] ?? "题型"),
                    onPressed: () => _addType(type),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
        SettingRow(
          leading: "组内单词乱序",
          icon: Icons.shuffle,
          note: "开启后同一组单词按随机顺序出现",
          end: Switch(
            value: _shuffleWithinSection,
            onChanged: (bool value) {
              setState(() {
                _shuffleWithinSection = value;
              });
            },
          ),
        ),
        SettingRow(
          leading: "打乱课程顺序",
          icon: Icons.swap_vert,
          note: "只打乱课程顺序，不影响组内单词顺序",
          end: Switch(
            value: _shuffleClasses,
            onChanged: (bool value) {
              setState(() {
                _shuffleClasses = value;
              });
            },
          ),
        ),
        SettingRow(
          leading: "介入连胜",
          icon: Icons.local_fire_department_outlined,
          note: "开启后，当日未完成最低目标前，任何学习都不会打卡",
          end: Switch(
            value: _streakGate,
            onChanged: (bool value) {
              setState(() {
                _streakGate = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChainEditor(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double referenceHeight =
        math.max(media.size.height, _kChainEditorReferenceHeight);
    final double tileHeight = referenceHeight * 0.08;
    // 空链条占位文案会随系统字号放大，固定 52 在 2 倍字号下会溢出。
    final double emptyViewport =
        math.max(52.0, media.textScaler.scale(16.0) * 2.4);
    final double viewport = _sections.isEmpty
        ? emptyViewport
        : _sections.length * tileHeight + 2.0;
    return SizedBox(
      height: viewport,
      child: MediaQuery(
        data: media.copyWith(
          size: Size(media.size.width, referenceHeight),
        ),
        child: QuestionChainListView(
          sections: _sections,
          emptyHint: "还没有题型，点下方的题型按钮开始配置",
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
