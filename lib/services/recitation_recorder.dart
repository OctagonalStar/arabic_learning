// 背诵录音：`record` 的薄封装，固定 16k / 单声道 / WAV。

import 'package:arabic_learning/services/recitation_audio.dart'
    show recitationSampleRate;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:record/record.dart';

class RecitationRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;

  /// `record` 覆盖原生五端；Web 端不启用本地评分。
  static bool get supported => !kIsWeb;

  Future<bool> ensurePermission() async {
    if (!supported) return false;
    return _recorder.hasPermission();
  }

  Future<void> start() async {
    if (!supported) throw UnsupportedError('当前平台不支持录音');
    final dir = await path_provider.getTemporaryDirectory();
    final String path = '${dir.path}/recitation.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        numChannels: 1,
        sampleRate: recitationSampleRate,
        echoCancel: false,
        noiseSuppress: false,
      ),
      path: path,
    );
    _path = path;
  }

  /// 停止录音，返回 WAV 文件路径。
  Future<String> stop() async {
    final String? stopped = await _recorder.stop();
    final String? path = stopped ?? _path;
    _path = null;
    if (path == null) throw StateError('没有正在进行的录音');
    return path;
  }

  Future<void> cancel() async {
    _path = null;
    if (!supported) return;
    await _recorder.cancel();
  }

  Future<void> dispose() async {
    _path = null;
    if (!supported) return;
    await _recorder.dispose();
  }
}
