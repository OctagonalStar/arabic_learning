import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:arabic_learning/vars/statics_var.dart' show StaticsVar;
import 'package:flutter/foundation.dart' show immutable;

@immutable
class Config {
  /// 用户名
  final String user;

  /// 上次使用时的版本号
  final int lastVersion;
  

  /// 调试设置类
  final DebugConfig debug;

  /// 常规设置类
  final RegularConfig regular;

  /// 音频设置类
  final AudioConfig audio;

  /// 学习设置类
  final LearningConfig learning;

  /// 题型设置类
  final QuizConfig quiz;

  /// 同步设置类
  final SyncConfig webSync;

  /// 彩蛋设置类
  final EggConfig egg;

  /// AI 练习配置类
  final AiConfig ai;
  
  const Config({
    String? user, 
    int? lastVersion, 
    DebugConfig? debug,
    RegularConfig? regular,
    AudioConfig? audio,
    LearningConfig? learning,
    QuizConfig? quiz,
    SyncConfig? webSync,
    EggConfig? egg,
    AiConfig? ai
  }) : // 空值合并
    user = user??"", 
    lastVersion = lastVersion??StaticsVar.appVersion,
    debug = debug??const DebugConfig(),
    regular = regular??const RegularConfig(),
    audio = audio??const AudioConfig(),
    learning = learning??const LearningConfig(),
    quiz = quiz??const QuizConfig(),
    webSync = webSync??const SyncConfig(),
    egg = egg??const EggConfig(),
    ai = ai??const AiConfig();

  /// 将设置转为Map格式
  Map<String, dynamic> toMap() {
    return {
      "User": user,
      "LastVersion": lastVersion,
      
      "Debug": debug.toMap(),
      "regular": regular.toMap(),
      "audio": audio.toMap(),
      "learning": learning.toMap(),
      "quiz": quiz.toMap(),
      "sync": webSync.toMap(),
      "eggs": egg.toMap(),
      "ai": ai.toMap()
    };
  }

  @override
  String toString() {
    final Map<String, dynamic> configMap = toMap();
    return jsonEncode(configMap);
  }

  static Config buildFromMap(Map<String, dynamic>? setting) {
    if(setting == null) return Config();
    return Config(
      user: setting["User"],
      lastVersion: setting["LastVersion"],
      debug: DebugConfig.buildFromMap(setting["Debug"]),
      regular: RegularConfig.buildFromMap(setting["regular"]),
      audio: AudioConfig.buildFromMap(setting["audio"]),
      learning: LearningConfig.buildFromMap(setting["learning"]),
      quiz: QuizConfig.buildFromMap(setting["quiz"]),
      webSync: SyncConfig.buildFromMap(setting["sync"]),
      egg: EggConfig.buildFromMap(setting["eggs"]),
      ai: AiConfig.buildFromMap(setting["ai"] as Map<String, dynamic>?)
    );
  }

  Config copyWith({
    String? user, 
    int? lastVersion, 
    DebugConfig? debug,
    RegularConfig? regular,
    AudioConfig? audio,
    LearningConfig? learning,
    QuizConfig? quiz,
    SyncConfig? webSync,
    EggConfig? egg,
    AiConfig? ai
  }) {
    return Config(
      user: user??this.user, 
      lastVersion: lastVersion??this.lastVersion,
      debug: debug??this.debug,
      regular: regular??this.regular,
      audio: audio??this.audio,
      learning: learning??this.learning,
      quiz: quiz??this.quiz,
      webSync: webSync??this.webSync,
      egg: egg??this.egg,
      ai: ai??this.ai
    );
  }
}

@immutable
class DebugConfig {
  /// 是否启用软件内部日志捕获
  final bool enableInternalLog;

  /// 日志捕获过滤级别
  /// ```
  /// 0:Level.ALL
  /// 1:Level.finest
  /// 2:Level.finer
  /// 3:Level.fine
  /// 4:Level.info
  /// 5:Level.warning
  /// 6:Level.severe
  /// 7:Level.shout
  /// 8:Level.off 
  /// ```
  final int internalLevel;
  
  const DebugConfig({
    bool? enableInternalLog, 
    int? internalLevel
  }): 
    enableInternalLog = enableInternalLog??false,
    internalLevel = internalLevel??0;

  Map<String, dynamic> toMap() {
    return {
      "internalLog": enableInternalLog,
      "internalLevel": internalLevel
    };
  }

  static DebugConfig buildFromMap(Map<String, dynamic>? setting) {
    if(setting == null) return DebugConfig();
    return DebugConfig(
      enableInternalLog: setting["internalLog"],
      internalLevel: setting["internalLevel"]
    );
  }

  DebugConfig copyWith({
    bool? enableInternalLog,
    int? internalLevel,
  }) {
    return DebugConfig(
      enableInternalLog: enableInternalLog ?? this.enableInternalLog,
      internalLevel: internalLevel ?? this.internalLevel,
    );
  }
}

@immutable
class RegularConfig {
  /// 软件主题颜色
  /// ```
  /// 0: Colors.pink,
  /// 1: Colors.blue,
  /// 2: Colors.green,
  /// 3: Colors.lime,
  /// 4: Colors.orange,
  /// 5: Colors.purple,
  /// 6: Colors.brown,
  /// 7: Colors.blueGrey,
  /// 8: Colors.teal,
  /// 9: Colors.cyan,
  /// 10: 0xFF97FFF6
  /// ```
  final int theme;

  /// 软件字体配置
  /// ```
  /// 0: 正常
  /// 1: 对阿语使用备用字体
  /// 2: 全局使用备用字体
  /// ```
  final int font;

  /// 是否启用深色模式
  final bool darkMode;

  /// 是否隐藏Web端`下载App`按钮
  final bool hideAppDownloadButton;

  const RegularConfig({
    int? theme,
    int? font,
    bool? darkMode,
    bool? hideAppDownloadButton
  }):
    theme = theme??9,
    font = font??0,
    darkMode = darkMode??false,
    hideAppDownloadButton = hideAppDownloadButton??false;

  Map<String, dynamic> toMap() {
    return {
      "theme": theme,
      "font": font,
      "darkMode": darkMode,
      "hideAppDownloadButton": hideAppDownloadButton,
    };
  }

  static RegularConfig buildFromMap(Map<String, dynamic>? setting) {
    if(setting == null) return RegularConfig();
    return RegularConfig(
      theme: setting["theme"],
      font: setting["font"],
      darkMode: setting["darkMode"],
      hideAppDownloadButton: setting["hideAppDownloadButton"]
    );
  }

  RegularConfig copyWith({
    int? theme,
    int? font,
    bool? darkMode,
    bool? hideAppDownloadButton,
  }) {
    return RegularConfig(
      theme: theme ?? this.theme,
      font: font ?? this.font,
      darkMode: darkMode ?? this.darkMode,
      hideAppDownloadButton: hideAppDownloadButton ?? this.hideAppDownloadButton,
    );
  }
}

@immutable
class AudioConfig {
  /// 使用的TTS音源
  /// ```
  /// 0: System TTS
  /// 1: Online
  /// 2: LocalViTS
  /// ```
  final int audioSource;

  /// 播放速度
  final double playRate;

  const AudioConfig({
    int? audioSource,
    double? playRate
  }):
    audioSource = audioSource??0,
    playRate = playRate??1.0;

  Map<String, dynamic> toMap(){
    return {
      "useBackupSource": audioSource,
      "playRate": playRate,
    };
  }

  static AudioConfig buildFromMap(Map<String, dynamic>? setting) {
    if(setting == null) return AudioConfig();
    return AudioConfig(
      audioSource: setting["useBackupSource"],
      playRate: setting["playRate"]
    );
  }

  AudioConfig copyWith({
    int? audioSource,
    double? playRate,
  }) {
    return AudioConfig(
      audioSource: audioSource ?? this.audioSource,
      playRate: playRate ?? this.playRate,
    );
  }
}

@immutable
class LearningConfig {
  /// 连续学习开始的日期(相较于2025/11/1)
  final int startDate;

  /// 连续学习最后有记录的日期(相较于2025/11/1)
  final int lastDate;

  /// 词汇总览中的固定列数
  final int overviewForceColumn;

  /// 搜索时是否实时搜索
  final bool wordLookupRealtime;

  const LearningConfig({
    int? startDate,
    int? lastDate,
    int? overviewForceColumn,
    bool? wordLookupRealtime
  }):
    startDate = startDate??0,
    lastDate = lastDate??0,
    overviewForceColumn = overviewForceColumn??0,
    wordLookupRealtime = wordLookupRealtime??true;

  Map<String, dynamic> toMap(){
    return {
      "startDate": startDate,
      "lastDate": lastDate,
      "overviewForceColumn": overviewForceColumn,
      "wordLookupRealtime": wordLookupRealtime
    };
  }

  static LearningConfig buildFromMap(Map<String, dynamic>? setting) {
    if(setting == null) return LearningConfig();
    return LearningConfig(
      startDate: setting["startDate"],
      lastDate: setting["lastDate"],
      overviewForceColumn: setting["overviewForceColumn"],
      wordLookupRealtime: setting["wordLookupRealtime"]
    );
  }

  LearningConfig copyWith({
    int? startDate,
    int? lastDate,
    int? overviewForceColumn,
    bool? wordLookupRealtime
  }) {
    return LearningConfig(
      startDate: startDate ?? this.startDate,
      lastDate: lastDate ?? this.lastDate,
      overviewForceColumn: overviewForceColumn??this.overviewForceColumn,
      wordLookupRealtime: wordLookupRealtime??this.wordLookupRealtime
    );
  }
}

@immutable
class QuizConfig {
  /// 混合学习配置类
  final SubQuizConfig zhar;

  /// 阿译中专项配置类
  final SubQuizConfig ar;

  /// 中译阿专项配置类
  final SubQuizConfig zh;

  const QuizConfig({
    SubQuizConfig? zhar,
    SubQuizConfig? ar,
    SubQuizConfig? zh
  }):
    zhar = zhar??const SubQuizConfig(
      questionSections: [1, 2], 
      shuffleGlobally: true, 
      shuffleInternaly: false, 
      shuffleExternaly: false, 
      modifyAllowed: true,
      preferSimilar: false
    ),
    ar = ar??const SubQuizConfig(
      questionSections: [2], 
      shuffleGlobally: true, 
      shuffleInternaly: false, 
      shuffleExternaly: false, 
      modifyAllowed: false,
      preferSimilar: false
    ),
    zh = zh??const SubQuizConfig(
      questionSections: [1], 
      shuffleGlobally: true, 
      shuffleInternaly: false, 
      shuffleExternaly: false, 
      modifyAllowed: false,
      preferSimilar: false
    );

  Map<String, dynamic> toMap(){
    return {
      "zh_ar": zhar.toMap(),
      "ar": ar.toMap(),
      "zh": zh.toMap()
    };
  }

  static QuizConfig buildFromMap(Map<String, dynamic>? setting) {
    if(setting == null) return QuizConfig();
    return QuizConfig(
      zhar: SubQuizConfig.buildFromMap(setting["zh_ar"]),
      ar: SubQuizConfig.buildFromMap(setting["ar"]),
      zh: SubQuizConfig.buildFromMap(setting["zh"])
    );
  }

  QuizConfig copyWith({
    SubQuizConfig? zhar,
    SubQuizConfig? ar,
    SubQuizConfig? zh,
  }) {
    return QuizConfig(
      zhar: zhar ?? this.zhar,
      ar: ar ?? this.ar,
      zh: zh ?? this.zh,
    );
  }
}

@immutable
class SubQuizConfig {
  /// 包含的题型
  /// ```
  /// 0: 单词卡片
  /// 1: 中译阿 选择题
  /// 2: 阿译中 选择题
  /// 3: 中译阿 拼写题
  /// 4：听力题
  /// ```
  final List<int> questionSections;

  /// 全局乱序
  final bool shuffleGlobally;

  /// 在题型内部乱序
  /// ```
  /// [[题目A1, 题目A2], [题目B1, 题目B2]]
  /// 可能=> 
  /// [[题目A2, 题目A1], [题目B1, 题目B2]]
  /// ```
  final bool shuffleInternaly;

  /// 将题型乱序
  /// ```
  /// [[题目A1, 题目A2], [题目B1, 题目B2]]
  /// 可能=> 
  /// [[题目B1, 题目B2], [题目A1, 题目A2]]
  /// ```
  final bool shuffleExternaly;

  /// 是否允许修改配置
  final bool modifyAllowed;

  /// 相比于同课程的单词，更偏向于相似的单词
  final bool preferSimilar;

  const SubQuizConfig ({
    required this.questionSections,
    required this.shuffleGlobally,
    required this.shuffleInternaly,
    required this.shuffleExternaly,
    required this.modifyAllowed,
    required this.preferSimilar
  });

  Map<String, dynamic> toMap(){
    return {
      "questionSections": questionSections,
      "shuffleGlobally": shuffleGlobally,
      "shuffleInternaly": shuffleInternaly,
      "shuffleExternaly": shuffleExternaly,
      "modifyAllowed": modifyAllowed,
      "preferSimilar": preferSimilar
    };
  }

  static SubQuizConfig buildFromMap(Map<String, dynamic>? setting){
    if(setting == null) throw Exception("no data for quiz load");
    return SubQuizConfig(
      questionSections: List<int>.generate(setting["questionSections"].length, (index) => setting["questionSections"][index]), 
      shuffleGlobally: setting["shuffleGlobally"], 
      shuffleInternaly: setting["shuffleInternaly"], 
      shuffleExternaly: setting["shuffleExternaly"], 
      modifyAllowed: setting["modifyAllowed"],
      preferSimilar: setting["preferSimilar"] ?? false
    );
  }

  SubQuizConfig copyWith({
    List<int>? questionSections,
    bool? shuffleGlobally,
    bool? shuffleInternaly,
    bool? shuffleExternaly,
    bool? modifyAllowed,
    bool? preferSimilar
  }) {
    return SubQuizConfig(
      questionSections: questionSections ?? this.questionSections,
      shuffleGlobally: shuffleGlobally ?? this.shuffleGlobally,
      shuffleInternaly: shuffleInternaly ?? this.shuffleInternaly,
      shuffleExternaly: shuffleExternaly ?? this.shuffleExternaly,
      modifyAllowed: modifyAllowed ?? this.modifyAllowed,
      preferSimilar: preferSimilar?? this.preferSimilar
    );
  }
}

@immutable
class EggConfig {
  final bool stella;

  const EggConfig({
    bool? stella
  }):stella = stella??false;

  Map<String, dynamic> toMap(){
    return {
      "stella": stella
    };
  }

  static EggConfig buildFromMap(Map<String, dynamic>? setting) {
    if(setting == null) return EggConfig();
    return EggConfig(
      stella: setting["stella"]
    );
  }

  EggConfig copyWith({
    bool? stella,
  }) {
    return EggConfig(
      stella: stella ?? this.stella,
    );
  }
}

@immutable
class SyncConfig {
  /// 是否启用同步
  final bool enabled;

  /// 同步账号配置类
  final SyncAccountConfig account;

  const SyncConfig({
    bool? enabled,
    SyncAccountConfig? account
  }):
    enabled = enabled??false,
    account = account??const SyncAccountConfig();

  Map<String,dynamic> toMap(){
    return {
      "enabled": enabled,
      "account": account.toMap()
    };
  }

  static SyncConfig buildFromMap(Map<String, dynamic>? setting) {
    if(setting == null) return SyncConfig();
    return SyncConfig(
      enabled: setting["enabled"],
      account: SyncAccountConfig.buildFromMap(setting["account"])
    );
  }

  SyncConfig copyWith({
    bool? enabled,
    SyncAccountConfig? account,
  }) {
    return SyncConfig(
      enabled: enabled ?? this.enabled,
      account: account ?? this.account,
    );
  }
}

@immutable
class SyncAccountConfig {
  /// 同步使用的Uri
  final String uri;

  /// 同步使用的用户名
  final String userName;

  /// 同步使用的密码
  final String passWord;

  const SyncAccountConfig({
    String? uri,
    String? userName,
    String? passWord
  }):
    uri = uri??"",
    userName = userName??"",
    passWord = passWord??"";

  Map<String, dynamic> toMap(){
    return {
      "uri": uri,
      "userName": userName,
      "passWord": passWord
    };
  }

  static SyncAccountConfig buildFromMap(Map<String, dynamic>? setting) {
    if(setting == null) return SyncAccountConfig();
    return SyncAccountConfig(
      uri: setting["uri"],
      userName: setting["userName"],
      passWord: setting["passWord"]
    );
  }

  SyncAccountConfig copyWith({
    String? uri,
    String? userName,
    String? passWord,
  }) {
    return SyncAccountConfig(
      uri: uri ?? this.uri,
      userName: userName ?? this.userName,
      passWord: passWord ?? this.passWord,
    );
  }
}

@immutable
class DictData {
  final List<WordItem> words;
  final List<SourceItem> classes;

  const DictData({
    required this.words,
    required this.classes
  });

  static DictData buildFromMap(Map<String, dynamic> data) {
    List<WordItem> wordsData = [];
    for(Map<String, dynamic> x in data["Words"]) {
      wordsData.add(WordItem.buildFromMap(x, wordsData.length));
    }
    List<SourceItem> classesData = [];
    for(String sourceName in (data["Classes"] as Map<String, dynamic>).keys) {
      classesData.add(SourceItem.buildFromMap(data["Classes"][sourceName], sourceName));
    }
    return DictData(words: wordsData, classes: classesData);
  }
  
  Map<String, dynamic> toMap(){
    List<Map<String, dynamic>> wordList = [];
    for(WordItem word in words){
      wordList.add(word.toMap());
    }
    Map<String, dynamic> classMap = {};
    for(SourceItem source in classes){
      classMap[source.sourceJsonFileName] = source.toMap();
    }
    return {
      "Words": wordList,
      "Classes": classMap
    };
  }
}

@immutable
class SourceItem {
  final String sourceJsonFileName;
  final List<ClassItem> subClasses;

  const SourceItem({
    required this.sourceJsonFileName,
    required this.subClasses
  });

  static SourceItem buildFromMap(Map<String, dynamic> data, String sourceJsonFileName) {
    List<ClassItem> classes = [];
    for(String className in data.keys) {
      classes.add(ClassItem(className: className, wordIndexs: List<int>.from(data[className])));
    }
    return SourceItem(sourceJsonFileName: sourceJsonFileName, subClasses: classes);
  }

  Map<String, List<int>> toMap(){
    Map<String, List<int>> classesMap = {};
    for(ClassItem classItem in subClasses) {
      classesMap[classItem.className] = classItem.wordIndexs;
    }
    return classesMap;
  }

  String getHash(List<WordItem> words) {
    return sha256.convert(utf8.encode(sourceJsonFileName)).toString();
  }
}

@immutable
class ClassItem {
  final String className;
  final List<int> wordIndexs;

  const ClassItem({
    required this.className,
    required this.wordIndexs
  });

  @override
  String toString() {
    return className;
  }

  String getHash() {
    return sha256.convert(utf8.encode(toString())).toString();
  }
}

/// 单个释义条目，包含中文、解释、所属课程和来源词典
@immutable
class WordMeaning {
  /// 中文含义
  final String chinese;

  /// 补充解释
  final String explanation;

  /// 所属子课程名称
  final String className;

  /// 词典来源（SourceItem.sourceJsonFileName）
  final String source;

  const WordMeaning({
    required this.chinese,
    required this.explanation,
    required this.className,
    required this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      "chinese": chinese,
      "explanation": explanation,
      "className": className,
      "source": source,
    };
  }

  static WordMeaning buildFromMap(Map<String, dynamic> m) {
    return WordMeaning(
      chinese: m["chinese"] ?? "",
      explanation: m["explanation"] ?? "",
      className: m["className"] ?? "",
      source: m["source"] ?? "",
    );
  }
}

@immutable
class WordItem {
  final String arabic;

  /// 所有来源的释义列表（一词多义）
  final List<WordMeaning> meanings;

  final int id;

  const WordItem({
    required this.arabic,
    required this.meanings,
    required this.id,
  });

  // ── 向后兼容 getter，旧代码无需修改 ─────────────────────────
  /// 主释义的中文（取 meanings[0]）
  String get chinese => meanings.isNotEmpty ? meanings[0].chinese : '';

  /// 主释义的解释（取 meanings[0]）
  String get explanation => meanings.isNotEmpty ? meanings[0].explanation : '';

  /// 主释义的课程（取 meanings[0]）
  String get className => meanings.isNotEmpty ? meanings[0].className : '';

  // ── 多义辅助方法 ──────────────────────────────────────────────
  /// 按词典来源获取对应的释义，找不到时返回 null
  WordMeaning? getMeaningForSource(String sourceFileName) {
    for (final m in meanings) {
      if (m.source == sourceFileName) return m;
    }
    return null;
  }

  /// 返回一个追加了新义项的新实例（immutable 模式）
  WordItem addMeaning(WordMeaning meaning) {
    return WordItem(
      arabic: arabic,
      meanings: List.unmodifiable([...meanings, meaning]),
      id: id,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "arabic": arabic,
      "meanings": meanings.map((m) => m.toMap()).toList(),
    };
  }

  @override
  String toString() {
    return jsonEncode(toMap());
  }

  /// 支持新格式（含 meanings 列表）和旧格式（chinese/explanation/subClass 扁平字段）
  static WordItem buildFromMap(Map<String, dynamic> word, int id) {
    if (word.containsKey("meanings") && word["meanings"] is List) {
      // 新格式
      final List<WordMeaning> meanings = (word["meanings"] as List)
          .map((m) => WordMeaning.buildFromMap(m as Map<String, dynamic>))
          .toList();
      return WordItem(arabic: word["arabic"], meanings: List.unmodifiable(meanings), id: id);
    } else {
      // 旧格式 fallback：封装为单元素列表（source 字段留空，由外层补充）
      final meaning = WordMeaning(
        chinese: word["chinese"] ?? "",
        explanation: word["explanation"] ?? "",
        className: word["subClass"] ?? "",
        source: "",
      );
      return WordItem(arabic: word["arabic"], meanings: List.unmodifiable([meaning]), id: id);
    }
  }
}

// ── AI 服务商预设 ──────────────────────────────────────────────────────────────

class AiPreset {
  final String name;
  final String baseUrl;
  final AiApiMode mode;
  final String defaultModel;
  final String hint;
  const AiPreset({
    required this.name,
    required this.baseUrl,
    required this.mode,
    required this.defaultModel,
    this.hint = '',
  });
}

// baseUrl 均已含版本路径，代码层不再自动追加 /v1
const List<AiPreset> kAiPresets = [
  AiPreset(name: 'OpenAI', baseUrl: 'https://api.openai.com/v1', mode: AiApiMode.openaiCompatible, defaultModel: 'gpt-4o-mini', hint: '官方 OpenAI 接口'),
  AiPreset(name: 'DeepSeek', baseUrl: 'https://api.deepseek.com/v1', mode: AiApiMode.openaiCompatible, defaultModel: 'deepseek-chat', hint: '国内高性价比首选'),
  AiPreset(name: 'SiliconFlow 硅基流动', baseUrl: 'https://api.siliconflow.cn/v1', mode: AiApiMode.openaiCompatible, defaultModel: 'Qwen/Qwen2.5-7B-Instruct', hint: '多模型聚合平台'),
  AiPreset(name: 'OpenRouter', baseUrl: 'https://openrouter.ai/api/v1', mode: AiApiMode.openaiCompatible, defaultModel: 'openai/gpt-4o-mini', hint: '多模型路由聚合'),
  AiPreset(name: '智谱 AI (GLM)', baseUrl: 'https://open.bigmodel.cn/api/paas/v4', mode: AiApiMode.openaiCompatible, defaultModel: 'glm-4-flash', hint: '清华·智谱 GLM 系列'),
  AiPreset(name: '火山引擎 (Ark)', baseUrl: 'https://ark.volces.com/api/v3', mode: AiApiMode.openaiCompatible, defaultModel: 'doubao-pro-4k', hint: '字节跳动豆包'),
  AiPreset(name: '阿里云百炼', baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1', mode: AiApiMode.openaiCompatible, defaultModel: 'qwen-turbo', hint: '阿里·通义千问'),
  AiPreset(name: '百度文心一言', baseUrl: 'https://qianfan.baidubce.com/v2', mode: AiApiMode.openaiCompatible, defaultModel: 'ernie-4.0-8k', hint: '百度文心大模型'),
  AiPreset(name: 'Gemini (原生接口)', baseUrl: 'https://generativelanguage.googleapis.com', mode: AiApiMode.geminiNative, defaultModel: 'gemini-2.0-flash', hint: 'Google Gemini 原生'),
  AiPreset(name: 'Gemini (OpenAI 兼容)', baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai', mode: AiApiMode.openaiCompatible, defaultModel: 'gemini-2.0-flash', hint: 'Google Gemini · OpenAI 兼容路径'),
];

// ── AI 练习配置 ──────────────────────────────────────────────────────────────
enum AiApiMode {
  openaiCompatible,
  geminiNative,
  webAutomation,
}

extension AiApiModeExt on AiApiMode {
  String get label {
    switch (this) {
      case AiApiMode.openaiCompatible: return 'OpenAI 兼容接口';
      case AiApiMode.geminiNative:     return 'Gemini 原生接口';
      case AiApiMode.webAutomation:    return '网页自动化 (Web)';
    }
  }

  static AiApiMode fromString(String val) {
    return AiApiMode.values.firstWhere(
      (e) => e.name == val,
      orElse: () => AiApiMode.openaiCompatible,
    );
  }
}

@immutable
class AiEndpoint {
  final String id;
  final String name;
  final AiApiMode mode;
  final String baseUrl;
  final String apiKey;
  final String model;

  const AiEndpoint({
    required this.id,
    required this.name,
    required this.mode,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mode': mode.name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'model': model,
    };
  }

  /// 旧数据向后兼容：若 baseUrl 不含版本路径（如 /v1、/v4），自动追加 /v1
  static String _migrateBaseUrl(String url) {
    final trimmed = url.trimRight();
    if (trimmed.isEmpty) return trimmed;
    // 已含 /v\d+ 路径片段则不修改
    if (RegExp(r'/v\d+').hasMatch(trimmed)) return trimmed;
    return '$trimmed/v1';
  }

  static AiEndpoint buildFromMap(Map<String, dynamic> data) {
    return AiEndpoint(
      id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: data['name'] ?? 'Unnamed',
      mode: AiApiModeExt.fromString(data['mode'] ?? ''),
      baseUrl: _migrateBaseUrl(data['baseUrl'] ?? ''),
      apiKey: data['apiKey'] ?? '',
      model: data['model'] ?? '',
    );
  }

  AiEndpoint copyWith({
    String? name,
    AiApiMode? mode,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) {
    return AiEndpoint(
      id: this.id,
      name: name ?? this.name,
      mode: mode ?? this.mode,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }
}

@immutable
class AiConfig {
  /// 选中的 AI 节点 ID
  final String selectedEndpointId;

  /// 所有保存的节点配置
  final List<AiEndpoint> endpoints;

  /// 默认出题数量（1-10）
  final int defaultQuestionCount;

  /// 阅读理解每批词汇量（10-50，默认25）
  final int readingBatchSize;

  const AiConfig({
    String? selectedEndpointId,
    List<AiEndpoint>? endpoints,
    int? defaultQuestionCount,
    int? readingBatchSize,
  })  : selectedEndpointId = selectedEndpointId ?? 'default_openai',
        endpoints = endpoints ?? const [
          AiEndpoint(
            id: 'default_openai',
            name: 'OpenAI',
            mode: AiApiMode.openaiCompatible,
            baseUrl: 'https://api.openai.com/v1',
            apiKey: '',
            model: 'gpt-4o-mini',
          )
        ],
        defaultQuestionCount = defaultQuestionCount ?? 3,
        readingBatchSize = readingBatchSize ?? 25;

  /// 获取当前选中的配置节点
  AiEndpoint get currentEndpoint {
    try {
      return endpoints.firstWhere((e) => e.id == selectedEndpointId);
    } catch (_) {
      return endpoints.isNotEmpty ? endpoints.first : const AiEndpoint(
        id: 'fallback',
        name: 'Fallback',
        mode: AiApiMode.openaiCompatible,
        baseUrl: '',
        apiKey: '',
        model: '',
      );
    }
  }

  // 兼容旧版访问方式（临时）
  @Deprecated('Use currentEndpoint.baseUrl instead')
  String get baseUrl => currentEndpoint.baseUrl;
  @Deprecated('Use currentEndpoint.apiKey instead')
  String get apiKey => currentEndpoint.apiKey;
  @Deprecated('Use currentEndpoint.model instead')
  String get model => currentEndpoint.model;

  Map<String, dynamic> toMap() {
    return {
      'selectedEndpointId': selectedEndpointId,
      'endpoints': endpoints.map((e) => e.toMap()).toList(),
      'defaultQuestionCount': defaultQuestionCount,
      'readingBatchSize': readingBatchSize,
    };
  }

  static AiConfig buildFromMap(Map<String, dynamic>? setting) {
    if (setting == null) return const AiConfig();

    // 兼容旧格式（如果没有 endpoints 但有 baseUrl/apiKey）
    List<AiEndpoint>? parsedEndpoints;
    String? parsedSelectedId;

    if (setting.containsKey('endpoints')) {
      final list = setting['endpoints'] as List<dynamic>;
      parsedEndpoints = list.map((e) => AiEndpoint.buildFromMap(e as Map<String, dynamic>)).toList();
      parsedSelectedId = setting['selectedEndpointId'] as String?;
    } else if (setting.containsKey('baseUrl') || setting.containsKey('apiKey')) {
      // 老版本数据迁移
      final oldBaseUrl = setting['baseUrl'] as String? ?? 'https://api.openai.com';
      final oldApiKey = setting['apiKey'] as String? ?? '';
      final oldModel = setting['model'] as String? ?? 'gpt-4o-mini';
      
      final defaultEp = AiEndpoint(
        id: 'migrated_default',
        name: '旧版迁移配置',
        mode: AiApiMode.openaiCompatible,
        baseUrl: oldBaseUrl,
        apiKey: oldApiKey,
        model: oldModel,
      );
      parsedEndpoints = [defaultEp];
      parsedSelectedId = 'migrated_default';
    }

    return AiConfig(
      selectedEndpointId: parsedSelectedId,
      endpoints: parsedEndpoints,
      defaultQuestionCount: setting['defaultQuestionCount'] as int?,
      readingBatchSize: setting['readingBatchSize'] as int?,
    );
  }

  AiConfig copyWith({
    String? selectedEndpointId,
    List<AiEndpoint>? endpoints,
    int? defaultQuestionCount,
    int? readingBatchSize,
  }) {
    return AiConfig(
      selectedEndpointId: selectedEndpointId ?? this.selectedEndpointId,
      endpoints: endpoints ?? this.endpoints,
      defaultQuestionCount: defaultQuestionCount ?? this.defaultQuestionCount,
      readingBatchSize: readingBatchSize ?? this.readingBatchSize,
    );
  }
}

class ClassSelection {
  List<ClassItem> selectedClass;
  bool countInReview;

  ClassSelection({
    required this.selectedClass,
    required this.countInReview
  });
}