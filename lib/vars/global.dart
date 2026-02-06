import 'dart:convert';

import 'package:arabic_learning/funcs/fsrs_func.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle, FontLoader;
import 'package:path_provider/path_provider.dart' as path_provider;

import 'package:arabic_learning/vars/statics_var.dart';
import 'package:arabic_learning/package_replacement/storage.dart';
import 'package:arabic_learning/vars/config_structure.dart' show ClassItem, SourceItem, Config, DictData, WordItem;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/package_replacement/fake_sherpa_onnx.dart' if (dart.library.io) 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class Global with ChangeNotifier {
  final Logger uiLogger = Logger("UI");
  final Logger logger = Logger("Global");
  
  bool backupFontLoaded = false;
  bool inited = false; //是否初始化完成
  List<String> internalLogCapture = [];
  Uint8List? stella;
  String? arFont;
  String? zhFont;
  late bool firstStart; // 是否为第一次使用
  late bool updateLogRequire; //是否需要显示更新日志
  late bool isWideScreen; // 设备是否是宽屏幕
  late final SharedPreferences prefs; // 储存实例
  late FSRS globalFSRS;
  late ThemeData themeData;
  bool modelTTSDownloaded = false;
  late DictData wordData;
  int get wordCount => wordData.words.length;
  sherpa_onnx.OfflineTts? vitsTTS;

  Config globalConfig = Config();


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
      wordData = DictData(words: [], classes: []);
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

    // 在配置文件加载完成前可以做的
    wordData = DictData.buildFromMap(jsonDecode(prefs.getString("wordData")!));
    if(!BKSearch.isReady) BKSearch.init(wordData.words);
    globalFSRS = FSRS()..init(outerPrefs: prefs);

    Config oldConfig = Config.buildFromMap(jsonDecode(prefs.getString("settingData")!));
    if(oldConfig.lastVersion != globalConfig.lastVersion) {
      logger.info("检测到当前版本与上次启动版本不同");
      updateLogRequire = true;
      oldConfig=oldConfig.copyWith(lastVersion: globalConfig.lastVersion);
    } else {
      updateLogRequire = false;
    }

    globalConfig = oldConfig;
    logger.info("配置文件合成完成");
    await updateSetting();
  }

  // 更新配置到存储中
  Future<void> updateSetting({Map<String, dynamic>? settingData, bool refresh = true}) async {
    logger.info("保存配置文件中");
    if(settingData != null) globalConfig = Config.buildFromMap(settingData);
    prefs.setString("settingData", jsonEncode(globalConfig.toMap()));
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
    if(globalConfig.debug.enableInternalLog){
      Logger.root.level = Level.ALL;
      const List<Level> levelList = [Level.ALL, Level.FINEST, Level.FINER, Level.FINE, Level.INFO, Level.WARNING, Level.SEVERE, Level.SHOUT, Level.OFF];
      Logger.root.onRecord.listen((record) async {
        if(record.level < levelList[globalConfig.debug.internalLevel]) return;
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
    if(kIsWeb || vitsTTS != null || globalConfig.audio.audioSource != 2) return;
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
        lengthScale: 1 / globalConfig.audio.playRate,
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
    if(globalConfig.egg.stella && stella == null){
      final rawString = await rootBundle.loadString("assets/eggs/s.txt");
      stella = base64Decode(rawString.replaceAll('\n', '').replaceAll('\r', '').trim());
    }
  }

  void updateTheme() {
    logger.info("更新主题中");
    if(globalConfig.regular.font == 2) {
      arFont = StaticsVar.arBackupFont;
      zhFont = StaticsVar.zhBackupFont;
      loadFont();
    } else if(globalConfig.regular.font == 1) {
      arFont = StaticsVar.arBackupFont;
      zhFont = null;
    } else {
      arFont = null;
      zhFont = null;
    }
    themeData = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: StaticsVar.themeList[globalConfig.regular.theme],
        brightness: globalConfig.regular.darkMode ? Brightness.dark : Brightness.light,
      ),
      fontFamily: zhFont,
    );
  }

  void acceptAggrement(String name) {
    firstStart = false;
    globalConfig = globalConfig.copyWith(user: name);
    prefs.setString("settingData", jsonEncode(globalConfig.toMap()));
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
  DictData dataFormater(Map<String, dynamic> data, DictData exData, String sourceName) {
    logger.info("开始词汇格式化");
    List<String> wordList = [];
    for(WordItem x in exData.words) {
      wordList.add(x.arabic);
    }
    int counter = wordList.length;

    SourceItem? exSource;
    // 查找已有数据中是否有同名的源数据组
    for(SourceItem x in exData.classes) {
      if(x.sourceJsonFileName == sourceName) exSource = x;
    }
    if(exSource == null){
      exData.classes.add(SourceItem(sourceJsonFileName: sourceName, subClasses: []));
      exSource = exData.classes.last;
    }

    for(var className in data.keys){
      ClassItem exClass = ClassItem(className: className, wordIndexs: []);
      for(var word in data[className]){
        if(wordList.contains(word["arabic"])){
          continue;
        }
        exClass.wordIndexs.add(counter);
        exData.words.add(
          WordItem(
            arabic: word["arabic"], 
            chinese: word["chinese"], 
            explanation: word["explanation"], 
            className: className, 
            id: counter
          )
        );
        wordList.add(word["arabic"]);
        counter ++;
      }
      exSource.subClasses.add(exClass);
    }
    return exData;
  }

  void importData(Map<String, dynamic> data, String source) {
    logger.info("收到词汇导入请求");
    wordData = dataFormater(data, wordData, source);
    prefs.setString("wordData", jsonEncode(wordData.toMap()));
    BKSearch.init(wordData.words); // 重新建树
    logger.info("词汇导入完成");
    notifyListeners();
  }
  
  void updateLearningStreak(){
    final int nowDate = DateTime.now().difference(DateTime(2025, 11, 1)).inDays;
    if (nowDate == globalConfig.learning.lastDate) return;
    logger.info("保存学习进度中");
    // 以 2025/11/1 为基准计算天数（因为这个bug是这天修的:} ）
    if (nowDate - globalConfig.learning.lastDate > 1) {
      globalConfig = globalConfig.copyWith(learning: globalConfig.learning.copyWith(startDate: nowDate));
    }
    globalConfig = globalConfig.copyWith(learning: globalConfig.learning.copyWith(lastDate: nowDate));
    updateSetting(refresh: false);
    logger.info("学习进度保存完成");
  }
}
