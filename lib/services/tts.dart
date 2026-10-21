// 文本转语音服务（原 lib/funcs/utili.dart 拆分）。
// playTextToSpeech 支持系统 TTS / 在线 TTS / sherpa-onnx 本地 VITS 三种音源。

import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/http_client.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/package_replacement/fake_sherpa_onnx.dart' if (dart.library.io) 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

final Logger _logger = Logger("TTS");

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
  _logger.warning("语音播放失败: $message", error);
  return TtsFailure(message, error);
}

Future<void> playTextToSpeech(String text, {double? speed}) async {
  speed ??= AppData().config.audio.playRate;

  // 0: System TTS
  if (AppData().config.audio.audioSource == 0) {
    FlutterTts flutterTts = FlutterTts();
    try {
      if(!(await flutterTts.getLanguages).toString().contains("ar")) {
        throw const TtsFailure(
          "设备上没有可用的阿拉伯语语音。请安装阿拉伯语语音包后再试，或在 设置-音频 中换用其他音源。\n"
          "详细说明见 设置-常见问题。",
        );
      }
      await flutterTts.setLanguage("ar");
      await flutterTts.setPitch(1.0);
      await flutterTts.setSpeechRate(speed / 2);
      await flutterTts.speak(text);
    } catch (e) {
      throw _toTtsFailure(
        "系统语音暂时无法播放。可稍后重试，或在 设置-音频 中换用其他音源。",
        e,
      );
    }
    await Future.delayed(Duration(seconds: 2));

    // 1: TextReadTTS
  } else if (AppData().config.audio.audioSource == 1) {
    try {
      final response = await createDio().getUri(Uri.parse("https://textreadtts.com/tts/convert?accessKey=FREE&language=arabic&speaker=speaker2&text=$text")).timeout(
            Duration(seconds: 8),
            onTimeout: () => throw const TtsFailure("在线音源连接超时。请检查网络，或换用其他音源。"),
          );
      if (response.statusCode == 200) {
        if(response.data["code"] == 1) {
          throw const TtsFailure("这段文本超过了在线音源的长度限制。可以把文本拆短，或换用其他音源。");
        }
        await StaticsVar.player.setUrl(response.data["audio"]);
        await StaticsVar.player.setSpeed(speed);
        await StaticsVar.player.play();
        await Future.delayed(Duration(seconds: 2));
      } else {
        throw _toTtsFailure(
          "在线音源暂时不可用（HTTP ${response.statusCode}）。可稍后重试或换用其他音源。",
          Exception("HTTP ${response.statusCode}"),
        );
      }
    } catch (e) {
      throw _toTtsFailure(
        "在线音源请求失败。请检查网络，或换用其他音源。",
        e,
      );
    }

    // 2: sherpa-onnx
  } else if (AppData().config.audio.audioSource == 2) {
    // 惰性加载：模型加载是同步的（ONNX 初始化），放在启动流程里会阻塞首帧，
    // 因此推迟到第一次真正需要合成语音时再做，之后的调用直接命中已加载实例。
    if(AppData().vitsTTS == null) {
      try {
        await AppData().loadTTS(AppData().config.audio.playRate);
      } catch (e) {
        throw _toTtsFailure(
          "本地语音模型加载失败。可在 设置-音频 中重新下载模型。",
          e,
        );
      }
    }
    if(AppData().vitsTTS == null) {
      throw const TtsFailure("本地语音模型还没有准备好。请先在 设置-音频 中下载模型。");
    }
    try {
      final basePath = await path_provider.getApplicationCacheDirectory();
      final cacheFile = io.File("${basePath.path}/temp.wav");
      if(cacheFile.existsSync()) cacheFile.deleteSync();
      final audio = AppData().vitsTTS!.generate(text: text, speed: speed);
      final ok = sherpa_onnx.writeWave(
                          filename: cacheFile.path,
                          samples: audio.samples,
                          sampleRate: audio.sampleRate,
                        );
      final Duration duration = Duration(milliseconds: (audio.samples.length / audio.sampleRate * 1000).round());
      if(ok) {
        await StaticsVar.player.setAudioSource(AudioSource.uri(Uri.file(cacheFile.path)));
        StaticsVar.player.play();
        await Future.delayed(duration);
        if(cacheFile.existsSync()) cacheFile.deleteSync();
      } else {
        throw Exception("无法将音频写入文件");
      }
    } catch (e) {
      throw _toTtsFailure(
        "本地语音合成失败。可重试一次，仍失败请在 设置-音频 中重新下载模型。",
        e,
      );
    }
  }
}
