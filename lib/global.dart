import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';


class Global with ChangeNotifier {
  static const String _settingFilePath = "arabicLearning/setting.json";
  static const String _dataFilePath = "arabicLearning/data.json";
  late bool isWideScreen;
  Map<String, dynamic> _settingData = {
    'regular': {
      "theme": 0,
      "font": 0,
      "darkMode": true,
    },
    'audio': {
      "useBackupSource": false,
      "playRate": 1.0,
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
    final directory = await getApplicationDocumentsDirectory();
    final settingFile = File('${directory.path}/$_settingFilePath');
    if (!await settingFile.exists()) {
      await settingFile.create(recursive: true);
      await settingFile.writeAsString(jsonEncode(_settingData));
    }
    _settingData = deepMerge(_settingData, jsonDecode((await settingFile.readAsString())) as Map<String, dynamic>);

    final dataFile = File('${directory.path}/$_dataFilePath');
    if (!await dataFile.exists()) {
      await dataFile.create(recursive: true);
      await dataFile.writeAsString(jsonEncode({"Words": [], "Classes": {}}));
    }
    wordData = jsonDecode(await dataFile.readAsString());
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

  Future<void> updateSetting(Map<String, dynamic> settingData) async {
    _settingData = settingData;
    final directory = await getApplicationDocumentsDirectory();
    final settingFile = File('${directory.path}/$_settingFilePath');
    try {
      final file = await settingFile.create(recursive: true);
      await file.writeAsString(jsonEncode(settingData));
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
  //        "learningProgress": {times}
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
    final directory = await getApplicationDocumentsDirectory();
    final tf = File('${directory.path}/$_dataFilePath');
    if (!await tf.exists()) {
      await tf.create(recursive: true);
      await tf.writeAsString(jsonEncode({"Words": [], "Classes": {}}));
    }
    // Read Existed Data
    final dataFile = File('${directory.path}/$_dataFilePath');
    Map<String, dynamic> exData = jsonDecode(await dataFile.readAsString());
    Map<String, dynamic> formatedData = dataFormater(data, exData, source);
    try {
      final file = await dataFile.create(recursive: true);
      await file.writeAsString(jsonEncode(formatedData));
      wordData = formatedData;
    } catch (e) {
      throw Exception("Failed to write data file: $e"); // 异常时抛出错误
    }
    notifyListeners();
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
            ],
          ),
        ),
      ),
    );
  }
}