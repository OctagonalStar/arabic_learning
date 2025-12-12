import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:flutter/services.dart' show rootBundle, FontLoader;
import 'package:arabic_learning/package_replacement/storage.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/package_replacement/fake_sherpa_onnx.dart' if (dart.library.io) 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class Global with ChangeNotifier {
  final Logger logger = Logger("Global");
  final Logger uiLogger = Logger("UI");
  Global();

  late bool firstStart; // 是否为第一次使用
  bool inited = false; //是否初始化完成
  late bool updateLogRequire; //是否需要显示更新日志
  late bool isWideScreen; // 设备是否是宽屏幕
  late final SharedPreferences prefs; // 储存实例
  bool backupFontLoaded = false;
  late bool modelTTSDownloaded = false;
  List<String> internalLogCapture = [];

  /// the setting data
  Map<String, dynamic> _settingData = {
    "User": "",
    "Debug": {
      "internalLog": false,
      "internalLevel": 0 //0:ALL ;1:finest ;2:finer ;3:fine ;4:info ;5:warning ;6:severe ;7:shout ;8:off 
    },
    "LastVersion": StaticsVar.appVersion,
    "regular": {
      "theme": 9,
      "font": 0, //0: normal, 1: backup for ar, 2:backup for ar&zh
      "darkMode": false,
      "hideAppDownloadButton": false,
    },
    "audio": {
      "useBackupSource": 0, // 0: Normal, 1: OnlineBackup, 2: LocalVITS
      "playRate": 1.0,
    },
    "learning": {
      "startDate": 0, // YYYYMMDD;int
      "lastDate": 0, // YYYYMMDD;int
      "KnownWords": [],
    },
    "quiz": {
      /*
      题型说明 
      0: 单词卡片
      1: 中译阿 选择题
      2: 阿译中 选择题
      3: 中译阿 拼写题
      
      Internaly: shuffle only in only each type of question. 
                The order of questionType was not changed.
      Externaly: shuff the order of questionType, but do not change its inside order.
      Globally: shuffle everything.
      */
      // 中阿混合学习
      "zh_ar": {
        "questionSections": [1, 2],
        "shuffleGlobally": true,
        "shuffleInternaly": true,
        "shuffleExternaly": true,
        "modifyAllowed": true,
      },

      // 阿译中学习
      "ar": {
        "questionSections": [2],
        "shuffleGlobally": true,
        "shuffleInternaly": true,
        "shuffleExternaly": true,
        "modifyAllowed": true,
      },

      // 中译阿学习
      "zh": {
        "questionSections": [1],
        "shuffleGlobally": true,
        "shuffleInternaly": true,
        "shuffleExternaly": true,
        "modifyAllowed": true,
      },
    },
    "eggs": {
      "stella": false
    },
    "sync": {
      "enabled": false,
      "account": {
        "uri": "",
        "userName": "",
        "passWord": ""
      },
    }
  };
  static const List<MaterialColor> _themeList = [
      Colors.pink,
      Colors.blue,
      Colors.green,
      Colors.lime,
      Colors.orange,
      Colors.purple,
      Colors.brown,
      Colors.blueGrey,
      Colors.teal,
      Colors.cyan,
      // 下面的是彩蛋颜色 :)
      MaterialColor(0xFF97FFF6, <int, Color>{
        50: Color(0xFFE0FFFF),
        100: Color(0xFFB3FFFF),
        200: Color(0xFF80FFFF),
        300: Color(0xFF4DFFFF),
        400: Color(0xFF1AFFFF),
        500: Color(0xFF00E6D9),
        600: Color(0xFF00BFB3),
        700: Color(0xFF00998C),
        800: Color(0xFF007366),
        900: Color(0xFF004D40),
      })
    ];
  late ThemeData _themeData;
  late Map<String, dynamic> wordData = {};
  Uint8List? stella;
  sherpa_onnx.OfflineTts? vitsTTS;
  String? arFont;
  String? zhFont;
  ThemeData get themeData => _themeData;

  /// 默认配置文件
  ///
  /// ``` json
  /// {
  ///  "User": "",
  ///  "Debug": false,
  ///  "LastVersion": StaticsVar.appVersion,
  ///  "regular": {
  ///    "theme": 9,
  ///    "font": 0, //0: normal, 1: backup for ar, 2:backup for ar&zh
  ///    "darkMode": false,
  ///    "hideAppDownloadButton": false,
  ///  },
  ///  "audio": {
  ///    "useBackupSource": 0, // 0: Normal, 1: OnlineBackup, 2: LocalVITS
  ///    "playRate": 1.0,
  ///  },
  ///  "learning": {
  ///    "startDate": 0, // YYYYMMDD;int
  ///    "lastDate": 0, // YYYYMMDD;int
  ///    "KnownWords": [],
  ///  },
  ///  "quiz": {
  ///    /*
  ///    题型说明 
  ///    0: 单词卡片
  ///    1: 中译阿 选择题
  ///    2: 阿译中 选择题
  ///    3: 中译阿 拼写题
  ///    
  ///    Internaly: shuffle only in only each type of question. 
  ///              The order of questionType was not changed.
  ///    Externaly: shuff the order of questionType, but do not change its inside order.
  ///    Globally: shuffle everything.
  ///    */
  ///    // 中阿混合学习
  ///    "zh_ar": {
  ///      "questionSections": [1, 2],
  ///      "shuffleGlobally": true,
  ///      "shuffleInternaly": true,
  ///      "shuffleExternaly": true,
  ///      "modifyAllowed": true,
  ///    },
  ///    // 阿译中学习
  ///    "ar": {
  ///      "questionSections": [2],
  ///      "shuffleGlobally": true,
  ///      "shuffleInternaly": true,
  ///      "shuffleExternaly": true,
  ///      "modifyAllowed": true,
  ///    },
  ///    // 中译阿学习
  ///    "zh": {
  ///      "questionSections": [1],
  ///      "shuffleGlobally": true,
  ///      "shuffleInternaly": true,
  ///      "shuffleExternaly": true,
  ///      "modifyAllowed": true,
  ///    },
  ///  },
  ///  "eggs": {
  ///    "stella": false
  ///  },
  /// "sync": {
  ///   "enabled": false,
  ///   "account": {
  ///     "uri": "",
  ///     "userName": "",
  ///     "passWord": ""
  ///   },
  /// }
  /// ```
  Map<String, dynamic> get settingData => _settingData;
  int get wordCount => wordData["Words"]!.length;

  Future<bool> init() async {
    logger.info("类收到初始化请求，当前初始化状态为 $inited");
    if(inited) return false;
    logger.info("类开始初始化");
    prefs = await SharedPreferences.getInstance();
    firstStart = prefs.getString("settingData") == null;
    if(firstStart) {
      logger.info("首次启动检测为真");
      updateLogRequire = false;
      await prefs.setString("wordData", jsonEncode({"Words": [], "Classes": {}}));
      wordData = jsonDecode(jsonEncode({"Words": [], "Classes": {}})) as Map<String, dynamic>;
      logger.info("首次启动: 配置表初始化完成");
      await postInit();
    } else {
      await conveySetting();
    }
    inited = true;
    logger.info("初始化完成");
    return true;
  }

  // 预处理一些版本更新的配置文件兼容
  Future<void> conveySetting() async {
    logger.info("处理配置文件");
    wordData = jsonDecode(prefs.getString("wordData")!) as Map<String, dynamic>;
    Map<String, dynamic> oldSetting = jsonDecode(prefs.getString("settingData")!) as Map<String, dynamic>;
    if(oldSetting["LastVersion"] != _settingData["LastVersion"]) {
      logger.info("检测到当前版本与上次启动版本不同");
      updateLogRequire = true;
      oldSetting["LastVersion"] = _settingData["LastVersion"];
    } else {
      updateLogRequire = false;
    }

    // 000109 题型设置更新 List => Map
    if(oldSetting["quiz"]["ar"].runtimeType == List) {
      logger.info("配置文件 000109 结构更新");
      oldSetting["quiz"] = _settingData["quiz"];
    }

    // 000111 调试更新
    if(oldSetting["Debug"].runtimeType == bool){
      logger.info("配置文件 000111 调试更新");
      oldSetting["Debug"] = _settingData["Debug"];
    }

    _settingData = deepMerge(_settingData, oldSetting);
    logger.info("配置文件合成完成");
    await updateSetting();
  }

  // 更新配置到存储中
  Future<void> updateSetting({Map<String, dynamic>? settingData, bool refresh = true}) async {
    logger.info("保存配置文件中");
    if(settingData != null) _settingData = settingData;
    prefs.setString("settingData", jsonEncode(_settingData));
    if(refresh) await postInit();
  }

  void loadFont() async {
    if(backupFontLoaded) return;
    backupFontLoaded = true;
    try{
      final ByteData bundle = await rootBundle.load("assets/fonts/zh/NotoSansSC-Medium.ttf");
      final FontLoader loader = FontLoader(StaticsVar.zhBackupFont)..addFont(Future.value(bundle));
      loader.load();
    } catch (e) {
      backupFontLoaded = false;
    }
    notifyListeners();
  }

  void changeLoggerBehavior() {
    Logger.root.clearListeners();
    if(kDebugMode){
      Logger.root.onRecord.listen((record) async {
        debugPrint('${record.time}-[${record.loggerName}][${record.level.name}]: ${record.message}');
      });
    }
    if(settingData["Debug"]["internalLog"]){
      const List<Level> levelList = [Level.ALL, Level.FINEST, Level.FINER, Level.FINE, Level.INFO, Level.WARNING, Level.SEVERE, Level.SHOUT, Level.OFF];
      Logger.root.onRecord.listen((record) async {
        if(record.level < levelList[settingData["Debug"]["internalLevel"]]) return;
        internalLogCapture.add('${record.time}-[${record.loggerName}][${record.level.name}]: ${record.message}');
      });
    }
  }

  Future<void> postInit() async {
    logger.info("应用设置中");
    changeLoggerBehavior();
    await loadTTS();
    await loadEggs();
    updateTheme();
    notifyListeners();
    logger.info("应用设置完成");
  }

  // load TTS model if any
  Future<void> loadTTS() async {
    if(kIsWeb || vitsTTS != null || settingData["audio"]["useBackupSource"] != 2) return;
    logger.info("TTS: 加载本地TTS中");
    final basePath = await path_provider.getApplicationDocumentsDirectory();
    if(io.File("${basePath.path}/${StaticsVar.modelPath}/ar_JO-kareem-medium.onnx").existsSync()){
      modelTTSDownloaded = true;
      sherpa_onnx.initBindings();
      final vits = sherpa_onnx.OfflineTtsVitsModelConfig(
        model: "${basePath.path}/${StaticsVar.modelPath}/ar_JO-kareem-medium.onnx",
        // lexicon: '${basePath.path}/${StaticsVar.modelPath}/',
        dataDir: "${basePath.path}/${StaticsVar.modelPath}/espeak-ng-data",
        tokens: '${basePath.path}/${StaticsVar.modelPath}/tokens.txt',
        lengthScale: 1 / _settingData["audio"]["playRate"],
      );
      // kokoro = sherpa_onnx.OfflineTtsKokoroModelConfig();
      final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
        vits: vits,
        numThreads: 2,
        debug: false,
        provider: 'cpu',
      );

      final config = sherpa_onnx.OfflineTtsConfig(
        model: modelConfig,
        maxNumSenetences: 1,
      );

      vitsTTS = sherpa_onnx.OfflineTts(config);
      logger.info("TTS: 本地TTS加载完成");
    }
  }

  Future<void> loadEggs() async {
    if(settingData['eggs']['stella'] && stella == null){
      final rawString = await rootBundle.loadString("assets/eggs/s.txt");
      stella = base64Decode(rawString.replaceAll('\n', '').replaceAll('\r', '').trim());
    }
  }

  void updateTheme() {
    logger.info("更新主题中");
    if(settingData["regular"]["font"] == 2) {
      arFont = StaticsVar.arBackupFont;
      zhFont = StaticsVar.zhBackupFont;
      loadFont();
    } else if(settingData["regular"]["font"] == 1) {
      arFont = StaticsVar.arBackupFont;
      zhFont = null;
    } else {
      arFont = null;
      zhFont = null;
    }
    _themeData = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _themeList[settingData["regular"]["theme"]],
        brightness: settingData["regular"]["darkMode"] ? Brightness.dark : Brightness.light,
      ),
      fontFamily: zhFont,
    );
  }

  void acceptAggrement(String name) {
    firstStart = false;
    _settingData["User"] = name;
    prefs.setString("settingData", jsonEncode(settingData));
    notifyListeners();
  }


  // Non-Format Data:
  // {
  //    "ClassName": [
  //       {
  //        "chinese": {Chinese},
  //        "arabic": {arabic},
  //        "explanation": {explanation}
  //       }, ...
  //    ]
  // }

  // Format Data:
  // {
  //    "Words" : [
  //      {
  //        "arabic": {arabic},
  //        "chinese": {Chinese},
  //        "explanation": {explanation},
  //        "subClass": {ClassName},
  //        "learningProgress": {times} //int
  //       }, ...
  //   ],
  //   "Classes": {
  //        "SourceJsonFileName": {
  //          "ClassName": [wordINDEX],
  //        }
  //    }
  // }
  Map<String, dynamic> dataFormater(Map<String, dynamic> data, Map<String, dynamic> exData, String sourceName) {
    logger.info("开始词汇格式化");
    List<String> wordList = [];
    for(var x in exData["Words"]!) {
      wordList.add(x["arabic"]);
    }
    int counter = wordList.length;
    exData["Classes"][sourceName] = {};
    for(var x in data.keys){
      for(var y in data[x]){
        if(wordList.contains(y["arabic"])){
          continue;
        }
        if(exData["Classes"][sourceName]?.containsKey(x) ?? false){
          exData["Classes"][sourceName][x].add(counter);
        } else {
          exData["Classes"][sourceName][x] = [counter];
        }
        exData["Words"]!.add({
          "arabic": y["arabic"],
          "chinese": y["chinese"],
          "explanation": y["explanation"],
          "subClass": x,
          "learningProgress": 0
        });
        wordList.add(y["arabic"]);
        counter ++;
      }
    }
    return exData;
  }

  void importData(Map<String, dynamic> data, String source) {
    logger.info("收到词汇导入请求");
    wordData = dataFormater(data, wordData, source);
    prefs.setString("wordData", jsonEncode(wordData));
    logger.info("词汇导入完成");
    notifyListeners();
  }
  
  void saveLearningProgress(List<Map<String, dynamic>> words){
    logger.info("保存学习进度中");
    List<int> wordIndexs = [];
    for (Map<String, dynamic> word in words){
      wordIndexs.add(word['id']);
    }

    for(int x in wordIndexs){
      wordData["Words"][x]["learningProgress"] += 1;
      if(_settingData["learning"]["KnownWords"].contains(x)) continue;
      if(wordData["Words"][x]["learningProgress"] >= 3) _settingData["learning"]["KnownWords"].add(x);
    }
    prefs.setString("wordData", jsonEncode(wordData));
    // 以 2025/11/1 为基准计算天数（因为这个bug是这天修的:} ）
    final int nowDate = DateTime.now().difference(DateTime(2025, 11, 1)).inDays;
    if (nowDate == _settingData["learning"]["lastDate"]) return;
    if (nowDate - _settingData["learning"]["lastDate"] > 1) {
      _settingData["learning"]["startDate"] = nowDate;
    }
    _settingData["learning"]["lastDate"] = nowDate;
    updateSetting(refresh: false);
    logger.info("学习进度保存完成");
  }
}
