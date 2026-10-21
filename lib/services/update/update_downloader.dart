// APK 下载：目录解析、临时文件名清洗、写盘与大小校验。
//
// 只负责「把文件完整写到磁盘」这一件事，进度回调、速度估算、状态机与通知
// 仍留在 `UpdateService`（门面）中，因此本类不持有任何 UI 状态，可被单元测试
// 直接驱动（注入 Dio / 目录 provider 即可，不依赖平台通道）。
//
// 目录默认取应用支持目录（Android 上等价于 `getFilesDir()`），落在 FileProvider
// 的 `<files-path>` 白名单内（见 android/app/src/main/res/xml/file_paths.xml）。

import 'package:arabic_learning/package_replacement/fake_dart_io.dart'
    if (dart.library.io) 'dart:io'
    as io;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

/// 下载被上层主动作废（取消 / 代次失效）时抛出。
///
/// 与取消（[CancelToken]）区分开：此处仅表示「结果已无意义」，上层静默丢弃，
/// 不做清理也不改状态（清理由 `cancelDownload` 负责）。
class DownloadAborted implements Exception {
  const DownloadAborted();
}

class UpdateDownloader {
  const UpdateDownloader();

  /// 下载根目录下的子目录名，隔离其他应用文件。
  static const String updateSubdirectory = 'arabicLearning/update';

  /// 取资产名的安全 basename：去掉任意目录分隔符，去掉首尾空白。
  ///
  /// 资产名由 GitHub 提供，直接拼进路径会有穿越风险，故先清洗再拼接。
  static String safeAssetName(String raw) {
    final int slash = raw.lastIndexOf('/');
    final int backslash = raw.lastIndexOf('\\');
    final int cut = slash > backslash ? slash : backslash;
    return (cut >= 0 ? raw.substring(cut + 1) : raw).trim();
  }

  /// 解析 APK 的存放目录。
  ///
  /// [directoryProvider] 仅为测试注入保留（历史命名，注入值代表「支持目录」）；
  /// 为 null 时使用 `getApplicationSupportDirectory()`。
  ///
  /// 参数类型写作 `Future<dynamic> Function()`：条件导入让 `io.Directory` 在静态
  /// 分析期解析为 `fake_dart_io` 的同名类，测试无法构造出该类型，故放宽为
  /// dynamic（运行时仍是 `dart:io` 的 Directory）。
  static Future<io.Directory> resolveDirectory({
    Future<dynamic> Function()? directoryProvider,
  }) async {
    final io.Directory base = directoryProvider != null
        ? await directoryProvider()
        : (await path_provider.getApplicationSupportDirectory())
              as io.Directory;
    return io.Directory('${base.path}/$updateSubdirectory');
  }

  /// 大小校验：被截断的下载直接失败，不进入安装。
  ///
  /// [expectedSize] 为 0 表示大小未知（确定性兜底地址场景），跳过校验。
  /// 只同步读取长度，避免把整个 APK 读入内存。
  static void verifySize(String path, int expectedSize) {
    if (expectedSize <= 0) return;
    final int actualSize = io.File(path).lengthSync();
    if (actualSize != expectedSize) {
      throw Exception('安装包大小不符，可能下载不完整');
    }
  }

  /// 下载 [url] 到更新目录下的 [assetName]，返回落盘路径。
  ///
  /// [isActive] 在每个可能被取消打断的步骤之间被调用；返回 false 时抛
  /// [DownloadAborted]，上层静默返回（与拆分前「代次失效即 return」等价）。
  /// [onPathResolved] 在真正开始写盘前回调落盘路径，便于上层在失败时清理残包。
  /// [dioProvider] 延迟到真正发请求前才解析网络客户端，保持拆分前的调用顺序
  /// （目录解析失败时不会去读网络配置）。
  Future<String> download({
    required Dio Function() dioProvider,
    required String url,
    required String assetName,
    required int expectedSize,
    required CancelToken cancelToken,
    required bool Function() isActive,
    void Function(String path)? onPathResolved,
    ProgressCallback? onReceiveProgress,
    Future<dynamic> Function()? directoryProvider,
  }) async {
    // 校验在任何文件系统写入之前完成。
    final String safeName = safeAssetName(assetName);
    if (safeName.isEmpty) {
      throw Exception('未找到可下载的安装包');
    }
    final io.Directory dir = await resolveDirectory(
      directoryProvider: directoryProvider,
    );
    if (!isActive()) throw const DownloadAborted();
    await dir.create(recursive: true);
    if (!isActive()) throw const DownloadAborted();

    final String savePath = '${dir.path}/$safeName';
    onPathResolved?.call(savePath);

    await dioProvider().download(
      url,
      savePath,
      cancelToken: cancelToken,
      deleteOnError: true,
      options: Options(
        headers: const <String, dynamic>{
          'Accept': 'application/octet-stream',
          'User-Agent': 'arabic_learning-updater',
        },
      ),
      onReceiveProgress: onReceiveProgress,
    );
    if (!isActive()) throw const DownloadAborted();

    verifySize(savePath, expectedSize);
    return savePath;
  }
}
