// 原生端的 WebModelStore 桩：Web 逻辑只在浏览器构建里编译。

import 'dart:typed_data';

import 'package:arabic_learning/services/web_model_store.dart';

bool isAvailable() => false;

Future<void> loadIndex() async {}

WebModelMeta? metaOf(String id) => null;

String? typeOf(String id) => null;

List<String> installedIds() => const <String>[];

Future<void> put(
  String id, {
  required String type,
  required List<String> topLevelNames,
  required Map<String, Uint8List> files,
}) async {
  throw UnsupportedError('当前平台不支持浏览器模型仓库');
}

Future<void> delete(String id) async {}

Future<void> mount(
  String id, {
  required Iterable<String> files,
  bool espeakData = false,
}) async {
  throw UnsupportedError('当前平台不支持浏览器模型仓库');
}

Future<Uint8List?> read(String id, String relPath) async => null;
