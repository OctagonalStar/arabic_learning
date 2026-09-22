// 文本转语音服务（原 lib/funcs/utili.dart 拆分）。
// playTextToSpeech 支持系统 TTS / 在线 TTS / sherpa-onnx 本地 VITS 三种音源。

import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/package_replacement/fake_sherpa_onnx.dart' if (dart.library.io) 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

Future<void> playTextToSpeech(String text, {double? speed}) async { 
  speed ??= AppData().config.audio.playRate;

  // 0: System TTS
  if (AppData().config.audio.audioSource == 0) {
    FlutterTts flutterTts = FlutterTts();
    if(!(await flutterTts.getLanguages).toString().contains("ar")) {
      throw Exception("你的设备似乎未安装阿拉伯语语言或不支持阿拉伯语文本转语音功能，语音可能无法正常播放。\n你可以在 设置-常见问题 中找到可能的解决方案");
    }
    await flutterTts.setLanguage("ar");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(speed / 2);
    await flutterTts.speak(text);
    await Future.delayed(Duration(seconds: 2));
  // 1: TextReadTTS
  } else if (AppData().config.audio.audioSource == 1) {
    try {
      final response = await Dio().getUri(Uri.parse("https://textreadtts.com/tts/convert?accessKey=FREE&language=arabic&speaker=speaker2&text=$text")).timeout(Duration(seconds: 8), onTimeout: () => throw Exception("请求超时"));
      if (response.statusCode == 200) {
        if(response.data["code"] == 1) {
          throw Exception("API音源请求失败:\n错误信息:文本长度超过API限制");
        }
        await StaticsVar.player.setUrl(response.data["audio"]);
        await StaticsVar.player.setSpeed(speed);
        await StaticsVar.player.play();
        await Future.delayed(Duration(seconds: 2));
      } else {
        throw Exception("API音源请求失败:\n错误码:${response.statusCode.toString()}");
      }
    } catch (e) {
      throw Exception("API音源请求失败:\n错误信息:${e.toString()}");
    }
  
  // 2: sherpa-onnx
  } else if (AppData().config.audio.audioSource == 2) {
    if(AppData().vitsTTS == null) throw Exception("神经网络音频模型尚未就绪");
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
        throw Exception("神经网络音频合成失败\n错误信息:无法将音频写入文件");
      }
    } catch (e) {
      throw Exception("sherpa_onnx 错误: $e");
    }
  }
}
