import 'package:arabic_learning/services/recitation_asr.dart';
import 'package:arabic_learning/services/recitation_audio.dart';
import 'package:arabic_learning/services/recitation_scorer.dart';
import 'package:arabic_learning/services/recitation_text.dart';
import 'package:flutter_test/flutter_test.dart';

const String _reference = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

List<AsrWord> _words(List<String> texts) => <AsrWord>[
  for (int i = 0; i < texts.length; i++)
    AsrWord(text: texts[i], start: i * 0.5, end: i * 0.5 + 0.4),
];

SpeechAnalysis _speech({int pauses = 0}) => SpeechAnalysis(
  speechRatio: 0.9,
  pauses: <({double start, double end})>[
    for (int i = 0; i < pauses; i++) (start: 1.0 + i * 3, end: 2.5 + i * 3),
  ],
);

RecitationOutcome _score({
  required List<AsrWord> words,
  SpeechAnalysis? analysis,
  double? audioSeconds,
  String reference = _reference,
}) => score(
  reference: reference,
  words: words,
  analysis: analysis ?? _speech(),
  audioSeconds: audioSeconds ?? estimateSeconds(reference),
  asrTruncated: false,
);

void main() {
  test('完全背对 -> 100 分 A', () {
    final RecitationOutcome outcome = _score(
      words: _words(tokenize(_reference)),
    );
    expect(outcome.scoreable, isTrue);
    expect(outcome.score, 100);
    expect(outcome.grade, 'A');
    expect(outcome.durationRatio, closeTo(1, 0.001));
    expect(outcome.issues, isEmpty);
    expect(outcome.marks.length, tokenize(_reference).length);
    expect(outcome.marks, everyElement(RecitationTokenMark.matched));
    expect(outcome.heard.every((String? h) => h == null), isTrue);
  });

  test('漏掉中间几个词 -> 覆盖率下降并给出 missing', () {
    final List<String> tokens = tokenize(_reference);
    final RecitationOutcome outcome = _score(
      words: _words(<String>[tokens[0], tokens[1], tokens[3]]),
    );
    expect(outcome.scoreable, isTrue);
    expect(outcome.coverage, closeTo(0.75, 0.001));
    final RecitationIssue missing = outcome.issues.firstWhere(
      (RecitationIssue i) => i.type == RecitationIssueType.missing,
    );
    expect(missing.text, tokens[2]);
    expect(outcome.marks.length, tokens.length);
    expect(outcome.marks[2], RecitationTokenMark.missing);
    expect(outcome.heard.every((String? h) => h == null), isTrue);
  });

  test('读成近音词 -> misread 而不是 missing / extra', () {
    final List<String> tokens = tokenize(_reference);
    final List<String> heard = <String>[...tokens];
    heard[2] = 'الرحمان';
    final RecitationOutcome outcome = _score(words: _words(heard));

    expect(outcome.scoreable, isTrue);
    expect(outcome.marks.length, tokens.length);
    expect(outcome.marks[2], RecitationTokenMark.misread);
    expect(outcome.heard[2], 'الرحمان');
    expect(outcome.heard.whereType<String>(), <String>['الرحمان']);
    for (int i = 0; i < tokens.length; i++) {
      if (i != 2) expect(outcome.marks[i], RecitationTokenMark.matched);
    }
    expect(
      outcome.issues.any(
        (RecitationIssue i) => i.type == RecitationIssueType.missing,
      ),
      isFalse,
    );
    final RecitationIssue misread = outcome.issues.firstWhere(
      (RecitationIssue i) => i.type == RecitationIssueType.misread,
    );
    expect(misread.text, '${tokens[2]} → الرحمان');
    expect(misread.detail, '这个词读成了别的词');
    // 错读不再算插入，也不出现在多读里。
    expect(outcome.insertionRate, 0);
    expect(
      outcome.issues.any(
        (RecitationIssue i) => i.type == RecitationIssueType.extra,
      ),
      isFalse,
    );
  });

  test('同位置词数相同：读音完全不同也判错读，不算漏读', () {
    final List<String> tokens = tokenize(_reference);
    final String heardWord = tokenize('مدرسة').single;
    final RecitationOutcome outcome = _score(
      words: _words(<String>[tokens[0], tokens[1], 'مدرسة', tokens[3]]),
    );

    expect(outcome.marks[2], RecitationTokenMark.misread);
    expect(outcome.heard[2], heardWord);
    for (int i = 0; i < tokens.length; i++) {
      if (i != 2) expect(outcome.marks[i], RecitationTokenMark.matched);
    }
    expect(
      outcome.issues.any(
        (RecitationIssue i) => i.type == RecitationIssueType.missing,
      ),
      isFalse,
    );
    expect(outcome.insertionRate, 0);
    final RecitationIssue misread = outcome.issues.firstWhere(
      (RecitationIssue i) => i.type == RecitationIssueType.misread,
    );
    expect(misread.text, '${tokens[2]} → $heardWord');
  });

  test('连续错读合成一条提示，最多 3 对', () {
    final List<String> tokens = tokenize(_reference);
    final RecitationOutcome outcome = _score(
      words: _words(<String>[tokens[0], tokens[1], 'الرحمان', 'رحيم']),
    );

    expect(outcome.marks[2], RecitationTokenMark.misread);
    expect(outcome.marks[3], RecitationTokenMark.misread);
    final Iterable<RecitationIssue> misreads = outcome.issues.where(
      (RecitationIssue i) => i.type == RecitationIssueType.misread,
    );
    expect(misreads.length, 1);
    expect(
      misreads.single.text,
      '${tokens[2]} → الرحمان · ${tokens[3]} → رحيم',
    );
  });

  test('transcript 是 ASR 词用空格连接', () {
    final RecitationOutcome outcome = _score(
      words: _words(<String>['بسم', ' الله ', 'الرحمن', '']),
    );
    expect(outcome.transcript, 'بسم الله الرحمن');
    expect(outcome.marks.length, tokenize(_reference).length);
  });

  test('门禁结果带 transcript，marks / heard 为空', () {
    final RecitationOutcome outcome = _score(
      words: _words(tokenize(_reference)),
      audioSeconds: 1.5,
    );
    expect(outcome.scoreable, isFalse);
    expect(outcome.marks, isEmpty);
    expect(outcome.heard, isEmpty);
    expect(outcome.transcript, tokenize(_reference).join(' '));
  });

  test('多读了词 -> 插入率上升', () {
    final RecitationOutcome outcome = _score(
      words: _words(<String>[...tokenize(_reference), 'زيادة', 'كلام']),
    );
    expect(outcome.insertionRate, closeTo(2 / 6, 0.001));
    expect(
      outcome.issues.any(
        (RecitationIssue i) => i.type == RecitationIssueType.extra,
      ),
      isTrue,
    );
  });

  test('一个词都没命中 -> 不给分', () {
    final RecitationOutcome outcome = _score(
      reference: 'بسم الله الرحمن الرحيم رب العالمين',
      words: _words(<String>['خطأ', 'كلام']),
    );
    expect(outcome.scoreable, isFalse);
    expect(outcome.score, isNull);
    expect(outcome.grade, isNull);
    expect(outcome.summary, '没听清，请靠近麦克风重录');
    expect(outcome.issues.single.type, RecitationIssueType.unclear);
  });

  test('识别结果退化成同一个词反复 -> 不给分', () {
    final RecitationOutcome outcome = _score(
      words: _words(List<String>.filled(10, 'ألغاء')),
    );
    expect(outcome.scoreable, isFalse);
    expect(outcome.score, isNull);
    expect(outcome.summary, unclearSummary);
  });

  test('录音短于 2 秒 -> 不给分', () {
    final RecitationOutcome outcome = _score(
      words: _words(tokenize(_reference)),
      audioSeconds: 1.5,
    );
    expect(outcome.scoreable, isFalse);
    expect(outcome.score, isNull);
    expect(outcome.summary, '没听清，请靠近麦克风重录');
  });

  test('停顿拉低流利度并给出 pause 提示', () {
    final RecitationOutcome outcome = _score(
      words: _words(tokenize(_reference)),
      analysis: _speech(pauses: 1),
    );
    expect(outcome.scoreable, isTrue);
    expect(outcome.score, lessThan(100));
    expect(
      outcome.issues.any(
        (RecitationIssue i) => i.type == RecitationIssueType.pause,
      ),
      isTrue,
    );
  });
}
