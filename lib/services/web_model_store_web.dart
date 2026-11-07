// Web 模型仓库实现：文件存 IndexedDB，运行前挂进 Emscripten MEMFS 供 sherpa-onnx 读取。

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:arabic_learning/services/web_model_store.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:logging/logging.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

final Logger _logger = Logger('WebModelStore');

const String _dbName = 'models.db';
const String _filesStore = 'files';
const String _metaStore = 'meta';

Database? _db;
final Map<String, WebModelMeta> _meta = <String, WebModelMeta>{};
final Set<String> _mounted = <String>{};

bool isAvailable() => true;

Future<Database> _open() async {
  final Database? existing = _db;
  if (existing != null) return existing;
  final IdbFactory factory = getIdbFactory()!;
  final Database opened = await factory.open(
    _dbName,
    version: 1,
    onUpgradeNeeded: (VersionChangeEvent event) {
      event.database.createObjectStore(_filesStore);
      event.database.createObjectStore(_metaStore);
    },
  );
  _db = opened;
  return opened;
}

/// 该模型在 `files` 里的全部 key（`id/rel`）。
Future<List<String>> _fileKeys(Database db, String id) async {
  final Transaction txn = db.transaction(_filesStore, idbModeReadOnly);
  final List<Object> keys = await txn.objectStore(_filesStore).getAllKeys();
  final String prefix = '$id/';
  return <String>[
    for (final Object key in keys)
      if (key is String && key.startsWith(prefix)) key,
  ];
}

Future<void> loadIndex() async {
  try {
    final Database db = await _open();
    final Transaction txn = db.transaction(_metaStore, idbModeReadOnly);
    final List<Object> values = await txn.objectStore(_metaStore).getAll();
    _meta.clear();
    for (final Object value in values) {
      if (value is! Map) continue;
      final Object? id = value['id'];
      final WebModelMeta? meta = _metaFrom(value);
      if (id is String && meta != null) _meta[id] = meta;
    }
    _logger.info('Web 模型索引已加载: ${_meta.keys.toList()..sort()}');
  } catch (e) {
    // IndexedDB 不可用时不影响其它功能，只当没有已安装模型。
    _logger.warning('Web 模型索引加载失败: $e');
  }
}

WebModelMeta? _metaFrom(Object? value) {
  if (value is! Map) return null;
  final Object? type = value['type'];
  final Object? names = value['names'];
  if (type is! String || names is! List) return null;
  return WebModelMeta(
    type: type,
    names: <String>[
      for (final Object? name in names)
        if (name is String) name,
    ],
    hasEspeakData: value['hasEspeakData'] == true,
  );
}

WebModelMeta? metaOf(String id) => _meta[id];

String? typeOf(String id) => _meta[id]?.type;

List<String> installedIds() => _meta.keys.toList()..sort();

Future<void> put(
  String id, {
  required String type,
  required List<String> topLevelNames,
  required Map<String, Uint8List> files,
}) async {
  final Database db = await _open();
  final List<String> oldKeys = await _fileKeys(db, id);
  final Transaction txn = db.transactionList(<String>[
    _filesStore,
    _metaStore,
  ], idbModeReadWrite);
  final ObjectStore fileStore = txn.objectStore(_filesStore);
  for (final String key in oldKeys) {
    await fileStore.delete(key);
  }
  for (final MapEntry<String, Uint8List> entry in files.entries) {
    await fileStore.put(entry.value, '$id/${entry.key}');
  }
  await txn.objectStore(_metaStore).put(<String, dynamic>{
    'id': id,
    'type': type,
    'names': topLevelNames,
    'hasEspeakData': topLevelNames.contains('espeak-ng-data'),
  }, id);
  await txn.completed;
  _meta[id] = WebModelMeta(
    type: type,
    names: List<String>.of(topLevelNames),
    hasEspeakData: topLevelNames.contains('espeak-ng-data'),
  );
  _mounted.removeWhere((String key) => key.startsWith('$id/'));
  _logger.info('模型已存入 IndexedDB: $id ($type, ${files.length} 个文件)');
}

Future<void> delete(String id) async {
  final Database db = await _open();
  final List<String> oldKeys = await _fileKeys(db, id);
  final Transaction txn = db.transactionList(<String>[
    _filesStore,
    _metaStore,
  ], idbModeReadWrite);
  final ObjectStore fileStore = txn.objectStore(_filesStore);
  for (final String key in oldKeys) {
    await fileStore.delete(key);
  }
  await txn.objectStore(_metaStore).delete(id);
  await txn.completed;
  _meta.remove(id);
  _mounted.removeWhere((String key) => key.startsWith('$id/'));
  _logger.info('模型已从 IndexedDB 删除: $id');
}

Future<void> mount(
  String id, {
  required Iterable<String> files,
  bool espeakData = false,
}) async {
  // MEMFS 由 sherpa 的 wasm 提供，必须先加载它。
  await sherpa_onnx.initBindingsAsync();
  final Database db = await _open();
  final Set<String> keys = (await _fileKeys(db, id)).toSet();

  final Set<String> rels = <String>{};
  for (final String file in files) {
    final String rel = file.replaceAll('\\', '/');
    if (keys.contains('$id/$rel')) {
      rels.add(rel);
      continue;
    }
    // 目录前缀：挂载其中全部文件。
    for (final String key in keys) {
      if (key.startsWith('$id/$rel/')) rels.add(key.substring(id.length + 1));
    }
  }
  if (espeakData) {
    for (final String key in keys) {
      final String rel = key.substring(id.length + 1);
      if (rel.startsWith('espeak-ng-data/')) rels.add(rel);
    }
  }

  final List<String> ordered = rels.toList()..sort();
  final Transaction txn = db.transaction(_filesStore, idbModeReadOnly);
  final ObjectStore store = txn.objectStore(_filesStore);
  final List<Object?> values = await Future.wait(<Future<Object?>>[
    for (final String rel in ordered) store.getObject('$id/$rel'),
  ]);

  final JSObject module = globalContext.getProperty('Module'.toJS) as JSObject;
  final JSObject fs = module.getProperty('FS'.toJS) as JSObject;
  int written = 0;
  for (int i = 0; i < ordered.length; i++) {
    final Object? value = values[i];
    if (value is! Uint8List) continue;
    final String rel = ordered[i];
    final String key = '$id/$rel';
    if (!_mounted.add(key)) continue;
    final String full = 'models/$key';
    final int slash = full.lastIndexOf('/');
    fs.callMethod(
      'createPath'.toJS,
      '/'.toJS,
      full.substring(0, slash).toJS,
      true.toJS,
      true.toJS,
    );
    fs.callMethod('writeFile'.toJS, full.toJS, value.toJS);
    written++;
  }
  _logger.info('模型已挂载到 MEMFS: $id ($written 个文件)');
}

Future<Uint8List?> read(String id, String relPath) async {
  final Database db = await _open();
  final Transaction txn = db.transaction(_filesStore, idbModeReadOnly);
  final Object? value = await txn
      .objectStore(_filesStore)
      .getObject('$id/${relPath.replaceAll('\\', '/')}');
  return value is Uint8List ? value : null;
}
