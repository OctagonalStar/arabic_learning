// 本地模型（TTS / ASR）的安装、删除与本地模型包导入。

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;

import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/download.dart';
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
import 'package:logging/logging.dart';

final Logger _logger = Logger('ModelManager');

class ModelManager {
  const ModelManager._();

  /// 指定模型是否已解压安装。
  static bool isInstalled(String id) =>
      AppData().isTtsModelInstalled(id) || AppData().isAsrModelInstalled(id);

  /// 下载并解压模型（发布包 `<id>.tar.bz2`）。未知 id 抛 [ArgumentError]。
  static Future<void> install(
    String id, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (kIsWeb) throw UnsupportedError('Web 端不支持下载模型');
    final bool isTts = _findTts(id) != null;
    if (!isTts && _findAsr(id) == null) throw ArgumentError('未知模型：$id');

    final String base = AppData().basePath.path;
    final String archiveRoot = isTts ? StaticsVar.ttsRootDir : StaticsVar.asrModelRoot;
    final String extractRoot = isTts ? StaticsVar.ttsModelRoot : StaticsVar.asrModelRoot;
    final String archivePath = '$base/$archiveRoot/$id.tar.bz2';
    final String url =
        isTts ? StaticsVar.ttsArchiveUrl(id) : StaticsVar.asrArchiveUrl(id);
    _logger.info('模型下载开始: id=$id, url=$url, 包=$archivePath, 解压到=$base/$extractRoot');
    await io.Directory('$base/$archiveRoot').create(recursive: true);
    final Stopwatch watch = Stopwatch()..start();
    try {
      await downloadFile(
        url,
        archivePath,
        onDownloading: onProgress == null
            ? null
            : (int received, int total) => onProgress(received, total),
      );
      final int archiveBytes = io.File(archivePath).lengthSync();
      _logger.info('模型下载完成: id=$id, ${watch.elapsedMilliseconds}ms, $archiveBytes 字节');
      await compute(extractTarBz2, (archivePath, '$base/$extractRoot'));
      _logger.info('模型解压完成: id=$id, 总耗时=${watch.elapsedMilliseconds}ms');
    } catch (e, s) {
      _logger.severe('模型安装失败: id=$id, 包=$archivePath', e, s);
      rethrow;
    } finally {
      final io.File archive = io.File(archivePath);
      if (archive.existsSync()) archive.deleteSync();
    }
  }

  /// 删除已解压的模型目录；未安装时无操作。
  static Future<void> delete(String id) async {
    if (kIsWeb) return;
    final String? dir = _modelDir(id);
    if (dir == null) return;
    final io.Directory directory = io.Directory('${AppData().basePath.path}/$dir');
    if (!directory.existsSync()) return;
    directory.deleteSync(recursive: true);
    _logger.info('模型已删除: id=$id, 目录=$dir');
  }

  /// 从本地 tar.bz2 安装模型包，返回识别到的模型 id。
  ///
  /// 包内必须只有一个顶层目录，且其名称为目录中的模型 id。
  static Future<String> importArchive(String archivePath) async {
    if (kIsWeb) throw UnsupportedError('Web 端不支持导入模型包');
    final io.File file = io.File(archivePath);
    if (!file.existsSync()) throw Exception('模型包不存在：$archivePath');
    _logger.info('模型导入开始: $archivePath, ${file.lengthSync()} 字节');

    final Archive tar = TarDecoder().decodeBytes(
      BZip2Decoder().decodeBytes(await file.readAsBytes()),
    );
    final Set<String> topDirs = <String>{};
    for (final ArchiveFile entry in tar.files) {
      final String name = entry.name.replaceAll('\\', '/');
      final int slash = name.indexOf('/');
      final String top = slash == -1 ? name : name.substring(0, slash);
      if (top.isNotEmpty) topDirs.add(top);
    }
    if (topDirs.length != 1) {
      _logger.warning('模型导入失败: 顶层目录数=${topDirs.length} ($topDirs)');
      throw Exception('不支持的模型包');
    }

    final String topDir = topDirs.first;
    final bool isTts = _findTts(topDir) != null;
    if (!isTts && _findAsr(topDir) == null) {
      _logger.warning('模型导入失败: 未知模型目录 $topDir');
      throw Exception('不支持的模型包：$topDir');
    }

    final String base = AppData().basePath.path;
    final String extractRoot = isTts ? StaticsVar.ttsModelRoot : StaticsVar.asrModelRoot;
    await delete(topDir); // 不覆盖已有安装
    await io.Directory('$base/$extractRoot').create(recursive: true);
    await compute(extractTarBz2, (archivePath, '$base/$extractRoot'));
    _logger.info('模型导入完成: id=$topDir -> $base/$extractRoot');
    return topDir;
  }

  static TtsModelInfo? _findTts(String id) {
    for (final TtsModelInfo info in StaticsVar.ttsModels) {
      if (info.id == id) return info;
    }
    return null;
  }

  static AsrModelInfo? _findAsr(String id) {
    for (final AsrModelInfo info in StaticsVar.asrModels) {
      if (info.id == id) return info;
    }
    return null;
  }

  static String? _modelDir(String id) {
    if (_findTts(id) != null) return StaticsVar.ttsModelDir(id);
    if (_findAsr(id) != null) return StaticsVar.asrModelDir(id);
    return null;
  }
}
