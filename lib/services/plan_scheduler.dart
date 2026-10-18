// 「计划学习」调度逻辑：日期计算、范围解析、每日最低量、当日状态评估与连胜门禁。
//
// 纯逻辑、无 UI。范围解析一律走 `wordData.classes` 中的
// 「词库文件名 + 课程名」，不依赖任何已持久化的 word id。

import 'dart:async' show unawaited;
import 'dart:math' show Random;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:fsrs/fsrs.dart' show Card;
import 'package:logging/logging.dart';

import 'package:arabic_learning/core/extensions.dart' show StringExtensions;
import 'package:arabic_learning/models/dict.dart'
    show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/models/plan.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/plan_store.dart';

final Logger _logger = Logger("Plan");

/// 日期键：yyyyMMdd。
int dayKeyOf(DateTime t) => t.year * 10000 + t.month * 100 + t.day;

/// 剩余天数（按日历日相减，可为负）。明天 = 1、今天 = 0、昨天 = -1。
///
/// 统一用 UTC 零点做差：本地零点在夏令时切换日可能相差 23/25 小时，
/// 直接用 `inDays` 会把整天数截断掉 1 天。
int daysLeft(DateTime today, DateTime deadline) {
  final DateTime todayDate = DateTime.utc(today.year, today.month, today.day);
  final DateTime deadlineDate =
      DateTime.utc(deadline.year, deadline.month, deadline.day);
  return deadlineDate.difference(todayDate).inDays;
}

/// 计划范围内、且当前词库仍能解析到的课程引用（按 scope 顺序去重）。
List<PlanScopeRef> activeScopeRefs(StudyPlan plan) {
  return _activeRefs(plan, _currentWordData());
}

/// 由课程选择页返回的 [ClassItem] 构造范围引用。
///
/// 优先按实例定位所属词库（不同词库可能有同名课程）；实例匹配失败时
/// 退回「课程名 + 相同下标列表」。词库中完全找不到时返回 null。
PlanScopeRef? scopeRefForClass(DictData wordData, ClassItem course) {
  for (final SourceItem source in wordData.classes) {
    for (final ClassItem candidate in source.subClasses) {
      if (identical(candidate, course) || candidate == course) {
        return PlanScopeRef(
          sourceFile: source.sourceJsonFileName,
          className: candidate.className,
        );
      }
    }
  }
  for (final SourceItem source in wordData.classes) {
    for (final ClassItem candidate in source.subClasses) {
      if (candidate.className == course.className &&
          listEquals(candidate.wordIndexs, course.wordIndexs)) {
        return PlanScopeRef(
          sourceFile: source.sourceJsonFileName,
          className: candidate.className,
        );
      }
    }
  }
  return null;
}

/// 按 scope 顺序拼接各课程单词，并按 `arabic.identityKey()` 去重。
List<WordItem> resolveScopeWords(StudyPlan plan, DictData wordData) {
  final List<WordItem> result = <WordItem>[];
  final Set<String> seen = <String>{};
  for (final PlanScopeRef ref in _activeRefs(plan, wordData)) {
    final ClassItem? course = _findCourse(wordData, ref);
    if (course == null) continue;
    for (final int index in course.wordIndexs) {
      if (index < 0 || index >= wordData.words.length) continue;
      final WordItem word = wordData.words[index];
      if (seen.add(word.arabic.identityKey())) result.add(word);
    }
  }
  return result;
}

/// 范围内尚未进入 FSRS 的单词（按 scope 顺序、词形去重）。
///
/// FSRS 未 init 时视为「全部未学」，保证调用安全。
List<WordItem> unlearnedScopeWords(
  StudyPlan plan,
  DictData wordData,
  FSRS fsrs,
) {
  final Set<int> learned = _learnedCardIds(fsrs);
  return resolveScopeWords(plan, wordData)
      .where((WordItem word) => !learned.contains(word.id))
      .toList(growable: false);
}

/// 已进入 FSRS 的词 id 集合。
///
/// 先建集合再过滤，避免 `isContained` 的线性查找在大词库下退化成
/// `O(范围内词数 × 卡片数)`（每答一题都会被连胜门禁调用）。
Set<int> _learnedCardIds(FSRS fsrs) {
  if (!fsrs.inited) return const <int>{};
  return <int>{for (final Card card in fsrs.config.cards) card.cardId};
}

/// 每日最低量：
/// - 剩余 <= 0 时为 0；
/// - 剩余天数不足 1 天时按 1 天计（今天必须学完）；
/// - 按整组向上取整：`ceil(remaining / (days * groupSize)) * groupSize`，
///   最后再以剩余量封顶（不足一组时就是剩余全部）。
int computeDailyMin({
  required int remaining,
  required int daysLeft,
  required int groupSize,
}) {
  if (remaining <= 0) return 0;
  final int size = groupSize < 1 ? 1 : groupSize;
  final int days = daysLeft < 1 ? 1 : daysLeft;
  final int groups = (remaining / (days * size)).ceil();
  final int min = groups * size;
  return min < remaining ? min : remaining;
}

/// 某一时刻的计划学习状态快照。
class PlanStatus {
  /// 评估当天日期键
  final int dayKey;

  /// 范围内单词总数（按词形去重）
  final int scopeWords;

  /// 范围内已进入 FSRS 的单词数
  final int learnedWords;

  /// 范围内尚未学习的单词数
  final int remainingWords;

  /// 剩余天数（可为负）
  final int daysLeft;

  /// 每组单词数
  final int groupSize;

  /// 当日最低量（当天快照）
  final int minWords;

  /// 当日已完成量（当天快照）
  final int doneWords;

  /// 周期完成：范围非空且剩余为 0
  final bool cycleComplete;

  /// 已逾期：仍有剩余但剩余天数 <= 0
  final bool overdue;

  /// 范围失效：计划内课程在当前词库中全部无法解析
  final bool invalidScope;

  /// FSRS 未启用（或未初始化）
  final bool fsrsDisabled;

  const PlanStatus({
    required this.dayKey,
    required this.scopeWords,
    required this.learnedWords,
    required this.remainingWords,
    required this.daysLeft,
    required this.groupSize,
    required this.minWords,
    required this.doneWords,
    required this.cycleComplete,
    required this.overdue,
    required this.invalidScope,
    required this.fsrsDisabled,
  });

  /// 今日需要完成的分组数。
  int get groupsToday => groupSize < 1 ? 0 : (minWords / groupSize).ceil();

  /// 今日还差多少词达标。
  int get todayRemaining {
    final int left = minWords - doneWords;
    return left > 0 ? left : 0;
  }

  /// 今日完成比例（最低量为 0 时为 0）。
  double get todayProgress => minWords == 0 ? 0 : doneWords / minWords;
}

/// 评估当前计划状态；若当日快照缺失或日期变化，按 [computeDailyMin] 重建并持久化。
PlanStatus evaluateNow({DateTime? now}) {
  final DateTime time = now ?? DateTime.now();
  final int todayKey = dayKeyOf(time);
  final FSRS fsrs = FSRS();
  final bool fsrsEnabled = fsrs.inited && fsrs.config.enabled;
  final StudyPlan? plan = PlanStore().state.plan;

  if (plan == null) {
    return PlanStatus(
      dayKey: todayKey,
      scopeWords: 0,
      learnedWords: 0,
      remainingWords: 0,
      daysLeft: 0,
      groupSize: 0,
      minWords: 0,
      doneWords: 0,
      cycleComplete: false,
      overdue: false,
      invalidScope: true,
      fsrsDisabled: !fsrsEnabled,
    );
  }

  final DictData wordData = _currentWordData();
  final List<PlanScopeRef> refs = _activeRefs(plan, wordData);
  // 范围只解析一次：既用于总数，也用于未学统计。
  final List<WordItem> scope = resolveScopeWords(plan, wordData);
  final Set<int> learned = _learnedCardIds(fsrs);
  final int scopeWords = scope.length;
  final int remainingWords =
      scope.where((WordItem word) => !learned.contains(word.id)).length;
  final int left = daysLeft(time, plan.deadline);
  final int minWords = computeDailyMin(
    remaining: remainingWords,
    daysLeft: left,
    groupSize: plan.groupSize,
  );

  // 当日快照：仅缺失或跨日时重建，当天内不再随剩余量变化而抬高最低量。
  PlanDayProgress? today = PlanStore().state.today;
  if (today == null || today.dayKey != todayKey) {
    final PlanDayProgress created = PlanDayProgress(
      dayKey: todayKey,
      minWords: minWords,
      doneWords: 0,
    );
    today = created;
    unawaited(PlanStore().setToday(created));
  }

  return PlanStatus(
    dayKey: todayKey,
    scopeWords: scopeWords,
    learnedWords: scopeWords - remainingWords,
    remainingWords: remainingWords,
    daysLeft: left,
    groupSize: plan.groupSize,
    minWords: today.minWords,
    doneWords: today.doneWords,
    cycleComplete: scopeWords > 0 && remainingWords == 0,
    overdue: remainingWords > 0 && left <= 0,
    invalidScope: refs.isEmpty,
    fsrsDisabled: !fsrsEnabled,
  );
}

/// 顺延截止日期，并保留当日已完成量。
///
/// 延期后按新的剩余天数重算最低量；当日快照属于今天时恢复其 `doneWords`，
/// 避免「逾期一键延期」让用户当天已学的词白做。
Future<void> extendPlanDeadline(int days, {DateTime? now}) async {
  if (days <= 0) return;
  final PlanStore store = PlanStore();
  final StudyPlan? plan = store.state.plan;
  if (plan == null) return;

  final DateTime time = now ?? DateTime.now();
  final PlanDayProgress? today = store.state.today;
  final DateTime moved = DateTime(
    plan.deadline.year,
    plan.deadline.month,
    plan.deadline.day + days,
  );
  final StudyPlan updated = plan.copyWith(deadline: moved);
  await store.setPlan(updated);

  final int minWords = computeDailyMin(
    remaining: unlearnedScopeWords(updated, _currentWordData(), FSRS()).length,
    daysLeft: daysLeft(time, moved),
    groupSize: updated.groupSize,
  );
  final int doneWords =
      today != null && today.dayKey == dayKeyOf(time) ? today.doneWords : 0;
  await store.setToday(PlanDayProgress(
    dayKey: dayKeyOf(time),
    minWords: minWords,
    doneWords: doneWords,
  ));
  _logger.info("计划截止日期顺延 $days 天，今日最低量重算为 $minWords");
}

/// 下一次会话要学习的单词：按课程分组，取前 `groupSize` 个。
///
/// [StudyPlan.shuffleClasses] 为真时用当天日期种子打乱**课程顺序**（同一天稳定），
/// 组内单词保持原顺序。范围失效或 FSRS 未启用时返回空列表。
List<WordItem> nextGroupWords({DateTime? now}) {
  final DateTime time = now ?? DateTime.now();
  final StudyPlan? plan = PlanStore().state.plan;
  if (plan == null) return const <WordItem>[];
  final FSRS fsrs = FSRS();
  if (!fsrs.inited || !fsrs.config.enabled) return const <WordItem>[];

  final DictData wordData = _currentWordData();
  final List<PlanScopeRef> refs = _activeRefs(plan, wordData);
  if (refs.isEmpty) return const <WordItem>[];

  // 以「未学词 id」作为分组过滤条件，保证与 [resolveScopeWords] 的词形去重一致。
  final Map<int, WordItem> allowed = <int, WordItem>{
    for (final WordItem word in unlearnedScopeWords(plan, wordData, fsrs))
      word.id: word,
  };
  if (allowed.isEmpty) return const <WordItem>[];

  if (plan.shuffleClasses) {
    // 复制后再打乱，避免修改作用域引用列表。
    refs.shuffle(Random(dayKeyOf(time)));
  }

  final List<WordItem> result = <WordItem>[];
  for (final PlanScopeRef ref in refs) {
    final ClassItem? course = _findCourse(wordData, ref);
    if (course == null) continue;
    for (final int index in course.wordIndexs) {
      final WordItem? word = allowed[index];
      if (word == null) continue;
      result.add(word);
      if (result.length >= plan.groupSize) return result; // 组内保持原顺序
    }
  }
  return result;
}

/// 连胜门禁：计划学习当日最低量未达标时返回 true（调用方应跳过连胜记录）。
///
/// 只在计划已加载、开启 [StudyPlan.streakGate]、FSRS 已启用、范围有效且周期
/// 未完成 / 未逾期时生效。任何异常一律返回 false，绝不影响既有连胜逻辑。
bool planBlocksStreak() {
  try {
    final PlanStore store = PlanStore();
    if (!store.inited) return false;
    final StudyPlan? plan = store.state.plan;
    if (plan == null || !plan.streakGate) return false;
    final FSRS fsrs = FSRS();
    if (!fsrs.inited || !fsrs.config.enabled) return false;
    final PlanStatus status = evaluateNow();
    if (status.invalidScope || status.cycleComplete || status.overdue) {
      return false;
    }
    return status.doneWords < status.minWords;
  } catch (e) {
    _logger.severe("连胜门禁判定失败: $e");
    return false;
  }
}

/// 当前词库数据；AppData 尚未完成初始化时回退为空词库，避免抛异常。
DictData _currentWordData() {
  try {
    return AppData().wordData;
  } catch (_) {
    return const DictData(words: <WordItem>[], classes: <SourceItem>[]);
  }
}

/// 解析到当前词库的课程引用（去重、保持 scope 顺序）。
List<PlanScopeRef> _activeRefs(StudyPlan plan, DictData wordData) {
  final List<PlanScopeRef> refs = <PlanScopeRef>[];
  final Set<String> seen = <String>{};
  for (final PlanScopeRef ref in plan.scope) {
    if (!seen.add(ref.key)) continue;
    if (_findCourse(wordData, ref) == null) continue;
    refs.add(ref);
  }
  return refs;
}

/// 按「词库文件名 + 课程名」查找课程。
ClassItem? _findCourse(DictData wordData, PlanScopeRef ref) {
  for (final SourceItem source in wordData.classes) {
    if (source.sourceJsonFileName != ref.sourceFile) continue;
    for (final ClassItem course in source.subClasses) {
      if (course.className == ref.className) return course;
    }
  }
  return null;
}
