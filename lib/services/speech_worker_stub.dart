// Web / 不支持 isolate 的平台实现：只用于让门面能编译，调用即报错。
// 调用方必须先用 SpeechWorker.supported 或 kIsWeb 分流。

import 'dart:typed_data';

const bool supported = false;
const bool alive = false;

Never _unsupported() => throw UnsupportedError('当前平台不支持后台语音处理');

Future<void> loadTts(Object config, {required String key}) async =>
    _unsupported();

Future<({Float32List samples, int sampleRate})> synthesize({
  required String text,
  required double speed,
}) async =>
    _unsupported();

Future<({List<String> tokens, List<double> timestamps, String text})>
    transcribe({
  required Float32List samples,
  required int sampleRate,
  required Object config,
}) async =>
        _unsupported();

void resetTts() {}
