import 'package:arabic_learning/screens/test/dictation/dictation_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('听抄固定四遍：正常 → 慢速 → 慢速 → 正常', () {
    expect(
      dictationPasses,
      <DictationPassKind>[
        DictationPassKind.normal,
        DictationPassKind.slow,
        DictationPassKind.slow,
        DictationPassKind.normal,
      ],
    );
  });

  test('总耗时包含倒计时、遍间准备与慢速句间隔', () {
    const DictationConfig config = DictationConfig(
      countdown: 10,
      passInterval: 5,
      sentenceInterval: 3,
    );
    final int seconds = estimateDictationSeconds(
      <String>['الجملة الأولى.', 'الجملة الثانية.'],
      config,
    );

    // 10 秒倒计时 + 3 次遍间准备 + 60 秒校对 + 两遍慢速各 2 句 × 3 秒。
    expect(seconds, greaterThan(10 + 15 + 60 + 12));
  });
}
