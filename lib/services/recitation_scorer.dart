// 背诵评分：归一化词序列对齐 + 可解释指标（纯 Dart，无 IO）。
//
// 只做词与时间这一层：覆盖率、插入、顺序、时长、停顿。
// 不做音素级发音或 tajweed 判断，也不在任何文案里这样宣称。

import 'dart:math' as math;

import 'package:arabic_learning/services/recitation_asr.dart';
import 'package:arabic_learning/services/recitation_audio.dart';
import 'package:arabic_learning/core/recitation_text.dart';

/// 门禁触发时的统一文案。
const String unclearSummary = '没听清，请靠近麦克风重录';

/// 低于该语音占比视为没听到有效内容。
const double minSpeechRatio = 0.2;

/// 短于该时长不做判定。
const double minAudioSeconds = 2;

/// 单个词重复到该次数、且占全部识别词的比例超过 [_loopShare] 时，
/// 视为 Whisper 的重复幻觉而不是人声。
const int _loopMinRepeats = 4;
const double _loopShare = 0.3;

enum RecitationIssueType {
  missing,
  extra,
  order,
  pause,
  tooFast,
  tooSlow,
  unclear,
  misread,
}

/// 参考词的对齐结果：命中 / 漏读 / 错读。
enum RecitationTokenMark { matched, missing, misread }

class RecitationIssue {
  final RecitationIssueType type;
  final String text;
  final String detail;

  const RecitationIssue({
    required this.type,
    required this.text,
    required this.detail,
  });
}

class RecitationOutcome {
  /// 0..100；[scoreable] 为 false 时一定是 null。
  final int? score;
  final String? grade;
  final bool scoreable;
  final double coverage;
  final double insertionRate;
  final double orderRate;
  final double durationRatio;
  final List<RecitationIssue> issues;
  final String summary;

  /// 与 tokenize(reference) 一一对应。
  final List<RecitationTokenMark> marks;

  /// 错读位置实际听到的词（仅 marks[i] == misread 时非空），与 [marks] 等长。
  final List<String?> heard;

  /// ASR 识别出的完整文本（各词用空格连接），逐句结果展示用。
  final String transcript;

  const RecitationOutcome({
    required this.score,
    required this.grade,
    required this.scoreable,
    required this.coverage,
    required this.insertionRate,
    required this.orderRate,
    required this.durationRatio,
    required this.issues,
    required this.summary,
    required this.marks,
    required this.heard,
    required this.transcript,
  });
}

/// 对一次背诵录音打分。
///
/// [asrTruncated] 表示识别没有覆盖完整录音；此时不给分，否则覆盖率会失真。
RecitationOutcome score({
  required String reference,
  required List<AsrWord> words,
  required SpeechAnalysis analysis,
  required double audioSeconds,
  required bool asrTruncated,
}) {
  final List<String> refTokens = tokenize(reference);
  final List<String> asrTokens = <String>[
    for (final AsrWord word in words) ...tokenize(word.text),
  ];
  final String transcript = <String>[
    for (final AsrWord word in words) word.text.trim(),
  ].where((String text) => text.isNotEmpty).join(' ');

  final ({int length, List<bool> refMatched, List<bool> asrMatched}) lcs = _lcs(
    refTokens,
    asrTokens,
  );

  final List<RecitationTokenMark> marks = <RecitationTokenMark>[
    for (int i = 0; i < refTokens.length; i++)
      lcs.refMatched[i]
          ? RecitationTokenMark.matched
          : RecitationTokenMark.missing,
  ];
  final List<String?> heard = List<String?>.filled(refTokens.length, null);
  final List<bool> asrPaired = List<bool>.filled(asrTokens.length, false);

  // 错读只在 LCS 锚点之间的空隙里找，锚点本身不会被改写。
  final List<int> refAnchors = <int>[
    for (int i = 0; i < refTokens.length; i++)
      if (lcs.refMatched[i]) i,
  ];
  final List<int> asrAnchors = <int>[
    for (int i = 0; i < asrTokens.length; i++)
      if (lcs.asrMatched[i]) i,
  ];
  int misreadPairs = 0;
  void alignGap(int refFrom, int refTo, int asrFrom, int asrTo) {
    for (final ({int refIndex, int asrIndex}) pair in _pairGap(
      refTokens,
      refFrom,
      refTo,
      asrTokens,
      asrFrom,
      asrTo,
    )) {
      marks[pair.refIndex] = RecitationTokenMark.misread;
      heard[pair.refIndex] = asrTokens[pair.asrIndex];
      asrPaired[pair.asrIndex] = true;
      misreadPairs++;
    }
  }

  int prevRef = 0;
  int prevAsr = 0;
  for (int k = 0; k < refAnchors.length; k++) {
    alignGap(prevRef, refAnchors[k], prevAsr, asrAnchors[k]);
    prevRef = refAnchors[k] + 1;
    prevAsr = asrAnchors[k] + 1;
  }
  alignGap(prevRef, refTokens.length, prevAsr, asrTokens.length);

  final int extraCount = math.max(
    0,
    asrTokens.length - lcs.length - misreadPairs,
  );
  final double coverage = refTokens.isEmpty ? 0 : lcs.length / refTokens.length;
  final double insertionRate = asrTokens.isEmpty
      ? 0
      : extraCount / asrTokens.length;
  final double orderRate = _orderRate(refTokens, asrTokens, lcs.length);
  final double expected = estimateSeconds(reference);
  final double durationRatio = expected > 0 ? audioSeconds / expected : 1;

  RecitationOutcome gate(String summary) => RecitationOutcome(
    score: null,
    grade: null,
    scoreable: false,
    coverage: coverage,
    insertionRate: insertionRate,
    orderRate: orderRate,
    durationRatio: durationRatio,
    issues: <RecitationIssue>[
      RecitationIssue(
        type: RecitationIssueType.unclear,
        text: '没听清',
        detail: summary,
      ),
    ],
    summary: summary,
    marks: const <RecitationTokenMark>[],
    heard: const <String?>[],
    transcript: transcript,
  );

  if (audioSeconds < minAudioSeconds || refTokens.isEmpty) {
    return gate(unclearSummary);
  }
  if (asrTruncated) {
    return gate('录音过长，未能完整识别，请分段重录');
  }
  if (analysis.speechRatio < minSpeechRatio) return gate(unclearSummary);
  // 识别包没有导出时间戳，对齐覆盖率只能靠合成时间，已无判别力；
  // 改为「一个词都没命中」与「重复幻觉」两道门禁。
  if (asrTokens.isNotEmpty && coverage == 0) return gate(unclearSummary);
  if (coverage < 0.5 && _looksLikeLoop(asrTokens)) return gate(unclearSummary);

  final double durationCompliance = (1 - (durationRatio - 1).abs() / 0.5).clamp(
    0.0,
    1.0,
  );
  final double fluency = (1 - 0.25 * analysis.pauses.length).clamp(0.0, 1.0);
  final int finalScore =
      (60 * coverage +
              15 * (1 - insertionRate) +
              10 * orderRate +
              10 * durationCompliance +
              5 * fluency)
          .round()
          .clamp(0, 100);
  final String grade = finalScore >= 85
      ? 'A'
      : finalScore >= 70
      ? 'B'
      : finalScore >= 55
      ? 'C'
      : '重录';

  final List<RecitationIssue> issues = <RecitationIssue>[];

  // 漏读：参考词里标记为 missing 的连续片段，最多列 3 处。
  int index = 0;
  while (index < marks.length && issues.length < 3) {
    if (marks[index] != RecitationTokenMark.missing) {
      index++;
      continue;
    }
    final int from = index;
    while (index < marks.length &&
        marks[index] == RecitationTokenMark.missing) {
      index++;
    }
    issues.add(
      RecitationIssue(
        type: RecitationIssueType.missing,
        text: refTokens.sublist(from, index).join(' '),
        detail: '这几个词没有听到',
      ),
    );
  }

  // 错读：连续错读的一段合成一条提示，最多 3 条，每条最多 3 对。
  int misreadIndex = 0;
  int misreadIssues = 0;
  while (misreadIndex < marks.length && misreadIssues < 3) {
    if (marks[misreadIndex] != RecitationTokenMark.misread) {
      misreadIndex++;
      continue;
    }
    final List<String> pairs = <String>[];
    while (misreadIndex < marks.length &&
        marks[misreadIndex] == RecitationTokenMark.misread) {
      if (pairs.length < 3) {
        pairs.add('${refTokens[misreadIndex]} → ${heard[misreadIndex]}');
      }
      misreadIndex++;
    }
    issues.add(
      RecitationIssue(
        type: RecitationIssueType.misread,
        text: pairs.join(' · '),
        detail: '这个词读成了别的词',
      ),
    );
    misreadIssues++;
  }

  // 多读：LCS 与错读配对之外的词占 ASR 词数的比例过高时提示一次。
  if (insertionRate >= 0.25) {
    final List<String> extra = <String>[
      for (int i = 0; i < asrTokens.length; i++)
        if (!lcs.asrMatched[i] && !asrPaired[i]) asrTokens[i],
    ];
    issues.add(
      RecitationIssue(
        type: RecitationIssueType.extra,
        text: extra.join(' '),
        detail: '录到了课文里没有的词，可能是口误或重复',
      ),
    );
  }

  if (orderRate < 0.9) {
    issues.add(
      RecitationIssue(
        type: RecitationIssueType.order,
        text: '顺序与课文不一致',
        detail: '这些词读到了，但先后顺序和课文不同',
      ),
    );
  }

  for (int i = 0; i < analysis.pauses.length && i < 3; i++) {
    final ({double start, double end}) pause = analysis.pauses[i];
    issues.add(
      RecitationIssue(
        type: RecitationIssueType.pause,
        text: '第 ${i + 1} 处停顿',
        detail: '这里停了 ${(pause.end - pause.start).toStringAsFixed(1)} 秒，建议再顺一遍',
      ),
    );
  }

  if (durationRatio < 0.6) {
    issues.add(
      const RecitationIssue(
        type: RecitationIssueType.tooFast,
        text: '整体偏快',
        detail: '比正常背诵快不少，注意把每个词读完整',
      ),
    );
  } else if (durationRatio > 1.6) {
    issues.add(
      const RecitationIssue(
        type: RecitationIssueType.tooSlow,
        text: '整体偏慢',
        detail: '比正常背诵慢不少，可以再连贯一些',
      ),
    );
  }

  return RecitationOutcome(
    score: finalScore,
    grade: grade,
    scoreable: true,
    coverage: coverage,
    insertionRate: insertionRate,
    orderRate: orderRate,
    durationRatio: durationRatio,
    issues: issues,
    summary:
        '覆盖 ${(coverage * 100).round()}%，用时 ${audioSeconds.toStringAsFixed(1)} 秒',
    marks: marks,
    heard: heard,
    transcript: transcript,
  );
}

/// Whisper 在听不清时常退化成同一个词反复输出，按最大重复词判定。
bool _looksLikeLoop(List<String> tokens) {
  if (tokens.length < _loopMinRepeats) return false;
  final Map<String, int> counts = <String, int>{};
  int max = 0;
  for (final String token in tokens) {
    final int next = (counts[token] ?? 0) + 1;
    counts[token] = next;
    if (next > max) max = next;
  }
  return max >= _loopMinRepeats && max / tokens.length >= _loopShare;
}

/// 内容命中里有多少保持了课文顺序（1 = 完全按顺序）。
double _orderRate(List<String> ref, List<String> asr, int lcsLength) {
  final Map<String, int> remaining = <String, int>{};
  for (final String token in ref) {
    remaining[token] = (remaining[token] ?? 0) + 1;
  }
  int overlap = 0;
  for (final String token in asr) {
    final int count = remaining[token] ?? 0;
    if (count > 0) {
      overlap++;
      remaining[token] = count - 1;
    }
  }
  if (overlap == 0) return 0;
  return (lcsLength / overlap).clamp(0.0, 1.0);
}

/// 最长公共子序列，同时返回两侧哪些词参与了对齐。
({int length, List<bool> refMatched, List<bool> asrMatched}) _lcs(
  List<String> ref,
  List<String> asr,
) {
  final int n = ref.length;
  final int m = asr.length;
  final List<List<int>> dp = List<List<int>>.generate(
    n + 1,
    (_) => List<int>.filled(m + 1, 0),
  );
  for (int i = n - 1; i >= 0; i--) {
    for (int j = m - 1; j >= 0; j--) {
      dp[i][j] = ref[i] == asr[j]
          ? dp[i + 1][j + 1] + 1
          : math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }

  final List<bool> refMatched = List<bool>.filled(n, false);
  final List<bool> asrMatched = List<bool>.filled(m, false);
  int i = 0;
  int j = 0;
  int length = 0;
  while (i < n && j < m) {
    if (ref[i] == asr[j]) {
      refMatched[i] = true;
      asrMatched[j] = true;
      length++;
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return (length: length, refMatched: refMatched, asrMatched: asrMatched);
}

/// 在一个空隙内做相似度对齐，返回确定配对的 (参考词, ASR 词) 下标对。
///
/// 两侧词数相同时按位置逐个配对（读音再不同也算错读）；数量不同时才按
/// 相似度配对，未配对的两侧分别保持漏读/多读。
List<({int refIndex, int asrIndex})> _pairGap(
  List<String> ref,
  int refFrom,
  int refTo,
  List<String> asr,
  int asrFrom,
  int asrTo,
) {
  final int n = refTo - refFrom;
  final int m = asrTo - asrFrom;
  if (n == 0 || m == 0) return const <({int refIndex, int asrIndex})>[];
  // 同位置一一对应：如原文 ABC、转录 ADC，B 判错读而不是漏读。
  if (n == m) {
    return <({int refIndex, int asrIndex})>[
      for (int i = 0; i < n; i++) (refIndex: refFrom + i, asrIndex: asrFrom + i),
    ];
  }

  final List<List<bool>> similar = List<List<bool>>.generate(
    n,
    (int i) => List<bool>.generate(
      m,
      (int j) => _similarity(ref[refFrom + i], asr[asrFrom + j]) > 0,
      growable: false,
    ),
    growable: false,
  );
  final List<List<int>> dp = List<List<int>>.generate(
    n + 1,
    (_) => List<int>.filled(m + 1, 0),
  );
  for (int i = n - 1; i >= 0; i--) {
    for (int j = m - 1; j >= 0; j--) {
      int best = math.max(dp[i + 1][j], dp[i][j + 1]);
      if (similar[i][j]) best = math.max(best, dp[i + 1][j + 1] + 1);
      dp[i][j] = best;
    }
  }

  final List<({int refIndex, int asrIndex})> pairs =
      <({int refIndex, int asrIndex})>[];
  int i = 0;
  int j = 0;
  while (i < n && j < m) {
    if (similar[i][j] && dp[i][j] == dp[i + 1][j + 1] + 1) {
      pairs.add((refIndex: refFrom + i, asrIndex: asrFrom + j));
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return pairs;
}

/// 两个归一化词是否像同一个词：共享词干，或编辑距离足够小。
///
/// 短词（≤5）只容 1 处差异，长词容 2 处，避免绝对阈值把短词随便配对。
double _similarity(String a, String b) {
  if (a == b) return 1;
  if (a.isEmpty || b.isEmpty) return 0;
  final Set<String> stems = lookupStems(a).toSet();
  if (lookupStems(b).any(stems.contains)) return 1;
  final int limit = math.max(a.length, b.length) <= 5 ? 1 : 2;
  return _levenshtein(a, b) <= limit ? 1 : 0;
}

/// 标准 Levenshtein 距离（按 UTF-16 码元计，词已归一化）。
int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  List<int> prev = List<int>.generate(b.length + 1, (int i) => i);
  List<int> cur = List<int>.filled(b.length + 1, 0);
  for (int i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (int j = 1; j <= b.length; j++) {
      final int cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = math.min(
        math.min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
    }
    final List<int> swap = prev;
    prev = cur;
    cur = swap;
  }
  return prev[b.length];
}
