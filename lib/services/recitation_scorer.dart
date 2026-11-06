// 背诵评分：归一化词序列对齐 + 可解释指标（纯 Dart，无 IO）。
//
// 只做词与时间这一层：覆盖率、插入、顺序、时长、停顿。
// 不做音素级发音或 tajweed 判断，也不在任何文案里这样宣称。

import 'dart:math' as math;

import 'package:arabic_learning/services/recitation_asr.dart';
import 'package:arabic_learning/services/recitation_audio.dart';
import 'package:arabic_learning/services/recitation_text.dart';

/// 门禁触发时的统一文案。
const String unclearSummary = '没听清，请靠近麦克风重录';

/// 低于该语音占比视为没听到有效内容。
const double minSpeechRatio = 0.2;

/// 短于该时长不做判定。
const double minAudioSeconds = 2;

const double _lowCoverage = 0.35;
const double _lowAlignmentCoverage = 0.5;

enum RecitationIssueType { missing, extra, order, pause, tooFast, tooSlow, unclear }

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

  final ({int length, List<bool> refMatched, List<bool> asrMatched}) lcs =
      _lcs(refTokens, asrTokens);
  final double coverage = refTokens.isEmpty ? 0 : lcs.length / refTokens.length;
  final int timedWords =
      words.where((AsrWord w) => w.end > w.start).length;
  final double alignmentCoverage = refTokens.isEmpty
      ? 0
      : math.min(1, timedWords / refTokens.length);
  final double insertionRate =
      asrTokens.isEmpty ? 0 : (asrTokens.length - lcs.length) / asrTokens.length;
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
      );

  if (audioSeconds < minAudioSeconds || refTokens.isEmpty) {
    return gate(unclearSummary);
  }
  if (asrTruncated) {
    return gate('录音过长，未能完整识别，请分段重录');
  }
  if (analysis.speechRatio < minSpeechRatio) return gate(unclearSummary);
  if (coverage < _lowCoverage && alignmentCoverage < _lowAlignmentCoverage) {
    return gate(unclearSummary);
  }

  final double durationCompliance =
      (1 - (durationRatio - 1).abs() / 0.5).clamp(0.0, 1.0);
  final double fluency =
      (1 - 0.25 * analysis.pauses.length).clamp(0.0, 1.0);
  final int finalScore = (60 * coverage +
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

  // 漏读：参考词里没被命中的连续片段，最多列 3 处。
  int index = 0;
  while (index < refTokens.length && issues.length < 3) {
    if (lcs.refMatched[index]) {
      index++;
      continue;
    }
    final int from = index;
    while (index < refTokens.length && !lcs.refMatched[index]) {
      index++;
    }
    issues.add(RecitationIssue(
      type: RecitationIssueType.missing,
      text: refTokens.sublist(from, index).join(' '),
      detail: '这几个词没有听到',
    ));
  }

  // 多读：LCS 之外的词占 ASR 词数的比例过高时提示一次。
  if (insertionRate >= 0.25) {
    final List<String> extra = <String>[
      for (int i = 0; i < asrTokens.length; i++)
        if (!lcs.asrMatched[i]) asrTokens[i],
    ];
    issues.add(RecitationIssue(
      type: RecitationIssueType.extra,
      text: extra.join(' '),
      detail: '录到了课文里没有的词，可能是口误或重复',
    ));
  }

  if (orderRate < 0.9) {
    issues.add(RecitationIssue(
      type: RecitationIssueType.order,
      text: '顺序与课文不一致',
      detail: '这些词读到了，但先后顺序和课文不同',
    ));
  }

  for (int i = 0; i < analysis.pauses.length && i < 3; i++) {
    final ({double start, double end}) pause = analysis.pauses[i];
    issues.add(RecitationIssue(
      type: RecitationIssueType.pause,
      text: '第 ${i + 1} 处停顿',
      detail: '这里停了 ${(pause.end - pause.start).toStringAsFixed(1)} 秒，建议再顺一遍',
    ));
  }

  if (durationRatio < 0.6) {
    issues.add(const RecitationIssue(
      type: RecitationIssueType.tooFast,
      text: '整体偏快',
      detail: '比正常背诵快不少，注意把每个词读完整',
    ));
  } else if (durationRatio > 1.6) {
    issues.add(const RecitationIssue(
      type: RecitationIssueType.tooSlow,
      text: '整体偏慢',
      detail: '比正常背诵慢不少，可以再连贯一些',
    ));
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
    summary: '覆盖 ${(coverage * 100).round()}%，用时 ${audioSeconds.toStringAsFixed(1)} 秒',
  );
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
  final List<List<int>> dp =
      List<List<int>>.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
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
