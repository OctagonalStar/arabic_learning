// 应用配置模型：Config 及其子配置（原 lib/vars/config_structure.dart 拆分）。
// 仅承载配置相关不可变数据类，词库/阅读模型见 models/dict.dart、models/reading.dart。

import 'package:arabic_learning/core/statics.dart' show StaticsVar;
import 'package:flutter/foundation.dart' show immutable;

@immutable
class Config {
  /// 用户名
  final String user;

  /// 上次使用时的版本号
  final int lastVersion;
  
  /// 上次签署的条款号
  final int lastTermVersion;

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

  
  const Config({
    this.user = "", 
    this.lastTermVersion = 0,
    this.lastVersion = StaticsVar.appVersion, 
    this.debug = const DebugConfig(),
    this.regular = const RegularConfig(),
    this.audio = const AudioConfig(),
    this.learning = const LearningConfig(),
    this.quiz = const QuizConfig(),
    this.webSync = const SyncConfig()
  });

  /// 将设置转为Map格式
  Map<String, dynamic> toMap() {
    return {
      "User": user,
      "LastVersion": lastVersion,
      "LastTermVersion": lastTermVersion,
      "Debug": debug.toMap(),
      "regular": regular.toMap(),
      "audio": audio.toMap(),
      "learning": learning.toMap(),
      "quiz": quiz.toMap(),
      "sync": webSync.toMap()
    };
  }

  static Config buildFromMap(Map<String, dynamic>? setting) {
    if(setting == null) return Config();
    return Config(
      user: setting["User"],
      lastVersion: setting["LastVersion"],
      lastTermVersion: setting["LastTermVersion"]??0,
      debug: DebugConfig.buildFromMap(setting["Debug"]),
      regular: RegularConfig.buildFromMap(setting["regular"]),
      audio: AudioConfig.buildFromMap(setting["audio"]),
      learning: LearningConfig.buildFromMap(setting["learning"]),
      quiz: QuizConfig.buildFromMap(setting["quiz"]),
      webSync: SyncConfig.buildFromMap(setting["sync"])
    );
  }

  Config copyWith({
    String? user, 
    int? lastVersion, 
    int? lastTermVersion,
    DebugConfig? debug,
    RegularConfig? regular,
    AudioConfig? audio,
    LearningConfig? learning,
    QuizConfig? quiz,
    SyncConfig? webSync
  }) {
    return Config(
      user: user??this.user, 
      lastVersion: lastVersion??this.lastVersion,
      lastTermVersion: lastTermVersion??this.lastTermVersion,
      debug: debug??this.debug,
      regular: regular??this.regular,
      audio: audio??this.audio,
      learning: learning??this.learning,
      quiz: quiz??this.quiz,
      webSync: webSync??this.webSync
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
    this.enableInternalLog = false, 
    this.internalLevel = 0
  });

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

  /// 是否启用深色模式。
  ///
  /// **已由 [themeMode] 取代**，仅为兼容旧版本降级读取而保留并继续写出
  /// （存储 key 仍为 `"darkMode"`）。新代码请使用 [themeMode]。
  final bool darkMode;

  /// 深色模式三态。
  /// ```
  /// 0: 跟随系统
  /// 1: 强制浅色
  /// 2: 强制深色
  /// ```
  ///
  /// 旧数据无此字段时由 [darkMode] 推导（`true→2`、`false→1`）以保持既有观感；
  /// 新安装默认 `0`（跟随系统）。
  final int themeMode;

  /// 是否启用动态取色（Material You）。
  ///
  /// 平台不支持或 Web 端时自动回退到 [theme] 指定的种子色。
  final bool dynamicColor;

  /// 是否隐藏Web端`下载App`按钮
  final bool hideAppDownloadButton;

  /// [themeMode] 取值：跟随系统。
  static const int themeModeSystem = 0;

  /// [themeMode] 取值：强制浅色。
  static const int themeModeLight = 1;

  /// [themeMode] 取值：强制深色。
  static const int themeModeDark = 2;

  const RegularConfig({
    this.theme = 9,
    this.font = 0,
    this.darkMode = false,
    this.themeMode = themeModeSystem,
    this.dynamicColor = false,
    this.hideAppDownloadButton = false
  });

  Map<String, dynamic> toMap() {
    return {
      "theme": theme,
      "font": font,
      "darkMode": darkMode,
      "themeMode": themeMode,
      "dynamicColor": dynamicColor,
      "hideAppDownloadButton": hideAppDownloadButton,
    };
  }

  static RegularConfig buildFromMap(Map<String, dynamic>? setting) {
    if(setting == null) return RegularConfig();

    // 旧数据兼容：无 themeMode 时由 darkMode 推导；两者都无则为新装默认 0。
    final int themeMode;
    if(setting.containsKey("themeMode")) {
      final dynamic rawThemeMode = setting["themeMode"];
      themeMode = rawThemeMode is num ? rawThemeMode.toInt() : themeModeSystem;
    } else if(setting.containsKey("darkMode")) {
      themeMode = setting["darkMode"] == true ? themeModeDark : themeModeLight;
    } else {
      themeMode = themeModeSystem;
    }

    return RegularConfig(
      theme: setting["theme"] ?? 9,
      font: setting["font"] ?? 0,
      darkMode: setting["darkMode"] ?? false,
      themeMode: themeMode,
      dynamicColor: setting["dynamicColor"] ?? false,
      hideAppDownloadButton: setting["hideAppDownloadButton"] ?? false
    );
  }

  RegularConfig copyWith({
    int? theme,
    int? font,
    bool? darkMode,
    int? themeMode,
    bool? dynamicColor,
    bool? hideAppDownloadButton,
  }) {
    final int nextThemeMode = themeMode ?? this.themeMode;
    // 显式传入 themeMode 时同步旧 darkMode 字段，保证降级兼容；
    // 跟随系统（0）无法确定亮暗，沿用原有 darkMode。
    final bool nextDarkMode = darkMode ??
        (themeMode == null
            ? this.darkMode
            : nextThemeMode == themeModeDark
                ? true
                : nextThemeMode == themeModeLight
                    ? false
                    : this.darkMode);
    return RegularConfig(
      theme: theme ?? this.theme,
      font: font ?? this.font,
      darkMode: nextDarkMode,
      themeMode: nextThemeMode,
      dynamicColor: dynamicColor ?? this.dynamicColor,
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

  /// 自动播放发音
  final bool autoPlay;

  const AudioConfig({
    this.audioSource = 0,
    this.playRate = 1.0,
    this.autoPlay = false
  });

  Map<String, dynamic> toMap(){
    return {
      "useBackupSource": audioSource,
      "playRate": playRate,
      "autoPlay": autoPlay
    };
  }

  static AudioConfig buildFromMap(Map<String, dynamic>? setting) {
    if(setting == null) return AudioConfig();
    return AudioConfig(
      audioSource: setting["useBackupSource"],
      playRate: setting["playRate"],
      autoPlay: setting["autoPlay"]??false
    );
  }

  AudioConfig copyWith({
    int? audioSource,
    double? playRate,
    bool? autoPlay
  }) {
    return AudioConfig(
      audioSource: audioSource ?? this.audioSource,
      playRate: playRate ?? this.playRate,
      autoPlay: autoPlay ?? this.autoPlay
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
    this.startDate = 0,
    this.lastDate = 0,
    this.overviewForceColumn = 0,
    this.wordLookupRealtime = true
  });

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

  const QuizConfig ({
    this.questionSections = const [1, 2],
    this.shuffleGlobally = true,
    this.shuffleInternaly = false,
    this.shuffleExternaly = false,
    this.modifyAllowed = true,
    this.preferSimilar = false
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

  static QuizConfig buildFromMap(Map<String, dynamic>? setting){
    if(setting == null) throw Exception("no data for quiz load");
    
    // 旧版本兼容
    if(setting.containsKey("zh_ar")){
      return QuizConfig.buildFromMap(setting["zh_ar"]);
    }

    return QuizConfig(
      questionSections: List<int>.generate(setting["questionSections"].length, (index) => setting["questionSections"][index]), 
      shuffleGlobally: setting["shuffleGlobally"], 
      shuffleInternaly: setting["shuffleInternaly"], 
      shuffleExternaly: setting["shuffleExternaly"], 
      modifyAllowed: setting["modifyAllowed"],
      preferSimilar: setting["preferSimilar"] ?? false
    );
  }

  QuizConfig copyWith({
    List<int>? questionSections,
    bool? shuffleGlobally,
    bool? shuffleInternaly,
    bool? shuffleExternaly,
    bool? modifyAllowed,
    bool? preferSimilar
  }) {
    return QuizConfig(
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
class SyncConfig {
  /// 是否启用同步
  final bool enabled;

  /// 同步账号配置类
  final SyncAccountConfig account;

  const SyncConfig({
    this.enabled = false,
    this.account = const SyncAccountConfig()
  });

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
    this.uri = "",
    this.userName = "",
    this.passWord = ""
  });

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
