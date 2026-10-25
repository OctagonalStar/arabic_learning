// 全局状态通知器（原 lib/vars/global.dart 拆分）。
// 承载 Global（应用初始化 / 设置同步 / 主题 / 字体 / 日志）。

import 'dart:convert';

import 'package:arabic_learning/core/date_utils.dart';
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/models/config.dart' show Config, LearningConfig, RegularConfig;
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
import 'package:arabic_learning/theme/theme_resolver.dart' show ThemeResolver;
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

  /// `settingData` 的实际写盘次数（诊断 / 测试用）。
  ///
  /// `Global` 不是单例（由 provider 创建），故用静态计数；用于断言
  /// 「配置没有变化时启动路径不重写偏好文件」。
  @visibleForTesting
  static int debugSettingWriteCount = 0;

  /// 由配置解析出的主题模式（跟随系统 / 浅色 / 深色）。
  ThemeMode get themeMode =>
      ThemeResolver.themeModeFromConfig(AppData().config.regular);

  ThemeData _buildTheme(Brightness brightness) {
    final RegularConfig regular = AppData().config.regular;
    final ColorScheme scheme = ThemeResolver.seedScheme(regular, brightness);
    // 字体回退链随备用字体配置变化：
    // font==1 → 阿语 Vazirmatn；font==2 → 阿语 Vazirmatn + 中文 NotoSansSC。
    // `fontFamily` 仍按原逻辑只传 zhFont，不改变其判定与语义。
    //
    // Web / 小程序（kIsWeb）额外规则：CanvasKit 没有系统字体，阿语只能靠内置
    // Vazirmatn（assets/fonts/ar）；引擎的在线回退字体 CDN 在小程序里也不可达。
    // 因此默认档（font==0）也必须把 Vazirmatn 挂进回退链，否则阿语全是方框。
    final List<String>? fontFallback = switch (regular.font) {
      1 => const <String>[StaticsVar.arBackupFont],
      2 => const <String>[StaticsVar.arBackupFont, StaticsVar.zhBackupFont],
      _ => kIsWeb ? const <String>[StaticsVar.arBackupFont] : null,
    };
    return buildTheme(
      scheme,
      fontFamily: zhFont,
      fontFamilyFallback: fontFallback,
    );
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
    // AppData.init 内部已并发启动 FSRS 的「SQLite 打开 + 旧数据迁移」并与词库
    // 解析重叠执行，返回时 FSRS 一定已就绪；这里的第二次调用命中 initAsync 的
    // 记忆化（`_opening`），是空操作，保留作为首次启动等路径的兜底。
    await appData.init();
    await FSRS().initAsync();

    if(appData.isFirstStart) {
      logger.info("首次启动检测为真");
      // 必须 await：后续 refreshApp/首帧读取依赖这些默认键已经写入。
      await appData.initStorageValue();
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
  /// 用于数据恢复（本地导入）之后，避免继续使用恢复前的旧内存数据
  /// （旧实现恢复后只重建了 Config）。正常启动不调用此方法，避免重复建树。
  Future<void> reloadStoredData() async {
    logger.info("重新加载本地数据");
    try {
      final String? wordRaw = AppData().storage.getString("wordData");
      if (wordRaw != null && wordRaw.isNotEmpty) {
        AppData().wordData = DictData.buildFromMap(jsonDecode(wordRaw));
        if (AppData().normalizeWordGenders()) {
          // 与启动路径共用延迟回写：编码在后台 isolate，且不阻塞首帧。
          // （这里也必须用同一个代际号，避免与启动回写互相覆盖。）
          AppData().persistWordDataDeferred();
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
      // 备份恢复后需按新数据重建配置（补齐既有缺口）。
      // SQLite 后端在 recovery 阶段已把 fsrsData 灌回库，这里 reload 只是再对齐一次内存副本。
      await FSRS().initAsync(reload: true);
      await PlanStore().reload();
      notifyListeners();
    } catch (e) {
      logger.severe("重新加载本地词库/阅读数据失败: $e");
    }
  }

  /// 以不可变方式打补丁到 [Config] 并持久化；内容未变时 [updateSetting] 会跳过写盘。
  ///
  /// 这是「改设置」的唯一入口，取代散落各处的
  /// `AppData().config = AppData().config.copyWith(...); updateSetting();` 样板：
  /// 调用方只需描述「从当前配置到新配置」的变换，读-改-写与落盘时机由这里保证。
  ///
  /// [patch] 收到的是当前配置，必须返回**新**实例（内部一律 `copyWith`）。
  /// [refresh] 与 [updateSetting] 的同名参数一致：默认 `true` 会走
  /// `refreshApp()`（重建主题 + 通知监听者）；服务层等无 UI 的场景传 `false`。
  ///
  /// 返回的 Future 只在需要「确认已落盘」时 await（例如服务层）；UI 回调里
  /// 直接作为语句调用即可，与改造前 `updateSetting()` 不 await 的时序一致。
  Future<void> patchConfig(
    Config Function(Config current) patch, {
    bool refresh = true,
  }) async {
    AppData().config = patch(AppData().config);
    await updateSetting(refresh: refresh);
  }

  // 更新配置到存储中
  Future<void> updateSetting({Map<String, dynamic>? settingData, bool refresh = true}) async {
    logger.info("保存配置文件中");
    AppData appData = AppData();
    if(settingData != null) appData.config = Config.buildFromMap(settingData);
    final String encoded = jsonEncode(appData.config.toMap());
    // 内容没变就不写：`shared_preferences` 每次 setString 都会重写整个偏好文件
    // （其中还有 2~6MB 的 wordData）。启动路径上 updateSetting() 只是把刚读出来
    // 的配置再写一遍，属于纯浪费；只有真正发生版本升级（lastVersion 变化）时
    // 内容才会不同。
    if(appData.storage.getString("settingData") != encoded) {
      appData.storage.setString("settingData", encoded);
      Global.debugSettingWriteCount++;
    } else {
      logger.fine("配置未变化，跳过写盘");
    }
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
    changeLoggerBehavior();
    updateTheme();
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
    // startDate 与 lastDate 在同一次 patch 里写入：原先的两次赋值之间没有任何
    // 读取点，合并后只落盘一次。
    patchConfig((Config config) {
      final LearningConfig learning = config.learning;
      return config.copyWith(
        learning: learning.copyWith(
          startDate: nowDate - learning.lastDate > 1 ? nowDate : learning.startDate,
          lastDate: nowDate,
        ),
      );
    }, refresh: false);
    logger.info("学习进度保存完成");
  }
}
