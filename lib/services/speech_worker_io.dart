// 原生端后台语音 isolate：常驻一个 worker，负责 sherpa-onnx 的 TTS 加载/合成
// 与 Whisper / NeMo ASR 解码。主 isolate 只发消息、收结果，不碰 ONNX 推理。
//
// 说明：
// - 每个 isolate 有独立的静态状态，因此 worker 内必须自己 initBindings()；
// - 配置对象（OfflineTtsConfig / OfflineRecognizerConfig）是纯 Dart 值对象，
//   可以直接 send；
// - worker 崩溃（errorsAreFatal）时把所有在途请求回错，下次调用重新拉起。

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

final Logger _logger = Logger('SpeechWorker');

const bool supported = true;

/// worker 是否存活；崩溃后调用方据此重新加载模型。
bool get alive => _commands != null;

ReceivePort? _replies;
ReceivePort? _exits;
SendPort? _commands;
Future<void>? _starting;
Completer<void>? _startGate;
Completer<SendPort?>? _handshake;
final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};
int _nextId = 1;

Future<SendPort> _ensureWorker() async {
  final SendPort? ready = _commands;
  if (ready != null) return ready;

  final Future<void>? starting = _starting;
  if (starting != null) {
    await starting;
    return _commands!;
  }

  final Completer<void> gate = Completer<void>();
  // 首个调用方只等 handshake（失败时 gate 可能先带错误完成），
  // ignore() 避免「无人监听」被报成未处理异步异常。
  gate.future.ignore();
  _starting = gate.future;
  _startGate = gate;

  final ReceivePort replies = ReceivePort();
  final ReceivePort exits = ReceivePort();
  _replies = replies;
  _exits = exits;
  // 用可空结果而不是错误：worker 启动即崩溃时，退出口会先完成它，
  // 若此时还没有人 await，带错误的 future 会被报成未处理异常。
  final Completer<SendPort?> handshake = Completer<SendPort?>();
  _handshake = handshake;
  replies.listen((Object? message) {
    // 第一条消息是 worker 的指令端口，之后都是 [id, ok, payload] 回复。
    if (!handshake.isCompleted) {
      handshake.complete(message as SendPort);
      return;
    }
    _onReply(message);
  });
  exits.listen((_) => _onWorkerExit());

  try {
    await Isolate.spawn(
      _workerMain,
      replies.sendPort,
      onExit: exits.sendPort,
      errorsAreFatal: true,
      debugName: 'speech-worker',
    );
    final SendPort? commands = await handshake.future;
    // 握手期间 worker 可能已退出并清空状态：此时不能把死端口写回去。
    if (commands == null || _handshake != handshake) {
      throw StateError('语音后台已退出');
    }
    _commands = commands;
    gate.complete();
    return commands;
  } catch (e) {
    // 启动失败：清掉端口与状态，让下一次调用重新拉起。
    _clearWorker();
    if (!gate.isCompleted) gate.completeError(e);
    rethrow;
  }
}

void _onReply(Object? message) {
  final List<Object?> reply = message as List<Object?>;
  final int id = reply[0] as int;
  _pending.remove(id)?.complete(reply);
}

/// worker isolate 退出：所有在途请求都会永远等不到回复，必须立刻失败。
void _onWorkerExit() {
  // 旧端口的迟到消息（已重新拉起 worker）直接忽略。用端口判活而不是 isolate 句柄：
  // worker 可能在 Isolate.spawn 返回前就退出。
  if (_replies == null) return;
  final StateError error = StateError('语音后台已退出');
  final Completer<void>? gate = _startGate;
  final Completer<SendPort?>? handshake = _handshake;
  _clearWorker();
  // 启动握手中崩溃：让 _ensureWorker 结束等待并抛错，而不是永久挂起。
  if (handshake != null && !handshake.isCompleted) handshake.complete(null);
  for (final Completer<Object?> completer in _pending.values) {
    if (!completer.isCompleted) completer.completeError(error);
  }
  _pending.clear();
  if (gate != null && !gate.isCompleted) gate.completeError(error);
}

void _clearWorker() {
  _commands = null;
  _starting = null;
  _startGate = null;
  _handshake = null;
  _replies?.close();
  _exits?.close();
  _replies = null;
  _exits = null;
}

/// 发一条请求并等待 worker 的回复；worker 报错时抛 [StateError]。
Future<Object?> _request(Map<String, Object?> message) async {
  final int id = _nextId++;
  final Completer<Object?> completer = Completer<Object?>();
  _pending[id] = completer;
  final SendPort commands;
  try {
    commands = await _ensureWorker();
  } catch (_) {
    _pending.remove(id);
    rethrow;
  }
  commands.send(<String, Object?>{...message, 'id': id});
  final List<Object?> reply = await completer.future as List<Object?>;
  if (reply[1] as bool) return reply.length > 2 ? reply[2] : null;
  throw StateError('${reply[2]}');
}

Future<void> loadTts(Object config, {required String key}) async {
  await _request(<String, Object?>{'kind': 'loadTts', 'config': config, 'key': key});
}

Future<({Float32List samples, int sampleRate})> synthesize({
  required String text,
  required double speed,
}) async {
  final List<Object?> audio = await _request(<String, Object?>{
        'kind': 'tts',
        'text': text,
        'speed': speed,
      }) as List<Object?>;
  return (samples: audio[0] as Float32List, sampleRate: audio[1] as int);
}

Future<({List<String> tokens, List<double> timestamps, String text})>
    transcribe({
  required Float32List samples,
  required int sampleRate,
  required Object config,
}) async {
  final List<Object?> result = await _request(<String, Object?>{
        'kind': 'asr',
        'samples': samples,
        'sampleRate': sampleRate,
        'config': config,
      }) as List<Object?>;
  return (
    tokens: List<String>.from(result[0] as List),
    timestamps: List<double>.from(result[1] as List),
    text: result[2] as String,
  );
}

void resetTts() {
  // 不等回复：resetTTS 是同步接口，且 worker 不存在时无需处理。
  _commands?.send(<String, Object?>{'kind': 'resetTts'});
}

@pragma('vm:entry-point')
void _workerMain(SendPort toMain) {
  final ReceivePort commands = ReceivePort();
  toMain.send(commands.sendPort);
  sherpa_onnx.initBindings();

  sherpa_onnx.OfflineTts? tts;
  String? ttsKey;

  commands.listen((Object? message) {
    if (message is! Map) return;
    final int? id = message['id'] as int?;
    void reply(bool ok, Object? payload) {
      // resetTts 没有 id：执行即可，不需要回复。
      if (id != null) toMain.send(<Object?>[id, ok, payload]);
    }

    try {
      switch (message['kind']) {
        case 'loadTts':
          final String key = message['key'] as String;
          if (key != ttsKey) {
            // 先置空再建新实例：构造失败时不能留下指向已释放原生对象的引用。
            tts?.free();
            tts = null;
            ttsKey = null;
            tts = sherpa_onnx.OfflineTts(
              message['config'] as sherpa_onnx.OfflineTtsConfig,
            );
            ttsKey = key;
          }
          reply(true, null);
        case 'resetTts':
          tts?.free();
          tts = null;
          ttsKey = null;
        case 'tts':
          final sherpa_onnx.OfflineTts? engine = tts;
          if (engine == null) throw StateError('本地语音模型尚未在后台加载');
          final sherpa_onnx.GeneratedAudio audio = engine.generate(
            text: message['text'] as String,
            speed: (message['speed'] as num).toDouble(),
          );
          reply(true, <Object?>[audio.samples, audio.sampleRate]);
        case 'asr':
          final sherpa_onnx.OfflineRecognizer recognizer =
              sherpa_onnx.OfflineRecognizer(
            message['config'] as sherpa_onnx.OfflineRecognizerConfig,
          );
          sherpa_onnx.OfflineStream? stream;
          try {
            stream = recognizer.createStream();
            stream.acceptWaveform(
              samples: message['samples'] as Float32List,
              sampleRate: message['sampleRate'] as int,
            );
            recognizer.decode(stream);
            final sherpa_onnx.OfflineRecognizerResult result =
                recognizer.getResult(stream);
            reply(true, <Object?>[result.tokens, result.timestamps, result.text]);
          } finally {
            stream?.free();
            recognizer.free();
          }
        default:
          reply(false, '未知任务: ${message['kind']}');
      }
    } catch (e, s) {
      _logger.severe('语音后台任务失败: ${message['kind']}', e, s);
      reply(false, e.toString());
    }
  });
}
