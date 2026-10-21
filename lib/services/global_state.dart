// 全局状态通知器（原 lib/vars/global.dart 拆分）。
// 承载 Global（应用初始化 / 设置同步 / 主题 / 字体 / 日志）。

import 'dart:convert';

import 'package:arabic_learning/core/date_utils.dart';
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/models/config.dart' show Config, RegularConfig;
import 'package:arabic_learning/models/dict.dart' show DictData;
import 'package:arabic_learning/models/reading.dart' show ReadingData;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/favorites.dart' show FavoriteStore;
import 'package:arabic_learning/services/fsrs.dart' show FSRS;
import 'package:arabic_learning/services/memberships.dart' show WordMembershipIndex;
import 'package:arabic_learning/services/plan_scheduler.dart' show planBlocksStreak;
import 'package:arabic_learning/services/plan_store.dart' show PlanStore;
import 'package:arabic_learning/services/search.dart' show BKSearch;
import 'package:arabic_learning/services/synonyms.dart' show SynonymStore;
import 'package:arabic_learning/theme/app_theme.dart' show buildTheme;
import 'package:arabic_learning/theme/theme_resolver.dart'
    show ResolvedSchemes, ThemeResolver;
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

  // 动态取色解析缓存：避免每次 build 重新请求原生插件。
  ColorScheme? _dynamicLightScheme;
  ColorScheme? _dynamicDarkScheme;
  String? _dynamicSchemeKey;

  // 主题缓存：ThemeData 构建开销较大，配置未变时复用同一实例。
  ThemeData? _lightTheme;
  ThemeData? _darkTheme;

  /// 亮色主题。
  ThemeData get lightThemeData => _lightTheme ??= _buildTheme(Brightness.light);

  /// 暗色主题。
  ThemeData get darkThemeData => _darkTheme ??= _buildTheme(Brightness.dark);

  /// 配置或动态取色变化后清除主题缓存，行为与逐次重建等价。
  void _invalidateThemeCache() {
    _lightTheme = null;
    _darkTheme = null;
  }

  /// 由配置解析出的主题模式（跟随系统 / 浅色 / 深色）。
  ThemeMode get themeMode =>
      ThemeResolver.themeModeFromConfig(AppData().config.regular);

  ThemeData _buildTheme(Brightness brightness) {
    final RegularConfig regular = AppData().config.regular;
    final ColorScheme scheme;
    if (regular.dynamicColor &&
        !kIsWeb &&
        _dynamicLightScheme != null &&
        _dynamicDarkScheme != null) {
      scheme =
          brightness == Brightness.dark ? _dynamicDarkScheme! : _dynamicLightScheme!;
    } else {
      scheme = ThemeResolver.seedScheme(regular, brightness);
    }
    // 字体回退链随备用字体配置变化：
    // font==1 → 阿语 Vazirmatn；font==2 → 阿语 Vazirmatn + 中文 NotoSansSC。
    // `fontFamily` 仍按原逻辑只传 zhFont，不改变其判定与语义。
    final List<String>? fontFallback = switch (regular.font) {
      1 => const <String>[StaticsVar.arBackupFont],
      2 => const <String>[StaticsVar.arBackupFont, StaticsVar.zhBackupFont],
      _ => null,
    };
    return buildTheme(
      scheme,
      fontFamily: zhFont,
      fontFamilyFallback: fontFallback,
    );
  }

  /// 按需解析并缓存动态取色方案；未启用或平台不支持时清空缓存回退种子色。
  Future<void> _refreshDynamicScheme() async {
    final RegularConfig regular = AppData().config.regular;
    if (!regular.dynamicColor || kIsWeb) {
      _dynamicLightScheme = null;
      _dynamicDarkScheme = null;
      _dynamicSchemeKey = null;
      _invalidateThemeCache(); // 关闭动态取色：回退种子色需重建主题
      return;
    }
    final String key = regular.theme.toString();
    if (_dynamicSchemeKey == key &&
        _dynamicLightScheme != null &&
        _dynamicDarkScheme != null) {
      return;
    }
    final ResolvedSchemes schemes = await ThemeResolver.resolveSchemes(regular);
    _dynamicLightScheme = schemes.light;
    _dynamicDarkScheme = schemes.dark;
    _dynamicSchemeKey = key;
    _invalidateThemeCache(); // 动态取色方案已解析：颜色变化需重建主题
  }


  // 初始化 Future 记忆化：init() 内部会 notifyListeners() 触发重建，
  // 若重建时再次被调用会重复解析/写入配置，故只执行一次。
  Future<bool>? _initFuture;

  /// 全局初始化（记忆化，只执行一次）。
  Future<bool> init() => _initFuture ??= _initGuarded();

  /// 失败时清空记忆化结果，使 UI 的「重试」能真正重新执行初始化。
  Future<bool> _initGuarded() async {
    try {
      return await _initOnce();
    } catch (e, stack) {
      logger.severe("全局控制类初始化失败: $e", e, stack);
      _initFuture = null;
      rethrow;
    }
  }

  Future<bool> _initOnce() async {
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
  Future<void> reloadStoredData() async {
    logger.info("重新加载本地数据");
    try {
      final String? wordRaw = AppData().storage.getString("wordData");
      if (wordRaw != null && wordRaw.isNotEmpty) {
        AppData().wordData = DictData.buildFromMap(jsonDecode(wordRaw));
        if (AppData().normalizeWordGenders()) {
          AppData().storage.setString("wordData", jsonEncode(AppData().wordData.toMap()));
        }
        BKSearch.rebuild(AppData().wordData.words);
        WordMembershipIndex.instance.rebuild(AppData().wordData.classes);
      }

      final String? readingRaw = AppData().storage.getString("readingData");
      if (readingRaw != null && readingRaw.isNotEmpty) {
        AppData().readingData = ReadingData.buildFromMap(jsonDecode(readingRaw));
      }

      SynonymStore().reload();
      FavoriteStore().reload();
      FSRS().init(); // 备份恢复后需按新 fsrsData 重建配置（补齐既有缺口）
      await PlanStore().reload();
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
    _invalidateThemeCache(); // 配置已变更：主题缓存失效
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
    // 本地 TTS 模型（sherpa_onnx）加载是同步的，放在这里会阻塞首帧；
    // 改为在 services/tts.dart 首次合成语音时惰性加载。
    changeLoggerBehavior();
    updateTheme();
    await _refreshDynamicScheme();
    notifyListeners();
    logger.info("应用设置完成");
  }

  void updateTheme() {
    logger.info("更新主题中");
    _invalidateThemeCache(); // 字体配置随之变化：清空主题缓存
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
    // 计划学习「连胜门禁」：当日最低量未达标时不记录连胜（其余逻辑保持不变）。
    if (planBlocksStreak()) return;
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
