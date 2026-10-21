// FSRS 卡片数据的 SQLite（drift）实现 —— **仅原生平台**。
//
// Web 端绝不能导入本文件：对外统一通过
// `services/db/fsrs_store_factory.dart` 的条件导入拿到空实现（返回 null）。
//
// 表结构（刻意「一行一卡 + 卡与日志同存」，不拆 fsrs 包的字段，
// 以免 fsrs 升级时被迫做 schema 迁移）：
//   fsrs_cards(card_id INTEGER PRIMARY KEY, card_json TEXT, log_json TEXT, updated_at INTEGER)
//   hot_kv(key TEXT PRIMARY KEY, value TEXT, updated_at INTEGER)      -- 目前只放 pushSessionData
//   meta(key TEXT PRIMARY KEY, value TEXT)                            -- schema_version / legacy_imported / config_meta
//
// `config_meta` 保存 `FSRSConfig.toMap()` 去掉 cards/reviewLog 后的配置项
// （enabled / 调度器参数 / 推送设置等），卡片本身按行存放。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:logging/logging.dart';

import 'package:arabic_learning/services/db/fsrs_store.dart';
import 'package:arabic_learning/services/fsrs.dart' show FSRSConfig;

part 'fsrs_drift_store.g.dart';

/// 卡片表：一行一张卡，卡与复习日志同存。
class FsrsCards extends Table {
  IntColumn get cardId => integer()();

  /// `Card.toMap()` 的 JSON 文本。
  TextColumn get cardJson => text()();

  /// `ReviewLog.toMap()` 的 JSON 文本。
  TextColumn get logJson => text()();

  /// 写入时间戳（毫秒），仅用于排障。
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{cardId};
}

/// 高频键值表（避免这些键落进 shared_preferences 触发整文件重写）。
class HotKv extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

/// 元信息表。表名固定为 `meta`（类名加后缀避免与 `package:meta` 的 `Meta` 混淆）。
class MetaTable extends Table {
  @override
  String get tableName => 'meta';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

@DriftDatabase(tables: <Type>[FsrsCards, HotKv, MetaTable])
class FsrsDatabase extends _$FsrsDatabase {
  FsrsDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

/// `flutter test` 环境下默认不启用 SQLite：
/// 既有单元测试全部基于 JSON 后端（行为与旧版完全一致），也不依赖 sqlite3 原生库。
/// 需要测试 drift 后端时（例如直接构造 [DriftFsrsStore]）无需打开本开关，
/// 只有想走完整 [openFsrsDriftStore] 路径时才需要设置它（并配合 [openFsrsDriftStore] 的
/// `databasePath`，把库文件放到测试自己的临时目录）。
bool debugForceDriftInTests = false;

/// 是否为 `flutter test` 进程。
bool get _isFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';

/// 打开原生 SQLite 存储；任何失败都返回 null（由调用方回退 JSON 存储）。
///
/// [databasePath] 为空时用 `drift_flutter` 的默认位置
/// （`path_provider` 的应用文档目录）。测试必须显式传一个临时路径：
/// drift 的数据库在后台 isolate 里打开，拿不到 `flutter test` 里 mock 的
/// `path_provider` 通道，否则会落到开发机的真实文档目录。
///
/// 对外请用 `fsrs_store_factory.dart` 的同名包装（Web 上不会导入本文件）。
Future<FsrsStore?> openFsrsDriftStore({
  String? legacyJson,
  Map<String, String>? legacyHotKv,
  String? databasePath,
}) async {
  final Logger logger = Logger('DriftFsrsStore');
  if (_isFlutterTest && !debugForceDriftInTests) {
    logger.fine('测试环境，跳过 SQLite（使用 JSON 后端）');
    return null;
  }
  FsrsDatabase? database;
  try {
    database = FsrsDatabase(
      driftDatabase(
        name: 'fsrs',
        native: databasePath == null
            ? null
            : DriftNativeOptions(databasePath: () async => databasePath),
      ),
    );
    final DriftFsrsStore store = DriftFsrsStore(database);
    await store.open(legacyJson: legacyJson, legacyHotKv: legacyHotKv);
    logger.info('SQLite 存储已打开');
    return store;
  } catch (e, stack) {
    logger.severe('SQLite 存储打开失败，回退 JSON 存储: $e', e, stack);
    try {
      await database?.close();
    } catch (_) {
      // 关闭失败无需处理：本次会话已回退 JSON 后端。
    }
    return null;
  }
}

/// drift 实现。
///
/// 写入策略：所有写操作串行排队（[FsrsStore.save] 只保留最新快照），
/// 因此答题时的防抖写不会互相覆盖，也不会阻塞 UI。
class DriftFsrsStore implements FsrsStore {
  DriftFsrsStore(this.db);

  final FsrsDatabase db;

  @override
  final Logger logger = Logger('DriftFsrsStore');

  /// 待写入的最新内存快照（只保留最新一份，避免积压）。
  FSRSConfig? _pending;

  /// 是否已有排队的落盘任务。
  bool _scheduled = false;

  /// 串行队列尾。
  Future<void> _tail = Future<void>.value();

  /// hot_kv 的内存缓存：同步读、异步写。
  final Map<String, String> _hotCache = <String, String>{};

  int _now() => DateTime.now().millisecondsSinceEpoch;

  @override
  bool get usesSqlite => true;

  Future<void> _enqueue(Future<void> Function() task) {
    final Future<void> next = _tail.then((_) => task()).catchError(
      (Object e, StackTrace s) => logger.severe('SQLite 写入失败: $e', e, s),
    );
    _tail = next;
    return next;
  }

  @override
  Future<void> open({
    String? legacyJson,
    Map<String, String>? legacyHotKv,
  }) async {
    // 触发一次真实查询：drift 的连接是惰性打开的，失败要在这里就暴露出来。
    await db.customSelect('SELECT 1 AS ok').get();
    await _migrate(legacyJson: legacyJson, legacyHotKv: legacyHotKv);
    await _loadHotCache();
  }

  /// 首启迁移与「外部写入」检测（幂等）。
  ///
  /// 两种导入情形：
  /// 1. 首启：`legacy_imported` 未标记 → 导入旧 `fsrsData`（单事务，失败回滚）。
  /// 2. 外部写入：`legacy_snapshot` 记录了我们最后一次写进偏好文件的 blob，
  ///    若当前 `fsrsData` 与它不同，说明是**别的途径**写的（降级到旧版本后又
  ///    答题、手工改、或上次写入被中断），此时导入以免丢失那份更新的数据。
  ///
  /// 旧数据里没有的卡片不会删除已有行（情形 2 会整表覆盖，由 [importLegacy] 负责）。
  Future<void> _migrate({
    String? legacyJson,
    Map<String, String>? legacyHotKv,
  }) async {
    final bool imported = await _getMeta('legacy_imported') == '1';
    final String? lastSnapshot = await _getMeta('legacy_snapshot');
    final bool hasLegacy = legacyJson != null && legacyJson.isNotEmpty;
    final bool foreignWrite = hasLegacy && lastSnapshot != null && lastSnapshot != legacyJson;

    if (imported && !foreignWrite) return;

    try {
      await db.transaction(() async {
        if (hasLegacy) {
          final FSRSConfig config = fsrsConfigFromJson(legacyJson);
          final List<FsrsCardRow> rows =
              fsrsRowsFromConfig(config, updatedAt: _now());
          if (rows.isNotEmpty) {
            await db.delete(db.fsrsCards).go();
            await _insertRows(rows);
            await _putMeta('config_meta', jsonEncode(fsrsConfigMeta(config)));
            logger.info(
              '${imported ? "检测到外部写入的 fsrsData，重新导入" : "首启迁移：从旧 fsrsData 导入"} ${rows.length} 张卡片',
            );
          } else if (imported) {
            // 外部写入的 fsrsData 不含卡片（例如旧版本里关掉了 FSRS）。
            // 只同步配置项，不删库里的卡片：误判成「清空」会永久丢掉全部进度，
            // 保留多出来的卡片最多只是多复习几张，用户可以手动清空。
            await _putMeta('config_meta', jsonEncode(fsrsConfigMeta(config)));
            logger.warning('外部 fsrsData 不含卡片，仅同步配置项，保留库中现有卡片');
          }
        }
        if (legacyHotKv != null) {
          for (final MapEntry<String, String> entry in legacyHotKv.entries) {
            if (entry.value.isEmpty) continue;
            // 只在库里还没有该键时导入：hot_kv 才是 SQLite 模式下的权威副本，
            // 偏好文件里的值可能只是迁移前的旧断点。
            if (await _getHotKv(entry.key) == null) {
              await _putHotKv(entry.key, entry.value);
            }
          }
        }
        if (hasLegacy) await _putMeta('legacy_snapshot', legacyJson);
        await _putMeta('schema_version', '1');
        await _putMeta('legacy_imported', '1');
      });
    } catch (e, stack) {
      logger.severe('旧 fsrsData 迁移失败，已回滚: $e', e, stack);
      rethrow; // 交给 openFsrsDriftStore 捕获并回退 JSON 存储
    }
  }

  Future<String?> _getMeta(String key) async {    final MetaTableData? row = await (db.select(db.metaTable)
          ..where((MetaTable t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _putMeta(String key, String value) async {
    await db.into(db.metaTable).insertOnConflictUpdate(
          MetaTableCompanion.insert(key: key, value: value),
        );
  }

  Future<String?> _getHotKv(String key) async {
    final HotKvData? row = await (db.select(db.hotKv)
          ..where((HotKv t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _putHotKv(String key, String value) async {
    await db.into(db.hotKv).insertOnConflictUpdate(
          HotKvCompanion.insert(key: key, value: value, updatedAt: _now()),
        );
  }

  Future<void> _loadHotCache() async {
    final List<HotKvData> rows = await db.select(db.hotKv).get();
    _hotCache
      ..clear()
      ..addEntries(rows.map(
        (HotKvData row) => MapEntry<String, String>(row.key, row.value),
      ));
  }

  Future<void> _insertRows(List<FsrsCardRow> rows) async {
    await db.batch((Batch batch) {
      batch.insertAll(
        db.fsrsCards,
        rows
            .map((FsrsCardRow row) => FsrsCardsCompanion(
                  // 显式传 cardId：integer 主键在 drift 里是 rowid 别名，
                  // `.insert` 构造器会把它当作自增列（Value.absent），必须绕开。
                  cardId: Value<int>(row.cardId),
                  cardJson: Value<String>(row.cardJson),
                  logJson: Value<String>(row.logJson),
                  updatedAt: Value<int>(row.updatedAt),
                ))
            .toList(growable: false),
      );
    });
  }

  @override
  Future<FSRSConfig?> load() async {
    final List<FsrsCard> rows = await (db.select(db.fsrsCards)
          ..orderBy(<OrderingTerm Function(FsrsCards)>[
            (FsrsCards t) => OrderingTerm(expression: t.cardId),
          ]))
        .get();
    final String? rawMeta = await _getMeta('config_meta');
    if (rows.isEmpty && rawMeta == null) return null;

    Map<String, dynamic> meta;
    if (rawMeta == null) {
      // 只可能在手工改库后出现：保留卡片，配置项回退到「已启用」的默认值。
      logger.warning('缺少 config_meta，按默认配置还原 ${rows.length} 张卡片');
      meta = fsrsConfigMeta(FSRSConfig(enabled: true));
    } else {
      meta = jsonDecode(rawMeta) as Map<String, dynamic>;
    }
    return fsrsConfigFromRows(
      meta,
      rows
          .map((FsrsCard row) => FsrsCardRow(
                cardId: row.cardId,
                cardJson: row.cardJson,
                logJson: row.logJson,
                updatedAt: row.updatedAt,
              ))
          .toList(growable: false),
    );
  }

  @override
  void save(FSRSConfig config) {
    _pending = config; // 只保留最新快照
    if (_scheduled) return;
    _scheduled = true;
    _enqueue(_drain);
  }

  Future<void> _drain() async {
    _scheduled = false;
    final FSRSConfig? config = _pending;
    _pending = null;
    if (config == null) return;
    try {
      await _writeAll(config);
    } catch (e) {
      // 写失败时保留快照（若期间没有更新的快照），让下一次 flush 重试。
      _pending ??= config;
      rethrow;
    }
  }

  /// 整表覆盖（单事务）：卡片行全量替换 + 配置项更新。
  Future<void> _writeAll(FSRSConfig config) async {
    final List<FsrsCardRow> rows =
        fsrsRowsFromConfig(config, updatedAt: _now());
    final String metaJson = jsonEncode(fsrsConfigMeta(config));
    await db.transaction(() async {
      await db.delete(db.fsrsCards).go();
      if (rows.isNotEmpty) await _insertRows(rows);
      await _putMeta('config_meta', metaJson);
    });
  }

  @override
  Future<void> flush() async {
    if (_pending != null && !_scheduled) {
      _scheduled = true;
      _enqueue(_drain);
    }
    await _tail;
  }

  /// 行级单事务重映射（按 `card_id` 重写 JSON 内的 id）。
  ///
  /// 注意：`FSRS.remapWordIds` 走的是「内存权威 → [save] 整表重写」，
  /// 因为 drift 的落盘有防抖，行级重映射可能看不到最后 400ms 内的内存改动。
  /// 本方法供需要直接操作行的场景与测试使用。
  @override
  Future<void> remapWordIds(Map<int, int> oldToNew) => _enqueue(() async {
        await db.transaction(() async {
          final List<FsrsCard> rows = await db.select(db.fsrsCards).get();
          final List<FsrsCardRow> remapped = <FsrsCardRow>[];
          int dropped = 0;
          for (final FsrsCard row in rows) {
            final Map<String, dynamic> card =
                jsonDecode(row.cardJson) as Map<String, dynamic>;
            final int? neu = oldToNew[card['cardId'] as int];
            if (neu == null) {
              dropped++;
              continue;
            }
            card['cardId'] = neu;
            final Map<String, dynamic> log =
                jsonDecode(row.logJson) as Map<String, dynamic>;
            log['cardId'] = neu;
            remapped.add(FsrsCardRow(
              cardId: neu,
              cardJson: jsonEncode(card),
              logJson: jsonEncode(log),
              updatedAt: row.updatedAt,
            ));
          }
          await db.delete(db.fsrsCards).go();
          if (remapped.isNotEmpty) await _insertRows(remapped);
          logger.info('SQLite 行级重映射: 保留 ${remapped.length} 张，丢弃 $dropped 张');
        });
      });

  @override
  Future<void> clear() {
    _pending = null;
    return _enqueue(() async {
      await db.delete(db.fsrsCards).go();
    });
  }

  /// 备份恢复/降级重灌：单事务内全量覆盖（幂等）。
  @override
  Future<void> importLegacy(String json) {
    final FSRSConfig config = fsrsConfigFromJson(json);
    final List<FsrsCardRow> rows =
        fsrsRowsFromConfig(config, updatedAt: _now());
    final String metaJson = jsonEncode(fsrsConfigMeta(config));
    _pending = null; // 丢弃旧内存快照，避免随后覆盖刚恢复的数据
    return _enqueue(() async {
      await db.transaction(() async {
        await db.delete(db.fsrsCards).go();
        if (rows.isNotEmpty) await _insertRows(rows);
        await _putMeta('config_meta', metaJson);
        await _putMeta('legacy_imported', '1');
        // 记下这次恢复的内容：下次启动不会把它当成「外部写入」再导一遍。
        await _putMeta('legacy_snapshot', json);
      });
      logger.info('已从备份导入 ${rows.length} 张卡片到 SQLite');
    });
  }

  @override
  Future<void> noteLegacySnapshot(String json) => _enqueue(() async {
        await _putMeta('legacy_snapshot', json);
      });

  @override
  String? hotKv(String key) => _hotCache[key];

  @override
  Future<void> setHotKv(String key, String? value) {
    if (value == null || value.isEmpty) {
      _hotCache.remove(key);
    } else {
      _hotCache[key] = value;
    }
    return _enqueue(() async {
      if (value == null || value.isEmpty) {
        await (db.delete(db.hotKv)
              ..where((HotKv t) => t.key.equals(key)))
            .go();
      } else {
        await _putHotKv(key, value);
      }
    });
  }

  @override
  Map<String, String> hotKvSnapshot() => Map<String, String>.of(_hotCache);

  @override
  Future<void> close() async {
    await flush();
    await db.close();
  }
}
