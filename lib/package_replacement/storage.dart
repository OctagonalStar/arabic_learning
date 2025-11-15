import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart' as shpr;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.html) 'package:idb_shim/idb_browser.dart' as idb;
// import 'package:idb_shim/idb_browser.dart';

class SharedPreferences {
  late bool type; // true: shpr ; false: indexDB
  late idb.IdbFactory idbFactory;
  late idb.Database db;
  Map<String, dynamic> dbCache = {}; // 使用缓存避免异步加载
  late shpr.SharedPreferences prefs;
  static Future<SharedPreferences> getInstance() async {
    SharedPreferences rt = SharedPreferences();
    if(kIsWeb) {
      try {
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
        rt.dbCache["settingData"] = await store.getObject("settingData");
        rt.dbCache["wordData"] = await store.getObject("wordData");
        rt.dbCache["fsrsData"] = await store.getObject("fsrsData");
        rt.type = false;
      } catch (e) {
        // print("FallBack to shpr $e");
        rt.prefs = await shpr.SharedPreferences.getInstance();
        rt.type = true;
      }
    } else {
      rt.prefs = await shpr.SharedPreferences.getInstance();
      rt.type = true;
    }
    return rt;
  }

  String? getString(String name){
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

        var txn = db.transaction("data", idb.idbModeReadWrite);
        var store = txn.objectStore("data");
        await store.put(value, key);
        await txn.completed;

        return true;
      } catch (e) {
        // print(e);
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
}
