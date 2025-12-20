import 'package:flutter/foundation.dart' show kIsWeb;
import '../package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

@immutable
class StaticsVar {
  static const String appName = 'Ar 学';
  static const int appVersion = 000111;
  static const String modelPath = 'arabicLearning/tts/model/vits-piper-ar_JO-kareem-medium';
  static const Map<String, dynamic> tempConfig = {"SelectedClasses": []};
  static const Curve curve = Curves.easeInOut;
  static const String onlineDictOwner = 'JYinherit';
  static const String arBackupFont = "Vazirmatn";
  static const String zhBackupFont = "NotoSansSC";
  static const List<String> learningMessage = [
    "⚠️ 警告：您积累的‘知识债’即将逾期。请立即支付5分钟学习时间以避免‘利息’。",
    "友情提示：今日的学习KPI已完成 0%，是时候启动“填鸭”程序了！",
    "你的阴性、阳性、单数、双数、复数... 你都记清楚了吗？",
    "«هل تتذكر ما تعلمته بالأمس؟» ",
    "«إن شاء الله» 你今天会完成学习任务的，对吧？"
    "听说，在沙漠的另一边，有一课书在等你翻开..."
    "..."
  ];
  static const List<MaterialColor> themeList = [
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
  static final isDesktop = kIsWeb ? false : (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  static final player = AudioPlayer(); // load Player when app start
  static final BorderRadius br = BorderRadius.circular(25.0);
}
