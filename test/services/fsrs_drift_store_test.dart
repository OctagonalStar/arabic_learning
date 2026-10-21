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

/// 构造 [count] 张卡的配置（cardId = 0..count-1），用于增量写/基准测试。
FSRSConfig _bulkConfig(int count) => FSRSConfig(
      enabled: true,
      scheduler: Scheduler(),
      cards: <Card>[
        for (int i = 0; i < count; i++)
          Card(
            cardId: i,
            state: State.review,
            stability: 10.0 + i,
            difficulty: 5.0,
            due: DateTime.utc(2026, 3, 1),
            lastReview: DateTime.utc(2026, 2, 1),
          ),
      ],
      reviewLogs: <ReviewLog>[
        for (int i = 0; i < count; i++)
          ReviewLog(
            cardId: i,
            rating: Rating.good,
            reviewDateTime: DateTime.utc(2026, 2, 1),
            reviewDuration: 1500,
          ),
      ],
    );

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

  group('增量写（只改变化行）', () {
    test('首写全量，之后单卡变更只 upsert 1 行', () async {
      final DriftFsrsStore store = await _openStore();
      addTearDown(store.close);

      final FSRSConfig base = _bulkConfig(50);
      store.save(base);
      await store.flush();
      expect(store.debugLastUpsertedRows, 50, reason: '首写要落全部卡片');
      expect(store.debugLastFullRewrite, isTrue, reason: '空库首写走全表替换');
      expect(store.debugSnapshotSize, 50);

      // 只改动一张卡的 stability（模拟答对一题）。
      final List<Card> cards = List<Card>.of(base.cards);
      cards[7] = cards[7].copyWith(stability: 99.0);
      store.save(base.copyWith(cards: cards));
      await store.flush();

      expect(store.debugLastUpsertedRows, 1, reason: '只有第 7 张卡变了');
      expect(store.debugLastDeletedRows, 0);
      expect(store.debugLastFullRewrite, isFalse, reason: '不应退化为全表替换');
      // 内容确实写进去了。
      final FSRSConfig? reloaded = await store.load();
      expect(reloaded!.cards[7].stability, 99.0);
      expect(reloaded.cards.length, 50);
    });

    test('只换复习日志（卡片字段不变）也会写入', () async {
      final DriftFsrsStore store = await _openStore();
      addTearDown(store.close);

      final FSRSConfig base = _bulkConfig(10);
      store.save(base);
      await store.flush();

      // cards 完全不动，只把第 3 条日志的评分改掉。
      final List<ReviewLog> logs = List<ReviewLog>.of(base.reviewLogs);
      logs[3] = ReviewLog(
        cardId: 3,
        rating: Rating.again,
        reviewDateTime: DateTime.utc(2026, 5, 5),
      );
      store.save(base.copyWith(reviewLogs: logs));
      await store.flush();

      expect(store.debugLastUpsertedRows, 1, reason: 'log_json 变化也算脏');
      final FSRSConfig? reloaded = await store.load();
      expect(reloaded!.reviewLogs[3].rating, Rating.again);
    });

    test('删除卡片只删消失的行，不做全表替换', () async {
      final DriftFsrsStore store = await _openStore();
      addTearDown(store.close);

      final FSRSConfig base = _bulkConfig(20);
      store.save(base);
      await store.flush();

      // 去掉 cardId=5 与 cardId=15。
      final List<Card> cards = <Card>[
        for (final Card c in base.cards)
          if (c.cardId != 5 && c.cardId != 15) c,
      ];
      final List<ReviewLog> logs = <ReviewLog>[
        for (final ReviewLog l in base.reviewLogs)
          if (l.cardId != 5 && l.cardId != 15) l,
      ];
      store.save(base.copyWith(cards: cards, reviewLogs: logs));
      await store.flush();

      expect(store.debugLastUpsertedRows, 0, reason: '没有卡片内容变化');
      expect(store.debugLastDeletedRows, 2);
      expect(store.debugLastFullRewrite, isFalse);
      expect(store.debugSnapshotSize, 18);
      final FSRSConfig? reloaded = await store.load();
      expect(reloaded!.cards.map((Card c) => c.cardId).toList(),
          <int>[for (int i = 0; i < 20; i++) if (i != 5 && i != 15) i]);
    });

    test('变化行数超过 60% 时退化为全表替换', () async {
      final DriftFsrsStore store = await _openStore();
      addTearDown(store.close);

      final FSRSConfig base = _bulkConfig(10);
      store.save(base);
      await store.flush();

      // 改 7/10 = 70% > 60%。
      final List<Card> cards = <Card>[
        for (int i = 0; i < base.cards.length; i++)
          i < 7
              ? base.cards[i].copyWith(stability: 50.0 + i)
              : base.cards[i],
      ];
      store.save(base.copyWith(cards: cards));
      await store.flush();

      expect(store.debugLastFullRewrite, isTrue, reason: '超过阈值应退化为全表替换');
      expect(store.debugLastUpsertedRows, 10);
      final FSRSConfig? reloaded = await store.load();
      expect(reloaded!.cards[0].stability, 50.0);
    });

    test('重复保存同一份配置不产生任何写入', () async {
      final DriftFsrsStore store = await _openStore();
      addTearDown(store.close);

      final FSRSConfig base = _bulkConfig(5);
      store.save(base);
      await store.flush();

      store.save(base);
      await store.flush();
      expect(store.debugLastUpsertedRows, 0);
      expect(store.debugLastDeletedRows, 0);
      expect(store.debugLastFullRewrite, isFalse);
    });

    test('快照在 importLegacy / clear / remapWordIds 后保持一致', () async {
      final DriftFsrsStore store = await _openStore();
      addTearDown(store.close);

      // importLegacy 后：快照应等于导入内容，后续单卡写只 upsert 1 行。
      final String backup = fsrsConfigToJson(_bulkConfig(30));
      await store.importLegacy(backup);
      expect(store.debugSnapshotSize, 30);
      final FSRSConfig imported = (await store.load())!;
      final List<Card> cards = List<Card>.of(imported.cards);
      cards[0] = cards[0].copyWith(stability: 77.0);
      store.save(imported.copyWith(cards: cards));
      await store.flush();
      expect(store.debugLastUpsertedRows, 1,
          reason: 'importLegacy 后快照必须已就绪，否则会整表重写');

      // clear 后：快照为空，再写入视为全新。
      await store.clear();
      expect(store.debugSnapshotSize, 0);
      store.save(_bulkConfig(4));
      await store.flush();
      expect(store.debugLastUpsertedRows, 4);

      // remapWordIds 后：快照按新 cardId 重建。
      await store.remapWordIds(<int, int>{0: 0, 1: 1, 2: 10, 3: 3});
      expect(store.debugSnapshotSize, 4);
      final FSRSConfig remapped = (await store.load())!;
      expect(remapped.cards.map((Card c) => c.cardId).toList(), <int>[0, 1, 3, 10]);
      // 只改 cardId=10 那张，应只 upsert 1 行（说明快照里的 key 已是新 id）。
      final List<Card> after = List<Card>.of(remapped.cards);
      final int idx = after.indexWhere((Card c) => c.cardId == 10);
      after[idx] = after[idx].copyWith(stability: 123.0);
      store.save(remapped.copyWith(cards: after));
      await store.flush();
      expect(store.debugLastUpsertedRows, 1);
    });

    test('写入失败后快照不被半更新（下次写仍是正确的增量）', () async {
      // 用一个独立的库文件：本用例会 close 掉连接来制造写失败。
      final String path = _tempPath();
      addTearDown(() => _removeDb(path));
      final DriftFsrsStore store = await _openStore(file: File(path));

      final FSRSConfig base = _bulkConfig(6);
      store.save(base);
      await store.flush();
      expect(store.debugSnapshotSize, 6);
      final int snapshotBefore = store.debugSnapshotSize;

      // 关库后写入必然失败：`_writeAll` 在事务里抛错，
      // 而快照的更新发生在事务成功之后，因此快照应保持 6 行不变。
      await store.close();
      final List<Card> cards = List<Card>.of(base.cards);
      cards[0] = cards[0].copyWith(stability: 123.0);
      store.save(base.copyWith(cards: cards));
      await store.flush(); // 失败被 _enqueue 的 catchError 吞掉并记 severe

      expect(store.debugSnapshotSize, snapshotBefore,
          reason: '事务失败时不得更新快照，否则下次增量写会漏行');
      expect(store.debugLastUpsertedRows, 0,
          reason: '失败的写入不应被计为成功 upsert');
    });
  });

  group('增量写基准（2500 张卡）', () {
    test('首写全量 + 单卡变更写只 upsert 1 行', () async {
      final DriftFsrsStore store = await _openStore();
      addTearDown(store.close);

      const int count = 2500;

      // 首次全量写入（空库 → 走全表替换）。
      final FSRSConfig base = _bulkConfig(count);
      final Stopwatch first = Stopwatch()..start();
      store.save(base);
      await store.flush();
      first.stop();

      final int firstUpserts = store.debugLastUpsertedRows;
      expect(firstUpserts, count, reason: '首写必须落全部卡片');
      expect(store.debugLastFullRewrite, isTrue);
      expect(store.debugSnapshotSize, count);

      // 之后只改一张卡（模拟答一题）。
      final List<Card> cards = List<Card>.of(base.cards);
      cards[1234] = cards[1234].copyWith(stability: 88.0);
      final Stopwatch second = Stopwatch()..start();
      store.save(base.copyWith(cards: cards));
      await store.flush();
      second.stop();

      // 核心断言：写入行数与变更数成正比，而不是与总行数成正比。
      expect(store.debugLastUpsertedRows, 1,
          reason: '只有 1 张卡变化，不能整表重写 $count 行');
      expect(store.debugLastDeletedRows, 0);
      expect(store.debugLastFullRewrite, isFalse);
      expect(store.debugLastUpsertedRows, lessThan(count ~/ 100),
          reason: '单卡变更的写入量应远小于总数（< 1%）');

      // 数据正确性。
      final FSRSConfig? reloaded = await store.load();
      expect(reloaded!.cards.length, count);
      expect(reloaded.cards[1234].stability, 88.0);
      // 顺序契约：仍按 card_id 升序，cards[i] 与 reviewLogs[i] 对齐。
      expect(reloaded.cards.map((Card c) => c.cardId).take(3).toList(),
          <int>[0, 1, 2]);
      expect(reloaded.reviewLogs[1234].cardId, 1234);

      // 实测耗时（开发机 Linux x64，flutter test 的 debug 模式，仅供参考；
      // 断言只用行数，因为 CI 上的绝对耗时不稳定）：
      //   2500 张卡首写（全表替换 2500 行）：约 60 ms
      //   单卡变更写（1 行 upsert，单事务）：约 3.7 ms
      // 改造前「每次防抖写都 delete + insertAll 2500 行」的单卡写约 70 ms，
      // 即本次优化把「答一题」的落盘量从 O(n) 降到 O(变化数)。
      // 剩余 3.7ms 主要是 2500 张卡的对象相等脏检查（~0.3ms）与事务提交，
      // 不再是序列化/整表重写。
      // 见下方 print，便于在本地复跑时对照。
      // ignore: avoid_print
      print('[bench] 2500 卡：首写 ${first.elapsedMilliseconds} ms'
          '（全表替换 $firstUpserts 行），'
          '单卡写 ${second.elapsedMicroseconds} µs'
          '（upsert=${store.debugLastUpsertedRows} 行）；'
          '首写内部计时 ${first.elapsedMicroseconds} µs');
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
