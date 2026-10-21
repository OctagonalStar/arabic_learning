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
import 'package:fsrs/fsrs.dart' show Card, ReviewLog;

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
///
/// 落盘采用**增量写**：内存里维护一份「已落库快照」（[_writtenCardJson] 等），
/// 每次只对新增/内容变化的行做 `insertOnConflictUpdate`、只删除已消失的行。
/// 答题时一次防抖写通常只产生 1~2 条语句，而不是重写整张表。
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

  // ---------------------------------------------------------------------------
  // 已落库快照（与数据库内容保持一致，仅在事务成功后才更新）
  // ---------------------------------------------------------------------------

  /// cardId → 已落库的 `card_json`。用于脏检查。
  final Map<int, String> _writtenCardJson = <int, String>{};

  /// cardId → 已落库的 `log_json`。
  ///
  /// 单独跟踪是因为「只换复习日志、卡片字段不变」在 `setAlignedCards` 里是可能的，
  /// 只比 `card_json` 会漏写。
  final Map<int, String> _writtenLogJson = <int, String>{};

  /// cardId → 已落库的 [Card] / [ReviewLog] 对象引用。
  ///
  /// 脏检查的**快路径**：`Card`/`ReviewLog` 都实现了全字段 `==`，直接比较对象
  /// 比对 2500 张卡重新 `jsonEncode` 便宜两个数量级（实测 0.3ms vs 8.5ms）。
  /// 只有对象不相等时才去序列化那一行，因此答题时一次写只序列化 1 张卡。
  /// 对象相同但 JSON 可能不同（理论上不会）的情形由 [_writtenCardJson] 兜底，
  /// 但为避免两条路径不一致，这里对「对象相等」直接信任。
  final Map<int, Card> _writtenCard = <int, Card>{};
  final Map<int, ReviewLog> _writtenLog = <int, ReviewLog>{};

  /// 已落库的 cardId，**按升序**。删除时遍历它即可找出「库里多出来的行」。
  final List<int> _writtenOrder = <int>[];

  /// 已落库的 `config_meta` JSON，用于跳过无变化的配置项写入。
  String? _writtenMetaJson;

  /// 增量写退化为全表替换的阈值（变化行数 / 总行数）。
  ///
  /// 逐行 upsert 的代价与变化行数成正比，但每行都是一条独立语句；当变化比例
  /// 很高时（首次导入、重置词库、大规模重映射），几千条语句明显慢于
  /// 「删全表 + 一次批量插入」。0.6 取自 2500 张卡上的实测拐点：低于该比例时
  /// 增量写稳定更快，高于它时全表替换更快且 WAL 增长更可控。
  static const double _fullRewriteRatio = 0.6;

  /// 删除语句里 `IN (...)` 的分块大小，远低于 SQLite 的变量上限。
  static const int _deleteChunkSize = 500;

  // 诊断计数（仅测试读取，用于断言「只写了 1 行」而不是整表）。
  int _debugLastUpsertedRows = 0;
  int _debugLastDeletedRows = 0;
  bool _debugLastFullRewrite = false;
  int _debugLastWriteMicros = 0;

  /// 上一次落盘实际 upsert 的行数（全表替换时等于总行数）。诊断用。
  @override
  int get debugLastUpsertedRows => _debugLastUpsertedRows;

  /// 上一次落盘删除的行数。诊断用。
  @override
  int get debugLastDeletedRows => _debugLastDeletedRows;

  /// 上一次落盘是否走了「全表替换」。诊断用。
  @override
  bool get debugLastFullRewrite => _debugLastFullRewrite;

  /// 上一次落盘的耗时（微秒，含事务提交）。诊断用。
  @override
  int get debugLastWriteMicros => _debugLastWriteMicros;

  /// 当前「已落库快照」的行数。诊断用。
  @override
  int get debugSnapshotSize => _writtenCardJson.length;

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
    // 迁移可能改写了卡片表，必须按库里的实际内容重建「已落库快照」。
    await _refreshWrittenSnapshot();
    await _loadHotCache();
  }

  /// 从数据库读取当前全部卡片行，重建 [_writtenCardJson] / [_writtenLogJson] /
  /// [_writtenOrder] / [_writtenMetaJson]。
  ///
  /// 只在 open / 外部直接改库之后调用；正常写入路径由 [_writeAll] 自己维护。
  /// 对象引用（[_writtenCard] / [_writtenLog]）会按 JSON 反序列化重建：这样
  /// 「库里的值」与「内存里的对象」用同一套 `==` 语义比较，避免手工改库后
  /// 快照与库不一致。
  Future<void> _refreshWrittenSnapshot() async {
    final List<FsrsCard> rows = await (db.select(db.fsrsCards)
          ..orderBy(<OrderingTerm Function(FsrsCards)>[
            (FsrsCards t) => OrderingTerm(expression: t.cardId),
          ]))
        .get();
    _clearSnapshot();
    for (final FsrsCard row in rows) {
      _writtenCardJson[row.cardId] = row.cardJson;
      _writtenLogJson[row.cardId] = row.logJson;
      _writtenCard[row.cardId] =
          Card.fromMap(jsonDecode(row.cardJson) as Map<String, dynamic>);
      _writtenLog[row.cardId] =
          ReviewLog.fromMap(jsonDecode(row.logJson) as Map<String, dynamic>);
      _writtenOrder.add(row.cardId); // 已按 card_id 升序
    }
    _writtenMetaJson = await _getMeta('config_meta');
  }

  void _clearSnapshot() {
    _writtenCardJson.clear();
    _writtenLogJson.clear();
    _writtenCard.clear();
    _writtenLog.clear();
    _writtenOrder.clear();
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
    if (rows.isEmpty && rawMeta == null) {
      // 空库：快照也清空，避免残留上一份数据导致后续误判。
      _clearSnapshot();
      _writtenMetaJson = null;
      return null;
    }

    // load 已经读到全表，顺手重建快照：若库被外部改过（手工/回滚），
    // 下一次增量写的脏检查就有正确基线。
    _clearSnapshot();
    for (final FsrsCard row in rows) {
      _writtenCardJson[row.cardId] = row.cardJson;
      _writtenLogJson[row.cardId] = row.logJson;
      _writtenCard[row.cardId] =
          Card.fromMap(jsonDecode(row.cardJson) as Map<String, dynamic>);
      _writtenLog[row.cardId] =
          ReviewLog.fromMap(jsonDecode(row.logJson) as Map<String, dynamic>);
      _writtenOrder.add(row.cardId);
    }
    _writtenMetaJson = rawMeta;

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
      // 写失败：清掉诊断计数（否则会残留上一次成功写入的数字），
      // 并保留快照（若期间没有更新的快照），让下一次 flush 重试。
      _debugLastUpsertedRows = 0;
      _debugLastDeletedRows = 0;
      _debugLastFullRewrite = false;
      _pending ??= config;
      rethrow;
    }
  }

  /// 把配置落库（单事务）：增量更新卡片行 + 配置项。
  ///
  /// 变化行数超过 [_fullRewriteRatio] 时退化为「删全表 + 批量插入」，
  /// 否则逐行 upsert / 删除。
  ///
  /// 脏检查用 [Card]/[ReviewLog] 的对象相等做快路径（全字段 `==`，不序列化），
  /// 只有确实变化的行才生成 JSON —— 这是「答题时一次写只序列化 1 张卡」的关键。
  ///
  /// 事务成功后才更新内存快照，失败时快照保持与库一致（不会半更新）。
  Future<void> _writeAll(FSRSConfig config) async {
    final Stopwatch watch = Stopwatch()..start();
    final String metaJson = jsonEncode(fsrsConfigMeta(config));
    final int updatedAt = _now();

    // 脏检查 + 只为变化行生成 JSON。
    final List<FsrsCardRow> upserts = <FsrsCardRow>[];
    final Set<int> nextIds = <int>{};
    // 落盘成功后要写入快照的对象（未变化的直接复用旧引用，避免再建对象）。
    final Map<int, Card> nextCards = <int, Card>{};
    final Map<int, ReviewLog> nextLogs = <int, ReviewLog>{};
    final Map<int, String> nextCardJson = <int, String>{};
    final Map<int, String> nextLogJson = <int, String>{};

    for (int i = 0; i < config.cards.length; i++) {
      final Card card = config.cards[i];
      final ReviewLog log = i < config.reviewLogs.length
          ? config.reviewLogs[i]
          : fallbackReviewLog(card.cardId);
      final int cardId = card.cardId;
      nextIds.add(cardId);

      final bool cardSame = _writtenCard[cardId] == card;
      final bool logSame = _writtenLog[cardId] == log;
      if (cardSame && logSame) {
        // 完全没变：沿用旧快照（含 JSON），不重新序列化。
        nextCards[cardId] = _writtenCard[cardId]!;
        nextLogs[cardId] = _writtenLog[cardId]!;
        nextCardJson[cardId] = _writtenCardJson[cardId]!;
        nextLogJson[cardId] = _writtenLogJson[cardId]!;
        continue;
      }

      final String cardJson = cardSame
          ? _writtenCardJson[cardId]!
          : jsonEncode(card.toMap());
      final String logJson = logSame
          ? _writtenLogJson[cardId]!
          : jsonEncode(log.toMap());
      nextCards[cardId] = card;
      nextLogs[cardId] = log;
      nextCardJson[cardId] = cardJson;
      nextLogJson[cardId] = logJson;
      upserts.add(FsrsCardRow(
        cardId: cardId,
        cardJson: cardJson,
        logJson: logJson,
        updatedAt: updatedAt,
      ));
    }

    // 库里存在、新配置里已不存在的行。
    final List<int> deletes = <int>[
      for (final int id in _writtenOrder)
        if (!nextIds.contains(id)) id,
    ];

    final int total = nextIds.length > _writtenOrder.length
        ? nextIds.length
        : _writtenOrder.length;
    final bool fullRewrite = total > 0 &&
        (upserts.length + deletes.length) > total * _fullRewriteRatio;

    // 完全没有变化（重复 save 同一份 config）：连事务都不用开。
    if (upserts.isEmpty && deletes.isEmpty && _writtenMetaJson == metaJson) {
      watch.stop();
      _debugLastUpsertedRows = 0;
      _debugLastDeletedRows = 0;
      _debugLastFullRewrite = false;
      _debugLastWriteMicros = watch.elapsedMicroseconds;
      return;
    }

    if (fullRewrite) {
      await _replaceAll(
        allIds: nextIds.toList(growable: false),
        nextCardJson: nextCardJson,
        nextLogJson: nextLogJson,
        metaJson: metaJson,
        updatedAt: updatedAt,
      );
    } else {
      await _writeDelta(upserts: upserts, deletes: deletes, metaJson: metaJson);
    }

    // 事务已提交：现在才更新内存快照。
    _writtenCard
      ..clear()
      ..addAll(nextCards);
    _writtenLog
      ..clear()
      ..addAll(nextLogs);
    _writtenCardJson
      ..clear()
      ..addAll(nextCardJson);
    _writtenLogJson
      ..clear()
      ..addAll(nextLogJson);
    _writtenOrder
      ..clear()
      ..addAll(nextIds.toList(growable: false)..sort());
    _writtenMetaJson = metaJson;

    watch.stop();
    _debugLastUpsertedRows = fullRewrite ? nextIds.length : upserts.length;
    _debugLastDeletedRows = fullRewrite ? 0 : deletes.length;
    _debugLastFullRewrite = fullRewrite;
    _debugLastWriteMicros = watch.elapsedMicroseconds;
  }

  /// 全表替换（单事务）。
  ///
  /// 行内容全部来自 [nextCardJson] / [nextLogJson]（已落库快照 + 本次变化行），
  /// 因此不必为「全表重写」重新序列化未变化的卡片。
  Future<void> _replaceAll({
    required List<int> allIds,
    required Map<int, String> nextCardJson,
    required Map<int, String> nextLogJson,
    required String metaJson,
    required int updatedAt,
  }) async {
    final List<FsrsCardRow> rows = <FsrsCardRow>[
      for (final int id in allIds)
        FsrsCardRow(
          cardId: id,
          cardJson: nextCardJson[id]!,
          logJson: nextLogJson[id]!,
          updatedAt: updatedAt,
        ),
    ];
    await db.transaction(() async {
      await db.delete(db.fsrsCards).go();
      if (rows.isNotEmpty) await _insertRows(rows);
      if (_writtenMetaJson != metaJson) await _putMeta('config_meta', metaJson);
    });
  }

  /// 增量写（单事务）：只 upsert 变化行、只删除消失行。
  Future<void> _writeDelta({
    required List<FsrsCardRow> upserts,
    required List<int> deletes,
    required String metaJson,
  }) async {
    await db.transaction(() async {
      if (upserts.isNotEmpty) {
        await db.batch((Batch batch) {
          batch.insertAllOnConflictUpdate(
            db.fsrsCards,
            upserts
                .map((FsrsCardRow row) => FsrsCardsCompanion(
                      cardId: Value<int>(row.cardId),
                      cardJson: Value<String>(row.cardJson),
                      logJson: Value<String>(row.logJson),
                      updatedAt: Value<int>(row.updatedAt),
                    ))
                .toList(growable: false),
          );
        });
      }
      for (int i = 0; i < deletes.length; i += _deleteChunkSize) {
        final int end = i + _deleteChunkSize < deletes.length
            ? i + _deleteChunkSize
            : deletes.length;
        final List<int> chunk = deletes.sublist(i, end);
        await (db.delete(db.fsrsCards)
              ..where((FsrsCards t) => t.cardId.isIn(chunk)))
            .go();
      }
      if (_writtenMetaJson != metaJson) await _putMeta('config_meta', metaJson);
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
        // 行被整体重写（card_id 全变），快照必须按库里的实际内容重建。
        await _refreshWrittenSnapshot();
      });

  @override
  Future<void> clear() {
    _pending = null;
    return _enqueue(() async {
      await db.delete(db.fsrsCards).go();
      // 卡片行已全部删除：快照同步清空（配置项保持不变）。
      _clearSnapshot();
    });
  }

  /// 备份恢复/降级重灌：单事务内全量覆盖（幂等）。
  @override
  Future<void> importLegacy(String json) {
    final FSRSConfig config = fsrsConfigFromJson(json);
    final int updatedAt = _now();
    final List<FsrsCardRow> rows =
        fsrsRowsFromConfig(config, updatedAt: updatedAt);
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
      // 库被整体替换：快照按导入的内容重建（不查库，省一次往返）。
      _clearSnapshot();
      for (int i = 0; i < config.cards.length; i++) {
        final Card card = config.cards[i];
        final ReviewLog log = i < config.reviewLogs.length
            ? config.reviewLogs[i]
            : fallbackReviewLog(card.cardId);
        final int cardId = card.cardId;
        _writtenCard[cardId] = card;
        _writtenLog[cardId] = log;
        _writtenCardJson[cardId] = rows[i].cardJson;
        _writtenLogJson[cardId] = rows[i].logJson;
        _writtenOrder.add(cardId);
      }
      _writtenOrder.sort();
      _writtenMetaJson = metaJson;
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
