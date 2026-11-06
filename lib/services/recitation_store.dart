// 背诵成绩持久化：只存分数摘要，不存录音。
//
// 新顶层键 `recitationData` 已登记进 `SharedPreferences.usedKeys`，
// 随 WebDAV 备份与本地导出同步。

import 'dart:convert';

import 'package:arabic_learning/services/app_data.dart';
import 'package:logging/logging.dart';

class RecitationRecord {
  final String hash;
  final int timestamp;
  final int score;
  final double coverage;

  const RecitationRecord({
    required this.hash,
    required this.timestamp,
    required this.score,
    required this.coverage,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'hash': hash,
        'timestamp': timestamp,
        'score': score,
        'coverage': coverage,
      };

  factory RecitationRecord.fromMap(Map<String, dynamic> map) =>
      RecitationRecord(
        hash: map['hash'] as String? ?? '',
        timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
        score: (map['score'] as num?)?.toInt() ?? 0,
        coverage: (map['coverage'] as num?)?.toDouble() ?? 0,
      );
}

class RecitationStore {
  static final RecitationStore _instance = RecitationStore._internal();
  factory RecitationStore() => _instance;
  RecitationStore._internal();

  final Logger logger = Logger('Recitation');

  static const String storageKey = 'recitationData';

  /// 每段课文最多保留最近多少次成绩。
  static const int maxPerHash = 10;

  Map<String, List<RecitationRecord>>? _records;

  Map<String, List<RecitationRecord>> get _data {
    if (_records == null) _load();
    return _records!;
  }

  /// 某段课文的历史成绩，最新在前。
  List<RecitationRecord> recordsFor(String hash) =>
      List<RecitationRecord>.unmodifiable(
          _data[hash] ?? const <RecitationRecord>[]);

  Future<void> save(RecitationRecord record) async {
    final Map<String, List<RecitationRecord>> data = _data;
    final List<RecitationRecord> list =
        data.putIfAbsent(record.hash, () => <RecitationRecord>[])..add(record);
    list.sort(
        (RecitationRecord a, RecitationRecord b) => b.timestamp.compareTo(a.timestamp));
    if (list.length > maxPerHash) list.removeRange(maxPerHash, list.length);
    await AppData().storage.setString(
      storageKey,
      jsonEncode(<String, dynamic>{
        'version': 1,
        'records': <Map<String, dynamic>>[
          for (final List<RecitationRecord> records in data.values)
            for (final RecitationRecord item in records) item.toMap(),
        ],
      }),
    );
  }

  /// 备份恢复后从存储重读。
  void reload() {
    _load();
    logger.info('背诵成绩重载完成');
  }

  void _load() {
    final Map<String, List<RecitationRecord>> records =
        <String, List<RecitationRecord>>{};
    final String? raw = AppData().storage.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(raw);
        final dynamic list = decoded is Map ? decoded['records'] : null;
        if (list is List) {
          for (final dynamic item in list) {
            if (item is! Map) continue;
            final RecitationRecord record = RecitationRecord.fromMap(
                Map<String, dynamic>.from(item));
            if (record.hash.isEmpty) continue;
            records.putIfAbsent(record.hash, () => <RecitationRecord>[])
                .add(record);
          }
        }
      } catch (e) {
        logger.warning('背诵成绩解析失败: $e');
      }
    }
    for (final List<RecitationRecord> list in records.values) {
      list.sort(
          (RecitationRecord a, RecitationRecord b) => b.timestamp.compareTo(a.timestamp));
      if (list.length > maxPerHash) list.removeRange(maxPerHash, list.length);
    }
    _records = records;
  }
}
