// 课文（背诵）题库数据模型：RecitationTextData / RecitationTextUnit /
// RecitationSentence / RecitationWord。
//
// 数据来自外部或聊天 AI 生成的 JSON，格式不可控，因此解析一律宽松：
// 字段别名、纯字符串句子、整段原文兜底都接受；任何解析失败都返回 null，绝不抛异常。

import 'dart:convert';

import 'package:arabic_learning/core/recitation_text.dart' show tokenize;
import 'package:crypto/crypto.dart';

const List<String> _arabicKeys = <String>['arabic', 'ar', 'text', '阿语', '原文'];
const List<String> _translationKeys = <String>[
  'translation',
  'zh',
  'chinese',
  '中文',
  '翻译',
  '译文',
  'meaning',
];
const List<String> _noteKeys = <String>['note', 'notes', 'comment', '注释', '说明'];
const List<String> _wordKeys = <String>['words', 'vocabulary', '生词', '词汇'];
const List<String> _wordArabicKeys = <String>[
  'arabic',
  'ar',
  'word',
  'word_arabic',
  '阿语',
  '原文',
];
const List<String> _wordChineseKeys = <String>[
  'chinese',
  'zh',
  'meaning',
  'translation',
  '中文',
  '释义',
];
const List<String> _sentenceKeys = <String>['sentences', 'lines', 'verses'];
const List<String> _passageKeys = <String>['passage', 'text', 'content'];

/// 取字段值：键名忽略大小写与首尾空白。
dynamic _pick(Map<String, dynamic> map, List<String> keys) {
  for (final MapEntry<String, dynamic> entry in map.entries) {
    if (keys.contains(entry.key.trim().toLowerCase())) return entry.value;
  }
  return null;
}

String _str(dynamic value) => value is String ? value.trim() : '';

/// 宽松解码：接受已解析的 Map，或（可能带 Markdown 围栏 / 前后说明文字的）
/// JSON 字符串；截取第一个 `{` 到最后一个 `}` 之间再解析，失败返回 null。
Map<String, dynamic>? _decodeObject(dynamic raw) {
  dynamic value = raw;
  if (value is String) {
    final int start = value.indexOf('{');
    final int end = value.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      value = jsonDecode(value.substring(start, end + 1));
    } catch (_) {
      return null;
    }
  }
  if (value is! Map) return null;
  try {
    return Map<String, dynamic>.from(value);
  } catch (_) {
    return null;
  }
}

/// 按换行与句末标点（含阿语问号、句点）切分，丢弃空段。
List<String> _splitPassage(String text) {
  final List<String> out = <String>[];
  final StringBuffer buffer = StringBuffer();
  void flush() {
    final String part = buffer.toString().trim();
    buffer.clear();
    if (part.isNotEmpty) out.add(part);
  }

  for (final int code in text.codeUnits) {
    final String char = String.fromCharCode(code);
    if (char == '\n' || char == '\r') {
      flush();
      continue;
    }
    buffer.write(char);
    if ('。？！?!؟.'.contains(char)) flush();
  }
  flush();
  return out;
}

int _difficulty(dynamic raw) {
  final num? value = raw is num
      ? raw
      : (raw is String ? num.tryParse(raw.trim()) : null);
  return value == null ? 0 : value.clamp(0, 100).toInt();
}

List<String> _tags(dynamic raw) {
  if (raw is String) {
    final String tag = raw.trim();
    return tag.isEmpty ? const <String>[] : <String>[tag];
  }
  if (raw is! List) return const <String>[];
  final List<String> tags = <String>[];
  for (final dynamic item in raw) {
    final String tag = _str(item);
    if (tag.isNotEmpty) tags.add(tag);
  }
  return tags;
}

class RecitationWord {
  final String arabic;
  final String chinese;

  const RecitationWord({required this.arabic, required this.chinese});

  Map<String, dynamic> toMap() => <String, dynamic>{
    'arabic': arabic,
    'chinese': chinese,
  };

  /// 阿语为空视为无效生词。
  static RecitationWord? buildFromMap(Map<String, dynamic> map) {
    final String arabic = _str(_pick(map, _wordArabicKeys));
    if (arabic.isEmpty) return null;
    return RecitationWord(
      arabic: arabic,
      chinese: _str(_pick(map, _wordChineseKeys)),
    );
  }
}

class RecitationSentence {
  final String arabic;
  final String translation;

  /// 可选注释 / 语法提示。
  final String? note;

  /// 该句生词，可能为空。
  final List<RecitationWord> words;

  const RecitationSentence({
    required this.arabic,
    required this.translation,
    this.note,
    this.words = const <RecitationWord>[],
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'arabic': arabic,
    'translation': translation,
    if (note != null && note!.isNotEmpty) 'note': note,
    if (words.isNotEmpty)
      'words': <Map<String, dynamic>>[
        for (final RecitationWord w in words) w.toMap(),
      ],
  };

  /// `raw` 可以是句子 Map，也可以是一整句纯字符串（译文留空）。
  static RecitationSentence? buildFromMap(dynamic raw) {
    if (raw is String) {
      final String text = raw.trim();
      return text.isEmpty
          ? null
          : RecitationSentence(arabic: text, translation: '');
    }
    if (raw is! Map) return null;
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final String arabic = _str(_pick(map, _arabicKeys));
    if (arabic.isEmpty) return null;

    final List<RecitationWord> words = <RecitationWord>[];
    final dynamic rawWords = _pick(map, _wordKeys);
    if (rawWords is List) {
      for (final dynamic item in rawWords) {
        if (item is String) {
          final String word = item.trim();
          if (word.isNotEmpty) {
            words.add(RecitationWord(arabic: word, chinese: ''));
          }
        } else if (item is Map) {
          final RecitationWord? word = RecitationWord.buildFromMap(
            Map<String, dynamic>.from(item),
          );
          if (word != null) words.add(word);
        }
      }
    }

    final String note = _str(_pick(map, _noteKeys));
    return RecitationSentence(
      arabic: arabic,
      translation: _str(_pick(map, _translationKeys)),
      note: note.isEmpty ? null : note,
      words: words,
    );
  }
}

class RecitationTextUnit {
  final String title;

  /// 0-100，缺省 0。
  final int difficulty;

  /// 来源，如「AI 生成」「课本第 3 课」。
  final String source;
  final List<String> tags;
  final List<RecitationSentence> sentences;

  const RecitationTextUnit({
    required this.title,
    this.difficulty = 0,
    this.source = '',
    this.tags = const <String>[],
    required this.sentences,
  });

  /// 供 ASR 评分使用的参考文本。
  String get reference =>
      sentences.map((RecitationSentence s) => s.arabic).join('\n');

  /// 内容指纹（不含类型等展示信息），与 [ReadingUnit.getHash] 同一思路。
  String getHash() => sha1.convert(utf8.encode('$title;$reference')).toString();

  /// 阿语词数（归一化后按空格切分，标点与变音符号不计）。
  int get wordCount => tokenize(reference).length;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'title': title,
    'difficulty': difficulty,
    'source': source,
    'tags': tags,
    'sentences': <Map<String, dynamic>>[
      for (final RecitationSentence s in sentences) s.toMap(),
    ],
  };

  /// 宽松解析一条课文。
  ///
  /// 逐句字段缺失时退回顶层 `passage` / `text` / `content` 按行与句末标点切分；
  /// 完全没有可用阿语内容才返回 null。
  /// [strict] 为 false 时跳过解析失败的句子，为 true 时整条返回 null。
  static RecitationTextUnit? buildFromMap(dynamic raw, {bool strict = true}) {
    final Map<String, dynamic>? map = _decodeObject(raw);
    if (map == null) return null;

    final List<RecitationSentence> sentences = <RecitationSentence>[];
    final dynamic rawSentences = _pick(map, _sentenceKeys);
    if (rawSentences is List) {
      for (final dynamic item in rawSentences) {
        final RecitationSentence? sentence = RecitationSentence.buildFromMap(
          item,
        );
        if (sentence != null) {
          sentences.add(sentence);
        } else if (strict && item != null) {
          return null;
        }
      }
    }

    if (sentences.isEmpty) {
      final dynamic passage = _pick(map, _passageKeys);
      if (passage is String) {
        for (final String line in _splitPassage(passage)) {
          sentences.add(RecitationSentence(arabic: line, translation: ''));
        }
      }
    }
    if (sentences.isEmpty) return null;

    final String reference = sentences
        .map((RecitationSentence s) => s.arabic)
        .join('\n');
    final String title = _str(_pick(map, const <String>['title']));
    // 无标题时取参考文本前 20 个字符（换行压成空格）。
    final String fallbackTitle = reference
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return RecitationTextUnit(
      title: title.isEmpty
          ? (fallbackTitle.length > 20
                ? fallbackTitle.substring(0, 20).trim()
                : fallbackTitle)
          : title,
      difficulty: _difficulty(_pick(map, const <String>['difficulty'])),
      source: _str(_pick(map, const <String>['source'])),
      tags: _tags(_pick(map, const <String>['tags'])),
      sentences: sentences,
    );
  }
}

class RecitationTextData {
  final List<RecitationTextUnit> units;

  RecitationTextData({List<RecitationTextUnit>? units})
    : units = units ?? <RecitationTextUnit>[];

  Map<String, dynamic> toMap() => <String, dynamic>{
    'units': <Map<String, dynamic>>[
      for (final RecitationTextUnit u in units) u.toMap(),
    ],
  };

  /// 逐条解析，坏数据直接跳过。
  static RecitationTextData buildFromMap(Map<String, dynamic> data) {
    final List<RecitationTextUnit> units = <RecitationTextUnit>[];
    final dynamic rawUnits = data['units'];
    if (rawUnits is List) {
      for (final dynamic item in rawUnits) {
        final RecitationTextUnit? unit = RecitationTextUnit.buildFromMap(item);
        if (unit != null) units.add(unit);
      }
    }
    return RecitationTextData(units: units);
  }
}
