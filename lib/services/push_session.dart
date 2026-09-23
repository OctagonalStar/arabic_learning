import 'dart:convert';
import 'dart:math';

import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/words.dart';

/// 每日推送的日期键（yyyyMMdd），与推送选词的随机种子保持一致。
int pushDayKey(DateTime t) => t.year * 10000 + t.month * 100 + t.day;

/// 每日推送断点：记录当天推送会话的导航位置。
class PushCheckpoint {
  final int day;        // pushDayKey
  final int phase;      // 0=卡片阶段, 1=答题阶段
  final int wordId;     // 当前单词 id（锚点）
  final int wordCount;  // 生成时的词库规模，用于失效判断

  const PushCheckpoint({required this.day, required this.phase, required this.wordId, required this.wordCount});

  Map<String, dynamic> toMap() => {'day': day, 'phase': phase, 'wordId': wordId, 'wordCount': wordCount};

  /// 解析；字段缺失/类型异常返回 null（视为无断点）。
  static PushCheckpoint? fromMap(Map<String, dynamic> m) {
    final dynamic d = m['day'], p = m['phase'], w = m['wordId'], c = m['wordCount'];
    if (d is! int || p is! int || w is! int || c is! int) return null;
    return PushCheckpoint(day: d, phase: p, wordId: w, wordCount: c);
  }
}

/// 每日推送断点的持久化（存储键 pushSessionData；已加入 usedKeys 以便备份）。
class PushSessionStore {
  static const String key = "pushSessionData";

  static PushCheckpoint? load() {
    final String? raw = AppData().storage.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PushCheckpoint.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(PushCheckpoint checkpoint) =>
      AppData().storage.setString(key, jsonEncode(checkpoint.toMap()));

  static Future<void> clear() => AppData().storage.setString(key, "");
}

/// 每日推送计划：本次实际要学习的单词，以及候选池是否为空。
class DailyPushPlan {
  final List<WordItem> words;
  final bool noCandidates;
  const DailyPushPlan({required this.words, required this.noCandidates});
}

/// 按当天日期种子生成每日推送单词（与原有按钮逻辑完全一致）。
/// 返回的 [DailyPushPlan.words] 已剔除已加入 FSRS 的单词。
DailyPushPlan buildDailyPushPlan({required DateTime now, required FSRS fsrs, required DictData wordData}) {
  final Set<String> selectedCategories = fsrs.config.pushCategories.toSet();
  List<int> candidateIndexes = List<int>.generate(wordData.words.length, (int index) => index);
  if (selectedCategories.isNotEmpty) {
    candidateIndexes = candidateIndexes
        .where((int index) => wordMatchesCategories(wordData.words[index], selectedCategories))
        .toList();
  }
  if (candidateIndexes.isEmpty) {
    return const DailyPushPlan(words: <WordItem>[], noCandidates: true);
  }
  final int seed = pushDayKey(now);
  final Set<WordItem> pushWords = {};
  final Random rnd = Random(seed);
  int tries = 0;
  while (pushWords.length < fsrs.config.pushAmount && tries < fsrs.config.pushAmount * 10) {
    final int chosen = candidateIndexes[rnd.nextInt(candidateIndexes.length)];
    final DateTime? cardBirthday = fsrs.getCardBirthday(chosen);
    if (cardBirthday == null || cardBirthday.difference(now).inDays == 0) {
      pushWords.add(wordData.words.elementAt(chosen));
    }
    tries++;
  }
  pushWords.removeWhere((WordItem item) => fsrs.isContained(item.id));
  return DailyPushPlan(words: pushWords.toList(), noCandidates: false);
}
