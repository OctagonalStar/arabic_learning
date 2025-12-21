import 'dart:convert';
import 'dart:math';

import 'package:arabic_learning/vars/config_structure.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:arabic_learning/package_replacement/storage.dart';

@pragma('vm:entry-point') 
Future<FlutterLocalNotificationsPlugin?> initNotificationsBackground() async {
  // 基础设置
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon'); // 应用图标

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  // 通知接口
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // 通知渠道
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'learning_notification_channel', // id
    '学习通知', // 名称
    description: '用于学习提醒的后台通知', // 描述
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    enableLights: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  return flutterLocalNotificationsPlugin;
}

@pragma('vm:entry-point') 
Future<bool> sendNotification() async {
  FlutterLocalNotificationsPlugin? localNotificationPlugin = await initNotificationsBackground();
  if(localNotificationPlugin == null) return Future.value(false);
  
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? configText = prefs.getString("settingData");
  if(configText == null) return Future.value(false);
  final Config config = Config.buildFromMap(jsonDecode(configText));
  
  // 如果当天连胜续了就不通知
  if(config.learning.lastDate == DateTime.now().difference(DateTime(2025, 11, 1)).inDays) return Future.value(true);
  // 起床前不通知
  if(DateTime.now().hour < 7) return Future.value(true);
  
  const androidDetails = AndroidNotificationDetails(
    'learning_notification_channel',
    '学习通知',
    channelDescription: '用于学习提醒的后台通知',
    importance: Importance.high,
    priority: Priority.high,
  );
  const notificationDetails = NotificationDetails(android: androidDetails);
  
  final Random rnd = Random();
  await localNotificationPlugin.show(
    rnd.nextInt(9999),
    '学习提醒',
    StaticsVar.learningMessage[rnd.nextInt(StaticsVar.learningMessage.length)],
    notificationDetails,
  );
  return Future.value(true);
}

// 独立 Isolate 后台任务
@pragma('vm:entry-point') 
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return await sendNotification();
  });
}