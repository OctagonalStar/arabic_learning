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
  static const List<String> usedKeys = ["settingData", "wordData", "fsrsData"]; // ! change this whenever add new setting key !
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
    logger.finer("设置键$key,值$value");
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

  Map<String, dynamic> export() {
    logger.info("导出存储数据");
    if(type) {
      Map<String, dynamic> overall = {};
      for(String keyName in usedKeys){
        overall[keyName] = prefs.getString(keyName);
      }
      return overall;
    } else {
      return dbCache;
    }
  }

  void recovery(Map<String, dynamic> backup) {
    logger.info("恢复存储数据");
    try{
      if(!type) dbCache = {}; // create a new instance
      for(String keyName in usedKeys) {
        setString(keyName, backup[keyName]);
        logger.fine("完成键恢复: $keyName");
      }
    } catch (e) {
      logger.severe("恢复数据出错: $e");
    }
    
  }
}
