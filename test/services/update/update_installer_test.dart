// 更新模块的下载 / 安装辅助逻辑测试。
//
// 只测可注入、无平台依赖的部分：资产名清洗、目录拼接、大小校验、以及
// `UpdateInstaller` 在插件缺失时的降级语义。真实下载与安装仍由手动回归清单覆盖。

import 'dart:io';

import 'package:arabic_learning/services/update/update_downloader.dart';
import 'package:arabic_learning/services/update/update_installer.dart';
import 'package:flutter/services.dart'
    show MethodCall, MethodChannel, MissingPluginException;
import 'package:flutter_test/flutter_test.dart';

/// 条件导入在静态分析期把 `Directory` 解析为 fake_dart_io 的同名类，运行时才是
/// dart:io 的类；返回类型写成 `Future<dynamic>` 以绕开两者的名义类型差异。
Future<dynamic> _baseDirectory() async => Directory('/base');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('safeAssetName', () {
    test('普通文件名原样返回', () {
      expect(
        UpdateDownloader.safeAssetName('app-arm64-v8a-release.apk'),
        'app-arm64-v8a-release.apk',
      );
    });

    test('去掉路径穿越前缀', () {
      expect(UpdateDownloader.safeAssetName('../../etc/passwd'), 'passwd');
      expect(
        UpdateDownloader.safeAssetName(r'..\..\windows\evil.apk'),
        'evil.apk',
      );
      expect(UpdateDownloader.safeAssetName('/tmp/a/b/c.apk'), 'c.apk');
    });

    test('去掉首尾空白，空串保持为空', () {
      expect(UpdateDownloader.safeAssetName('  app.apk  '), 'app.apk');
      expect(UpdateDownloader.safeAssetName('   '), '');
      expect(UpdateDownloader.safeAssetName(''), '');
    });
  });

  group('resolveDirectory', () {
    test('注入目录下拼出固定子目录', () async {
      final dynamic dir = await UpdateDownloader.resolveDirectory(
        directoryProvider: _baseDirectory,
      );
      expect(dir.path, '/base/arabicLearning/update');
    });
  });

  group('verifySize', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('update_size_test');
    });

    tearDown(() async {
      if (temp.existsSync()) await temp.delete(recursive: true);
    });

    test('大小未知（0 / 负数）时跳过校验', () {
      final String path = '${temp.path}/a.apk';
      File(path).writeAsBytesSync(<int>[1, 2, 3]);
      expect(() => UpdateDownloader.verifySize(path, 0), returnsNormally);
      expect(() => UpdateDownloader.verifySize(path, -1), returnsNormally);
    });

    test('大小一致时通过', () {
      final String path = '${temp.path}/b.apk';
      File(path).writeAsBytesSync(<int>[1, 2, 3, 4]);
      expect(() => UpdateDownloader.verifySize(path, 4), returnsNormally);
    });

    test('大小不符（被截断）时抛异常', () {
      final String path = '${temp.path}/c.apk';
      File(path).writeAsBytesSync(<int>[1, 2]);
      expect(
        () => UpdateDownloader.verifySize(path, 10),
        throwsA(
          predicate<Exception>(
            (Exception e) => e.toString().contains('安装包大小不符'),
          ),
        ),
      );
    });
  });

  group('UpdateInstaller 在插件缺失时降级', () {
    late UpdateInstaller installer;

    setUp(() {
      const MethodChannel channel = MethodChannel('app_update_test_missing');
      final TestDefaultBinaryMessenger messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      // 未注册 handler 时 invokeMethod 会抛 MissingPluginException。
      messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        throw MissingPluginException('no implementation for ${call.method}');
      });
      installer = UpdateInstaller(channel: channel);
    });

    test('supportedAbis 返回空列表', () async {
      expect(await installer.supportedAbis(), isEmpty);
    });

    test('canRequestPackageInstalls 返回 false', () async {
      expect(await installer.canRequestPackageInstalls(), isFalse);
    });

    test('requestInstallPermission 静默失败', () async {
      await expectLater(installer.requestInstallPermission(), completes);
    });

    test('launchInstall 抛 InstallUnsupportedException', () async {
      expect(
        () => installer.launchInstall('/tmp/x.apk'),
        throwsA(isA<InstallUnsupportedException>()),
      );
    });

    test('verifyApk 返回 null 表示「无法校验」', () async {
      expect(await installer.verifyApk('/tmp/x.apk'), isNull);
    });
  });

  group('UpdateInstaller 读取原生返回', () {
    late UpdateInstaller installer;
    Map<String, Object?>? payload;

    setUp(() {
      const MethodChannel channel = MethodChannel('app_update_test_ok');
      final TestDefaultBinaryMessenger messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'getSupportedAbis':
            return <String>['arm64-v8a', 'armeabi-v7a'];
          case 'canRequestPackageInstalls':
            return true;
          case 'installApk':
            return true;
          case 'verifyApk':
            return payload;
        }
        return null;
      });
      installer = UpdateInstaller(channel: channel);
    });

    test('supportedAbis 按原生顺序返回', () async {
      expect(await installer.supportedAbis(), <String>[
        'arm64-v8a',
        'armeabi-v7a',
      ]);
    });

    test('installApk 返回 true', () async {
      expect(await installer.launchInstall('/tmp/x.apk'), isTrue);
    });

    test('verifyApk：包名与版本号合法时为 true', () async {
      payload = <String, Object?>{
        'packageName': 'com.ayuban.arlearning',
        'versionCode': 102000,
        'currentVersionCode': 101000,
      };
      expect(await installer.verifyApk('/tmp/x.apk'), isTrue);
    });

    test('verifyApk：包名不符为 false', () async {
      payload = <String, Object?>{
        'packageName': 'com.example.other',
        'versionCode': 102000,
        'currentVersionCode': 101000,
      };
      expect(await installer.verifyApk('/tmp/x.apk'), isFalse);
    });

    test('verifyApk：版本低于当前为 false', () async {
      payload = <String, Object?>{
        'packageName': 'com.ayuban.arlearning',
        'versionCode': 100000,
        'currentVersionCode': 101000,
      };
      expect(await installer.verifyApk('/tmp/x.apk'), isFalse);
    });

    test('verifyApk：原生返回非 Map 为 false', () async {
      payload = null;
      expect(await installer.verifyApk('/tmp/x.apk'), isFalse);
    });
  });
}
