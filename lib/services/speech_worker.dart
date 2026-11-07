// 本地语音（sherpa-onnx TTS / ASR）后台执行门面。
//
// 原生端把模型加载与推理放到常驻后台 isolate，主线程只做落盘 / 播放，
// 否则 VITS 合成与 Whisper 解码会把 UI 冻住数秒。Web 没有 dart:isolate，
// 由 stub 保持「不支持」，调用方在 kIsWeb 分支走原来的主线程实现。
//
// config 参数故意用 Object：sherpa_onnx 的配置类是纯 Dart 值对象，可以跨
// isolate 传递，门面因此不需要 import sherpa_onnx。

import 'dart:typed_data';

import 'speech_worker_stub.dart'
    if (dart.library.io) 'speech_worker_io.dart' as impl;

class SpeechWorker {
  const SpeechWorker._();

  /// 当前平台是否支持后台语音处理（仅原生端）。
  static bool get supported => impl.supported;

  /// 后台 worker 是否存活（Web 恒为 false）。
  static bool get alive => impl.alive;

  /// 在后台加载 TTS 模型。[key] 相同则复用已加载实例（含语速等配置）。
  static Future<void> loadTts(Object config, {required String key}) =>
      impl.loadTts(config, key: key);

  /// 后台合成一段语音。
  static Future<({Float32List samples, int sampleRate})> synthesize({
    required String text,
    required double speed,
  }) => impl.synthesize(text: text, speed: speed);

  /// 后台识别一段 16k 单声道音频。
  static Future<({List<String> tokens, List<double> timestamps, String text})>
      transcribe({
    required Float32List samples,
    required int sampleRate,
    required Object config,
  }) => impl.transcribe(
        samples: samples,
        sampleRate: sampleRate,
        config: config,
      );

  /// 释放后台 TTS 模型（切换 / 删除模型前调用）。
  static void resetTts() => impl.resetTts();
}
