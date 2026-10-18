import 'dart:convert';
import 'dart:math';

import 'package:arabic_learning/core/date_utils.dart';
import 'package:arabic_learning/models/config.dart';
import 'package:arabic_learning/core/statics.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
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
  await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

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
  if(config.learning.lastDate == daysSinceEpoch()) return Future.value(true);
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
    id: rnd.nextInt(9999),
    title: '学习提醒',
    body: StaticsVar.learningMessage[rnd.nextInt(StaticsVar.learningMessage.length)],
    notificationDetails: notificationDetails,
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

// ---------------------------------------------------------------------------
// 应用更新下载通知：复用同一个 flutter_local_notifications 插件，仅用于前台展示
// APK 下载进度。点击通知只打开应用（不做深链导航）。非 Android / 插件缺失时静默跳过。
// ---------------------------------------------------------------------------

/// 更新下载通知使用的固定通知 id。
///
/// 单一来源：`UpdateService.updateNotificationId` 直接引用此常量，
/// 避免两处硬编码不一致（D10）。
const int updateNotificationId = 87001;

/// 更新下载通知渠道 id。
const String _updateChannelId = 'update_download_channel';

const String _updateChannelName = '应用更新';
const String _updateChannelDescription = '用于显示应用更新下载进度';

FlutterLocalNotificationsPlugin? _updateNotificationPlugin;
bool _updateNotificationReady = false;

/// 懒初始化更新通知渠道，失败（插件缺失 / 非 Android）时返回 null。
Future<FlutterLocalNotificationsPlugin?> _ensureUpdateNotifications() async {
  if (kIsWeb || !io.Platform.isAndroid) return null;
  try {
    final FlutterLocalNotificationsPlugin plugin =
        _updateNotificationPlugin ??= FlutterLocalNotificationsPlugin();
    if (!_updateNotificationReady) {
      const AndroidInitializationSettings initAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      await plugin.initialize(
          settings: const InitializationSettings(android: initAndroid));
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _updateChannelId,
        _updateChannelName,
        description: _updateChannelDescription,
        importance: Importance.low,
      );
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      _updateNotificationReady = true;
    }
    return plugin;
  } on MissingPluginException {
    return null;
  } catch (_) {
    return null;
  }
}

Future<void> _showUpdateNotification({
  required String title,
  required String body,
  required AndroidNotificationDetails androidDetails,
}) async {
  final FlutterLocalNotificationsPlugin? plugin =
      await _ensureUpdateNotifications();
  if (plugin == null) return;
  try {
    await plugin.show(
      id: updateNotificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  } on MissingPluginException {
    // 插件不可用，忽略
  } catch (_) {
    // 通知失败不应影响下载流程
  }
}

/// 显示更新下载进度（带进度条的常驻通知）。
Future<void> showUpdateDownloadProgress({required int percent}) async {
  final int clamped = percent.clamp(0, 100).toInt();
  await _showUpdateNotification(
    title: '正在下载更新',
    body: '已完成 $clamped%',
    androidDetails: AndroidNotificationDetails(
      _updateChannelId,
      _updateChannelName,
      channelDescription: _updateChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: clamped,
    ),
  );
}

/// 显示更新下载完成通知。
Future<void> showUpdateDownloadComplete() async {
  await _showUpdateNotification(
    title: '更新下载完成',
    body: '点击打开应用完成安装',
    androidDetails: const AndroidNotificationDetails(
      _updateChannelId,
      _updateChannelName,
      channelDescription: _updateChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      onlyAlertOnce: true,
      autoCancel: true,
    ),
  );
}

/// 显示更新下载中断通知。
Future<void> showUpdateDownloadInterrupted() async {
  await _showUpdateNotification(
    title: '更新下载中断',
    body: '下载未完成，可稍后重试',
    androidDetails: const AndroidNotificationDetails(
      _updateChannelId,
      _updateChannelName,
      channelDescription: _updateChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      onlyAlertOnce: true,
      autoCancel: true,
    ),
  );
}

/// 取消常驻的更新下载通知。
///
/// 进度通知是 `ongoing: true, autoCancel: false`，用户无法划掉，因此在取消下载 /
/// 删除安装包 / 安装器成功启动后必须主动撤销（D4）。非 Android / 插件缺失时静默返回。
Future<void> cancelUpdateNotification() async {
  if (kIsWeb) return;
  final FlutterLocalNotificationsPlugin? plugin =
      await _ensureUpdateNotifications();
  if (plugin == null) return;
  try {
    await plugin.cancel(id: updateNotificationId);
  } on MissingPluginException {
    // 插件不可用，忽略。
  } catch (_) {
    // 取消失败不应影响调用方流程。
  }
}