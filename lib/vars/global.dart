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
  String? arFont;
  String? zhFont;
  bool updateLogRequire = false; //是否需要显示更新日志

  ThemeData get themeData => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: StaticsVar.themeList[AppData().config.regular.theme],
      brightness: AppData().config.regular.darkMode ? Brightness.dark : Brightness.light,
    ),
    fontFamily: zhFont,
  );


  Future<bool> init() async {
    logger.info("开始全局控制类初始化");

    AppData appData = AppData();
    await appData.init();
    FSRS().init();

    if(appData.isFirstStart) {
      logger.info("首次启动检测为真");
      appData.initStorageValue();
      await refreshApp();
    } else {
      conveySetting();
      await updateSetting();
    }

    logger.info("初始化完成");
    return true;
  }

  // 预处理一些版本更新的配置文件兼容
  void conveySetting() {
    logger.info("处理配置文件");

    Config oldConfig = Config.buildFromMap(jsonDecode(AppData().storage.getString("settingData")!));
    if(oldConfig.lastVersion != AppData().config.lastVersion) {
      logger.info("检测到当前版本与上次启动版本不同");
      updateLogRequire = true;
      oldConfig=oldConfig.copyWith(lastVersion: AppData().config.lastVersion);
    }

    AppData().config = oldConfig;
    logger.info("配置文件合成完成");
  }

  // 更新配置到存储中
  Future<void> updateSetting({Map<String, dynamic>? settingData, bool refresh = true}) async {
    logger.info("保存配置文件中");
    if(settingData != null) AppData().config = Config.buildFromMap(settingData);
    AppData().storage.setString("settingData", jsonEncode(AppData().config.toMap()));
    if(refresh) await refreshApp();
  }

  Future<void> loadFont() async {
    if(backupFontLoaded) return;
    try{
      final ByteData bundle = await rootBundle.load("assets/fonts/zh/NotoSansSC-Medium.ttf");
      final FontLoader loader = FontLoader(StaticsVar.zhBackupFont)..addFont(Future.value(bundle));
      await loader.load();
    } catch (e) {
      logger.severe("无法加载备用字体");
      return;
    }
    backupFontLoaded = true;
    notifyListeners();
  }

  void changeLoggerBehavior() {
    Logger.root.clearListeners();
    if(kDebugMode){
      Logger.root.onRecord.listen((record) async {
        debugPrint('${record.time}-[${record.loggerName}][${record.level.name}]: ${record.message}');
      });
    }
    if(AppData().config.debug.enableInternalLog){
      Logger.root.level = Level.ALL;
      const List<Level> levelList = [Level.ALL, Level.FINEST, Level.FINER, Level.FINE, Level.INFO, Level.WARNING, Level.SEVERE, Level.SHOUT, Level.OFF];
      AppData appData = AppData();
      Logger.root.onRecord.listen((record) async {
        if(record.level < levelList[AppData().config.debug.internalLevel]) return;
        appData.internalLogCapture.add('${record.time}-[${record.loggerName}][${record.level.name}]: ${record.message}');
      });
    }
  }

  Future<void> refreshApp() async {
    logger.info("应用设置中");
    AppData appData = AppData();
    if(appData.config.audio.audioSource == 2) await appData.loadTTS(appData.config.audio.playRate);
    if(appData.config.egg.stella) await appData.loadEggs();
    changeLoggerBehavior();
    updateTheme();
    notifyListeners();
    logger.info("应用设置完成");
  }

  void updateTheme() {
    logger.info("更新主题中");
    if(AppData().config.regular.font == 2) {
      arFont = StaticsVar.arBackupFont;
      zhFont = StaticsVar.zhBackupFont;
      loadFont();
    } else if(AppData().config.regular.font == 1) {
      arFont = StaticsVar.arBackupFont;
      zhFont = null;
    } else {
      arFont = null;
      zhFont = null;
    }
  }
  
  void updateLearningStreak(){
    final int nowDate = DateTime.now().difference(DateTime(2025, 11, 1)).inDays;
    if (nowDate == AppData().config.learning.lastDate) return;
    logger.info("保存学习进度中");
    // 以 2025/11/1 为基准计算天数（因为这个bug是这天修的:} ）
    if (nowDate - AppData().config.learning.lastDate > 1) {
      AppData().config = AppData().config.copyWith(learning: AppData().config.learning.copyWith(startDate: nowDate));
    }
    AppData().config = AppData().config.copyWith(learning: AppData().config.learning.copyWith(lastDate: nowDate));
    updateSetting(refresh: false);
    logger.info("学习进度保存完成");
  }
}

class AppData {
  // 作为单例
  static final AppData _instance = AppData._internal();
  factory AppData() => _instance;
  AppData._internal();

  bool inited = false;
  Logger logger = Logger("AppData");

  List<String> internalLogCapture = [];
  Uint8List? stella;
  bool isWideScreen = false;
  Config config = Config();

  late final SharedPreferences storage;
  late final io.Directory basePath;
  late FSRS fsrs;
  late DictData wordData;
  sherpa_onnx.OfflineTts? vitsTTS;
  
  int get wordCount => wordData.words.length;
  bool get isFirstStart => storage.getString("settingData") == null;
  bool get modelTTSDownloaded => io.File("${basePath.path}/${StaticsVar.modelPath}/ar_JO-kareem-medium.onnx").existsSync();

  Future<void> init() async {
    if(inited) return;
    storage = await SharedPreferences.getInstance();
    if(!kIsWeb) {
      basePath = (await path_provider.getApplicationDocumentsDirectory()) as io.Directory;
    }

    if(!isFirstStart) {
      wordData = DictData.buildFromMap(jsonDecode(storage.getString("wordData")!));
      if(!BKSearch.isReady) BKSearch.init(wordData.words);
      FSRS().init();
    }
    inited = true;
  }

  Future<void> initStorageValue() async {
      await storage.setString("wordData", jsonEncode({"Words": [], "Classes": {}}));
      wordData = DictData(words: [], classes: []);
      logger.info("配置表初始化完成");
  }

  // load TTS model if any
  Future<void> loadTTS(double playRate) async {
    if(kIsWeb || vitsTTS != null || !modelTTSDownloaded) return;
    logger.info("TTS: 加载本地TTS中");
    sherpa_onnx.initBindings();
    final vits = sherpa_onnx.OfflineTtsVitsModelConfig(
      model: "${basePath.path}/${StaticsVar.modelPath}/ar_JO-kareem-medium.onnx",
      dataDir: "${basePath.path}/${StaticsVar.modelPath}/espeak-ng-data",
      tokens: '${basePath.path}/${StaticsVar.modelPath}/tokens.txt',
      lengthScale: 1 / playRate,
    );
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

  Future<void> loadEggs() async {
    if(stella == null){
      final rawString = await rootBundle.loadString("assets/eggs/s.txt");
      stella = base64Decode(rawString);
    }
  }

  /// Non-Format Data:
  /// {
  ///    "ClassName": [
  ///       {
  ///        "chinese": {Chinese},
  ///        "arabic": {arabic},
  ///        "explanation": {explanation}
  ///       }, ...
  ///    ]
  /// }
  /// Format Data:
  /// {
  ///    "Words" : [
  ///      {
  ///        "arabic": {arabic},
  ///        "chinese": {Chinese},
  ///        "explanation": {explanation},
  ///        "subClass": {ClassName},
  ///        "learningProgress": {times} //int
  ///       }, ...
  ///   ],
  ///   "Classes": {
  ///        "SourceJsonFileName": {
  ///          "ClassName": [wordINDEX],
  ///        }
  ///    }
  /// }
  DictData dataFormater(Map<String, dynamic> data, DictData existData, String sourceName) {
    logger.info("开始词汇格式化");
    
    // Use Maps for O(1) lookup speed instead of O(N) List.indexOf
    Map<String, int> rawWordMap = {};
    Map<String, int> pureWordMap = {};
    List<String> chineseList = [];
    
    for(int i = 0; i < existData.words.length; i++) {
      WordItem x = existData.words[i];
      rawWordMap[x.arabic] = i;
      pureWordMap[x.arabic.removeAracicExtensionPart().trim()] = i;
      chineseList.add(x.chinese); // Keep list for indexing since it maps 1:1 with word id
    }
    
    int counter = existData.words.length;

    SourceItem? exSource;
    // 查找已有数据中是否有同名的源数据组
    for(SourceItem x in existData.classes) {
      if(x.sourceJsonFileName == sourceName) exSource = x;
    }
    if(exSource == null){
      existData.classes.add(SourceItem(sourceJsonFileName: sourceName, subClasses: []));
      exSource = existData.classes.last;
    }

    for(var className in data.keys){
      ClassItem exClass = ClassItem(className: className, wordIndexs: []);
      for(var word in data[className]){
        String newRaw = word["arabic"];
        String newPure = newRaw.removeAracicExtensionPart().trim();
        int existingIndex = -1;

        if (rawWordMap.containsKey(newRaw)) {
          existingIndex = rawWordMap[newRaw]!;
        } else if (pureWordMap.containsKey(newPure)) {
          int potentialIndex = pureWordMap[newPure]!;
          // Pure arabic is the same, but different vowels. Are they the same meaning?
          if (chineseList[potentialIndex].hasSimilarMeaning(word["chinese"])) {
            existingIndex = potentialIndex;
          }
        }

        if (existingIndex != -1) {
          // If it already exists globally, just add it to this class
          if(!exClass.wordIndexs.contains(existingIndex)) {
            exClass.wordIndexs.add(existingIndex);
          }
          continue;
        }

        exClass.wordIndexs.add(counter);
        existData.words.add(
          WordItem(
            arabic: word["arabic"], 
            chinese: word["chinese"], 
            explanation: word["explanation"], 
            className: className, 
            id: counter
          )
        );
        rawWordMap[newRaw] = counter;
        pureWordMap[newPure] = counter;
        chineseList.add(word["chinese"]);
        counter ++;
      }
      exSource.subClasses.add(exClass);
    }
    return existData;
  }

  void importDictData(Map<String, dynamic> importData, String source) {
    logger.info("收到词汇导入请求");
    wordData = dataFormater(importData, wordData, source);
    storage.setString("wordData", jsonEncode(wordData.toMap()));
    BKSearch.init(wordData.words); // 重新建树
    logger.info("词汇导入完成");
  }
}