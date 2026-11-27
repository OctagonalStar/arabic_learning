// 文本转语音服务（原 lib/funcs/utili.dart 拆分）。
// playTextToSpeech 支持系统 TTS / 在线 TTS / sherpa-onnx 本地 VITS 三种音源。

import 'dart:convert';
import 'dart:typed_data';

import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/core/wav.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/blob_url.dart';
import 'package:arabic_learning/services/speech_worker.dart';
import 'package:arabic_learning/services/web_audio.dart';
import 'package:arabic_learning/services/http_client.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart'
    if (dart.library.io) 'dart:io'
    as io;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

final Logger _logger = Logger("TTS");

/// 上次本地合成的缓存：文本、语速与模型都没变时直接复用音频，不重复推理。
String? _cacheKey;
io.File? _cacheFile;

/// Web 没有文件系统，缓存是常驻的 blob URL。
String? _cacheWebUrl;

/// 上一段 blob URL，等下一次换缓存时再释放（播放期间不能删）。
String? _spareWebUrl;
Duration _cacheDuration = Duration.zero;

/// 语音播放失败。
///
/// [message] 是给用户看的一句话（可直接放进对话框），
/// [detail] 是技术细节，只写日志，不展示给用户。
class TtsFailure implements Exception {
  final String message;
  final Object? detail;

  const TtsFailure(this.message, [this.detail]);

  @override
  String toString() => message;
}

/// 把任意异常归一成 [TtsFailure]，避免不同音源的错误层层套娃。
/// 已经是 [TtsFailure] 的直接透传，只把技术细节写日志。
TtsFailure _toTtsFailure(String message, Object error) {
  if (error is TtsFailure) return error;
  _logger.warning("语音播放失败: $message（${error.runtimeType}）", error);
  return TtsFailure("$message（错误类型: ${error.runtimeType}）", error);
}

/// 预合成完成、可重复播放的语音片段。
///
/// [cached] 为 false 表示当前音源（系统 TTS / 在线 TTS）无法提前落盘，
/// 播放时仍需现场合成；调用方应避免依赖精确的播放完成时刻。
class SpeechClip {
  final String text;
  final double speed;
  final bool cached;

  /// 原生端的缓存文件。
  final Uri? source;

  /// Web 端的整段 WAV 字节（浏览器没有文件系统缓存）。
  final Uint8List? wavBytes;

  /// 本地合成已知时长；原生缓存命中时为 [Duration.zero]，播放时从解码器读。
  final Duration duration;

  const SpeechClip({
    required this.text,
    required this.speed,
    required this.cached,
    this.source,
    this.wavBytes,
    this.duration = Duration.zero,
  });
}

/// 确保本地 TTS 模型已加载；未安装时抛出可展示的 [TtsFailure]。
Future<void> _ensureLocalTtsLoaded() async {
  if (kIsWeb ? AppData().vitsTTS == null : !AppData().ttsLoaded) {
    try {
      await AppData().loadTTS(AppData().config.audio.playRate);
    } catch (e) {
      throw _toTtsFailure("本地语音模型加载失败。可在 设置-音频 中重新下载模型。", e);
    }
  }
  if (kIsWeb ? AppData().vitsTTS == null : !AppData().ttsLoaded) {
    throw const TtsFailure("本地语音模型还没有准备好。请先在 设置-音频 中下载模型。");
  }
}

/// 合成一段 WAV；调用方负责把异常归一成 [TtsFailure]。
Future<({Uint8List wav, Duration duration})> _synthesizeWav(
  String text,
  double speed,
) async {
  final Float32List samples;
  final int sampleRate;
  if (kIsWeb) {
    final sherpa_onnx.GeneratedAudio audio = AppData().vitsTTS!.generate(
      text: text,
      speed: speed,
    );
    samples = audio.samples;
    sampleRate = audio.sampleRate;
  } else {
    // 原生端：合成在后台 isolate 跑，UI 线程只做落盘。
    final ({Float32List samples, int sampleRate}) audio =
        await SpeechWorker.synthesize(text: text, speed: speed);
    samples = audio.samples;
    sampleRate = audio.sampleRate;
  }
  return (
    wav: encodeWav16(samples, sampleRate),
    duration: Duration(
      milliseconds: (samples.length / sampleRate * 1000).round(),
    ),
  );
}

bool _clipCachePruned = false;

/// 清理听抄语音缓存：删除超过 [maxAge] 的文件，再按修改时间从旧到新
/// 淘汰到总大小不超过 [maxBytes]。
///
/// 只在需要预合成时才扫描一次；单独导出便于测试。
@visibleForTesting
void pruneTtsClipCache(
  String directoryPath, {
  Duration maxAge = const Duration(days: 7),
  int maxBytes = 200 * 1024 * 1024,
}) {
  final io.Directory dir = io.Directory(directoryPath);
  final DateTime now = DateTime.now();
  final List<({io.File file, DateTime modified, int size})> entries =
      <({io.File file, DateTime modified, int size})>[];
  int total = 0;
  for (final io.FileSystemEntity entity in dir.listSync()) {
    final String path = entity.path;
    if (!path.endsWith('.wav')) continue;
    final io.File file = io.File(path);
    if (!file.existsSync()) continue;
    final DateTime modified = file.lastModifiedSync();
    final int size = file.lengthSync();
    if (now.difference(modified) > maxAge) {
      file.deleteSync();
      continue;
    }
    entries.add((file: file, modified: modified, size: size));
    total += size;
  }
  if (total <= maxBytes) return;
  entries.sort(
    (
      ({io.File file, DateTime modified, int size}) a,
      ({io.File file, DateTime modified, int size}) b,
    ) => a.modified.compareTo(b.modified),
  );
  for (final ({io.File file, DateTime modified, int size}) entry in entries) {
    if (total <= maxBytes) break;
    entry.file.deleteSync();
    total -= entry.size;
  }
}

void _pruneClipCacheOnce(io.Directory dir) {
  if (_clipCachePruned) return;
  _clipCachePruned = true;
  try {
    pruneTtsClipCache(dir.path);
  } catch (e) {
    _logger.warning("清理听抄语音缓存失败", e);
  }
}

/// 预合成并缓存一段文本，供听抄等需要精确间隔的场景反复播放。///
/// 仅本地 sherpa-onnx 音源能落盘；系统 / 在线音源返回 `cached == false`，
/// 由 [playSpeech] 回退到现场朗读。
Future<SpeechClip> prepareSpeech(String text, {double? speed}) async {
  speed ??= AppData().config.audio.playRate;
  if (AppData().config.audio.audioSource != 2) {
    return SpeechClip(text: text, speed: speed, cached: false);
  }
  await _ensureLocalTtsLoaded();
  try {
    if (kIsWeb) {
      final ({Uint8List wav, Duration duration}) audio = await _synthesizeWav(
        text,
        speed,
      );
      return SpeechClip(
        text: text,
        speed: speed,
        cached: true,
        wavBytes: audio.wav,
        duration: audio.duration,
      );
    }
    final String key = sha1
        .convert(utf8.encode("$text|$speed|${AppData().preferredTtsModelId}"))
        .toString();
    final basePath = await path_provider.getApplicationCacheDirectory();
    final io.Directory dir = io.Directory("${basePath.path}/tts_clips");
    if (!dir.existsSync()) await dir.create(recursive: true);
    _pruneClipCacheOnce(dir);
    final io.File file = io.File("${dir.path}/$key.wav");
    if (file.existsSync()) {
      return SpeechClip(
        text: text,
        speed: speed,
        cached: true,
        source: Uri.file(file.path),
      );
    }
    final ({Uint8List wav, Duration duration}) audio = await _synthesizeWav(
      text,
      speed,
    );
    await file.writeAsBytes(audio.wav);
    return SpeechClip(
      text: text,
      speed: speed,
      cached: true,
      source: Uri.file(file.path),
      duration: audio.duration,
    );
  } catch (e) {
    throw _toTtsFailure("本地语音合成失败。可重试一次，仍失败请在 设置-音频 中重新下载模型。", e);
  }
}

/// 播放 [prepareSpeech] 得到的片段。
Future<void> playSpeech(SpeechClip clip) async {
  if (!clip.cached) {
    await playTextToSpeech(clip.text, speed: clip.speed, awaitCompletion: true);
    return;
  }
  try {
    if (kIsWeb) {
      final String url = createBlobUrl(clip.wavBytes!);
      try {
        await playWavBlobUrl(url, clip.duration);
      } finally {
        revokeBlobUrl(url);
      }
    } else {
      final Duration? duration = await StaticsVar.player.setAudioSource(
        AudioSource.uri(clip.source!),
      );
      // 音频已按目标语速合成，播放器保持 1.0。
      await StaticsVar.player.setSpeed(1.0);
      await Future.wait([
        StaticsVar.player.play(),
        Future.delayed(duration ?? clip.duration),
      ]);
    }
  } catch (e) {
    throw _toTtsFailure("音频播放失败，可能是本机没有可用的播放后端。", e);
  }
}

Future<void> playTextToSpeech(
  String text, {
  double? speed,
  bool awaitCompletion = false,
}) async {
  speed ??= AppData().config.audio.playRate;

  // 0: System TTS
  if (AppData().config.audio.audioSource == 0) {
    FlutterTts flutterTts = FlutterTts();
    try {
      if (!(await flutterTts.getLanguages).toString().contains("ar")) {
        throw const TtsFailure(
          "设备上没有可用的阿拉伯语语音。请安装阿拉伯语语音包后再试，或在 设置-音频 中换用其他音源。\n"
          "详细说明见 设置-常见问题。",
        );
      }
      await flutterTts.setLanguage("ar");
      await flutterTts.setPitch(1.0);
      await flutterTts.setSpeechRate(speed / 2);
      if (awaitCompletion) {
        await flutterTts.awaitSpeakCompletion(true);
        await flutterTts.speak(text);
      } else {
        await flutterTts.speak(text);
        await Future.delayed(Duration(seconds: 2));
      }
    } catch (e) {
      throw _toTtsFailure("系统语音暂时无法播放。可稍后重试，或在 设置-音频 中换用其他音源。", e);
    }

    // 1: TextReadTTS
  } else if (AppData().config.audio.audioSource == 1) {
    try {
      final response = await createDio()
          .getUri(
            Uri.parse(
              "https://textreadtts.com/tts/convert?accessKey=FREE&language=arabic&speaker=speaker2&text=$text",
            ),
          )
          .timeout(
            Duration(seconds: 8),
            onTimeout: () => throw const TtsFailure("在线音源连接超时。请检查网络，或换用其他音源。"),
          );
      if (response.statusCode == 200) {
        if (response.data["code"] == 1) {
          throw const TtsFailure("这段文本超过了在线音源的长度限制。可以把文本拆短，或换用其他音源。");
        }
        await StaticsVar.player.setUrl(response.data["audio"]);
        await StaticsVar.player.setSpeed(speed);
        await StaticsVar.player.play();
        if (!awaitCompletion) await Future.delayed(Duration(seconds: 2));
      } else {
        throw _toTtsFailure(
          "在线音源暂时不可用（HTTP ${response.statusCode}）。可稍后重试或换用其他音源。",
          Exception("HTTP ${response.statusCode}"),
        );
      }
    } catch (e) {
      throw _toTtsFailure("在线音源请求失败。请检查网络，或换用其他音源。", e);
    }

    // 2: sherpa-onnx
  } else if (AppData().config.audio.audioSource == 2) {
    // 惰性加载：模型加载是同步的（ONNX 初始化），放在启动流程里会阻塞首帧，
    // 因此推迟到第一次真正需要合成语音时再做，之后的调用直接命中已加载实例。
    // 原生端的实例在后台 isolate，主 isolate 只能看 ttsLoaded 标记。
    await _ensureLocalTtsLoaded();
    late final Duration duration;
    late final Uri source;
    final String cacheKey = "$text|$speed|${AppData().preferredTtsModelId}";
    final bool hit =
        _cacheKey == cacheKey &&
        (kIsWeb
            ? _cacheWebUrl != null
            : _cacheFile != null && _cacheFile!.existsSync());
    if (hit) {
      duration = _cacheDuration;
      source = kIsWeb ? Uri.parse(_cacheWebUrl!) : Uri.file(_cacheFile!.path);
      _logger.info("本地语音命中缓存: ${text.length} 字");
    } else {
      // 合成与播放分开报错：播放失败不代表模型有问题，不能让用户去重下模型。
      try {
        final ({Uint8List wav, Duration duration}) audio = await _synthesizeWav(
          text,
          speed,
        );
        duration = audio.duration;
        if (kIsWeb) {
          // 轮换两个槽位：上一段可能还在播，只回收再往前的那一段。
          final String? spare = _spareWebUrl;
          _spareWebUrl = _cacheWebUrl;
          _cacheWebUrl = createBlobUrl(audio.wav);
          if (spare != null) revokeBlobUrl(spare);
          source = Uri.parse(_cacheWebUrl!);
        } else {
          final basePath = await path_provider.getApplicationCacheDirectory();
          final io.File cacheFile = io.File("${basePath.path}/tts_cache.wav");
          if (cacheFile.existsSync()) cacheFile.deleteSync();
          // 纯 Dart 编码落盘：sherpa_onnx.writeWave 要求主 isolate 先
          // initBindings()，而绑定只在后台 worker 里初始化。
          await cacheFile.writeAsBytes(audio.wav);
          _cacheFile = cacheFile;
          source = Uri.file(cacheFile.path);
        }
        _cacheKey = cacheKey;
        _cacheDuration = duration;
      } catch (e) {
        throw _toTtsFailure("本地语音合成失败。可重试一次，仍失败请在 设置-音频 中重新下载模型。", e);
      }
    }
    try {
      if (kIsWeb) {
        // Web 上 just_audio 换源会残留旧音频，这里用一次性 <audio> 元素。
        _logger.info(
          "Web 本地语音播放: ${text.length} 字, ${duration.inMilliseconds}ms",
        );
        await playWavBlobUrl(source.toString(), duration);
      } else {
        await StaticsVar.player.setAudioSource(AudioSource.uri(source));
        // 本地音频已按 speed 合成，播放器保持 1.0，避免沿用在线音源留下的变速。
        await StaticsVar.player.setSpeed(1.0);
        // play() 在播放结束/暂停时完成，和固定时长一起等，异常才能落在这个 try 里。
        await Future.wait([StaticsVar.player.play(), Future.delayed(duration)]);
      }
    } catch (e) {
      throw _toTtsFailure("音频播放失败，可能是本机没有可用的播放后端。", e);
    }
  }
}
