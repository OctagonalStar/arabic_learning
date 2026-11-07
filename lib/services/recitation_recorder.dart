// 背诵录音：`record` 的薄封装，固定 16k / 单声道 / WAV。

import 'package:arabic_learning/services/recitation_audio.dart'
    show recitationSampleRate;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:logging/logging.dart';
import 'package:record/record.dart';

final Logger _logger = Logger('RecitationRecorder');

class RecitationRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;

  /// `record` 覆盖原生六端；Web 端录音交给浏览器，评分也在本地 wasm 里做。
  static bool get supported => true;

  Future<bool> ensurePermission() async {
    if (!supported) return false;
    final bool granted = await _recorder.hasPermission();
    _logger.info('麦克风权限: ${granted ? "已授权" : "被拒绝"}');
    return granted;
  }

  Future<void> start() async {
    if (!supported) throw UnsupportedError('当前平台不支持录音');
    // Web 的 record 实现忽略 path，stop() 返回 blob URL。
    final String path = kIsWeb
        ? 'recitation.wav'
        : '${(await path_provider.getTemporaryDirectory()).path}/recitation.wav';
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
    _logger.info('录音开始: $path');
  }

  /// 停止录音，返回 WAV 文件路径。
  Future<String> stop() async {
    final String? stopped = await _recorder.stop();
    final String? path = stopped ?? _path;
    _path = null;
    if (path == null) throw StateError('没有正在进行的录音');
    _logger.info('录音结束: $path');
    return path;
  }

  Future<void> cancel() async {
    _logger.info('录音取消');
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
