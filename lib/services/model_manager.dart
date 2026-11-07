// 本地模型（TTS / ASR）的安装、删除与本地模型包导入。

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;

import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/download.dart';
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
import 'package:logging/logging.dart';

final Logger _logger = Logger('ModelManager');

/// 本地模型包内的 TTS 架构；由目录内容识别，不依赖目录名。
enum TtsModelKind { vits, kokoro }

/// [ModelManager.resolveTts] 的解析结果（文件名均相对于模型目录）。
class TtsModelFiles {
  final TtsModelKind kind;
  final String model;
  final String? voices;
  final String tokens;
  final String? dataDir;

  const TtsModelFiles({
    required this.kind,
    required this.model,
    required this.voices,
    required this.tokens,
    required this.dataDir,
  });
}

/// [ModelManager.resolveAsr] 的解析结果（文件名均相对于模型目录）。
class AsrModelFiles {
  /// true 表示 NeMo CTC（单文件）；false 表示 Whisper（encoder + decoder）。
  final bool nemoCtc;
  final String model;
  final String? encoder;
  final String? decoder;
  final String tokens;

  const AsrModelFiles({
    required this.nemoCtc,
    required this.model,
    required this.encoder,
    required this.decoder,
    required this.tokens,
  });
}

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
  ///
  /// 不依赖内置目录：导入的模型 id 同样直接按根目录下的同名子目录删除。
  static Future<void> delete(String id) async {
    if (kIsWeb) return;
    final String base = AppData().basePath.path;
    for (final String root in <String>[
      StaticsVar.ttsModelRoot,
      StaticsVar.asrModelRoot,
    ]) {
      final io.Directory directory = io.Directory('$base/$root/$id');
      if (!directory.existsSync()) continue;
      directory.deleteSync(recursive: true);
      _logger.info('模型已删除: id=$id, 目录=$root/$id');
    }
  }

  /// 从本地 tar.bz2 安装模型包，返回解压出的顶层目录名。
  ///
  /// 包内必须只有一个顶层目录，目录名不限；类型按目录内文件名判断。
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
    final List<String> names = <String>[
      for (final ArchiveFile entry in tar.files)
        if (entry.name.replaceAll('\\', '/').startsWith('$topDir/'))
          entry.name.replaceAll('\\', '/').split('/').last,
    ];
    final bool? isTts = _classify(names);
    if (isTts == null) {
      _logger.warning('模型导入失败: 无法识别目录结构 $topDir');
      throw Exception('无法识别的模型包结构，请查看模型管理页的说明');
    }

    final String base = AppData().basePath.path;
    final String extractRoot =
        isTts ? StaticsVar.ttsModelRoot : StaticsVar.asrModelRoot;
    await delete(topDir); // 不覆盖已有安装
    await io.Directory('$base/$extractRoot').create(recursive: true);
    await compute(extractTarBz2, (archivePath, '$base/$extractRoot'));
    _logger.info('模型导入完成: id=$topDir -> $base/$extractRoot');
    return topDir;
  }

  /// 按包内文件名判断是 TTS (true) 还是 ASR (false)；无法识别返回 null。
  static bool? _classify(List<String> names) {
    bool isOnnx(String name) => name.endsWith('.onnx');
    if (names.contains('voices.bin') ||
        names.any((String n) => n.endsWith('.onnx.json'))) {
      return true;
    }
    if (names.any((String n) => isOnnx(n) && n.contains('encoder')) &&
        names.any((String n) => isOnnx(n) && n.contains('decoder'))) {
      return false;
    }
    if (names.any((String n) => isOnnx(n) && n.startsWith('model'))) {
      return false;
    }
    return null;
  }

  /// 解析目录内的 TTS 模型文件；目录不是可识别的 TTS 结构时返回 null。
  static TtsModelFiles? resolveTts(String dirPath) {
    final List<String> names = _baseNames(dirPath);
    if (names.contains('voices.bin')) {
      final String? model = names.contains('model.int8.onnx')
          ? 'model.int8.onnx'
          : names.contains('model.onnx')
              ? 'model.onnx'
              : null;
      if (model == null) return null;
      return TtsModelFiles(
        kind: TtsModelKind.kokoro,
        model: model,
        voices: 'voices.bin',
        tokens: 'tokens.txt',
        dataDir: _dataDir(dirPath),
      );
    }
    final List<String> jsonNames =
        names.where((String n) => n.endsWith('.onnx.json')).toList()..sort();
    for (final String json in jsonNames) {
      final String onnx = json.substring(0, json.length - '.json'.length);
      if (!names.contains(onnx)) continue;
      return TtsModelFiles(
        kind: TtsModelKind.vits,
        model: onnx,
        voices: null,
        tokens: 'tokens.txt',
        dataDir: _dataDir(dirPath),
      );
    }
    return null;
  }

  /// 解析目录内的 ASR 模型文件；目录不是可识别的 ASR 结构时返回 null。
  static AsrModelFiles? resolveAsr(String dirPath) {
    final List<String> names = _baseNames(dirPath);
    final List<String> onnx = names
        .where((String n) => n.endsWith('.onnx'))
        .toList()
      ..sort();
    final String? encoder = _first(onnx.where((String n) => n.contains('encoder')));
    final String? decoder = _first(onnx.where((String n) => n.contains('decoder')));
    if (encoder != null && decoder != null) {
      return AsrModelFiles(
        nemoCtc: false,
        model: encoder,
        encoder: encoder,
        decoder: decoder,
        tokens: _asrTokens(names),
      );
    }
    final List<String> models =
        onnx.where((String n) => n.startsWith('model')).toList();
    if (models.isEmpty) return null;
    return AsrModelFiles(
      nemoCtc: true,
      model: models.contains('model.int8.onnx')
          ? 'model.int8.onnx'
          : models.first,
      encoder: null,
      decoder: null,
      tokens: _asrTokens(names),
    );
  }

  static List<String> _baseNames(String dirPath) {
    if (!io.Directory(dirPath).existsSync()) return const <String>[];
    try {
      return io.Directory(dirPath)
          .listSync()
          .map((entity) =>
              entity.path.replaceAll('\\', '/').split('/').last)
          .toList();
    } on io.FileSystemException {
      return const <String>[];
    }
  }

  static String _dataDir(String dirPath) =>
      io.Directory('$dirPath/espeak-ng-data').existsSync()
          ? '$dirPath/espeak-ng-data'
          : dirPath;

  /// 识别模型的分词表：优先任意 `*tokens*.txt`（Whisper），否则 `tokens.txt`。
  static String _asrTokens(List<String> names) {
    final List<String> tokens = names
        .where((String n) => n.contains('tokens') && n.endsWith('.txt'))
        .toList()
      ..sort();
    return tokens.isEmpty ? 'tokens.txt' : tokens.first;
  }

  static String? _first(Iterable<String> items) =>
      items.isEmpty ? null : items.first;

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
}
