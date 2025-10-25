import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/package_replacement/fake_sherpa_onnx.dart' if (dart.library.io) 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

Future<void> downloadFile(String url, String savePath, {ProgressCallback? onDownloading}) async {
  final dio = Dio();
  await dio.download(
    url,
    savePath,
    onReceiveProgress: onDownloading?? (count, total){},
  );
}

List<Map<String, dynamic>> getSelectedWords(BuildContext context , {bool doShuffle = false, bool doDouble = false}) {
  final tpcPrefs = context.read<Global>().prefs.getString("tempConfig") ?? jsonEncode(StaticsVar.tempConfig);
  final wordData = context.read<Global>().wordData;
  final courseList = (jsonDecode(tpcPrefs)["SelectedClasses"] as List)
      .cast<List>()
      .map((e) => e.cast<String>().toList())
      .toList();
  List<Map<String, dynamic>> ans = [];
  for(List<String> c in courseList) {
    for (int x in wordData["Classes"][c[0]][c[1]].cast<int>()){
      ans.add({...wordData["Words"][x], "id": x}); // 保留id方便后面进度保存
    }
  }
  if(doDouble) ans = [...ans, ...ans];
  if(doShuffle) ans.shuffle();
  return ans;
}

Future<List<dynamic>> playTextToSpeech(String text, BuildContext context, {double? speed}) async { 
  // return [bool isSuccessed?, String errorInfo];
  speed ??= context.read<Global>().settingData["audio"]["playRate"];

  // 0: System TTS
  if (context.read<Global>().settingData["audio"]["useBackupSource"] == 0) {
    FlutterTts flutterTts = FlutterTts();
    if(!(await flutterTts.getLanguages).toString().contains("ar")) return [false, "你的设备似乎未安装阿拉伯语语言或不支持阿拉伯语文本转语音功能，语音可能无法正常播放。\n你可以尝试在 设置 - 系统语言 - 添加语言 中添加阿拉伯语。\n实在无法使用可在设置页面启用备用音频源(需要网络)"];
    await flutterTts.setLanguage("ar");
    await flutterTts.setPitch(1.0);
    if(!context.mounted) return [false, "神经网络音频合成失败\n中途退出context"];
    await flutterTts.setSpeechRate(speed! / 2);
    await flutterTts.speak(text);

  // 1: TextReadTTS
  } else if (context.read<Global>().settingData["audio"]["useBackupSource"] == 1) {
    try {
      final response = await http.get(Uri.parse("https://textreadtts.com/tts/convert?accessKey=FREE&language=arabic&speaker=speaker2&text=$text")).timeout(Duration(seconds: 8), onTimeout: () => throw Exception("请求超时"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if(data["code"] == 1) {
          return [false, "备用音源请求失败:\n错误信息:文本长度超过API限制"];
        }
        await StaticsVar.player.setUrl(data["audio"]);
        if(!context.mounted) return [false, "神经网络音频合成失败\n中途退出context"];
        await StaticsVar.player.setSpeed(speed!);
        await StaticsVar.player.play();
      } else {
        return [false, "备用音源请求失败:\n错误码:${response.statusCode.toString()}"];
      }
    } catch (e) {
      return [false, "备用音源请求失败:\n错误信息:${e.toString()}"];
    }
  
  // 2: sherpa-onnx
  } else if (context.read<Global>().settingData["audio"]["useBackupSource"] == 2) {
    if(context.read<Global>().vitsTTS == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('神经网络音频模型尚未就绪，请等待...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    try {
      final basePath = await path_provider.getApplicationCacheDirectory();
      final cacheFile = io.File("${basePath.path}/temp.wav");
      if(cacheFile.existsSync()) cacheFile.deleteSync();
      if(!context.mounted) return [false, "神经网络音频合成失败\n中途退出context"];
      final audio = context.read<Global>().vitsTTS!.generate(text: text, speed: speed!);
      final ok = sherpa_onnx.writeWave(
                          filename: cacheFile.path,
                          samples: audio.samples,
                          sampleRate: audio.sampleRate,
                        );
      final Duration duration = Duration(milliseconds: (audio.samples.length / audio.sampleRate * 1000).round());
      if(ok) {
        await StaticsVar.player.setAudioSource(AudioSource.uri(Uri.file(cacheFile.path)));
        // await StaticsVar.player.setSpeed(playRate);

        StaticsVar.player.play();
        await Future.delayed(duration);
        if(cacheFile.existsSync()) cacheFile.deleteSync();
      }else {
        return [false, "神经网络音频合成失败\n错误信息:无法将音频写入文件"];
      }
    } catch (e) {
      return [false, "神经网络音频合成失败\n错误信息:${e.toString()}"];
    }
  }
  return [true, ""];
}


Future<void> extractTarBz2(String inputPath, String outputDir) async {
  final bytes = await io.File(inputPath).readAsBytes();

  // 解压 bz2
  final bz2Decoder = BZip2Decoder();
  final tarBytes = bz2Decoder.decodeBytes(bytes);

  // 解包 tar
  final tarArchive = TarDecoder().decodeBytes(tarBytes);

  // 解出文件
  for (final file in tarArchive.files) {
    final filePath = '$outputDir/${io.Platform.pathSeparator}${file.name}';
    if (file.isFile) {
      final outFile = io.File(filePath);
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>);
    } else {
      await io.Directory(filePath).create(recursive: true);
    }
  }
}