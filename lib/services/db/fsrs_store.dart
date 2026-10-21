// FSRS 卡片数据的持久化抽象。
//
// 背景：`shared_preferences` 在原生端每次 `setString` 都会重写整个偏好文件
// （其中还包含 2~6MB 的 `wordData`），所以「每答一题写一次 fsrsData」的真正代价
// 不是序列化卡片，而是整份偏好文件的重复落盘。
//
// 因此原生平台把**卡片数据**（以及少量高频键）改由 SQLite（drift）承载；
// Web 与所有兜底/测试路径仍使用原来的 JSON 字符串（`fsrsData`）。

import 'dart:convert';

import 'package:fsrs/fsrs.dart' show Rating, ReviewLog;
import 'package:logging/logging.dart';

import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRSConfig;

/// 卡片行：一行一张卡，卡与复习日志同存。
///
/// 刻意**不把** fsrs 包的字段拆成列，避免 `fsrs` 升级时被迫做 schema 迁移；
/// 行内直接保存 `Card.toMap()` / `ReviewLog.toMap()` 的 JSON 文本。
class FsrsCardRow {
  final int cardId;
  final String cardJson;
  final String logJson;
  final int updatedAt;

  const FsrsCardRow({
    required this.cardId,
    required this.cardJson,
    required this.logJson,
    required this.updatedAt,
  });

  @override
  String toString() => 'FsrsCardRow($cardId)';
}

/// 卡片与日志缺失时的兜底日志（旧数据里 cards 比 reviewLog 长时会出现）。
/// 使用固定时间戳而非 `DateTime.now()`，保证同一份数据反复序列化结果稳定。
ReviewLog _fallbackLog(int cardId) => ReviewLog(
      cardId: cardId,
      rating: Rating.good,
      reviewDateTime: DateTime.fromMillisecondsSinceEpoch(0),
    );

/// 把配置拆成「卡片行 + 配置元信息（不含 cards/reviewLog）」。
///
/// 导出/写盘时按 [FSRSConfig.cards] 的顺序产出，天然保持旧版
/// 「`cards[i]` 与 `reviewLog[i]` 位置对齐」的契约。
List<FsrsCardRow> fsrsRowsFromConfig(FSRSConfig config, {required int updatedAt}) {
  final List<FsrsCardRow> rows = <FsrsCardRow>[];
  for (int i = 0; i < config.cards.length; i++) {
    final int cardId = config.cards[i].cardId;
    final ReviewLog log = i < config.reviewLogs.length
        ? config.reviewLogs[i]
        : _fallbackLog(cardId);
    rows.add(FsrsCardRow(
      cardId: cardId,
      cardJson: jsonEncode(config.cards[i].toMap()),
      logJson: jsonEncode(log.toMap()),
      updatedAt: updatedAt,
    ));
  }
  return rows;
}

/// 配置元信息（`FSRSConfig.toMap()` 去掉卡片与日志）。
Map<String, dynamic> fsrsConfigMeta(FSRSConfig config) {
  final Map<String, dynamic> map = config.toMap();
  map.remove('cards');
  map.remove('reviewLog');
  return map;
}

/// 由「配置元信息 + 按 card_id 排序的卡片行」还原 [FSRSConfig]。
///
/// 走的是与旧 JSON 完全相同的反序列化入口（[FSRSConfig.buildFromMap]），
/// 因此逐字段（含 `enabled` / 调度器参数 / 列表顺序）与旧版等价。
FSRSConfig fsrsConfigFromRows(Map<String, dynamic> meta, List<FsrsCardRow> rows) {
  final Map<String, dynamic> map = Map<String, dynamic>.of(meta);
  map['cards'] = <dynamic>[
    for (final FsrsCardRow row in rows) jsonDecode(row.cardJson),
  ];
  map['reviewLog'] = <dynamic>[
    for (final FsrsCardRow row in rows) jsonDecode(row.logJson),
  ];
  return FSRSConfig.buildFromMap(map);
}

/// 旧版 `fsrsData` JSON → [FSRSConfig]。
FSRSConfig fsrsConfigFromJson(String json) =>
    FSRSConfig.buildFromMap(jsonDecode(json) as Map<String, dynamic>);

/// [FSRSConfig] → 旧版 `fsrsData` JSON（备份/降级快照用，格式必须与旧版一致）。
String fsrsConfigToJson(FSRSConfig config) => jsonEncode(config.toMap());

/// FSRS 卡片数据的存储后端。
abstract class FsrsStore {
  final Logger logger = Logger('FsrsStore');

  /// 打开存储。drift 实现会在此完成建表与首启迁移（幂等）。
  ///
  /// [legacyJson] 为旧版 `fsrsData` 内容，[legacyHotKv] 为需要迁移的高频键。
  Future<void> open({String? legacyJson, Map<String, String>? legacyHotKv});

  /// 读取配置；无任何数据时返回 null。
  Future<FSRSConfig?> load();

  /// 异步入队保存（不阻塞调用方）。实现需在调用瞬间对 [config] 做快照。
  void save(FSRSConfig config);

  /// 等待已入队的写入全部落盘。
  Future<void> flush();

  /// 按 `old→new` 映射重建卡片行（drift：单事务）。
  ///
  /// JSON 后端是空操作：它的权威副本就是内存中的 `FSRS.config`，
  /// 由 [save] 统一写回。
  Future<void> remapWordIds(Map<int, int> oldToNew);

  /// 删除全部卡片行（不改变配置项）。
  Future<void> clear();

  /// 备份恢复/降级重灌：用旧版 `fsrsData` JSON 在单事务内全量覆盖（幂等）。
  Future<void> importLegacy(String json);

  /// 读取高频键（同步，来自内存缓存）。
  String? hotKv(String key);

  /// 写入/删除高频键（异步入队）。
  Future<void> setHotKv(String key, String? value);

  /// 当前全部高频键的缓存快照。
  Map<String, String> hotKvSnapshot();

  /// 记录「最后一次写入 `fsrsData` 的内容摘要」。
  ///
  /// SQLite 后端用它区分「偏好文件里的 fsrsData 是我们自己写的」还是
  /// 「别的途径（旧版本、手工、备份）写的」：后者应当被导入，前者不导入，
  /// 以免用一次会话前的陈旧快照覆盖数据库里更新的卡片。
  Future<void> noteLegacySnapshot(String json);

  /// 该后端是否为 SQLite（drift 为 true）。
  ///
  /// 用于区分「内存副本即权威」（drift）与「`fsrsData` 即权威」（JSON）：
  /// 前者需要额外写降级快照、导出时覆盖 `fsrsData`、备份恢复后重灌。
  bool get usesSqlite => false;

  Future<void> close();
}

/// 纯 JSON 实现：读写 `shared_preferences` 里的 `fsrsData`。
///
/// 作为 Web 端的唯一实现、原生端的兜底，以及全部单元测试的默认后端
/// （测试因此完全不需要 SQLite）。
class JsonFsrsStore implements FsrsStore {
  @override
  final Logger logger = Logger('JsonFsrsStore');

  Future<void>? _write;

  @override
  Future<void> open({String? legacyJson, Map<String, String>? legacyHotKv}) async {
    // 无需打开：`shared_preferences` 由 AppData 统一初始化。
  }

  /// 同步读取（供 [FSRS.init] 的同步兜底路径使用）。
  FSRSConfig? loadSync() {
    final String? raw = AppData().storage.getString('fsrsData');
    if (raw == null || raw.isEmpty) return null;
    return fsrsConfigFromJson(raw);
  }

  @override
  Future<FSRSConfig?> load() async => loadSync();

  @override
  void save(FSRSConfig config) {
    _write = AppData().storage.setString('fsrsData', fsrsConfigToJson(config));
  }

  @override
  Future<void> flush() async {
    final Future<void>? pending = _write;
    _write = null;
    if (pending != null) await pending;
  }

  @override
  Future<void> remapWordIds(Map<int, int> oldToNew) async {
    // 空操作：见 [FsrsStore.remapWordIds] 的说明。
  }

  @override
  Future<void> clear() async {
    // 空操作：JSON 后端的清空同样由 `save(FSRSConfig(cards: [], reviewLogs: []))` 完成。
  }

  @override
  Future<void> importLegacy(String json) async {
    _write = AppData().storage.setString('fsrsData', json);
  }

  @override
  Future<void> noteLegacySnapshot(String json) async {
    // JSON 后端的 fsrsData 本身就是权威副本，无需额外记录摘要。
  }

  @override
  String? hotKv(String key) => AppData().storage.getString(key);

  @override
  Future<void> setHotKv(String key, String? value) async {
    AppData().storage.setString(key, value ?? '');
  }

  @override
  Map<String, String> hotKvSnapshot() => <String, String>{};

  @override
  bool get usesSqlite => false;

  @override
  Future<void> close() => flush();
}
