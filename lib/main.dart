// 应用入口（引导）。
// 仅负责日志、屏幕方向、Android 后台任务、桌面窗口与 runApp；
// 应用外壳 MyApp / MyHomePage 位于 lib/app.dart。

import 'package:arabic_learning/app.dart' show MyApp;
import 'package:arabic_learning/core/adaptive.dart' show shouldLockPortrait;
import 'package:arabic_learning/core/statics.dart' show StaticsVar;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:workmanager/workmanager.dart' show Workmanager, Constraints;

void main() async {
  Logger.root.level = kDebugMode ? Level.ALL : Level.OFF;
  if (kDebugMode){
    Logger.root.clearListeners();
    Logger.root.onRecord.listen((record) {
      if(record.loggerName == "BKTree") return; // bk树不要刷屏
      debugPrint('${record.time}-[${record.loggerName}][${record.level.name}]: ${record.message}');
    });
  }
  
  final Logger logger = Logger("enter");
  logger.info("日志加载成功");
  WidgetsFlutterBinding.ensureInitialized();

  // 定向策略：仅手机（非桌面 / 非 Web 且最短边 < 600）锁竖屏；
  // 平板允许全部方向。桌面 / Web 上 SystemChrome 无副作用，直接跳过。
  if (!kIsWeb && !StaticsVar.isDesktop) {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final double shortestSide =
        view.physicalSize.shortestSide / view.devicePixelRatio;
    if (shouldLockPortrait(shortestSide)) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  if(io.Platform.isAndroid) {
    Workmanager().initialize(callbackDispatcher);
    Workmanager().registerPeriodicTask(
      "dynamic-notification-task",
      "fetchAndShowNotification",
      frequency: Duration(minutes: 30),
      constraints: Constraints(),
    );
  }
  

  if (StaticsVar.isDesktop) {
    await windowManager.ensureInitialized();
    logger.info("检测到当前为桌面端，正在加载窗口配置");
    WindowOptions windowOptions = WindowOptions(
      size: Size(1300, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: StaticsVar.appName,
      // 允许矮横屏窗口（如 480x420），不再强制较高的最小高度。
      minimumSize: Size(480, 420),
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    logger.info("窗口配置加载完成");
  }
  runApp(
    ChangeNotifierProvider(
      create: (context) => Global(),
      child: MyApp(),
    ),
  );
}
