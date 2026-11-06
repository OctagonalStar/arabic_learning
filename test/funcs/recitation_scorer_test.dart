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
}) =>
    score(
      reference: reference,
      words: words,
      analysis: analysis ?? _speech(),
      audioSeconds: audioSeconds ?? estimateSeconds(reference),
      asrTruncated: false,
    );

void main() {
  test('完全背对 -> 100 分 A', () {
    final RecitationOutcome outcome =
        _score(words: _words(tokenize(_reference)));
    expect(outcome.scoreable, isTrue);
    expect(outcome.score, 100);
    expect(outcome.grade, 'A');
    expect(outcome.durationRatio, closeTo(1, 0.001));
    expect(outcome.issues, isEmpty);
  });

  test('漏掉中间几个词 -> 覆盖率下降并给出 missing', () {
    final List<String> tokens = tokenize(_reference);
    final RecitationOutcome outcome = _score(words: _words(<String>[
      tokens[0],
      tokens[1],
      tokens[3],
    ]));
    expect(outcome.scoreable, isTrue);
    expect(outcome.coverage, closeTo(0.75, 0.001));
    final RecitationIssue missing = outcome.issues.firstWhere(
      (RecitationIssue i) => i.type == RecitationIssueType.missing,
    );
    expect(missing.text, tokens[2]);
  });

  test('多读了词 -> 插入率上升', () {
    final RecitationOutcome outcome = _score(
      words: _words(<String>[
        ...tokenize(_reference),
        'زيادة',
        'كلام',
      ]),
    );
    expect(outcome.insertionRate, closeTo(2 / 6, 0.001));
    expect(
      outcome.issues.any((RecitationIssue i) => i.type == RecitationIssueType.extra),
      isTrue,
    );
  });

  test('覆盖率与对齐覆盖率同时偏低 -> 不给分', () {
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

  test('录音短于 2 秒 -> 不给分', () {
    final RecitationOutcome outcome =
        _score(words: _words(tokenize(_reference)), audioSeconds: 1.5);
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
      outcome.issues.any((RecitationIssue i) => i.type == RecitationIssueType.pause),
      isTrue,
    );
  });
}
