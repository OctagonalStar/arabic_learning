// 阿拉伯语背诵文本的归一化、分词与期望时长估算。
// 纯 Dart，无 Flutter / IO 依赖，便于单元测试。

/// 每个「字母权重」折算的秒数，用于估算正常背诵时长。
///
/// 只是粗略基准（未用真实录音校准）；要校准只改这一个常量。
const double secondsPerLetterUnit = 0.12;

const int _space = 0x20;

/// 变音符号、古兰经标记与 tatweel：比较时一律忽略。
bool _isMark(int code) =>
    (code >= 0x0610 && code <= 0x061A) ||
    (code >= 0x064B && code <= 0x065F) ||
    code == 0x0670 || // 上标 alef
    (code >= 0x06D6 && code <= 0x06ED) || // 古兰经停顿/小标记
    code == 0x0640; // tatweel

bool _isLetter(int code) =>
    (code >= 0x0621 && code <= 0x063A) || (code >= 0x0641 && code <= 0x064A);

/// 统一书写差异：أإآٱ→ا、ة→ه、ى→ي、ؤ→و、ئ→ي。
int _fold(int code) {
  switch (code) {
    case 0x0623: // أ
    case 0x0625: // إ
    case 0x0622: // آ
    case 0x0671: // ٱ
      return 0x0627;
    case 0x0629: // ة
      return 0x0647;
    case 0x0649: // ى
      return 0x064A;
    case 0x0624: // ؤ
      return 0x0648;
    case 0x0626: // ئ
      return 0x064A;
  }
  return _isLetter(code) ? code : 0;
}

/// 归一化：去变音符号与 tatweel，统一字母写法，标点/数字/拉丁字符转为词边界。
String normalizeArabic(String text) {
  final StringBuffer out = StringBuffer();
  bool boundary = false;
  for (final int code in text.codeUnits) {
    if (_isMark(code)) continue;
    if (code == _space || code == 0x09 || code == 0x0A || code == 0x0D) {
      boundary = out.isNotEmpty;
      continue;
    }
    final int folded = _fold(code);
    if (folded == 0) {
      // 标点等非阿语字母：当作词边界，避免把两个词粘成一个。
      boundary = out.isNotEmpty;
      continue;
    }
    if (boundary) {
      out.write(' ');
      boundary = false;
    }
    out.writeCharCode(folded);
  }
  return out.toString();
}

/// 归一化后的词序列。
List<String> tokenize(String text) {
  final String normalized = normalizeArabic(text);
  if (normalized.isEmpty) return const <String>[];
  return normalized.split(' ');
}

/// 前附词（连写前缀）：从长到短，避免 `وال` 先被 `و` 吃掉。
const List<String> _proclitics = <String>[
  'وال', 'بال', 'كال', 'فال', 'لل', 'ال', 'و', 'ف', 'ب', 'ك', 'ل',
];

/// 后附代词与复数/双数词尾（均已按 [normalizeArabic] 折叠，故 ة 写作 ه）。
const List<String> _suffixes = <String>[
  'ها', 'هم', 'هن', 'كما', 'كم', 'نا', 'ه', 'ك', 'ي', 'ات', 'ون', 'ين', 'ان',
];

/// 查词用的候选词形：原形 → 去前附词 → 去后缀 → 前后都去。
///
/// 只做机械剥离，不判断剥离后的词是否成立；调用方按查词结果决定取舍。
List<String> lookupStems(String raw) {
  final String word = normalizeArabic(raw);
  if (word.isEmpty) return const <String>[];
  final Set<String> out = <String>{word};
  void add(String w) {
    if (w.length >= 2) out.add(w);
  }

  final List<String> prefixes = <String>[];
  for (final String p in _proclitics) {
    if (word.length > p.length + 1 && word.startsWith(p)) prefixes.add(word.substring(p.length));
  }
  final List<String> suffixes = <String>[];
  for (final String s in _suffixes) {
    if (word.length > s.length + 1 && word.endsWith(s)) {
      suffixes.add(word.substring(0, word.length - s.length));
    }
  }
  prefixes.forEach(add);
  suffixes.forEach(add);
  for (final String p in prefixes) {
    for (final String s in _suffixes) {
      if (p.length > s.length + 1 && p.endsWith(s)) add(p.substring(0, p.length - s.length));
    }
  }
  return out.toList();
}

/// 正常背诵这段文本大约需要多少秒。
///
/// 按字母权重累加：每个字母 1，长元音（ا و ي）与 shadda 额外加长。
double estimateSeconds(String reference) {
  double units = 0;
  for (final int code in reference.codeUnits) {
    if (code == 0x0651) {
      // shadda：前一个辅音读两次
      units += 0.5;
      continue;
    }
    if (_isMark(code)) continue;
    final int folded = _fold(code);
    if (folded == 0) continue;
    units += 1;
    if (folded == 0x0627 || folded == 0x0648 || folded == 0x064A) units += 0.5;
  }
  return units * secondsPerLetterUnit;
}
