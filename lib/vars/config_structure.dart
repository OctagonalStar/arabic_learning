import 'dart:convert';

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
  
  const Config({
    String? user, 
    int? lastVersion, 
    DebugConfig? debug,
    RegularConfig? regular,
    AudioConfig? audio,
    LearningConfig? learning,
    QuizConfig? quiz,
    SyncConfig? webSync,
    EggConfig? egg
  }) : // 空值合并
    user = user??"", 
    lastVersion = lastVersion??StaticsVar.appVersion,
    debug = debug??const DebugConfig(),
    regular = regular??const RegularConfig(),
    audio = audio??const AudioConfig(),
    learning = learning??const LearningConfig(),
    quiz = quiz??const QuizConfig(),
    webSync = webSync??const SyncConfig(),
    egg = egg??const EggConfig();

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
      "eggs": egg.toMap()
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
      egg: EggConfig.buildFromMap(setting["eggs"])
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
    EggConfig? egg
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
      egg: egg??this.egg
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

  /// 已经学习的单词
  /// 内部int为单词ID
  final List<int> knownWords;

  const LearningConfig({
    int? startDate,
    int? lastDate,
    List<int>? knownWords
  }):
    startDate = startDate??0,
    lastDate = lastDate??0,
    knownWords = knownWords??const [];

  Map<String, dynamic> toMap(){
    return {
      "startDate": startDate,
      "lastDate": lastDate,
      "KnownWords": knownWords,
    };
  }

  static LearningConfig buildFromMap(Map<String, dynamic>? setting) {
    if(setting == null) return LearningConfig();
    return LearningConfig(
      startDate: setting["startDate"],
      lastDate: setting["lastDate"],
      knownWords: setting["knownWords"]
    );
  }

  LearningConfig copyWith({
    int? startDate,
    int? lastDate,
    List<int>? knownWords,
  }) {
    return LearningConfig(
      startDate: startDate ?? this.startDate,
      lastDate: lastDate ?? this.lastDate,
      knownWords: knownWords ?? this.knownWords,
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
      modifyAllowed: true
    ),
    ar = ar??const SubQuizConfig(
      questionSections: [2], 
      shuffleGlobally: true, 
      shuffleInternaly: false, 
      shuffleExternaly: false, 
      modifyAllowed: false
    ),
    zh = zh??const SubQuizConfig(
      questionSections: [1], 
      shuffleGlobally: true, 
      shuffleInternaly: false, 
      shuffleExternaly: false, 
      modifyAllowed: false
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

  const SubQuizConfig ({
    required this.questionSections,
    required this.shuffleGlobally,
    required this.shuffleInternaly,
    required this.shuffleExternaly,
    required this.modifyAllowed
  });

  Map<String, dynamic> toMap(){
    return {
      "questionSections": questionSections,
      "shuffleGlobally": shuffleGlobally,
      "shuffleInternaly": shuffleInternaly,
      "shuffleExternaly": shuffleExternaly,
      "modifyAllowed": modifyAllowed,
    };
  }

  static SubQuizConfig buildFromMap(Map<String, dynamic>? setting){
    if(setting == null) throw Exception("no data for quiz load");
    return SubQuizConfig(
      questionSections: List<int>.generate(setting["questionSections"].length, (index) => setting["questionSections"][index]), 
      shuffleGlobally: setting["shuffleGlobally"], 
      shuffleInternaly: setting["shuffleInternaly"], 
      shuffleExternaly: setting["shuffleExternaly"], 
      modifyAllowed: setting["modifyAllowed"]
    );
  }

  SubQuizConfig copyWith({
    List<int>? questionSections,
    bool? shuffleGlobally,
    bool? shuffleInternaly,
    bool? shuffleExternaly,
    bool? modifyAllowed,
  }) {
    return SubQuizConfig(
      questionSections: questionSections ?? this.questionSections,
      shuffleGlobally: shuffleGlobally ?? this.shuffleGlobally,
      shuffleInternaly: shuffleInternaly ?? this.shuffleInternaly,
      shuffleExternaly: shuffleExternaly ?? this.shuffleExternaly,
      modifyAllowed: modifyAllowed ?? this.modifyAllowed,
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