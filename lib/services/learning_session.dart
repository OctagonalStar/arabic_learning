// 常规学习会话暂存（"learningSessionData" 键，已加入 usedKeys 以便备份）。
//
// 常规学习的题目列表由「词表 × 题型 + 固定随机种子」生成，因此断点只需保存
// 种子、题型配置与当前剩余题目的原始索引；恢复时按同一配置重建后再按下标取题，
// 避免把整个题目/选项序列写入存储。单词本身以「阿语 + 中文」身份键保存，
// 词库重排（id 变化）后仍能解析回当前词条。

import 'dart:convert';
import 'dart:math' show max;

import 'package:arabic_learning/core/extensions.dart' show StringExtensions;
import 'package:arabic_learning/models/config.dart' show QuizConfig;
import 'package:arabic_learning/models/dict.dart' show DictData, WordItem;
import 'package:arabic_learning/services/app_data.dart' show AppData;

/// 常规学习的一次暂存断点。
class LearningSessionCheckpoint {
  /// 数据格式版本；不匹配视为无断点。
  static const int currentVersion = 1;

  /// 创建会话时使用的随机种子（保证重建的题目顺序一致）。
  final int seed;

  /// 参与本次学习的单词身份键（[wordKey]），顺序与创建会话时一致。
  final List<String> wordKeys;

  /// 创建会话时的题型配置快照；恢复时不受期间设置变更影响。
  final QuizConfig quiz;

  /// 作答后是否写入 FSRS。
  final bool countInReview;

  /// 剩余题目在「重建后的完整题目列表」中的原始索引（按出题顺序）。
  /// 听力题「跳过」会移除后续听力题，该状态由这份索引列表自然表达。
  final List<int> itemIndices;

  /// 下次继续时展示的题目下标；等于 [itemIndices] 长度表示进入结算页。
  final int pageIndex;

  /// 已答对题数（含暂存前已计入的单词卡片题）。
  final int correctCount;

  /// 已消耗的学习时长（秒，不含暂存期间）。
  final int elapsedSeconds;

  /// 暂存时刻（毫秒时间戳，仅用于日志/排查）。
  final int savedAtMillis;

  LearningSessionCheckpoint({
    required this.seed,
    required List<String> wordKeys,
    required this.quiz,
    required this.countInReview,
    required List<int> itemIndices,
    required this.pageIndex,
    required this.correctCount,
    required this.elapsedSeconds,
    required this.savedAtMillis,
  }) : wordKeys = List<String>.unmodifiable(wordKeys),
       itemIndices = List<int>.unmodifiable(itemIndices);

  /// 尚未完成的题数（结算页时为 0）。
  int get remaining => max(0, itemIndices.length - pageIndex);

  /// 单词身份键：阿语 + 中文，避免同形异义词在恢复时混淆。
  static String wordKey(WordItem word) => "${word.arabic}\u0000${word.chinese}";

  Map<String, dynamic> toMap() => <String, dynamic>{
    'v': currentVersion,
    'seed': seed,
    'words': wordKeys,
    'quiz': quiz.toMap(),
    'countInReview': countInReview,
    'items': itemIndices,
    'page': pageIndex,
    'correct': correctCount,
    'elapsed': elapsedSeconds,
    'savedAt': savedAtMillis,
  };

  /// 解析存储内容；字段缺失、类型异常或版本不符时返回 null。
  static LearningSessionCheckpoint? fromMap(Map<String, dynamic> map) {
    if (map['v'] != currentVersion) return null;
    final dynamic seed = map['seed'];
    final dynamic countInReview = map['countInReview'];
    final dynamic page = map['page'];
    final dynamic correct = map['correct'];
    final dynamic elapsed = map['elapsed'];
    final dynamic savedAt = map['savedAt'];
    if (seed is! int ||
        countInReview is! bool ||
        page is! int ||
        correct is! int ||
        elapsed is! int ||
        savedAt is! int) {
      return null;
    }
    if (correct < 0 || elapsed < 0 || page < 0) return null;

    final dynamic rawWords = map['words'];
    if (rawWords is! List) return null;
    final List<String> wordKeys = <String>[];
    for (final dynamic raw in rawWords) {
      if (raw is! String || raw.isEmpty) return null;
      wordKeys.add(raw);
    }
    if (wordKeys.isEmpty) return null;

    final dynamic rawItems = map['items'];
    if (rawItems is! List) return null;
    final List<int> itemIndices = <int>[];
    for (final dynamic raw in rawItems) {
      if (raw is! int || raw < 0) return null;
      itemIndices.add(raw);
    }
    if (itemIndices.isEmpty || page > itemIndices.length) return null;

    final dynamic rawQuiz = map['quiz'];
    if (rawQuiz is! Map) return null;
    final QuizConfig quiz;
    try {
      quiz = QuizConfig.buildFromMap(Map<String, dynamic>.from(rawQuiz));
    } catch (_) {
      return null;
    }

    return LearningSessionCheckpoint(
      seed: seed,
      wordKeys: wordKeys,
      quiz: quiz,
      countInReview: countInReview,
      itemIndices: itemIndices,
      pageIndex: page,
      correctCount: correct,
      elapsedSeconds: elapsed,
      savedAtMillis: savedAt,
    );
  }

  /// 把保存的单词身份键解析回当前词库中的词条。
  ///
  /// 优先按「阿语 + 中文」精确匹配；词条释义被补充/改写时回退到阿语身份键。
  /// 任一单词已不存在（词库删除/重置）则返回 null，调用方应丢弃断点。
  List<WordItem>? resolveWords(DictData data) {
    final Map<String, WordItem> byExact = <String, WordItem>{};
    final Map<String, WordItem> byArabic = <String, WordItem>{};
    for (final WordItem word in data.words) {
      byExact.putIfAbsent(wordKey(word), () => word);
      byArabic.putIfAbsent(word.arabic.identityKey(), () => word);
    }

    final List<WordItem> resolved = <WordItem>[];
    for (final String key in wordKeys) {
      final int split = key.indexOf('\u0000');
      final String arabic = split < 0 ? key : key.substring(0, split);
      final WordItem? word = byExact[key] ?? byArabic[arabic.identityKey()];
      if (word == null) return null;
      resolved.add(word);
    }
    return resolved;
  }
}

/// 常规学习断点的持久化。
class LearningSessionStore {
  /// 存储键；新增顶级键必须登记进 `SharedPreferences.usedKeys`，否则备份会丢失。
  static const String key = "learningSessionData";

  static LearningSessionCheckpoint? load() {
    final String? raw = AppData().storage.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return LearningSessionCheckpoint.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(LearningSessionCheckpoint checkpoint) =>
      AppData().storage.setString(key, jsonEncode(checkpoint.toMap()));

  static Future<void> clear() => AppData().storage.setString(key, "");
}
