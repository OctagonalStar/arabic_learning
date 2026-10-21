// 安装相关的平台桥接：ABI 查询、安装权限、调起系统安装器、APK 元数据校验。
//
// 所有方法都通过 [channel]（默认 `app_update`）与原生交互，并对
// `MissingPluginException` / 其他异常做容错：非 Android 与测试环境不应因插件
// 缺失而崩溃。桥接返回的原始数据一律交给
// `github_release.dart` 中的纯函数判定（见 [verifyApkMetadata]）。
//
// 通道可注入，便于测试在不依赖真实插件的前提下验证降级分支。

import 'package:arabic_learning/services/update/github_release.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, MethodChannel;
import 'package:logging/logging.dart';

/// 当前平台不支持应用内安装（原生桥接缺失）。
class InstallUnsupportedException implements Exception {
  const InstallUnsupportedException();

  @override
  String toString() => '当前平台不支持应用内安装';
}

class UpdateInstaller {
  UpdateInstaller({
    MethodChannel? channel,
    Logger? logger,
    this.expectedPackageName = expectedApkPackageName,
  }) : _channel = channel ?? const MethodChannel(updateMethodChannelName),
       logger = logger ?? Logger('UpdateInstaller');

  final MethodChannel _channel;
  final Logger logger;

  /// 期望的 Android 包名；与原生返回的包名做严格比较。
  ///
  /// 默认取 [expectedApkPackageName]，可在测试中改写以验证包名分支。
  final String expectedPackageName;

  /// 查询设备支持的 ABI 列表（最优在前）。
  ///
  /// 通过原生桥接获取 `Build.SUPPORTED_ABIS`；非 Android / 插件缺失 / 出错时
  /// 返回空列表，由资产匹配逻辑走无 ABI 信息的回退分支。
  Future<List<String>> supportedAbis() async {
    try {
      final List<dynamic>? raw = await _channel.invokeMethod<List<dynamic>>(
        'getSupportedAbis',
      );
      if (raw == null) return const <String>[];
      return raw.map((dynamic e) => e.toString()).toList();
    } on MissingPluginException {
      return const <String>[];
    } catch (e) {
      logger.warning('查询设备 ABI 失败: $e');
      return const <String>[];
    }
  }

  /// 是否已获得「安装未知来源应用」权限。插件缺失 / 出错时返回 false。
  Future<bool> canRequestPackageInstalls() async {
    try {
      return (await _channel.invokeMethod<bool>('canRequestPackageInstalls')) ??
          false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      logger.warning('查询安装权限失败: $e');
      return false;
    }
  }

  /// 拉起系统「安装未知来源应用」授权页。
  Future<void> requestInstallPermission() async {
    try {
      await _channel.invokeMethod<void>('requestInstallPermission');
    } on MissingPluginException {
      logger.warning('当前平台不支持申请安装权限');
    } catch (e) {
      logger.warning('申请安装权限失败: $e');
    }
  }

  /// 调起系统安装器；返回是否成功启动。
  ///
  /// 插件缺失时抛 [InstallUnsupportedException]，其他异常原样上抛，由调用方
  /// 决定如何呈现错误（保持 `ready` 状态以便重试）。
  Future<bool> launchInstall(String path) async {
    try {
      return (await _channel.invokeMethod<bool>('installApk', <String, dynamic>{
            'path': path,
          })) ??
          false;
    } on MissingPluginException {
      throw const InstallUnsupportedException();
    }
  }

  /// 校验下载的 APK：确认包名一致且版本号不低于当前安装版本。
  ///
  /// 返回 null 表示「无法校验」（插件缺失），由调用方决定是否放行（拆分前
  /// 的语义是放行）；返回 false 表示明确校验失败（失败关闭）。
  Future<bool?> verifyApk(String path) async {
    try {
      final dynamic raw = await _channel.invokeMethod<dynamic>(
        'verifyApk',
        <String, dynamic>{'path': path},
      );
      if (raw is! Map) {
        logger.warning('APK 校验失败：无法解析原生返回信息');
        return false;
      }
      final String pkg = raw['packageName']?.toString() ?? '';
      if (pkg.isEmpty || pkg != expectedPackageName) {
        logger.warning('安装包包名不匹配: $pkg');
        return false;
      }
      final int? apkCode = toIntOrNull(raw['versionCode']);
      final int? currentCode = toIntOrNull(raw['currentVersionCode']);
      if (!verifyApkMetadata(
        packageName: pkg,
        versionCode: apkCode,
        currentVersionCode: currentCode,
      )) {
        logger.warning('安装包版本号($apkCode)不合法或低于当前版本($currentCode)');
        return false;
      }
      return true;
    } on MissingPluginException {
      return null;
    } catch (e) {
      logger.warning('APK 校验失败: $e');
      return false;
    }
  }
}
