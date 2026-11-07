// Web 本地模型仓库门面：IndexedDB 持久化 + Emscripten MEMFS 挂载。
// 条件导入与 package_replacement/storage.dart 保持一致。

import 'dart:typed_data';

import 'package:arabic_learning/services/web_model_store_stub.dart'
    if (dart.library.html) 'package:arabic_learning/services/web_model_store_web.dart'
    as impl;

/// 已安装模型的元数据：只需顶层结构就够 [ModelManager] 识别类型与所需文件。
class WebModelMeta {
  /// 'tts' | 'asr'
  final String type;

  /// 模型目录顶层文件名/子目录名。
  final List<String> names;

  final bool hasEspeakData;

  const WebModelMeta({
    required this.type,
    required this.names,
    required this.hasEspeakData,
  });
}

/// Web 端模型文件仓库；原生端除 [isAvailable] 外均为空/不支持。
class WebModelStore {
  const WebModelStore._();

  static bool isAvailable() => impl.isAvailable();

  /// 启动时把 IndexedDB 里的元数据读进内存。
  static Future<void> loadIndex() => impl.loadIndex();

  static WebModelMeta? metaOf(String id) => impl.metaOf(id);

  static String? typeOf(String id) => impl.typeOf(id);

  static List<String> installedIds() => impl.installedIds();

  /// [files] 的 key 是相对模型目录的路径。
  static Future<void> put(
    String id, {
    required String type,
    required List<String> topLevelNames,
    required Map<String, Uint8List> files,
  }) => impl.put(id, type: type, topLevelNames: topLevelNames, files: files);

  static Future<void> delete(String id) => impl.delete(id);

  /// 把 [files] 写进 wasm 的 MEMFS；目录前缀（如 `espeak-ng-data`）会展开为其中全部文件。
  static Future<void> mount(
    String id, {
    required Iterable<String> files,
    bool espeakData = false,
  }) => impl.mount(id, files: files, espeakData: espeakData);

  /// 调试用：直接读回某个文件。
  static Future<Uint8List?> read(String id, String relPath) =>
      impl.read(id, relPath);
}
