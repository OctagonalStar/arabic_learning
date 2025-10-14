import 'dart:io';

import 'package:flutter/material.dart';

class StaticsVar {
  static const String appName = 'arabic Learning';
  static const String appVersion = '1.0.0';
  static final BorderRadius br = BorderRadius.circular(25.0);
  static final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  static const Curve curve = Curves.easeInOutQuad;
}
