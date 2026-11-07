// 背诵分析入口：解码 → 能量分析 → 切段 → 逐段识别 → 评分 → 存档。
// Web 端不启用（由调用方挡住），这里直接抛错避免半途失败。

import 'dart:convert';
import 'dart:typed_data';

import 'package:arabic_learning/package_replacement/fake_dart_io.dart'
    if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/services/recitation_asr.dart';
import 'package:arabic_learning/services/recitation_audio.dart';
import 'package:arabic_learning/services/recitation_scorer.dart';
import 'package:arabic_learning/services/recitation_store.dart';
import 'package:arabic_learning/services/recitation_text.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';

final Logger _logger = Logger('Recitation');

class RecitationService {
  /// 课文 hash（与存档键一致）；界面用它查询历史成绩。
  static String textHash(String reference) =>
      sha1.convert(utf8.encode(normalizeArabic(reference))).toString();

  /// 分析一段录音；[onStatus] 用于把中文进度文案显示在界面上。
  Future<RecitationOutcome> analyze({
    required String reference,
    required String wavPath,
    void Function(String status)? onStatus,
  }) async {
    if (kIsWeb) throw UnsupportedError('网页端暂不支持本地录音评分');

    final Stopwatch watch = Stopwatch()..start();
    onStatus?.call('正在分析录音…');
    final Uint8List bytes = (await io.File(wavPath).readAsBytes()) as Uint8List;
    final Float32List samples = decodeWav16(bytes);
    final SpeechAnalysis speech = analysis(samples);
    final List<({Float32List samples, double start})> segments =
        splitSegments(samples);
    final double audioSeconds = samples.length / recitationSampleRate;
    _logger.info(
        '分析开始: wav=$wavPath, bytes=${bytes.length}, 时长=${audioSeconds.toStringAsFixed(2)}s, '
        '语音占比=${speech.speechRatio.toStringAsFixed(3)}, 停顿=${speech.pauses.length}, '
        '段数=${segments.length}, 解码=${watch.elapsedMilliseconds}ms');

    final RecitationAsr asr = RecitationAsr();
    final List<AsrWord> words = <AsrWord>[];
    for (int i = 0; i < segments.length; i++) {
      onStatus?.call('正在识别第 ${i + 1}/${segments.length} 段…');
      final ({Float32List samples, double start}) segment = segments[i];
      final List<AsrWord> segmentWords =
          await asr.transcribe(segment.samples);
      _logger.info(
          '第 ${i + 1}/${segments.length} 段: 起点=${segment.start.toStringAsFixed(2)}s, '
          '词数=${segmentWords.length}');
      for (final AsrWord word in segmentWords) {
        words.add(AsrWord(
          text: word.text,
          start: word.start + segment.start,
          end: word.end + segment.start,
        ));
      }
    }

    final RecitationOutcome outcome = score(
      reference: reference,
      words: words,
      analysis: speech,
      audioSeconds: audioSeconds,
      // 长录音已在 splitSegments 里切段，识别一定覆盖完整录音。
      asrTruncated: false,
    );
    _logger.info(
        '分析完成: ${watch.elapsedMilliseconds}ms, 识别词数=${words.length}, '
        'scoreable=${outcome.scoreable}, score=${outcome.score}, grade=${outcome.grade}, '
        'coverage=${outcome.coverage.toStringAsFixed(3)}, '
        'insertion=${outcome.insertionRate.toStringAsFixed(3)}, '
        'order=${outcome.orderRate.toStringAsFixed(3)}, '
        'duration=${outcome.durationRatio.toStringAsFixed(2)}, '
        'issues=${outcome.issues.length}, summary="${outcome.summary}"');

    if (outcome.scoreable && outcome.score != null) {
      await RecitationStore().save(RecitationRecord(
        hash: textHash(reference),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        score: outcome.score!,
        coverage: outcome.coverage,
      ));
      _logger.info('成绩已保存: hash=${textHash(reference)}, score=${outcome.score}');
    }
    return outcome;
  }
}
