import 'dart:convert';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/package_replacement/fake_sherpa_onnx.dart' if (dart.library.io) 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

/// 下载文件到指定的目录
/// 
/// [url] :文件网址
/// 
/// [savePath] :保存地址
/// 
/// [onDownloading] :下载进程中的回调，传入两个参数(int count, int total)，可用于进度展示
Future<void> downloadFile(String url, String savePath, {ProgressCallback? onDownloading}) async {
  final dio = Dio();
  await dio.download(
    url,
    savePath,
    onReceiveProgress: onDownloading?? (count, total){},
  );
}

List<Map<String, dynamic>> getSelectedWords(BuildContext context , {List<List<String>>? forceSelectClasses, bool doShuffle = false, bool doDouble = false}) {
  final wordData = context.read<Global>().wordData;
  late final List<List<String>> courseList;
  if(forceSelectClasses == null) {
    final tpcPrefs = context.read<Global>().prefs.getString("tempConfig") ?? jsonEncode(StaticsVar.tempConfig);
    courseList = (jsonDecode(tpcPrefs)["SelectedClasses"] as List)
      .cast<List>()
      .map((e) => e.cast<String>().toList())
      .toList();
  } else {
    courseList = forceSelectClasses;
  }
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

void viewAnswer(MediaQueryData mediaQuery, 
                BuildContext context, 
                Map<String, dynamic> wordData
                ) async {
  showBottomSheet(
    context: context, 
    shape: RoundedSuperellipseBorder(side: BorderSide(width: 1.0, color: Theme.of(context).colorScheme.onSurface), borderRadius: StaticsVar.br),
    enableDrag: true,
    builder: (context) {
      return Container(
        padding: EdgeInsets.only(top: mediaQuery.size.height * 0.05),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onPrimary,
          borderRadius: StaticsVar.br,
        ),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(width: mediaQuery.size.width * 0.05),
                Expanded(
                  child: Column(
                    crossAxisAlignment: context.read<Global>().isWideScreen ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                    children: [
                      Text(wordData["arabic"], style: TextStyle(fontSize: 36.0, fontFamily: context.read<Global>().arFont)),
                      Text(wordData["chinese"], style: TextStyle(fontSize: 36.0)),
                      Text("例句:\t${wordData["explanation"]}", style: TextStyle(fontSize: 20.0),),
                      Text("所属课程:\t${wordData["subClass"]}", style: TextStyle(fontSize: 20.0),),
                    ]
                  ),
                ),
                SizedBox(width: mediaQuery.size.width * 0.05),
              ],
            ),
            Expanded(child: SizedBox()),
            ElevatedButton(
              onPressed: () {Navigator.pop(context);}, 
              style: ElevatedButton.styleFrom(
                fixedSize: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.1),
                shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
              ),
              child: Text("我知道了"),
            )
          ],
        ),
      );
    },
  );
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
    await Future.delayed(Duration(seconds: 2));

  // 1: TextReadTTS
  } else if (context.read<Global>().settingData["audio"]["useBackupSource"] == 1) {
    try {
      final response = await Dio().getUri(Uri.parse("https://textreadtts.com/tts/convert?accessKey=FREE&language=arabic&speaker=speaker2&text=$text")).timeout(Duration(seconds: 8), onTimeout: () => throw Exception("请求超时"));
      if (response.statusCode == 200) {
        if(response.data["code"] == 1) {
          return [false, "备用音源请求失败:\n错误信息:文本长度超过API限制"];
        }
        await StaticsVar.player.setUrl(response.data["audio"]);
        if(!context.mounted) return [false, "神经网络音频合成失败\n中途退出context"];
        await StaticsVar.player.setSpeed(speed!);
        await StaticsVar.player.play();
        await Future.delayed(Duration(seconds: 2));
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

extension StringExtensions on String {
  bool isArabic() {
    final arabicRegExp = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return arabicRegExp.hasMatch(this);
  }
}

extension ListExtensions on List {
  bool hasDuplicate() {
    final seen = <dynamic>{};
    for (var element in this) {
      if (seen.contains(element)) {
        return true;
      }
      seen.add(element);
    }
    return false;
  }
}

int getStrokeDays(Map<String, dynamic> settingData) {
  return (DateTime.now().difference(DateTime(2025, 11, 1)).inDays - settingData["learning"]["lastDate"] > 1) ? 0 : (settingData["learning"]["lastDate"] - settingData["learning"]["startDate"] + 1);
}

extension ZFillExtension on num {
  String zfill(int width) => _zfillImpl(this, width);
}

String _zfillImpl(num value, int width) {
  if (width <= 0) return value.toString();

  String raw = value.toString();
  bool isNegative = raw.startsWith('-');
  if (isNegative) raw = raw.substring(1);

  int padding = width - raw.length - (isNegative ? 1 : 0);
  if (padding <= 0) return isNegative ? '-$raw' : raw;

  String zeros = '0' * padding;
  return isNegative ? '-$zeros$raw' : '$zeros$raw';
}

Map<K, V> deepMerge<K, V>(Map<K, V> base, Map<K, V> overlay) {
  final result = Map<K, V>.from(base);
  overlay.forEach((key, value) {
    if (result[key] is Map && value is Map) {
      result[key] = deepMerge(
        Map<String, dynamic>.from(result[key] as Map),
        Map<String, dynamic>.from(value as Map),
      ) as V;
    } else {
      result[key] = value;
    }
  });
  return result;
}
class AnalysisResult {
  /// 提取出的三字母词根。
  final String root;
  /// 匹配到的构词法模式名称。
  final String patternName;
  AnalysisResult(this.root, this.patternName);
}

/// 内部辅助类，用于定义一个构词法模式。
class _RootPattern {
  /// 模式的名称，如 "Form X (Past)"。
  final String name; 
  /// 用于匹配的正则表达式。
  final RegExp regex;
  /// 捕获组索引，定义了词根字母 (R1, R2, R3) 在正则匹配中的位置。
  final List<int> groups; 

  _RootPattern(this.name, String pattern, {this.groups = const [1, 2, 3]}) 
      : regex = RegExp(pattern);
}

/// 一个基于构词法模式的阿拉伯语词根提取器 (Stemmer)。
///
/// 该类通过一个预定义的模式库来识别单词的构词形式，并从中提取出标准的三字母词根。
/// 这对于判断不同派生词之间的相似性至关重要。
class ArabicStemmer {
  // 1. 元音范围
  static final _diacritics = RegExp(r'[\u064B-\u065F\u0640\u0670\u06D6-\u06ED]');
  
  // 2. 定义模式库 (优先级：长/特异性 -> 短/通用性)
  static final List<_RootPattern> _patterns = [
    // --- Form X (استفعل) ---
    _RootPattern("Form X (Past)", r'^است(.)(.)(.)$'), 
    _RootPattern("Form X (Present)", r'^يست(.)(.)(.)$'), 
    _RootPattern("Form X (Participle)", r'^مست(.)(.)(.)$'),
    
    // --- [新增] Instrumental (Mif'aal - مفعال) ---
    // e.g., Miftah (مفتاح) -> F-T-H
    // 正则：Meem + R1 + R2 + Alef + R3
    _RootPattern("Instrumental (Mif'aal)", r'^م(.)(.)ا(.)$'),

    // --- Form I Passive (مفعول) ---
    // e.g., Maktub (مكتوب)
    // 正则：Meem + R1 + R2 + Waw + R3
    _RootPattern("Form I (Passive)", r'^م(.)(.)و(.)$'), 

    // --- Form VII (انفعل) ---
    _RootPattern("Form VII (Past)", r'^ان(.)(.)(.)$'), 
    _RootPattern("Form VII (Present)", r'^ين(.)(.)(.)$'),
    _RootPattern("Form VII (Participle)", r'^من(.)(.)(.)$'), 

    // --- Form VIII (افتعل) ---
    _RootPattern("Form VIII (Past)", r'^ا(.)ت(.)(.)$'), 
    _RootPattern("Form VIII (Present)", r'^ي(.)ت(.)(.)$'), 
    _RootPattern("Form VIII (Participle)", r'^م(.)ت(.)(.)$'), 

    // --- Form VI (تفاعل) ---
    _RootPattern("Form VI (Past)", r'^ت(.)ا(.)(.)$'), 
    _RootPattern("Form VI (Present)", r'^يت(.)ا(.)(.)$'), 
    _RootPattern("Form VI (Participle)", r'^مت(.)ا(.)(.)$'), 

    // --- Form III (فاعل) ---
    _RootPattern("Form III/I-Active", r'^(.)ا(.)(.)$'), 
    _RootPattern("Form III (Present)", r'^ي(.)ا(.)(.)$'), 
    _RootPattern("Form III (Participle)", r'^م(.)ا(.)(.)$'), 

    // --- Form V (تفعّل) ---
    _RootPattern("Form V (Past)", r'^ت(.)(.)(.)$'), 
    _RootPattern("Form V (Present)", r'^يت(.)(.)(.)$'),
    _RootPattern("Form V (Participle)", r'^مت(.)(.)(.)$'),

    // --- Masdar Form II/V (Taf'aal) ---
    _RootPattern("Masdar (Taf'aal)", r'^ت(.)(.)ا(.)$'), 

    // --- [新增] Elative/Comparative (Af'al - أفعل) ---
    // e.g., Akbar (أكبر) -> K-B-R
    // 归一化后为: Alef + R1 + R2 + R3
    // 注意：这也涵盖了 Form IV Past (Af'ala - أكرم)
    _RootPattern("Comparative (Af'al)", r'^ا(.)(.)(.)$'), 

    // --- [新增] Elative Fem (Fu'la - فعلى) ---
    // e.g., Kubra (كبرى) -> K-B-R
    // 归一化后：R1 + R2 + R3 + Alef (from Yaa/Alif Maqsura)
    // 必须是4个字母，以Alef结尾
    _RootPattern("Comparative Fem (Fu'la)", r'^(.)(.)(.)ا$'),

    // --- Form IV (Participle) ---
    _RootPattern("Form IV (Participle)", r'^م(.)(.)(.)$'), 
    
    // --- Default Form I Present (Yaf'alu) ---
    _RootPattern("Form I (Present)", r'^ي(.)(.)(.)$'),
  ];

  /// 对输入的阿拉伯语单词进行预处理和规范化。
  String normalize(String text) {
    if (text.isEmpty) return "";
    // 移除所有元音符号
    String res = text.replaceAll(_diacritics, '');
    // 统一不同形式的 Alef
    res = res.replaceAll(RegExp(r'[أإآ]'), 'ا');
    // 将 Alef Maqsura 统一为 Alef
    res = res.replaceAll('ى', 'ا');
    
    // 忽略所有 "ة" (Ta Marbuta)，直接删除
    // 之前是替换为 'ه'，现在按照需求删除，以便处理如 'مكتبة' -> 'مكتب'
    res = res.replaceAll('ة', '');
    
    return res.trim();
  }

  /// 分析单词，返回其词根和匹配的模式。
  AnalysisResult analyze(String word) {
    String stem = normalize(word);
    if (stem.length <= 2) return AnalysisResult(stem, "Too Short");

    // 遍历模式库，找到第一个匹配的模式
    for (final pattern in _patterns) {
      final match = pattern.regex.firstMatch(stem);
      if (match != null) {
        String r1 = match.group(pattern.groups[0])!;
        String r2 = match.group(pattern.groups[1])!;
        String r3 = match.group(pattern.groups[2])!;
        return AnalysisResult(r1 + r2 + r3, pattern.name);
      }
    }
    
    // 如果没有模式匹配成功，则使用后备的词缀剥离方法
    String fallbackRoot = _fallbackStripping(stem);
    return AnalysisResult(fallbackRoot, "Fallback/Form I");
  }

  /// 提取单词的词根（仅返回词根字符串）。
  String extractRoot(String word) {
    return analyze(word).root;
  }

  /// 后备方案：通过剥离常见的前后缀来简化单词。
  String _fallbackStripping(String stem) {
    String s = stem;
    
    if (s.startsWith('وال') || s.startsWith('فال')) s = s.substring(1);
    if (s.startsWith('لل') || s.startsWith('ال')) s = s.substring(2);
    if (s.length > 3 && (s.startsWith('و') || s.startsWith('ف'))) s = s.substring(1);

    if (s.length > 4) {
       if (s.endsWith('ات') || s.endsWith('ون') || s.endsWith('ين')) s = s.substring(0, s.length - 2);
       else if (s.endsWith('ي')) s = s.substring(0, s.length - 1);
       // 注意：这里去掉了对 'ه' (Ha) 的移除，因为我们不再把 'ة' 转为 'ه'
       // 如果 'ه' 是原生字母或代词后缀，仍需小心
    }

    return s;
  }
}

/// 计算两个字符串之间的 Levenshtein 编辑距离。
///
/// 编辑距离指从一个字符串转换成另一个所需的最少单字符编辑（插入、删除或替换）次数。
int getLevenshtein(String s, String t) {
  if (s == t) return 0;
  if (s.isEmpty) return t.length;
  if (t.isEmpty) return s.length;

  List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
  List<int> v1 = List<int>.filled(t.length + 1, 0);

  for (int i = 0; i < s.length; i++) {
    v1[0] = i + 1;
    for (int j = 0; j < t.length; j++) {
      int cost = (s[i] == t[j]) ? 0 : 1;
      v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
    }
    for (int j = 0; j < t.length + 1; j++) {
      v0[j] = v1[j];
    }
  }
  return v1[t.length];
}

final _arabicStemmer = ArabicStemmer();

// ===================================================================
//
//                 Public API Handle (调用抓手)
//
// ===================================================================

/// 检查两个阿拉伯语单词是否相似。
///
/// 这是一个供 App 其他部分调用的高级函数 ("抓手")。
/// 它封装了词根提取和编辑距离计算的复杂逻辑。
///
/// [wordA] - 第一个单词。
/// [wordB] - 第二个单词。
///
/// 如果两个单词的词根相同，或者词根之间的编辑距离小于等于1，则返回 `true`。
/// 否则返回 `false`。
bool areArabicWordsSimilar(String wordA, String wordB) {
  final rootA = _arabicStemmer.extractRoot(wordA);
  final rootB = _arabicStemmer.extractRoot(wordB);
  
  // 1. 词根完全相同 (最强匹配)
  if (rootA == rootB) {
    return true;
  }
  
  // 2. 词根编辑距离小于等于1 (容错匹配)
  // 这对于处理弱动词或书写变体很有用。
  if (getLevenshtein(rootA, rootB) <= 1) {
    return true;
  }
  
  return false;
}
