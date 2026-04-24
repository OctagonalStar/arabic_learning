import 'dart:convert';

import 'package:arabic_learning/package_replacement/fake_dart_io.dart'
    if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/vars/config_structure.dart' show WordItem;
import 'package:arabic_learning/vars/global.dart' show AppData;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:logging/logging.dart';

// ── 题型枚举 ──────────────────────────────────────────────────────────────────

enum QuizType { fillBlank, multipleChoice, trueFalse, errorCorrection }

extension QuizTypeLabel on QuizType {
  String get label {
    switch (this) {
      case QuizType.fillBlank:       return '填空题';
      case QuizType.multipleChoice:  return '选择题';
      case QuizType.trueFalse:       return '判断题';
      case QuizType.errorCorrection: return '改错题';
    }
  }
}

// ── 难度枚举 ──────────────────────────────────────────────────────────────────

enum QuizDifficulty { easy, medium, hard }

extension QuizDifficultyLabel on QuizDifficulty {
  String get label {
    switch (this) {
      case QuizDifficulty.easy:   return '简单';
      case QuizDifficulty.medium: return '中等';
      case QuizDifficulty.hard:   return '困难';
    }
  }
  String get apiValue {
    switch (this) {
      case QuizDifficulty.easy:   return 'easy';
      case QuizDifficulty.medium: return 'medium';
      case QuizDifficulty.hard:   return 'hard';
    }
  }
}

// ── QuizItem 数据模型 ────────────────────────────────────────────────────────

@immutable
class QuizItem {
  /// 唯一 ID
  final String id;

  /// 对应 WordItem.id
  final int wordId;

  /// 阿语原词（冗余存储）
  final String arabicWord;

  /// 阿语例句：填空/选择含 [____]；判断为完整句；改错为含错句
  final String sentence;

  /// 考点说明（中文）
  final String grammarPoint;

  /// 标准答案：填空=填入词；选择=正确选项文字；判断="صح"/"خطأ"；改错=被纠正的词
  final String stdAnswer;

  /// 可接受的变体列表（填空/改错用）
  final List<String> variants;

  /// 答案解析（中文）
  final String explanation;

  /// 生成时间
  final DateTime generatedAt;

  /// 首次作答结果（null=未作答）
  final bool? firstResult;

  /// 首次作答时间
  final DateTime? firstAttemptedAt;

  // ── 扩展字段 ────────────────────────────────────────────────────────────────

  /// 题型
  final QuizType quizType;

  /// 难度
  final QuizDifficulty difficulty;

  /// 选项列表（选择题：含正确选项的4个选项）
  final List<String> choices;

  /// 正确选项下标（选择题用，-1=不适用）
  final int correctChoiceIndex;

  /// 句子是否正确（判断题用）
  final bool? isStatementTrue;

  /// 改错后的完整句子（改错题用）
  final String correctSentence;

  const QuizItem({
    required this.id,
    required this.wordId,
    required this.arabicWord,
    required this.sentence,
    required this.grammarPoint,
    required this.stdAnswer,
    required this.variants,
    required this.explanation,
    required this.generatedAt,
    this.firstResult,
    this.firstAttemptedAt,
    this.quizType = QuizType.fillBlank,
    this.difficulty = QuizDifficulty.medium,
    this.choices = const [],
    this.correctChoiceIndex = -1,
    this.isStatementTrue,
    this.correctSentence = '',
  });

  // ── 从 AI 响应构建 ──────────────────────────────────────────────────────────
  factory QuizItem.fromAiResponse(
    Map<String, dynamic> aiQ,
    WordItem word,
    int idx, {
    QuizType quizType = QuizType.fillBlank,
    QuizDifficulty difficulty = QuizDifficulty.medium,
  }) {
    final String rawId = '${word.id}_${DateTime.now().millisecondsSinceEpoch}_$idx';
    final String id =
        sha256.convert(utf8.encode(rawId)).toString().substring(0, 16);
    return QuizItem(
      id: id,
      wordId: word.id,
      arabicWord: word.arabic,
      sentence: (aiQ['sentence'] as String? ?? '').trim(),
      grammarPoint: (aiQ['grammar_point'] as String? ?? '').trim(),
      stdAnswer: (aiQ['std_answer'] as String? ?? '').trim(),
      variants: ((aiQ['variants'] as List?)?.cast<String>() ?? []),
      explanation: (aiQ['explanation'] as String? ?? '').trim(),
      generatedAt: DateTime.now(),
      quizType: quizType,
      difficulty: difficulty,
      choices: ((aiQ['choices'] as List?)?.cast<String>() ?? []),
      correctChoiceIndex: (aiQ['correct_index'] as int?) ?? -1,
      isStatementTrue: aiQ['is_true'] as bool?,
      correctSentence: (aiQ['correct_sentence'] as String? ?? '').trim(),
    );
  }

  // ── 序列化 ────────────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wordId': wordId,
      'arabicWord': arabicWord,
      'sentence': sentence,
      'grammarPoint': grammarPoint,
      'stdAnswer': stdAnswer,
      'variants': variants,
      'explanation': explanation,
      'generatedAt': generatedAt.toIso8601String(),
      'firstResult': firstResult,
      'firstAttemptedAt': firstAttemptedAt?.toIso8601String(),
      'quizType': quizType.name,
      'difficulty': difficulty.name,
      'choices': choices,
      'correctChoiceIndex': correctChoiceIndex,
      'isStatementTrue': isStatementTrue,
      'correctSentence': correctSentence,
    };
  }

  static QuizItem buildFromMap(Map<String, dynamic> m) {
    return QuizItem(
      id: m['id'] as String,
      wordId: m['wordId'] as int,
      arabicWord: m['arabicWord'] as String? ?? '',
      sentence: m['sentence'] as String? ?? '',
      grammarPoint: m['grammarPoint'] as String? ?? '',
      stdAnswer: m['stdAnswer'] as String? ?? '',
      variants: ((m['variants'] as List?)?.cast<String>() ?? []),
      explanation: m['explanation'] as String? ?? '',
      generatedAt: DateTime.parse(m['generatedAt'] as String),
      firstResult: m['firstResult'] as bool?,
      firstAttemptedAt: m['firstAttemptedAt'] != null
          ? DateTime.parse(m['firstAttemptedAt'] as String)
          : null,
      quizType: QuizType.values.firstWhere(
        (e) => e.name == (m['quizType'] as String?),
        orElse: () => QuizType.fillBlank,
      ),
      difficulty: QuizDifficulty.values.firstWhere(
        (e) => e.name == (m['difficulty'] as String?),
        orElse: () => QuizDifficulty.medium,
      ),
      choices: ((m['choices'] as List?)?.cast<String>() ?? []),
      correctChoiceIndex: (m['correctChoiceIndex'] as int?) ?? -1,
      isStatementTrue: m['isStatementTrue'] as bool?,
      correctSentence: m['correctSentence'] as String? ?? '',
    );
  }

  QuizItem withFirstResult(bool result) {
    if (firstResult != null) return this;
    return QuizItem(
      id: id,
      wordId: wordId,
      arabicWord: arabicWord,
      sentence: sentence,
      grammarPoint: grammarPoint,
      stdAnswer: stdAnswer,
      variants: variants,
      explanation: explanation,
      generatedAt: generatedAt,
      firstResult: result,
      firstAttemptedAt: DateTime.now(),
      quizType: quizType,
      difficulty: difficulty,
      choices: choices,
      correctChoiceIndex: correctChoiceIndex,
      isStatementTrue: isStatementTrue,
      correctSentence: correctSentence,
    );
  }
}

// ── QuizBank 单例 ─────────────────────────────────────────────────────────────

class QuizBank {
  static final QuizBank _instance = QuizBank._internal();
  factory QuizBank() => _instance;
  QuizBank._internal();

  final Logger _logger = Logger('QuizBank');
  static const String _fileName = 'ai_quiz_bank.json';

  final Map<String, QuizItem> _items = {};
  bool _loaded = false;

  String get _filePath => '${AppData().basePath.path}/$_fileName';

  Future<void> load() async {
    if (_loaded) return;
    if (kIsWeb) { _loaded = true; return; }
    try {
      final file = io.File(_filePath);
      if (!file.existsSync()) { _loaded = true; return; }
      final String raw = await file.readAsString();
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      for (final m in list) {
        final item = QuizItem.buildFromMap(m as Map<String, dynamic>);
        _items[item.id] = item;
      }
      _logger.info('题库加载完成，共 ${_items.length} 道题');
    } catch (e) {
      _logger.severe('题库加载失败: $e');
    }
    _loaded = true;
  }

  Future<void> _save() async {
    if (kIsWeb) return;
    try {
      final file = io.File(_filePath);
      final String json =
          jsonEncode(_items.values.map((i) => i.toMap()).toList());
      await file.writeAsString(json);
      _logger.fine('题库已保存，共 ${_items.length} 道题');
    } catch (e) {
      _logger.severe('题库保存失败: $e');
    }
  }

  Future<void> addItems(List<QuizItem> items) async {
    await load();
    int added = 0;
    for (final item in items) {
      if (!_items.containsKey(item.id)) {
        _items[item.id] = item;
        added++;
      }
    }
    if (added > 0) await _save();
    _logger.info('题库新增 $added 道题');
  }

  Future<List<QuizItem>> getItemsForWord(int wordId) async {
    await load();
    return _items.values.where((i) => i.wordId == wordId).toList()
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
  }

  Future<List<QuizItem>> getAllItems() async {
    await load();
    return _items.values.toList()
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
  }

  Future<void> recordFirstResult(String id, bool result) async {
    await load();
    final item = _items[id];
    if (item == null) return;
    final updated = item.withFirstResult(result);
    if (identical(updated, item)) return;
    _items[id] = updated;
    await _save();
    _logger.fine('记录题目 $id 首次结果: $result');
  }

  static String normalizeArabic(String s) {
    return s
        .replaceAll(
          RegExp(
              r'[\u064B-\u065F\u0670\u0610-\u061A\u06D6-\u06DC\u0615\u0670]'),
          '',
        )
        .trim();
  }

  static bool checkAnswer(String userInput, QuizItem item) {
    final String normed = normalizeArabic(userInput);
    if (normed.isEmpty) return false;
    final String stdNorm = normalizeArabic(item.stdAnswer);
    if (normed == stdNorm || userInput.trim() == item.stdAnswer) return true;
    for (final v in item.variants) {
      if (normed == normalizeArabic(v)) return true;
    }
    if (_levenshtein(normed, stdNorm) <= 1) return true;
    for (final v in item.variants) {
      if (_levenshtein(normed, normalizeArabic(v)) <= 1) return true;
    }
    return false;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final List<List<int>> dp = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => i == 0 ? j : (j == 0 ? i : 0)),
    );
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        dp[i][j] = a[i - 1] == b[j - 1]
            ? dp[i - 1][j - 1]
            : 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                .reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[a.length][b.length];
  }
}
