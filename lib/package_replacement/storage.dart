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
    return rt;
  }

  String? getString(String name){
    logger.finer("获取键$name");
    if(type) {
      return prefs.getString(name);
    } else {
      if(dbCache.containsKey(name)) return dbCache[name];
      return null;
    }
  }

  Future<bool> setString(String key, String value) async {
    if (type) {
      return prefs.setString(key, value);
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

  /// 导出前需要强制落盘的延迟写入钩子（目前用于 FSRS 的防抖写）。
  /// 由对应服务在自己的初始化里注册，存储层不直接依赖服务层，避免循环依赖。
  static void Function()? flushPendingWrites;

  /// 导出时覆盖若干键的钩子（FSRS 在 SQLite 后端下用它把内存中的权威副本
  /// 写成旧版格式的 `fsrsData`，保证备份与降级兼容）。
  static Map<String, String>? Function()? exportOverrides;

  /// 备份恢复完成后的钩子（FSRS 用它把恢复出来的 `fsrsData` 灌回 SQLite）。
  static Future<void> Function()? afterRecovery;

  Map<String, dynamic> export() {
    logger.info("导出存储数据");
    // 先落盘防抖中的写入，避免备份快照落后于最后一次操作（例如刚答完的复习卡片）。
    flushPendingWrites?.call();
    final Map<String, String>? overrides = exportOverrides?.call();
    if(type) {
      Map<String, dynamic> overall = {};
      for(String keyName in usedKeys){
        overall[keyName] = prefs.getString(keyName);
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
