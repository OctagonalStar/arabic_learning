// 全局状态通知器（原 lib/vars/global.dart 拆分）。
// 承载 Global（应用初始化 / 设置同步 / 主题 / 字体 / 日志）。

import 'dart:convert';

import 'package:arabic_learning/core/date_utils.dart';
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/models/config.dart' show Config;
import 'package:arabic_learning/models/dict.dart' show DictData;
import 'package:arabic_learning/models/reading.dart' show ReadingData;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS;
import 'package:arabic_learning/services/search.dart' show BKSearch;
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle, FontLoader;

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

    final String? settingRaw = AppData().storage.getString("settingData");
    if (settingRaw != null && settingRaw.isNotEmpty) {
      Config oldConfig = Config.buildFromMap(jsonDecode(settingRaw));
      if(oldConfig.lastVersion != AppData().config.lastVersion) {
        logger.info("检测到当前版本与上次启动版本不同");
        updateLogRequire = true;
        oldConfig=oldConfig.copyWith(lastVersion: AppData().config.lastVersion);
      }
      AppData().config = oldConfig;
    }

    logger.info("配置文件合成完成");
  }

  /// 从存储重新加载词库/阅读数据并重建搜索索引。
  ///
  /// 用于备份恢复/WebDAV 同步之后，避免继续使用恢复前的旧内存数据
  /// （旧实现恢复后只重建了 Config）。正常启动不调用此方法，避免重复建树。
  void reloadStoredData() {
    logger.info("重新加载本地数据");
    try {
      final String? wordRaw = AppData().storage.getString("wordData");
      if (wordRaw != null && wordRaw.isNotEmpty) {
        AppData().wordData = DictData.buildFromMap(jsonDecode(wordRaw));
        BKSearch.rebuild(AppData().wordData.words);
      }

      final String? readingRaw = AppData().storage.getString("readingData");
      if (readingRaw != null && readingRaw.isNotEmpty) {
        AppData().readingData = ReadingData.buildFromMap(jsonDecode(readingRaw));
      }
      notifyListeners();
    } catch (e) {
      logger.severe("重新加载本地词库/阅读数据失败: $e");
    }
  }

  // 更新配置到存储中
  Future<void> updateSetting({Map<String, dynamic>? settingData, bool refresh = true}) async {
    logger.info("保存配置文件中");
    AppData appData = AppData();
    if(settingData != null) appData.config = Config.buildFromMap(settingData);
    appData.storage.setString("settingData", jsonEncode(appData.config.toMap()));
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
    final int nowDate = daysSinceEpoch();
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
