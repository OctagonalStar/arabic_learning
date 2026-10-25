import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart' as shpr;

import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.html) 'package:idb_shim/idb_browser.dart' as idb;

class SharedPreferences {
  final Logger logger = Logger("Storage");
  late bool type; // true: shpr ; false: indexDB
  late idb.IdbFactory idbFactory;
  late idb.Database db;
  late shpr.SharedPreferences prefs;
  static const List<String> usedKeys = ["settingData", "wordData", "fsrsData", "readingData", "synonymData", "favoriteData", "pushSessionData", "planData", "learningSessionData"]; // ! change this whenever add new setting key !
  Map<String, dynamic> dbCache = {}; // 使用缓存避免异步加载

  /// 小程序里 `wx.setStorage` 单键上限 1MB，而 `wordData` 是 2~3MB 的整串 JSON。
  /// 超过 [chunkChars] 的值会被切成多个键，主键只留分片标记。
  /// 仅 Web 走 shared_preferences 后端时启用（即小程序），原生端和 IndexedDB 端不受影响。
  bool chunked = false;

  /// 每片字符数。中文 UTF-8 占 3 字节，250k 字符最坏 750KB，留足余量。
  static const int chunkChars = 250000;
  static const String _chunkPrefix = "\u0000mpc:";

  static String _partKey(String key, int i) => "$key\u0000p$i";

  /// 分片标记里的片数；非分片值返回 0。
  static int chunkCount(String? raw) {
    if (raw == null || !raw.startsWith(_chunkPrefix)) return 0;
    return int.tryParse(raw.substring(_chunkPrefix.length)) ?? 0;
  }

  /// 按 [chunkChars] 切片（纯函数，便于测试）。
  static List<String> slice(String value) {
    final List<String> parts = [];
    for (int i = 0; i < value.length; i += chunkChars) {
      final int end = i + chunkChars;
      parts.add(value.substring(i, end < value.length ? end : value.length));
    }
    return parts;
  }

  static Future<SharedPreferences> getInstance() async {
    SharedPreferences rt = SharedPreferences();
    rt.logger.info("开始存储实例初始化;kIsWeb: $kIsWeb");
    if(kIsWeb) {
      try {
        rt.logger.fine("尝试获取浏览器IndexDB实例");
        rt.idbFactory = idb.getIdbFactory()!;
        // open the database
        rt.db = await rt.idbFactory.open("data.db", version: 1,
            onUpgradeNeeded: (idb.VersionChangeEvent event) {
            idb.Database db = event.database;
            // create the store
            db.createObjectStore("data", autoIncrement: true);
          }
        );
        var txn = rt.db.transaction("data", "readonly");
        var store = txn.objectStore("data");
        rt.logger.fine("IndexDB实例获取成功");
        for(String keyName in usedKeys) {
          rt.dbCache[keyName] = await store.getObject(keyName);
        }
        rt.logger.fine("已完成数据库缓存读取");
        rt.type = false;
      } catch (e) {
        rt.logger.warning("IndexDB实例获取失败[$e]，回退至SharedPreferences");
        rt.prefs = await shpr.SharedPreferences.getInstance();
        rt.type = true;
      }
    } else {
      rt.logger.fine("非浏览器端，使用SharedPreferences");
      rt.prefs = await shpr.SharedPreferences.getInstance();
      rt.type = true;
    }
    rt.logger.info("存储实例初始化完成");
    rt.chunked = kIsWeb && rt.type;
    return rt;
  }

  String? getString(String name){
    logger.finer("获取键$name");
    if(type) {
      final String? raw = prefs.getString(name);
      final int n = chunkCount(raw);
      if (n == 0) return raw;
      final StringBuffer sb = StringBuffer();
      for (int i = 0; i < n; i++) {
        final String? part = prefs.getString(_partKey(name, i));
        if (part == null) {
          logger.severe("键$name 分片$i 缺失，按无数据处理");
          return null;
        }
        sb.write(part);
      }
      return sb.toString();
    } else {
      if(dbCache.containsKey(name)) return dbCache[name];
      return null;
    }
  }

  /// 清掉 [key] 遗留的分片键（从头到 [keep] 之前）。
  ///
  /// 故意同步、不 await：{@link setString} 的非分片路径必须保持「调用即写盘」，
  /// 否则调用方紧接着读 `prefs.getString` 会读不到刚写的内容（有单测依赖此顺序）。
  void _dropChunks(String key, {int keep = 0}) {
    final int old = chunkCount(prefs.getString(key));
    for (int i = keep; i < old; i++) {
      prefs.remove(_partKey(key, i));
    }
  }

  Future<bool> setString(String key, String value) async {
    if (type) {
      if (!chunked || value.length <= chunkChars) {
        _dropChunks(key);
        return prefs.setString(key, value);
      }
      final List<String> parts = slice(value);
      for (int i = 0; i < parts.length; i++) {
        if (!await prefs.setString(_partKey(key, i), parts[i])) {
          logger.severe("键$key 分片$i 写入失败");
          return false;
        }
      }
      _dropChunks(key, keep: parts.length);
      logger.fine("键$key 分 ${parts.length} 片存储（${value.length} 字符）");
      return prefs.setString(key, "$_chunkPrefix${parts.length}");
    } else {
      try {
        dbCache[key] = value;
        logger.fine("IndexDB值缓存完成");
        var txn = db.transaction("data", idb.idbModeReadWrite);
        var store = txn.objectStore("data");
        await store.put(value, key);
        await txn.completed;
        return true;
      } catch (e) {
        logger.severe("IndexDB值设置出现错误: $e");
        return false;
      }
    }
  }


  bool containsKey(String key) {
    if(type) {
      return prefs.containsKey(key);
    } else {
      if(dbCache.containsKey(key)){
        if(dbCache[key] != null && dbCache[key] != ''){
          return true;
        }
      }
      return false;
    }
  }

  /// 导出前需要强制落盘的延迟写入钩子（FSRS 的卡片防抖、PlanStore 的进度防抖）。
  /// 由对应服务在自己的初始化里注册，存储层不直接依赖服务层，避免循环依赖。
  ///
  /// 支持多个订阅者：早期只有一个函数槽，后注册者会把先注册者顶掉。
  static final List<void Function()> flushPendingWrites = <void Function()>[];

  /// 注册一个落盘钩子（按函数身份去重，重复注册是幂等的）。
  static void addFlushHook(void Function() hook) {
    if (!flushPendingWrites.contains(hook)) flushPendingWrites.add(hook);
  }

  /// 注销一个落盘钩子（测试清理用）。
  static void removeFlushHook(void Function() hook) {
    flushPendingWrites.remove(hook);
  }

  /// 导出时覆盖若干键的钩子（FSRS 在 SQLite 后端下用它把内存中的权威副本
  /// 写成旧版格式的 `fsrsData`，保证备份与降级兼容）。
  static Map<String, String>? Function()? exportOverrides;

  /// 备份恢复完成后的钩子（FSRS 用它把恢复出来的 `fsrsData` 灌回 SQLite）。
  static Future<void> Function()? afterRecovery;

  Map<String, dynamic> export() {
    logger.info("导出存储数据");
    // 先落盘防抖中的写入，避免备份快照落后于最后一次操作（例如刚答完的复习卡片）。
    for (final void Function() hook in flushPendingWrites) {
      hook();
    }
    final Map<String, String>? overrides = exportOverrides?.call();
    if(type) {
      Map<String, dynamic> overall = {};
      for(String keyName in usedKeys){
        overall[keyName] = getString(keyName);
      }
      if(overrides != null) overall.addAll(overrides);
      return overall;
    } else {
      if(overrides == null) return dbCache;
      return <String, dynamic>{...dbCache, ...overrides};
    }
  }

  /// 恢复备份。返回的 Future 完成时，所有键（含异步后端）都已可见。
  ///
  /// 引入 SQLite 卡片后端后，`fsrsData` 需要异步灌回数据库；调用方必须
  /// `await` 本方法，再调用 `Global.reloadStoredData()`，否则 FSRS 会读到旧数据。
  Future<void> recovery(Map<String, dynamic> backup) async {
    logger.info("恢复存储数据");
    try{
      if(!type) dbCache = {}; // create a new instance
      for(String keyName in usedKeys) {
        final dynamic v = backup[keyName];
        if(v is String && v.isNotEmpty) {
          await setString(keyName, v);
          logger.fine("完成键恢复: $keyName");
        } else {
          logger.fine("跳过缺失的键: $keyName");
        }
      }
      await afterRecovery?.call();
    } catch (e) {
      logger.severe("恢复数据出错: $e");
    }
    
  }
}
