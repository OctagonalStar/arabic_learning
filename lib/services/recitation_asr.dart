// 本地 sherpa-onnx Whisper 识别封装（背诵辅助用）。
// Web 与模型缺失时返回空列表，由调用方提示下载模型。

import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/model_manager.dart';
import 'package:arabic_learning/services/web_asr_globals.dart';
import 'package:arabic_learning/services/web_model_store.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';

/// 识别出的一个词及其在音频中的起止时间（秒）。
class AsrWord {
  final String text;
  final double start;
  final double end;

  const AsrWord({required this.text, required this.start, required this.end});
}

/// sherpa 的分词标记：空格、▁（sentencepiece）、Ġ（Whisper BPE）。
const String _boundaryChars = ' \u2581\u0120';

final Logger _logger = Logger('RecitationAsr');

class RecitationAsr {
  /// 识别一段 16k 单声道音频。
  ///
  /// 每次调用创建并释放 recognizer（Whisper tiny 常驻内存不值得），
  /// 模型未下载时返回空列表。
  Future<List<AsrWord>> transcribe(
    Float32List samples, {
    int sampleRate = 16000,
  }) async {
    if (samples.isEmpty) return const <AsrWord>[];

    final String id = AppData().preferredAsrModelId;
    final AsrModelFiles? files;
    final String dir;
    if (kIsWeb) {
      final WebModelMeta? meta = WebModelStore.metaOf(id);
      if (meta == null) {
        _logger.info('识别模型未下载: $id');
        return const <AsrWord>[];
      }
      dir = 'models/$id';
      files = ModelManager.resolveAsrNames(meta.names);
    } else {
      dir = '${AppData().basePath.path}/${AppData().preferredAsrModelDir}';
      files = ModelManager.resolveAsr(dir);
    }
    if (files == null) {
      _logger.info('识别模型未下载: $dir');
      return const <AsrWord>[];
    }

    await sherpa_onnx.initBindingsAsync();
    if (kIsWeb) {
      await exposeSherpaOnnxAsrGlobals();
      await WebModelStore.mount(
        id,
        files: files.nemoCtc
            ? <String>[files.model, files.tokens]
            : <String>[files.encoder!, files.decoder!, files.tokens],
      );
    }
    final String family = files.nemoCtc ? 'NeMo CTC' : 'Whisper';
    _logger.info(
        '识别模型: 家族=$family, model=${files.model}, '
        'encoder=${files.encoder ?? '-'}, decoder=${files.decoder ?? '-'}, '
        'tokens=${files.tokens}');
    final sherpa_onnx.OfflineModelConfig modelConfig;
    if (files.nemoCtc) {
      modelConfig = sherpa_onnx.OfflineModelConfig(
        nemoCtc: sherpa_onnx.OfflineNemoEncDecCtcModelConfig(
          model: '$dir/${files.model}',
        ),
        tokens: '$dir/${files.tokens}',
        // wasm 是单线程构建，多线程参数只会刷警告。
        numThreads: kIsWeb ? 1 : 2,
        debug: false,
        provider: 'cpu',
      );
    } else {
      modelConfig = sherpa_onnx.OfflineModelConfig(
        whisper: sherpa_onnx.OfflineWhisperModelConfig(
          encoder: '$dir/${files.encoder}',
          decoder: '$dir/${files.decoder}',
          language: 'ar',
          task: 'transcribe',
          // 发布包的 tiny-*.onnx 未导出 cross-attention，开启只会刷警告且时间戳恒空；
          // 词级时间由 _wordsFrom 均匀回退，评分不依赖精确时间。
          enableTokenTimestamps: false,
        ),
        tokens: '$dir/${files.tokens}',
        // wasm 是单线程构建，多线程参数只会刷警告。
        numThreads: kIsWeb ? 1 : 2,
        debug: false,
        provider: 'cpu',
      );
    }
    final sherpa_onnx.OfflineRecognizerConfig config =
        sherpa_onnx.OfflineRecognizerConfig(model: modelConfig);
    _logger.info(
        '识别开始: 模型=${AppData().preferredAsrModelId}, 采样=${samples.length}, 时长=${(samples.length / sampleRate).toStringAsFixed(2)}s');

    sherpa_onnx.OfflineRecognizer? recognizer;
    sherpa_onnx.OfflineStream? stream;
    final Stopwatch watch = Stopwatch()..start();
    try {
      recognizer = sherpa_onnx.OfflineRecognizer(config);
      stream = recognizer.createStream();
      stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
      recognizer.decode(stream);
      final sherpa_onnx.OfflineRecognizerResult result =
          recognizer.getResult(stream);
      final List<AsrWord> words = _wordsFrom(
        result.tokens,
        result.timestamps,
        result.text,
        samples.length / sampleRate,
      );
      _logger.info(
          '识别完成: ${watch.elapsedMilliseconds}ms, tokens=${result.tokens.length}, '
          'timestamps=${result.timestamps.length}, words=${words.length}, '
          'text="${result.text.trim()}"');
      return words;
    } catch (e, s) {
      _logger.severe('识别失败: 模型=${AppData().preferredAsrModelId}', e, s);
      rethrow;
    } finally {
      stream?.free();
      recognizer?.free();
    }
  }
}

/// 把 token 序列合并成词。
///
/// token 以空格 / ▁ / Ġ 开头表示新词；若模型直接给出整词 token（无标记），
/// 则一个 token 当一个词。时间戳是 token 起点，词末用下一个词起点近似。
List<AsrWord> _wordsFrom(
  List<String> tokens,
  List<double> timestamps,
  String fallbackText,
  double durationSeconds,
) {
  final List<({String text, double start})> pieces =
      <({String text, double start})>[];
  final bool marked = tokens.any(
    (String t) => t.isNotEmpty && _boundaryChars.contains(t[0]),
  );

  double timestampAt(int i) {
    if (timestamps.isEmpty) {
      return tokens.isEmpty ? 0 : durationSeconds * i / tokens.length;
    }
    return timestamps[i < timestamps.length ? i : timestamps.length - 1];
  }

  if (marked) {
    final StringBuffer buffer = StringBuffer();
    double start = 0;
    for (int i = 0; i < tokens.length; i++) {
      final String piece =
          tokens[i].replaceFirst(RegExp(r'^[ \u2581\u0120]+'), '');
      if (piece.trim().isEmpty) continue;
      final double ts = timestampAt(i);
      if (_boundaryChars.contains(tokens[i][0]) && buffer.isNotEmpty) {
        pieces.add((text: buffer.toString(), start: start));
        buffer.clear();
      }
      if (buffer.isEmpty) start = ts;
      buffer.write(piece);
    }
    if (buffer.isNotEmpty) pieces.add((text: buffer.toString(), start: start));
  } else {
    for (int i = 0; i < tokens.length; i++) {
      final double ts = timestampAt(i);
      for (final String part in tokens[i].trim().split(RegExp(r'\s+'))) {
        if (part.isNotEmpty) pieces.add((text: part, start: ts));
      }
    }
  }

  if (pieces.isEmpty) {
    // 没有 token 时退回纯文本：均匀铺满整段时间，只用于覆盖率对齐。
    final List<String> words = fallbackText.trim().split(RegExp(r'\s+'));
    final List<String> kept = words.where((String w) => w.isNotEmpty).toList();
    return List<AsrWord>.generate(kept.length, (int i) {
      final double start = durationSeconds * i / kept.length;
      return AsrWord(
        text: kept[i],
        start: start,
        end: durationSeconds * (i + 1) / kept.length,
      );
    });
  }

  return List<AsrWord>.generate(pieces.length, (int i) {
    return AsrWord(
      text: pieces[i].text.trim(),
      start: pieces[i].start,
      end: i + 1 < pieces.length ? pieces[i + 1].start : durationSeconds,
    );
  });
}
