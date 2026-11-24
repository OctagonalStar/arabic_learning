// 听抄训练：遍数编排与配置（固定四遍，对齐专业四级听写）。
//
// 纯数据与估算，不依赖 Flutter 组件，便于单测。

import 'package:arabic_learning/core/recitation_text.dart' show estimateSeconds;
import 'package:flutter/foundation.dart' show immutable;

/// 正常遍句间固定留白（秒）：专业四级的第一、四遍是整篇连读，不留书写间隔。
const double dictationNormalSentenceGap = 0.0;

/// 单遍的播放方式。
enum DictationPassKind {
  /// 正常语速，整篇连读（仅换句处有播放器自身的极短间隙）。
  normal,

  /// 稍慢语速，每句后留出用户设置的书写间隔。
  slow,
}

/// 专业四级听写固定为：正常 → 慢速逐句 → 慢速逐句 → 正常。
const List<DictationPassKind> dictationPasses = <DictationPassKind>[
  DictationPassKind.normal,
  DictationPassKind.slow,
  DictationPassKind.slow,
  DictationPassKind.normal,
];

@immutable
class DictationConfig {
  /// 第一、四遍的语速。
  final double normalSpeed;

  /// 第二、三遍的语速。
  final double slowSpeed;

  /// 慢速遍每句后的书写间隔（秒）。
  final int sentenceInterval;

  /// 两遍之间的准备时间（秒）。
  final int passInterval;

  /// 开始前的倒计时（秒）。
  final int countdown;

  /// 第四遍结束后的校对时间（秒）。
  final int finalCheck;

  const DictationConfig({
    this.normalSpeed = 1.0,
    this.slowSpeed = 0.7,
    this.sentenceInterval = 10,
    this.passInterval = 15,
    this.countdown = 20,
    this.finalCheck = 60,
  });

  DictationConfig copyWith({
    double? normalSpeed,
    double? slowSpeed,
    int? sentenceInterval,
    int? passInterval,
    int? countdown,
    int? finalCheck,
  }) {
    return DictationConfig(
      normalSpeed: normalSpeed ?? this.normalSpeed,
      slowSpeed: slowSpeed ?? this.slowSpeed,
      sentenceInterval: sentenceInterval ?? this.sentenceInterval,
      passInterval: passInterval ?? this.passInterval,
      countdown: countdown ?? this.countdown,
      finalCheck: finalCheck ?? this.finalCheck,
    );
  }
}

/// 粗略估算总耗时（秒），只用于配置页提示，不参与播放计时。
int estimateDictationSeconds(
  List<String> sentences,
  DictationConfig config,
) {
  double total = config.countdown.toDouble();
  final int passGaps = dictationPasses.length - 1;
  total += passGaps * config.passInterval;
  total += config.finalCheck;
  for (final DictationPassKind kind in dictationPasses) {
    final double speed =
        kind == DictationPassKind.normal ? config.normalSpeed : config.slowSpeed;
    for (final String sentence in sentences) {
      total += estimateSeconds(sentence) / speed;
      total += kind == DictationPassKind.slow
          ? config.sentenceInterval
          : dictationNormalSentenceGap;
    }
  }
  return total.round();
}
