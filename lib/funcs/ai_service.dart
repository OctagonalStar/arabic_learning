import 'dart:convert';

import 'package:arabic_learning/funcs/quiz_bank.dart';
import 'package:arabic_learning/vars/config_structure.dart' show AiConfig, WordItem;
import 'package:arabic_learning/vars/global.dart' show AppData;
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

// ── 错误类型 ─────────────────────────────────────────────────────────────────

enum AiErrorType {
  noApiKey,
  noNetwork,
  unauthorized,
  serverError,
  parseError,
  cancelled,
  unknown,
}

class AiException implements Exception {
  final AiErrorType type;
  final String message;
  const AiException(this.type, this.message);

  String get userMessage {
    switch (type) {
      case AiErrorType.noApiKey:    return '请先在设置页填写 AI API Key';
      case AiErrorType.noNetwork:   return '网络不可用，请检查连接后重试';
      case AiErrorType.unauthorized: return 'API Key 无效或已过期，请在设置中更新';
      case AiErrorType.serverError: return 'AI 服务暂时异常（服务端错误），请稍后重试';
      case AiErrorType.parseError:  return 'AI 返回的内容格式异常，请重试或更换模型';
      case AiErrorType.cancelled:   return '已取消';
      case AiErrorType.unknown:     return '未知错误：$message';
    }
  }

  @override
  String toString() => 'AiException(${type.name}): $message';
}

// ── System Prompts ────────────────────────────────────────────────────────────

const String _kFillBlankPrompt = '''
You are an Arabic language teacher generating fill-in-the-blank (cloze) exercises for a Chinese learner.
Given a target Arabic word/phrase, generate exactly {COUNT} exercises at {DIFFICULTY} difficulty.
Difficulty scale: easy=simple sentences & basic grammar; medium=standard grammar; hard=complex sentences & advanced grammar.

Rules:
1. Each exercise contains ONE blank marked as [____] in a natural Arabic sentence.
2. The sentence must test a real grammar point (verb conjugation, noun case, preposition collocation, dual/plural, etc.).
3. std_answer MUST be the full voweled Arabic form that fills the blank.
4. variants is a list of equally acceptable alternate spellings. Can be empty [].
5. explanation is ONE concise Chinese sentence (≤50 chars) describing the tested grammar point.
6. grammar_point is a short Chinese label (≤15 chars) of the grammar focus.
7. DO NOT include any text outside the JSON.

Output format:
{
  "questions": [
    {
      "sentence": "أَنَا [____] فِي الْبَيْتِ.",
      "grammar_point": "动词变位",
      "std_answer": "أَجْلِسُ",
      "variants": ["أجلس"],
      "explanation": "第一人称单数阳性现在时，表示我坐着。"
    }
  ]
}
''';

const String _kMultipleChoicePrompt = '''
You are an Arabic language teacher generating multiple choice exercises for a Chinese learner.
Given a target Arabic word/phrase, generate exactly {COUNT} exercises at {DIFFICULTY} difficulty.
Difficulty scale: easy=simple vocabulary & basic grammar; medium=standard grammar; hard=advanced grammar & complex forms.

Rules:
1. Each question has a sentence with [____] marking the blank.
2. Provide exactly 4 choices, only one is correct.
3. Other choices must be plausible distractors (wrong conjugations, wrong cases, similar-looking words).
4. correct_index is the 0-based index of the correct choice in the choices array.
5. std_answer must equal choices[correct_index].
6. explanation is ONE Chinese sentence (≤50 chars) explaining the grammar focus.
7. grammar_point is a short Chinese label (≤15 chars).
8. DO NOT include any text outside the JSON.

Output format:
{
  "questions": [
    {
      "sentence": "أَنَا [____] فِي الْبَيْتِ.",
      "grammar_point": "动词变位",
      "std_answer": "أَجْلِسُ",
      "choices": ["أَجْلِسُ", "يَجْلِسُ", "جَلَسَ", "جُلِسَ"],
      "correct_index": 0,
      "explanation": "第一人称单数现在时主动语态。"
    }
  ]
}
''';

const String _kTrueFalsePrompt = '''
You are an Arabic language teacher generating true/false judgment exercises for a Chinese learner.
Given a target Arabic word/phrase, generate exactly {COUNT} exercises at {DIFFICULTY} difficulty.
Difficulty scale: easy=obvious errors; medium=subtle grammar errors; hard=complex grammar nuances.

Rules:
1. Present a complete Arabic sentence (correct or intentionally containing ONE grammatical error).
2. Mix roughly 50% true and 50% false sentences.
3. False sentences contain ONE clear grammatical error related to the target word or general Arabic grammar.
4. is_true: true if the sentence is grammatically correct, false if it contains an error.
5. std_answer: "صَحِيحٌ" if is_true=true, "خَطَأٌ" if is_true=false.
6. correct_sentence: when is_true=false, provide the FULL corrected sentence (empty string if is_true=true).
7. explanation: ONE Chinese sentence (≤60 chars) explaining why correct or what the error is.
8. grammar_point: a short Chinese label (≤15 chars).
9. DO NOT include any text outside the JSON.

Output format:
{
  "questions": [
    {
      "sentence": "ذَهَبَتِ الطَّالِبُ إِلَى الْمَدْرَسَةِ.",
      "grammar_point": "性数一致",
      "is_true": false,
      "std_answer": "خَطَأٌ",
      "correct_sentence": "ذَهَبَ الطَّالِبُ إِلَى الْمَدْرَسَةِ.",
      "explanation": "طالب为阳性，动词应用ذهب（阳性）而非ذهبت（阴性）。"
    }
  ]
}
''';

String _buildErrorCorrectionPrompt(QuizDifficulty difficulty) {
  // easy：用 【...】 标记错误词位置；medium/hard：不标记
  final bool markError = difficulty == QuizDifficulty.easy;
  final String diffDesc = difficulty == QuizDifficulty.easy
      ? 'easy=obvious case/conjugation error, mark the erroneous word with 「【error_word】」 in the sentence'
      : difficulty == QuizDifficulty.medium
          ? 'medium=subtle agreement error, do NOT mark the position'
          : 'hard=complex morphology error, do NOT mark the position';

  return '''
You are an Arabic language teacher generating error correction exercises for a Chinese learner.
Given a target Arabic word/phrase, generate exactly {COUNT} exercises at {DIFFICULTY} difficulty.
Difficulty: {DIFFICULTY} ($diffDesc)

Rules:
1. Present an Arabic sentence with exactly ONE grammatical error.
${markError ? '   For EASY difficulty, wrap the erroneous word in 「【 】」 markers, e.g. 「【ذَهَبَتِ】」.' : '   Do NOT mark or hint at the error position.'}
2. The student must identify and write the CORRECTED word or short phrase.
3. std_answer is the corrected word/phrase (NOT the whole sentence).
4. sentence is the FULL sentence WITH the error${markError ? ' (error word wrapped in 【 】)' : ''}.
5. correct_sentence is the FULL corrected sentence WITHOUT any markers.
6. variants: acceptable alternate spellings of std_answer. Can be empty [].
7. grammar_point: type of error in Chinese (≤15 chars).
8. explanation: ONE Chinese sentence (≤60 chars) explaining the error and correction.
9. DO NOT include any text outside the JSON.

Output format:
{
  "questions": [
    {
      "sentence": "${markError ? '【ذَهَبَتِ】' : 'ذَهَبَتِ'} الطَّالِبُ إِلَى الْمَدْرَسَةِ.",
      "grammar_point": "性数不一致",
      "std_answer": "ذَهَبَ",
      "correct_sentence": "ذَهَبَ الطَّالِبُ إِلَى الْمَدْرَسَةِ.",
      "variants": ["ذهب"],
      "explanation": "ذهبت为阴性，主语طالب为阳性，应改为ذهب。"
    }
  ]
}
'''.replaceAll('{DIFFICULTY}', difficulty.apiValue).replaceAll('{COUNT}', '{COUNT}');
}

// ── Reading Prompt ────────────────────────────────────────────────────────────

String buildReadingPrompt(List<WordItem> words, QuizDifficulty difficulty) {
  final wordList = words.map((w) => '${w.arabic}（${w.chinese}）').join('、');

  // 目标词数 = 复习词数 × 10
  final int baseWords = words.length * 10;
  final int minWords = (baseWords * 0.8).round().clamp(40, 600);
  final int maxWords = (baseWords * 1.2).round().clamp(60, 800);

  // 总问题数（含最后1道开放题）
  final int totalQ = (words.length / 3).ceil().clamp(3, 6);
  final int choiceQ = totalQ - 1; // 选择题数量

  final String diffDesc;
  switch (difficulty) {
    case QuizDifficulty.easy:
      diffDesc = 'simple vocabulary, short clear sentences, basic grammar (present tense, simple nouns)';
      break;
    case QuizDifficulty.medium:
      diffDesc = 'moderate vocabulary, standard grammar, mix of tenses and sentence structures';
      break;
    case QuizDifficulty.hard:
      diffDesc = 'rich vocabulary, complex grammar, formal register, varied sentence structures including subordinate clauses';
      break;
  }

  return '''
You are an Arabic language teacher. Create an Arabic reading passage for a Chinese learner.
The passage MUST naturally incorporate ALL of these vocabulary words: $wordList
Target length: $minWords–$maxWords Arabic words (approx. ${words.length * 10} words total).
Difficulty: {DIFFICULTY} ($diffDesc)

After the passage, create exactly $totalQ comprehension questions in MIXED format:
- First $choiceQ questions: multiple-choice (4 options each), testing fact-finding from the passage.
- Last 1 question: open-ended, requiring the student to write a short answer (2-4 Arabic words).

Rules:
1. passage: the Arabic reading text (MUST be $minWords–$maxWords words long).
2. passage_summary: a brief Chinese translation/summary (≤120 chars).
3. For CHOICE questions: type="choice", q (Chinese question), choices (array of 4 Arabic options), correct_index (0-based), std_answer = choices[correct_index], explanation (≤40 chars).
4. For OPEN question: type="open", q (Chinese question), std_answer (short Arabic answer), explanation (≤40 chars hint).
5. DO NOT include any text outside the JSON.

Output format:
{
  "passage": "...",
  "passage_summary": "...",
  "questions": [
    { "type": "choice", "q": "...", "choices": ["...", "...", "...", "..."], "correct_index": 0, "std_answer": "...", "explanation": "..." },
    { "type": "open", "q": "...", "std_answer": "...", "explanation": "..." }
  ]
}
'''.replaceAll('{DIFFICULTY}', difficulty.apiValue);
}

// ── AiService ─────────────────────────────────────────────────────────────────

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  final Logger _logger = Logger('AiService');
  CancelToken? _cancelToken;

  void cancel() => _cancelToken?.cancel('user_cancel');

  // ── 主入口：按题型生成并存库 ──────────────────────────────────────────────
  Future<List<QuizItem>> generateAndSave({
    required WordItem word,
    QuizType quizType = QuizType.fillBlank,
    QuizDifficulty difficulty = QuizDifficulty.medium,
    int? count,
  }) async {
    final AiConfig cfg = AppData().config.ai;
    if (cfg.apiKey.trim().isEmpty) {
      throw const AiException(AiErrorType.noApiKey, 'API key is empty');
    }

    final int questionCount = count ?? cfg.defaultQuestionCount;
    final String systemPrompt = _getSystemPrompt(quizType, difficulty)
        .replaceAll('{COUNT}', '$questionCount')
        .replaceAll('{DIFFICULTY}', difficulty.apiValue);
    final String userPrompt = _buildUserPrompt(word, questionCount, quizType);

    final String raw = await _callApi(cfg, systemPrompt, userPrompt);
    _logger.fine('AI 原始响应（前200字符）: ${raw.substring(0, raw.length.clamp(0, 200))}');

    final List<QuizItem> items =
        _parseResponse(raw, word, quizType: quizType, difficulty: difficulty);
    _logger.info('解析得到 ${items.length} 道题目');

    await QuizBank().addItems(items);
    return items;
  }

  // ── 阅读理解（不入题库，直接返回原始 Map）────────────────────────────────
  Future<Map<String, dynamic>> generateReading({
    required List<WordItem> words,
    QuizDifficulty difficulty = QuizDifficulty.medium,
  }) async {
    final AiConfig cfg = AppData().config.ai;
    if (cfg.apiKey.trim().isEmpty) {
      throw const AiException(AiErrorType.noApiKey, 'API key is empty');
    }

    final String systemPrompt = buildReadingPrompt(words, difficulty);
    final String userPrompt =
        'Generate a reading passage for ${words.length} vocabulary words at ${difficulty.apiValue} difficulty.';

    final String raw = await _callApi(cfg, systemPrompt, userPrompt);
    _logger.fine('阅读原始响应（前200字符）: ${raw.substring(0, raw.length.clamp(0, 200))}');

    final Map<String, dynamic>? parsed = _tryParseJson(raw) ??
        _tryParseJson(
            RegExp(r'```(?:json)?\s*([\s\S]+?)\s*```').firstMatch(raw)?.group(1) ?? '') ??
        _tryParseJson(RegExp(r'\{[\s\S]+\}').firstMatch(raw)?.group(0) ?? '');

    if (parsed == null || parsed['passage'] == null) {
      throw const AiException(AiErrorType.parseError, 'Cannot parse reading response');
    }
    return parsed;
  }

  // ── 内部：HTTP 调用 ────────────────────────────────────────────────────────
  Future<String> _callApi(AiConfig cfg, String systemPrompt, String userPrompt) async {
    _cancelToken = CancelToken();
    final Dio dio = Dio(BaseOptions(
      baseUrl: '${cfg.baseUrl.trimRight()}/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 90),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${cfg.apiKey}',
      },
    ));
    try {
      final Response<dynamic> response = await dio.post(
        '/chat/completions',
        data: {
          'model': cfg.model,
          'temperature': 0.7,
          'max_tokens': 2048,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
        },
        cancelToken: _cancelToken,
      );
      return _extractContent(response.data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    } catch (e) {
      if (e is AiException) rethrow;
      _logger.severe('AI 请求发生未知错误: $e');
      throw AiException(AiErrorType.unknown, e.toString());
    }
  }

  // ── 题型 → 系统 Prompt ────────────────────────────────────────────────────
  String _getSystemPrompt(QuizType type, QuizDifficulty difficulty) {
    switch (type) {
      case QuizType.fillBlank:       return _kFillBlankPrompt;
      case QuizType.multipleChoice:  return _kMultipleChoicePrompt;
      case QuizType.trueFalse:       return _kTrueFalsePrompt;
      case QuizType.errorCorrection: return _buildErrorCorrectionPrompt(difficulty);
    }
  }

  String _buildUserPrompt(WordItem word, int count, QuizType type) {
    return 'Target Arabic word/phrase: ${word.arabic}\nChinese meaning: ${word.chinese}\nGenerate $count ${type.label} exercises targeting this word.';
  }

  // ── 内容提取 ──────────────────────────────────────────────────────────────
  String _extractContent(dynamic data) {
    try {
      final Map<String, dynamic> body =
          (data is String ? jsonDecode(data) : data) as Map<String, dynamic>;
      return (body['choices'] as List<dynamic>)[0]['message']['content'] as String;
    } catch (e) {
      throw const AiException(AiErrorType.parseError, 'Failed to extract content');
    }
  }

  // ── JSON 解析（三级策略）────────────────────────────────────────────────────
  List<QuizItem> _parseResponse(String raw, WordItem word,
      {required QuizType quizType, required QuizDifficulty difficulty}) {
    Map<String, dynamic>? parsed = _tryParseJson(raw);
    if (parsed == null) {
      final match = RegExp(r'```(?:json)?\s*([\s\S]+?)\s*```').firstMatch(raw);
      if (match != null) parsed = _tryParseJson(match.group(1)!);
    }
    if (parsed == null) {
      final match = RegExp(r'\{[\s\S]+\}').firstMatch(raw);
      if (match != null) parsed = _tryParseJson(match.group(0)!);
    }
    if (parsed == null) {
      _logger.severe('无法从以下内容解析 JSON:\n$raw');
      throw const AiException(AiErrorType.parseError, 'Cannot extract valid JSON');
    }
    final List<dynamic> questions = parsed['questions'] as List<dynamic>? ?? [];
    if (questions.isEmpty) {
      throw const AiException(AiErrorType.parseError, 'AI returned empty questions list');
    }
    return questions
        .asMap()
        .entries
        .map((e) => QuizItem.fromAiResponse(
              e.value as Map<String, dynamic>,
              word,
              e.key,
              quizType: quizType,
              difficulty: difficulty,
            ))
        .where((q) => q.sentence.isNotEmpty)
        .toList();
  }

  Map<String, dynamic>? _tryParseJson(String raw) {
    try {
      return jsonDecode(raw.trim()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  AiException _mapDioError(DioException e) {
    if (e.type == DioExceptionType.cancel) {
      return const AiException(AiErrorType.cancelled, 'Request cancelled');
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return AiException(AiErrorType.noNetwork, e.message ?? 'network error');
    }
    final int? status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      return AiException(AiErrorType.unauthorized, 'HTTP $status');
    }
    if (status != null && status >= 500) {
      return AiException(AiErrorType.serverError, 'HTTP $status');
    }
    return AiException(AiErrorType.unknown, e.toString());
  }
}
