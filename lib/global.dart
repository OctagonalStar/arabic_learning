import 'package:arabic_learning/statics_var.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class Global with ChangeNotifier {
  late bool firstStart;
  late bool isWideScreen;
  late final SharedPreferences prefs;
  late String dailyWord = "";
  Map<String, dynamic> _settingData = {
    'User': "",
    'regular': {
      "theme": 9,
      "font": 0, //0: Noto Sans SC, 1: Google Noto Sans SC
      "darkMode": false,
    },
    'audio': {
      "useBackupSource": false,
      "playRate": 1.0,
    },
    'learning': {
      "startDate": 0, // YYYYMMDD;int
      "lastDate": 0, // YYYYMMDD;int
      "KnownWords": [],
    }
  };
  static const List<MaterialColor> _themeList = [
      Colors.pink,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.orange,
      Colors.purple,
      Colors.brown,
      Colors.grey,
      Colors.teal,
      Colors.cyan,
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
      }),
      Colors.lime,
    ];
  late var _themeData = ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _themeList[settingData["regular"]["theme"]],
          brightness: settingData["regular"]["darkMode"] ? Brightness.dark : Brightness.light,
        ),
        textTheme: settingData["regular"]["font"] == 1 ? settingData["regular"]["darkMode"] ? GoogleFonts.notoSansScTextTheme(ThemeData.dark().textTheme) : GoogleFonts.notoSansScTextTheme(ThemeData.light().textTheme) : settingData["regular"]["darkMode"] ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
  );

  late Map<String, dynamic> wordData = {};
  ThemeData get themeData => _themeData;
  Map<String, dynamic> get settingData => _settingData;
  int get wordCount => wordData["Words"]!.length;

  Map<K, V> deepMerge<K, V>(Map<K, V> base, Map<K, V> overlay) {
  final result = Map<K, V>.from(base);
  overlay.forEach((key, value) {
    if (result[key] is Map && value is Map) {
      result[key] = deepMerge(
        Map<String, dynamic>.from(result[key] as Map),
        Map<String, dynamic>.from(value as Map),
      ) as V;
    } else {
      result[key] = value;
    }
  });
  return result;
  }

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    firstStart = prefs.getString("settingData") == null;
    if(prefs.getString("wordData") == null) {
      await prefs.setString("wordData", jsonEncode({"Words": [], "Classes": {}}));
      wordData = jsonDecode(jsonEncode({"Words": [], "Classes": {}})) as Map<String, dynamic>;
    } else {
      wordData = jsonDecode(prefs.getString("wordData")!) as Map<String, dynamic>;
    }
    if (firstStart) return;
    _settingData = deepMerge(_settingData, jsonDecode(prefs.getString("settingData")!) as Map<String, dynamic>);
  }
  void updateTheme() {
    _themeData = ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _themeList[settingData["regular"]["theme"]],
          brightness: settingData["regular"]["darkMode"] ? Brightness.dark : Brightness.light,
        ),
        textTheme: settingData["regular"]["font"] == 1 ? settingData["regular"]["darkMode"] ? GoogleFonts.notoSansScTextTheme(ThemeData.dark().textTheme) : GoogleFonts.notoSansScTextTheme(ThemeData.light().textTheme) : settingData["regular"]["darkMode"] ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );
    notifyListeners();
  }

  Future<void> acceptAggrement(String name) async {
    firstStart = false;
    _settingData["User"] = name;
    prefs.setString("settingData", jsonEncode(settingData));
    notifyListeners();
  }
  
  Future<void> updateSetting(Map<String, dynamic> settingData) async {
    _settingData = settingData;
    try {
      prefs.setString("settingData", jsonEncode(settingData));
    } catch (e) {
      throw Exception("Failed to write setting file: $e"); // 异常时抛出错误
    }
    updateTheme();
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

  void importData(Map<String, dynamic> data, String source) async {
    wordData = dataFormater(data, wordData, source);
    prefs.setString("wordData", jsonEncode(wordData));
    notifyListeners();
  }
  
  void saveLearningProgress(List<int> wordIndexs){
    final int nowDate = int.parse("${DateTime.now().year}${DateTime.now().month}${DateTime.now().day}");
    for(int x in wordIndexs){
      wordData["Words"][x]["learningProgress"] += 1;
      if(_settingData["learning"]["KnownWords"].contains(x)) continue;
      if(wordData["Words"][x]["learningProgress"] >= 3) _settingData["learning"]["KnownWords"].add(x);
    }
    prefs.setString("wordData", jsonEncode(wordData));
    if (nowDate == _settingData["learning"]["lastDate"]) return;
    if (nowDate - _settingData["learning"]["lastDate"] > 1) {
      _settingData["learning"]["startDate"] = nowDate;
    }
    _settingData["learning"]["lastDate"] = nowDate;
    prefs.setString("settingData", jsonEncode(settingData));
  }
}

class InDevelopingPage extends StatelessWidget {
  const InDevelopingPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("开发中"),
      ),
      body: Center(
        child: FittedBox(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.build,
                size: 100.0,
              ),
              Text(
                "该页面还在开发中...",
                style: TextStyle(
                  fontSize: 40.0,
                ),
              ),
              Text(
                "日子要一天一天过，单词要一个一个背...\n高数要一课一课学，阿语要一句一句记...\n牙膏要一点一点挤，代码要一行一行敲...",
                style: TextStyle(
                  fontSize: 18.0,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<List<dynamic>> playTextToSpeech(String text, {bool useBackup = false, double playRate = 1.0}) async { 
  // return [bool isSuccessed?, String errorInfo];
  if (useBackup) {
    try {
      final response = await http.get(Uri.parse("https://textreadtts.com/tts/convert?accessKey=FREE&language=arabic&speaker=speaker2&text=$text")).timeout(Duration(seconds: 8), onTimeout: () => throw Exception("请求超时"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if(data["code"] == 1) {
          return [false, "备用音源请求失败:\n错误信息:文本长度超过API限制"];
        }
        await StaticsVar.player.setUrl(data["audio"]);
        await StaticsVar.player.setSpeed(playRate);
        await StaticsVar.player.play();
      } else {
        return [false, "备用音源请求失败:\n错误码:${response.statusCode.toString()}"];
      }
    } catch (e) {
      return [false, "备用音源请求失败:\n错误信息:${e.toString()}"];
    }
  } else {
    FlutterTts flutterTts = FlutterTts();
    if(!(await flutterTts.getLanguages).toString().contains("ar")) return [false, "你的设备似乎未安装阿拉伯语语言或不支持阿拉伯语文本转语音功能，语音可能无法正常播放。\n你可以尝试在 设置 - 系统语言 - 添加语言 中添加阿拉伯语。\n实在无法使用可在设置页面启用备用音频源(需要网络)"];
    await flutterTts.setLanguage("ar");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(playRate / 2);
    await flutterTts.speak(text);
  }
  return [true, ""];
}

void alart(context, String e) {
  showDialog(
    context: context, 
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("提示"),
        content: Text(e),
        actions: [
          TextButton(
            child: Text("确定"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          )
        ],
      );
    }
  );
}
