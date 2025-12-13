import 'dart:convert';
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
import 'dart:math';
import 'package:bk_tree/bk_tree.dart';

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

Future<List<dynamic>> playTextToSpeech(String text, BuildContext context, {double? speed}) async { 
  // return [bool isSuccessed?, String errorInfo];
  speed ??= context.read<Global>().settingData["audio"]["playRate"];
  context.read<Global>().logger.info("[TTS]请求: 文本: [$text]");

  // 0: System TTS
  if (context.read<Global>().settingData["audio"]["useBackupSource"] == 0) {
    context.read<Global>().logger.info("[TTS]配置使用系统TTS");
    FlutterTts flutterTts = FlutterTts();
    if(!(await flutterTts.getLanguages).toString().contains("ar") && context.mounted) {
      context.read<Global>().logger.warning("[TTS]用户设备不支持AR语言TTS");
      return [false, "你的设备似乎未安装阿拉伯语语言或不支持阿拉伯语文本转语音功能，语音可能无法正常播放。\n你可以尝试在 设置 - 系统语言 - 添加语言 中添加阿拉伯语。\n实在无法使用可在设置页面启用备用音频源(需要网络)"];
    }
    await flutterTts.setLanguage("ar");
    await flutterTts.setPitch(1.0);
    if(!context.mounted) return [false, ""];
    await flutterTts.setSpeechRate(speed! / 2);
    await flutterTts.speak(text);
    await Future.delayed(Duration(seconds: 2));
    if(!context.mounted) return [false, ""];
    context.read<Global>().logger.fine("[TTS]系统TTS阅读完成");
  // 1: TextReadTTS
  } else if (context.read<Global>().settingData["audio"]["useBackupSource"] == 1) {
    context.read<Global>().logger.info("[TTS]配置使用API进行TTS");
    try {
      context.read<Global>().logger.fine("[TTS]正在获取");
      final response = await Dio().getUri(Uri.parse("https://textreadtts.com/tts/convert?accessKey=FREE&language=arabic&speaker=speaker2&text=$text")).timeout(Duration(seconds: 8), onTimeout: () => throw Exception("请求超时"));
      if (response.statusCode == 200) {
        if(response.data["code"] == 1 && context.mounted) {
          context.read<Global>().logger.fine("[TTS]API音频获取失败，文本长度超过API限制");
          return [false, "API音源请求失败:\n错误信息:文本长度超过API限制"];
        }
        await StaticsVar.player.setUrl(response.data["audio"]);
        if(!context.mounted) return [false, ""];
        await StaticsVar.player.setSpeed(speed!);
        await StaticsVar.player.play();
        await Future.delayed(Duration(seconds: 2));
        if(context.mounted) context.read<Global>().logger.fine("[TTS]API TTS阅读完成");
      } else {
        if(context.mounted) context.read<Global>().logger.severe("[TTS]网络获取错误 ${response.statusCode}");
        return [false, "API音源请求失败:\n错误码:${response.statusCode.toString()}"];
      }
    } catch (e) {
      if(context.mounted) context.read<Global>().logger.severe("[TTS]API错误 $e");
      return [false, "API音源请求失败:\n错误信息:${e.toString()}"];
    }
  
  // 2: sherpa-onnx
  } else if (context.read<Global>().settingData["audio"]["useBackupSource"] == 2) {
    context.read<Global>().logger.info("[TTS]配置使用 sherpa_onnx TTS");
    if(context.read<Global>().vitsTTS == null) {
      context.read<Global>().logger.warning("[TTS]sherpa_onnx 未加载");
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
      if(!context.mounted) return [false, ""];
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
        if(context.mounted) context.read<Global>().logger.fine("[TTS]sherpa_onnx TTS阅读完成");
      } else {
        context.read<Global>().logger.severe("[TTS]sherpa_onnx 无法将音频写入文件");
        return [false, "神经网络音频合成失败\n错误信息:无法将音频写入文件"];
      }
    } catch (e) {
      if(context.mounted) context.read<Global>().logger.severe("[TTS]sherpa_onnx 错误: $e");
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


/// 简单的词性枚举，用于区分词汇类别
enum ArabicPOS {
  verb,   // 动词
  noun,   // 名词（包括形容词、分词、动名词）
  unknown // 无法判断（如太短或未匹配到模式）
}

class AnalysisResult {
  /// 提取出的三字母词根。
  final String root;
  /// 匹配到的构词法模式名称。
  final String patternName;
  /// 词性标记
  final ArabicPOS pos;

  AnalysisResult(this.root, this.patternName, this.pos);
}

/// 内部辅助类，用于定义一个构词法模式。
class _RootPattern {
  /// 模式的名称，如 "Form X (Past)"。
  final String name; 
  /// 用于匹配的正则表达式。
  final RegExp regex;
  /// 捕获组索引，定义了词根字母 (R1, R2, R3) 在正则匹配中的位置。
  final List<int> groups; 
  /// 该模式对应的词性
  final ArabicPOS pos;

  _RootPattern(this.name, String pattern, this.pos, {this.groups = const [1, 2, 3]})
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
    _RootPattern("Form X (Past)", r'^است(.)(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form X (Present)", r'^يست(.)(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form X (Participle)", r'^مست(.)(.)(.)$', ArabicPOS.noun),
    
    // --- [新增] Instrumental (Mif'aal - مفعال) ---
    // e.g., Miftah (مفتاح) -> F-T-H
    // 正则：Meem + R1 + R2 + Alef + R3
    _RootPattern("Instrumental (Mif'aal)", r'^م(.)(.)ا(.)$', ArabicPOS.noun),

    // --- Form I Passive (مفعول) ---
    // e.g., Maktub (مكتوب)
    // 正则：Meem + R1 + R2 + Waw + R3
    _RootPattern("Form I (Passive)", r'^م(.)(.)و(.)$', ArabicPOS.noun), 

    // --- Form VII (انفعل) ---
    _RootPattern("Form VII (Past)", r'^ان(.)(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form VII (Present)", r'^ين(.)(.)(.)$', ArabicPOS.verb),
    _RootPattern("Form VII (Participle)", r'^من(.)(.)(.)$', ArabicPOS.noun), 

    // --- Form VIII (افتعل) ---
    _RootPattern("Form VIII (Past)", r'^ا(.)ت(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form VIII (Present)", r'^ي(.)ت(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form VIII (Participle)", r'^م(.)ت(.)(.)$', ArabicPOS.noun), 

    // --- Form VI (تفاعل) ---
    _RootPattern("Form VI (Past)", r'^ت(.)ا(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form VI (Present)", r'^يت(.)ا(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form VI (Participle)", r'^مت(.)ا(.)(.)$', ArabicPOS.noun), 

    // --- Form III (فاعل) ---
    _RootPattern("Form III/I-Active", r'^(.)ا(.)(.)$', ArabicPOS.noun), // 这里的 Active Participle 往往作名词用，但也可能是动词过去式，暂定名词
    _RootPattern("Form III (Present)", r'^ي(.)ا(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form III (Participle)", r'^م(.)ا(.)(.)$', ArabicPOS.noun), 

    // --- Form V (تفعّل) ---
    _RootPattern("Form V (Past)", r'^ت(.)(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form V (Present)", r'^يت(.)(.)(.)$', ArabicPOS.verb),
    _RootPattern("Form V (Participle)", r'^مت(.)(.)(.)$', ArabicPOS.noun),

    // --- Masdar Form II/V (Taf'aal) ---
    _RootPattern("Masdar (Taf'aal)", r'^ت(.)(.)ا(.)$', ArabicPOS.noun), 

    // --- [新增] Elative/Comparative (Af'al - أفعل) ---
    // e.g., Akbar (أكبر) -> K-B-R
    // 归一化后为: Alef + R1 + R2 + R3
    // 注意：这也涵盖了 Form IV Past (Af'ala - أكرم)
    _RootPattern("Comparative (Af'al)", r'^ا(.)(.)(.)$', ArabicPOS.noun), 

    // --- [新增] Elative Fem (Fu'la - فعلى) ---
    // e.g., Kubra (كبرى) -> K-B-R
    // 归一化后：R1 + R2 + R3 + Alef (from Yaa/Alif Maqsura)
    // 必须是4个字母，以Alef结尾
    _RootPattern("Comparative Fem (Fu'la)", r'^(.)(.)(.)ا$', ArabicPOS.noun),

    // --- Form IV (Participle) ---
    _RootPattern("Form IV (Participle)", r'^م(.)(.)(.)$', ArabicPOS.noun), 
    
    // --- Default Form I Present (Yaf'alu) ---
    _RootPattern("Form I (Present)", r'^ي(.)(.)(.)$', ArabicPOS.verb),
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

    if (stem.length <= 2) return AnalysisResult(stem, "Too Short", ArabicPOS.unknown);

    // 遍历模式库，找到第一个匹配的模式
    for (final pattern in _patterns) {
      final match = pattern.regex.firstMatch(stem);
      if (match != null) {
        String r1 = match.group(pattern.groups[0])!;
        String r2 = match.group(pattern.groups[1])!;
        String r3 = match.group(pattern.groups[2])!;
        return AnalysisResult(r1 + r2 + r3, pattern.name, pattern.pos);
      }
    }
    
    // 如果没有模式匹配成功，则使用后备的词缀剥离方法
    String fallbackRoot = _fallbackStripping(stem);
    return AnalysisResult(fallbackRoot, "Fallback/Form I", ArabicPOS.unknown);
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
  List<int> v1 = List<int>.generate(t.length + 1, (index) => 0);

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

/// 混淆项的优先级等级
/// 1: 同根 + 同词性 (最高质量，考义项辨析)
/// 2: 近根 + 同词性 (考拼写辨析)
/// 3: 同根 + 异词性 (考词性辨析，难度较低)
/// 4: 近根 + 异/未知词性 (视觉干扰)
int _calculateTier(AnalysisResult target, AnalysisResult candidate) {
  int rootDist = getLevenshtein(target.root, candidate.root);

  // 1. 同根词 (Root Distance = 0)
  if (rootDist == 0) {
    if (target.pos == candidate.pos && target.pos != ArabicPOS.unknown) {
      return 1; // Tier 1: 同根同性
    }
    return 3; // Tier 3: 同根异性
  }

  // 2. 近根词 (Root Distance = 1)
  if (rootDist == 1) {
    if (target.pos == candidate.pos && target.pos != ArabicPOS.unknown) {
      return 2; // Tier 2: 近根同性
    }
    return 4; // Tier 4: 近根异性/未知
  }

  return 0; // 不相关
}

/// 计算两个阿拉伯语单词的相似度（编辑距离）。
/// [wordA] - 第一个单词。
/// [wordB] - 第二个单词。
/// 返回两个单词词根之间的 Levenshtein 编辑距离。距离越小，单词越相似。
int getArabicWordsSimilarity(String wordA, String wordB) {
  final rootA = _arabicStemmer.extractRoot(wordA);
  final rootB = _arabicStemmer.extractRoot(wordB);
  
  return getLevenshtein(rootA, rootB);
}

//基于BK-tree实现快速相似词搜索

class VocabularyOptimizer {
  final _stemmer = ArabicStemmer();
  BKTree? _bkTree;
  final Map<String, Set<String>> _rootToWordsMap = {}; 

  /// 初始化并构建优化器
  void build(List<String> words) {
    _rootToWordsMap.clear();
    for (final word in words) {
      _addWordToMap(word);
    }
    
    final rootMap = {for (var r in _rootToWordsMap.keys) r: r};
    if (rootMap.isNotEmpty) {
      _bkTree = BKTree(rootMap, getLevenshtein);
    }
  }

  void _addWordToMap(String word) {
    final root = _stemmer.extractRoot(word);
    if (root.isEmpty) return;

    if (_rootToWordsMap.containsKey(root)) {
      _rootToWordsMap[root]!.add(word);
    } else {
      _rootToWordsMap[root] = {word};
    }
  }

  /// 查找与给定单词相似的所有单词
  List<String> findSimilarWords(String word, {int maxDistance = 1}) {
    if (_bkTree == null) return [];
    final queryRoot = _stemmer.extractRoot(word);
    if (queryRoot.isEmpty) return [];

    final results = _bkTree!.search(queryHash: queryRoot, tolerance: maxDistance);
    
    final resultWords = <String>[];
    for (final match in results) {
      if (match is Map && match.isNotEmpty) {
          final root = match.keys.first as String;
          if (_rootToWordsMap.containsKey(root)) {
            resultWords.addAll(_rootToWordsMap[root]!);
          }
      }
    }
    return resultWords;
  }
}

/// 1. 初始化: BKSearch.init(['ktb', 'maktaba', ...]);
/// 2. 搜索: var results = BKSearch.search('kitab');
class BKSearch {
  // 私有构造函数，防止外部实例化
  BKSearch._();
  
  // 单例实例
  static final VocabularyOptimizer _optimizer = VocabularyOptimizer();
  static bool _isInitialized = false;

  /// [必须调用] 初始化搜索引擎
  /// 通常在 App 启动或加载词库时调用
  static void init(List<String> allWords) {
    if (_isInitialized) return; // 避免重复初始化
    print("正在构建 BK-Tree 搜索索引，词库大小: ${allWords.length}...");
    final stopwatch = Stopwatch()..start();
    
    _optimizer.build(allWords);
    
    stopwatch.stop();
    _isInitialized = true;
    print("BK-Tree 索引构建完成，耗时: ${stopwatch.elapsedMilliseconds}ms");
  }

  /// 普通搜索: 返回所有相似词列表
  /// [query] : 用户输入的单词
  /// [threshold] : 容错阈值，默认 1 (允许 1 个字符的编辑距离差异)
  static List<String> search(String query, {int threshold = 1}) {
    if (!_isInitialized) {
      debugPrint("警告: BKSearch 尚未初始化，请先调用 init()");
      return [];
    }
    return _optimizer.findSimilarWords(query, maxDistance: threshold);
  }

  /// [核心功能] 分级搜索混淆词
  /// 返回一个 Map，key 为优先级 (1-4)，value 为符合该优先级的单词列表。
  /// 
  /// Tier 1: 同根 + 同词性 (最高质量)
  /// Tier 2: 近根(dist=1) + 同词性
  /// Tier 3: 同根 + 异词性
  /// Tier 4: 近根(dist=1) + 异/未知词性
  static Map<int, List<String>> searchWithTiers(String targetWord) {
    if (!_isInitialized) {
      debugPrint("警告: BKSearch 尚未初始化，无法执行分级搜索");
      return {1: [], 2: [], 3: [], 4: []};
    }

    // 1. 分析目标词
    final targetAnalysis = _arabicStemmer.analyze(targetWord);
    
    // 2. 使用 BK-Tree 快速获取候选词 (词根距离 <= 1)
    // 这一步利用了索引，极大减少了计算量
    final candidates = _optimizer.findSimilarWords(targetWord, maxDistance: 1);

    final Map<int, List<String>> result = {
      1: [],
      2: [],
      3: [],
      4: [],
    };

    // 3. 遍历候选词，进行精细分类
    for (String candidateStr in candidates) {
      if (candidateStr == targetWord) continue; // 跳过自己

      final candidateAnalysis = _arabicStemmer.analyze(candidateStr);
      
      int tier = _calculateTier(targetAnalysis, candidateAnalysis);
      if (tier > 0) {
        result[tier]!.add(candidateStr);
      }
    }

    return result;
  }

  /// 检查是否已经准备好
  static bool get isReady => _isInitialized;
}
