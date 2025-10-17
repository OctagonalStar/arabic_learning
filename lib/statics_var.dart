import 'dart:io';

import 'package:flutter/material.dart';

class StaticsVar {
  static const String appName = 'ar学';
  static const String appVersion = '1.0.0';
  static const String tempConfigPath = 'arabicLearning/tpc.json';
  static const Map<String, dynamic> tempConfig = {"SelectedClasses": []};
  static final BorderRadius br = BorderRadius.circular(25.0);
  static final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  static const Curve curve = Curves.easeInOutQuad;
}
