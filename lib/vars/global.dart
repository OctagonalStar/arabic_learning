import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:flutter/services.dart' show rootBundle;
import 'package:arabic_learning/package_replacement/storage.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/package_replacement/fake_sherpa_onnx.dart' if (dart.library.io) 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class Global with ChangeNotifier {
  late bool firstStart; // 是否为第一次使用
  bool inited = false; //是否初始化完成
  late bool updateLogRequire; //是否需要显示更新日志
  late bool isWideScreen; // 设备是否是宽屏幕
  late final SharedPreferences prefs; // 储存实例

  late bool modelTTSDownloaded = false;
  Map<String, dynamic> _settingData = {
    'User': "",
    'LastVersion': StaticsVar.appVersion,
    'regular': {
      "theme": 9,
      "font": 0, //0: normal, 1: backup for ar, 2:backup for ar&zh
      "darkMode": false,
      "hideAppDownloadButton": false,
    },
    'audio': {
      "useBackupSource": 0, // 0: Normal, 1: OnlineBackup, 2: LocalVITS
      "playRate": 1.0,
    },
    'learning': {
      "startDate": 0, // YYYYMMDD;int
      "lastDate": 0, // YYYYMMDD;int
      "KnownWords": [],
    },
    'quiz': {
      /*
      题型说明 
      0: 单词卡片
      1: 中译阿 选择题
      2: 阿译中 选择题
      3: 中译阿 拼写题
      
      结构：
      [[int], bool, bool]
      [[the questions], doShuffleInternaly?, doShuffleGlobally? ,isAllowModify?]
      Internaly: do shuffle only in only each type of question. The order of questionType was not changed.
      Globally: shuffle everything
      */

      // 中阿混合学习
      'zh_ar': [[1, 2], true, true, true],

      // 阿译中学习
      'ar': [[2], true, true, false],

      // 中译阿学习
      'zh': [[1], true, true, false]
    },
    'eggs': {
      'stella': false
    },
    // fsrs 独立设置
    // 'fsrs': {
    //   'enabled' : false,
    //   'scheduler': {},
    //   'cards': [],
    //   'reviewLogs': [],
    // }
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
  Map<String, dynamic> get settingData => _settingData;
  int get wordCount => wordData["Words"]!.length;

  Future<bool> init() async {
    if(inited) return false;
    prefs = await SharedPreferences.getInstance();
    firstStart = prefs.getString("settingData") == null;
    if(firstStart) {
      updateLogRequire = false;
      await prefs.setString("wordData", jsonEncode({"Words": [], "Classes": {}}));
      wordData = jsonDecode(jsonEncode({"Words": [], "Classes": {}})) as Map<String, dynamic>;
      await postInit();
    } else {
      wordData = jsonDecode(prefs.getString("wordData")!) as Map<String, dynamic>;
      await conveySetting();
    }
    inited = true;
    return true;
  }

  // 预处理一些版本更新的配置文件兼容
  Future<void> conveySetting() async {
    Map<String, dynamic> oldSetting = jsonDecode(prefs.getString("settingData")!) as Map<String, dynamic>;
    if(oldSetting["LastVersion"] != _settingData["LastVersion"]) {
      updateLogRequire = true;
      oldSetting["LastVersion"] = _settingData["LastVersion"];
    } else {
      updateLogRequire = false;
    }
    _settingData = deepMerge(_settingData, oldSetting);
    await updateSetting();
  }

  // 更新配置到存储中
  Future<void> updateSetting({Map<String, dynamic>? settingData, bool refresh = true}) async {
    if(settingData != null) _settingData = settingData;
    prefs.setString("settingData", jsonEncode(_settingData));
    if(refresh) await postInit();
  }

  Future<void> postInit() async {
    await loadTTS();
    await loadEggs();
    updateTheme();
    notifyListeners();
  }

  // load TTS model if any
  Future<void> loadTTS() async {
    if(kIsWeb || vitsTTS != null) return;
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
    }
  }

  Future<void> loadEggs() async {
    if(settingData['eggs']['stella'] && stella == null){
      final rawString = await rootBundle.loadString("assets/eggs/s.txt");
      stella = base64Decode(rawString.replaceAll('\n', '').replaceAll('\r', '').trim());
    }
  }

  void updateTheme() {
    _themeData = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _themeList[settingData["regular"]["theme"]],
        brightness: settingData["regular"]["darkMode"] ? Brightness.dark : Brightness.light,
      ),
      fontFamily: settingData["regular"]["font"] == 2 ? "NotoSansSC" : null,
    );
    if(settingData["regular"]["font"] == 2) {
      arFont = StaticsVar.arBackupFont;
      zhFont = StaticsVar.zhBackupFont;
    } else if(settingData["regular"]["font"] == 1) {
      arFont = StaticsVar.arBackupFont;
      zhFont = null;
    } else {
      arFont = null;
      zhFont = null;
    }
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
    wordData = dataFormater(data, wordData, source);
    prefs.setString("wordData", jsonEncode(wordData));
    notifyListeners();
  }
  
  void saveLearningProgress(List<Map<String, dynamic>> words){
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
    prefs.setString("settingData", jsonEncode(settingData));
  }
}
