// drift（SQLite）卡片后端的测试。
//
// 这里直接构造 `FsrsDatabase(NativeDatabase.memory()/file)`，不经过
// `openDriftStore()`（后者在 `flutter test` 下刻意返回 null，让既有测试全部
// 走 JSON 后端、行为与改造前一致，也不产生跨测试文件的库文件污染）。
//
// 覆盖：首启迁移幂等性、行级重映射事务、导入导出与旧 JSON 完全一致（golden）、
// 配置项与卡片顺序还原、hot_kv 写穿。

import 'dart:convert';
import 'dart:io';

import 'package:arabic_learning/services/db/fsrs_drift_store.dart';
import 'package:arabic_learning/services/db/fsrs_store.dart';
import 'package:arabic_learning/services/fsrs.dart' show FSRSConfig;
import 'package:drift/drift.dart' show QueryExecutor, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';

import '../helpers/test_env.dart' show testDbDir;

/// 固定样例：3 张卡（含中间缺口），日志与卡片一一对齐。
FSRSConfig _sampleConfig() => FSRSConfig(
      enabled: true,
      scheduler: Scheduler(desiredRetention: 0.85),
      cards: <Card>[
        Card(
          cardId: 0,
          state: State.review,
          step: 0,
          stability: 12.5,
          difficulty: 5.25,
          due: DateTime.utc(2026, 3, 1, 8),
          lastReview: DateTime.utc(2026, 2, 1, 8),
        ),
        Card(
          cardId: 2,
          state: State.learning,
          step: 1,
          due: DateTime.utc(2026, 2, 2, 9),
        ),
        Card(
          cardId: 7,
          state: State.relearning,
          step: 0,
          stability: 1.25,
          difficulty: 9.5,
          due: DateTime.utc(2026, 2, 3, 10),
          lastReview: DateTime.utc(2026, 2, 2, 10),
        ),
      ],
      reviewLogs: <ReviewLog>[
        ReviewLog(
          cardId: 0,
          rating: Rating.easy,
          reviewDateTime: DateTime.utc(2026, 2, 1, 8),
          reviewDuration: 1200,
        ),
        ReviewLog(
          cardId: 2,
          rating: Rating.good,
          reviewDateTime: DateTime.utc(2026, 2, 2, 9),
        ),
        ReviewLog(
          cardId: 7,
          rating: Rating.again,
          reviewDateTime: DateTime.utc(2026, 2, 2, 10),
          reviewDuration: 9000,
        ),
      ],
      desiredRetention: 0.85,
      easyDuration: 2500,
      goodDuration: 5000,
      preferSimilar: true,
      selfEvaluate: false,
      pushAmount: 4,
      reinforceMemory: true,
      pushCategories: const <String>['四级', '六级'],
      reviewQuestionSections: const <int>[1, 3],
    );

/// 打开一个 store。传 [file] 可在关闭后重新打开（验证持久化）。
Future<DriftFsrsStore> _openStore({
  QueryExecutor? executor,
  File? file,
  String? legacyJson,
  Map<String, String>? legacyHotKv,
}) async {
  final DriftFsrsStore store = DriftFsrsStore(
    FsrsDatabase(executor ?? NativeDatabase(file ?? File(_tempPath()))),
  );
  await store.open(legacyJson: legacyJson, legacyHotKv: legacyHotKv);
  return store;
}

/// 测试库文件统一放在 `/tmp/opencode`（已批准的临时区），避免写入仓库外的
/// 用户目录。直接给 [NativeDatabase] 传路径，不经过 path_provider。
String _tempPath() {
  final Directory dir = Directory(testDbDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return '$testDbDir/fsrs_${DateTime.now().microsecondsSinceEpoch}.sqlite';
}

/// 删除库文件及其 WAL/SHM 伴生文件。
void _removeDb(String path) {
  for (final String suffix in <String>['', '-wal', '-shm']) {
    final File f = File('$path$suffix');
    if (f.existsSync()) f.deleteSync();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // 测试里会为每个用例新建数据库类实例，关掉这条噪音警告。
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  tearDownAll(() {
    // drift 的库在后台 isolate 里打开/关闭，单用例 tearDown 里删文件可能被
    // 随后的 WAL checkpoint 重建；全部用例结束后统一清掉整个测试目录。
    final Directory dir = Directory(testDbDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('首启迁移', () {
    test('从旧 fsrsData 导入卡片与配置项，且与旧 JSON 逐字段一致', () async {
      final String legacyJson = fsrsConfigToJson(_sampleConfig());

      final DriftFsrsStore store =
          await _openStore(legacyJson: legacyJson);
      addTearDown(store.close);

      final FSRSConfig? loaded = await store.load();
      expect(loaded, isNotNull);
      // golden：导出格式与旧版 `fsrsData` 完全相同（含 cards/reviewLog 顺序）。
      expect(fsrsConfigToJson(loaded!), legacyJson);
      expect(loaded.enabled, isTrue);
      expect(loaded.desiredRetention, 0.85);
      expect(loaded.scheduler!.desiredRetention, 0.85);
      expect(loaded.cards.map((Card c) => c.cardId).toList(), <int>[0, 2, 7]);
      expect(
        loaded.reviewLogs.map((ReviewLog l) => l.cardId).toList(),
        <int>[0, 2, 7],
        reason: 'reviewLogs 必须与 cards 位置对齐',
      );
      expect(loaded.reviewLogs[0].reviewDuration, 1200);
      expect(loaded.pushCategories, <String>['四级', '六级']);
      expect(loaded.reviewQuestionSections, <int>[1, 3]);
    });

    test('重复打开不会重复导入（legacy_imported 幂等）', () async {
      final String path = _tempPath();
      addTearDown(() => _removeDb(path));
      final String legacyJson = fsrsConfigToJson(_sampleConfig());

      final DriftFsrsStore first =
          await _openStore(file: File(path), legacyJson: legacyJson);
      expect((await first.load())!.cards.length, 3);

      // 改成只有 1 张卡的配置后关闭，再用同一份 legacyJson 重新打开：
      // 幂等标记已写，因此不会被旧数据重新灌满。
      first.save(FSRSConfig(
        enabled: true,
        scheduler: Scheduler(),
        cards: <Card>[Card(cardId: 5, state: State.learning)],
        reviewLogs: <ReviewLog>[
          ReviewLog(
            cardId: 5,
            rating: Rating.good,
            reviewDateTime: DateTime.utc(2026, 1, 1),
          ),
        ],
      ));
      await first.close();

      final DriftFsrsStore second =
          await _openStore(file: File(path), legacyJson: legacyJson);
      addTearDown(second.close);
      final FSRSConfig? loaded = await second.load();
      expect(loaded!.cards.map((Card c) => c.cardId).toList(), <int>[5]);
    });

    test('迁移旧高频键 pushSessionData 到 hot_kv', () async {
      final DriftFsrsStore store = await _openStore(
        legacyHotKv: <String, String>{'pushSessionData': '{"day":1}'},
      );
      addTearDown(store.close);
      expect(store.hotKv('pushSessionData'), '{"day":1}');
    });

    test('空库且无旧数据时 load 返回 null', () async {
      final DriftFsrsStore store = await _openStore();
      addTearDown(store.close);
      expect(await store.load(), isNull);
    });
  });

  group('读写', () {
    test('save → flush → load 往返一致，且按 card_id 排序', () async {
      final DriftFsrsStore store = await _openStore();
      addTearDown(store.close);

      // 故意乱序写入：读回时应按 card_id 升序，满足旧版位置对齐契约。
      store.save(FSRSConfig(
        enabled: true,
        scheduler: Scheduler(),
        cards: <Card>[
          Card(cardId: 9, state: State.learning),
          Card(cardId: 1, state: State.review),
          Card(cardId: 4, state: State.learning),
        ],
        reviewLogs: <ReviewLog>[
          ReviewLog(
            cardId: 9,
            rating: Rating.easy,
            reviewDateTime: DateTime.utc(2026, 1, 9),
          ),
          ReviewLog(
            cardId: 1,
            rating: Rating.good,
            reviewDateTime: DateTime.utc(2026, 1, 1),
          ),
          ReviewLog(
            cardId: 4,
            rating: Rating.hard,
            reviewDateTime: DateTime.utc(2026, 1, 4),
          ),
        ],
      ));
      await store.flush();

      final FSRSConfig? loaded = await store.load();
      expect(loaded!.cards.map((Card c) => c.cardId).toList(), <int>[1, 4, 9]);
      expect(loaded.reviewLogs.map((ReviewLog l) => l.cardId).toList(),
          <int>[1, 4, 9]);
      // 日志随卡片一起迁移（不是按原下标错位配对）。
      expect(loaded.reviewLogs[0].rating, Rating.good);
      expect(loaded.reviewLogs[2].rating, Rating.easy);
    });

    test('连续 save 只落最新快照', () async {
      final DriftFsrsStore store = await _openStore();
      addTearDown(store.close);

      for (int i = 0; i < 5; i++) {
        store.save(FSRSConfig(
          enabled: true,
          scheduler: Scheduler(),
          cards: <Card>[
            for (int j = 0; j <= i; j++) Card(cardId: j, state: State.learning),
          ],
          reviewLogs: <ReviewLog>[
            for (int j = 0; j <= i; j++)
              ReviewLog(
                cardId: j,
                rating: Rating.good,
                reviewDateTime: DateTime.utc(2026, 1, 1),
              ),
          ],
        ));
      }
      await store.flush();
      expect((await store.load())!.cards.length, 5);
    });

    test('clear 只清卡片，保留配置项', () async {
      final DriftFsrsStore store = await _openStore();
      addTearDown(store.close);

      store.save(_sampleConfig());
      await store.flush();
      await store.clear();

      final FSRSConfig? loaded = await store.load();
      expect(loaded!.cards, isEmpty);
      expect(loaded.enabled, isTrue);
      expect(loaded.pushAmount, 4);
    });
  });

  group('remapWordIds（单事务行级重写）', () {
    test('丢弃不在映射中的卡片并重写 cardId，保持对齐', () async {
      final DriftFsrsStore store = await _openStore();
      addTearDown(store.close);

      store.save(_sampleConfig());
      await store.flush();

      // 0→0 保留，2 丢弃，7→1
      await store.remapWordIds(<int, int>{0: 0, 7: 1});

      final FSRSConfig? loaded = await store.load();
      expect(loaded!.cards.map((Card c) => c.cardId).toList(), <int>[0, 1]);
      expect(loaded.reviewLogs.map((ReviewLog l) => l.cardId).toList(),
          <int>[0, 1]);
      expect(loaded.reviewLogs[1].rating, Rating.again,
          reason: '原 card_id=7 的日志随卡片一起改 id');
      expect(loaded.reviewLogs[1].reviewDuration, 9000);
      expect(loaded.cards[1].stability, 1.25);
    });
  });

  group('备份恢复（importLegacy）', () {
    test('全量覆盖且幂等，重复导入结果一致', () async {
      final DriftFsrsStore store = await _openStore();
      addTearDown(store.close);

      final String backup = fsrsConfigToJson(_sampleConfig());
      await store.importLegacy(backup);
      await store.importLegacy(backup);

      final FSRSConfig? loaded = await store.load();
      expect(fsrsConfigToJson(loaded!), backup);
    });

    test('恢复后的空卡片备份能覆盖掉库里的旧卡片', () async {
      final DriftFsrsStore store = await _openStore();
      addTearDown(store.close);

      store.save(_sampleConfig());
      await store.flush();

      final String empty =
          fsrsConfigToJson(FSRSConfig(enabled: true, scheduler: Scheduler()));
      await store.importLegacy(empty);

      final FSRSConfig? loaded = await store.load();
      expect(loaded!.cards, isEmpty, reason: '恢复空备份必须清空旧卡片');
    });
  });

  group('hot_kv', () {
    test('setHotKv 写穿缓存，flush 后可被重新加载', () async {
      final String path = _tempPath();
      addTearDown(() => _removeDb(path));
      final DriftFsrsStore store = await _openStore(file: File(path));

      await store.setHotKv('pushSessionData', '{"day":2}');
      expect(store.hotKv('pushSessionData'), '{"day":2}');
      expect(store.hotKvSnapshot(),
          <String, String>{'pushSessionData': '{"day":2}'});
      await store.close();

      final DriftFsrsStore reopened = await _openStore(file: File(path));
      addTearDown(reopened.close);
      expect(reopened.hotKv('pushSessionData'), '{"day":2}');

      // 传 null 表示删除。
      await reopened.setHotKv('pushSessionData', null);
      expect(reopened.hotKv('pushSessionData'), isNull);
      await reopened.flush();
      expect(reopened.hotKvSnapshot(), isEmpty);
    });
  });

  group('纯函数转换', () {
    test('fsrsRowsFromConfig 缺日志时补默认日志且不抛异常', () {
      final List<FsrsCardRow> rows = fsrsRowsFromConfig(
        FSRSConfig(
          enabled: true,
          scheduler: Scheduler(),
          cards: <Card>[
            Card(cardId: 0, state: State.learning),
            Card(cardId: 1, state: State.learning),
          ],
          reviewLogs: <ReviewLog>[
            ReviewLog(
              cardId: 0,
              rating: Rating.easy,
              reviewDateTime: DateTime.utc(2026, 1, 1),
            ),
          ],
        ),
        updatedAt: 1,
      );
      expect(rows.length, 2);
      final ReviewLog fallback =
          ReviewLog.fromMap(jsonDecode(rows[1].logJson) as Map<String, dynamic>);
      expect(fallback.cardId, 1);
      expect(fallback.rating, Rating.good);
    });

    test('fsrsConfigMeta 不含卡片与日志', () {
      final Map<String, dynamic> meta = fsrsConfigMeta(_sampleConfig());
      expect(meta.containsKey('cards'), isFalse);
      expect(meta.containsKey('reviewLog'), isFalse);
      expect(meta['enabled'], isTrue);
      expect(meta['pushAmount'], 4);
    });
  });
}
