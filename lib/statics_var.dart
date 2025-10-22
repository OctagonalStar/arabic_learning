import 'package:flutter/foundation.dart' show kIsWeb;
import 'package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class StaticsVar {
  static const String appName = 'Ar 学';
  static const String appVersion = '0.1.0';
  static const String modelPath = 'arabicLearning/tts/model/vits-piper-ar_JO-kareem-medium';
  static const Map<String, dynamic> tempConfig = {"SelectedClasses": []};
  static const String onlineDictOwner = 'JYinherit';
  static const String onlineDictRepo = 'Arabiclearning';
  static const String onlineDictPath = '词库';
  static final BorderRadius br = BorderRadius.circular(25.0);
  static final isDesktop = kIsWeb ? false : (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  static const Curve curve = Curves.easeInOut;
  static final player = AudioPlayer(); // load Player when app start
}
