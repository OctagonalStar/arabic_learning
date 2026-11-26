import 'package:arabic_learning/models/reading.dart';
import 'package:arabic_learning/models/recitation_text.dart';
import 'package:arabic_learning/screens/test/dictation/dictation_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('听抄固定四遍：正常 → 慢速 → 慢速 → 正常', () {
    expect(dictationPasses, <DictationPassKind>[
      DictationPassKind.normal,
      DictationPassKind.slow,
      DictationPassKind.slow,
      DictationPassKind.normal,
    ]);
  });

  test('总耗时包含倒计时、遍间准备与慢速句间隔', () {
    const DictationConfig config = DictationConfig(
      countdown: 10,
      passInterval: 5,
      sentenceInterval: 3,
    );
    final int seconds = estimateDictationSeconds(<String>[
      'الجملة الأولى.',
      'الجملة الثانية.',
    ], config);

    // 10 秒倒计时 + 3 次遍间准备 + 60 秒校对 + 两遍慢速各 2 句 × 3 秒。
    expect(seconds, greaterThan(10 + 15 + 60 + 12));
  });

  test('阅读题与课文都能转成听抄文本', () {
    const ReadingUnit reading = ReadingUnit(
      type: 1,
      title: '阅读文章',
      passage: 'الجملة الأولى. الجملة الثانية.',
      difficulty: 4,
      tashkeel: false,
      questions: <ReadingQuestion>[],
      corrects: <int>[],
      tags: <String>[],
    );
    const RecitationTextUnit recitation = RecitationTextUnit(
      title: '背诵课文',
      difficulty: 6,
      sentences: <RecitationSentence>[
        RecitationSentence(arabic: 'الجملة الأولى.', translation: '第一句'),
        RecitationSentence(arabic: 'الجملة الثانية.', translation: '第二句'),
      ],
    );

    final DictationArticle fromReading = DictationArticle.fromReading(reading);
    final DictationArticle fromRecitation = DictationArticle.fromRecitation(
      recitation,
    );

    expect(fromReading.sourceLabel, "阅读理解");
    expect(fromReading.passage, reading.passage);
    expect(fromRecitation.sourceLabel, "课文背诵");
    expect(fromRecitation.passage, recitation.reference);
    expect(fromReading.key, isNot(fromRecitation.key));
  });
}
