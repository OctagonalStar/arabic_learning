// FSRS ↔ 存储后端 的集成测试。
//
// 验证「每题写盘不再落进 shared_preferences」这条核心约束，以及
// 导出/恢复链路（备份格式不变、恢复后灌回 SQLite、FSRS 读到新数据）。

import 'dart:convert';
import 'dart:io' as io;

import 'package:arabic_learning/package_replacement/storage.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/db/fsrs_drift_store.dart'
    show DriftFsrsStore, FsrsDatabase, debugForceDriftInTests;
import 'package:arabic_learning/services/db/fsrs_store.dart';
import 'package:arabic_learning/services/db/fsrs_store_factory.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';

import '../helpers/test_env.dart';

FSRSConfig _configWithCards(List<int> ids) => FSRSConfig(
      enabled: true,
      scheduler: Scheduler(),
      cards: <Card>[
        for (final int id in ids) Card(cardId: id, state: State.learning),
      ],
      reviewLogs: <ReviewLog>[
        for (final int id in ids)
          ReviewLog(
            cardId: id,
            rating: Rating.good,
            reviewDateTime: DateTime.utc(2026, 1, 1),
          ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    mockPathProvider();
    mockStorage(<String, Object>{});
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  tearDownAll(() {
    // 同 fsrs_drift_store_test：drift 后台 isolate 的关闭是异步的，
    // 单用例 tearDown 删文件会被 WAL checkpoint 重建，统一在最后清理。
    final io.Directory dir = io.Directory(testDbDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  setUp(() async {
    await AppData().init();
    if (AppData().isFirstStart) await AppData().initStorageValue();
    // 每个用例都从「JSON 后端 + 空 fsrsData」出发。
    FSRS().debugUseStore(JsonFsrsStore());
    await AppData().storage.setString('fsrsData', jsonEncode(FSRSConfig().toMap()));
    FSRS().init();
  });

  test('flutter test 环境下 openDriftStore 返回 null，自动走 JSON 后端', () async {
    await FSRS().initAsync();
    expect(FSRS().usingSqlite, isFalse);
    expect(FSRS().store, isA<JsonFsrsStore>());
    expect(FSRS().inited, isTrue);
  });

  test('答题（produceCard）在 SQLite 后端下不写 shared_preferences', () async {
    final DriftFsrsStore dbStore = DriftFsrsStore(FsrsDatabase(NativeDatabase.memory()));
    await dbStore.open();
    addTearDown(dbStore.close);
    dbStore.save(_configWithCards(<int>[0]));
    await dbStore.flush();

    FSRS().debugUseStore(dbStore);
    await FSRS().initAsync(reload: true);
    expect(FSRS().usingSqlite, isTrue);

    // 记录一次「答题前的偏好文件内容」。
    final String? before = AppData().storage.getString('fsrsData');

    FSRS().produceCard(1, forceRate: Rating.good);
    // 越过 400ms 防抖窗口，等异步入队写完。
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await dbStore.flush();

    // 1) 数据库里有新卡片；
    final FSRSConfig? inDb = await dbStore.load();
    expect(inDb!.cards.map((Card c) => c.cardId).toSet(), <int>{0, 1});
    // 2) 偏好文件未被逐题重写（这正是本次改造要消除的开销）。
    expect(AppData().storage.getString('fsrsData'), before);
  });

  test('导出：fsrsData 由内存副本生成，格式与旧版完全一致', () async {
    final DriftFsrsStore dbStore = DriftFsrsStore(FsrsDatabase(NativeDatabase.memory()));
    await dbStore.open();
    addTearDown(dbStore.close);
    dbStore.save(_configWithCards(<int>[3, 5]));
    await dbStore.flush();

    FSRS().debugUseStore(dbStore);
    await FSRS().initAsync(reload: true);

    // 模拟答题后立即导出（未过防抖窗口）。
    FSRS().produceCard(9, forceRate: Rating.easy);

    final Map<String, dynamic> backup = AppData().storage.export();
    expect(backup.containsKey('fsrsData'), isTrue,
        reason: '备份必须仍包含 fsrsData（降级/兼容旧版）');

    final Map<String, dynamic> decoded =
        jsonDecode(backup['fsrsData'] as String) as Map<String, dynamic>;
    // 旧版字段齐全
    expect(decoded.keys, containsAll(<String>[
      'enabled',
      'scheduler',
      'cards',
      'reviewLog',
      'desiredRetention',
      'easyDuration',
      'goodDuration',
      'preferSimilar',
      'selfEvaluate',
      'pushAmount',
      'reinforceMemory',
      'pushCategories',
      'reviewQuestionSections',
    ]));
    // 卡片来自内存中的权威副本（含刚答的那张）
    final List<dynamic> cards = decoded['cards'] as List<dynamic>;
    expect(
      cards.map((dynamic c) => (c as Map<String, dynamic>)['cardId']).toSet(),
      <int>{3, 5, 9},
    );
    // 旧版可直接反序列化
    final FSRSConfig reparsed = FSRSConfig.buildFromMap(decoded);
    expect(reparsed.cards.map((Card c) => c.cardId).toSet(), <int>{3, 5, 9});
    expect(reparsed.reviewLogs.length, 3);
  });

  test('恢复：recovery 完成后 SQLite 已是新数据，FSRS 也能立刻读到', () async {
    final DriftFsrsStore dbStore = DriftFsrsStore(FsrsDatabase(NativeDatabase.memory()));
    await dbStore.open();
    addTearDown(dbStore.close);
    dbStore.save(_configWithCards(<int>[0]));
    await dbStore.flush();

    FSRS().debugUseStore(dbStore);
    await FSRS().initAsync(reload: true);
    expect(FSRS().config.cards.map((Card c) => c.cardId).toList(), <int>[0]);

    // 构造一份旧格式备份（含 pushSessionData），走真实 recovery 路径。
    final FSRSConfig backupConfig = _configWithCards(<int>[4, 6, 8]);
    await AppData().storage.recovery(<String, dynamic>{
      'fsrsData': jsonEncode(backupConfig.toMap()),
      'pushSessionData': '{"day":20260101,"phase":1,"wordId":6,"wordCount":9}',
    });

    // 恢复后：库、内存、高频键都已更新。
    expect((await dbStore.load())!.cards.map((Card c) => c.cardId).toList(),
        <int>[4, 6, 8]);
    expect(FSRS().config.cards.map((Card c) => c.cardId).toList(), <int>[4, 6, 8]);
    expect(dbStore.hotKv('pushSessionData'), contains('20260101'));
    // 恢复出来的 fsrsData 仍是旧格式（旧版本可读）。
    expect(AppData().storage.getString('fsrsData'), jsonEncode(backupConfig.toMap()));
  });

  test('恢复空卡片备份会清空 SQLite 里的旧卡片', () async {
    final DriftFsrsStore dbStore = DriftFsrsStore(FsrsDatabase(NativeDatabase.memory()));
    await dbStore.open();
    addTearDown(dbStore.close);
    dbStore.save(_configWithCards(<int>[0, 1, 2]));
    await dbStore.flush();

    FSRS().debugUseStore(dbStore);
    await FSRS().initAsync(reload: true);

    await AppData().storage.recovery(<String, dynamic>{
      'fsrsData': jsonEncode(
        FSRSConfig(enabled: true, scheduler: Scheduler()).toMap(),
      ),
    });

    expect((await dbStore.load())!.cards, isEmpty);
    expect(FSRS().config.cards, isEmpty);
  });

  test('热键：pushSessionData 在 SQLite 后端下写入 hot_kv 而不是偏好文件', () async {
    final DriftFsrsStore dbStore = DriftFsrsStore(FsrsDatabase(NativeDatabase.memory()));
    await dbStore.open();
    addTearDown(dbStore.close);

    FSRS().debugUseStore(dbStore);
    await FSRS().initAsync(reload: true);

    await AppData().storage.setString('pushSessionData', '');
    await dbStore.setHotKv('pushSessionData', '{"day":7}');
    expect(dbStore.hotKv('pushSessionData'), '{"day":7}');

    // 导出时由钩子补齐该键，备份格式不变。
    final Map<String, dynamic> backup = AppData().storage.export();
    expect(backup['pushSessionData'], '{"day":7}');
  });

  test('JSON 后端下 export 不注入任何覆盖值（行为与改造前一致）', () async {
    FSRS().init();
    await AppData().storage.setString('fsrsData', jsonEncode(_configWithCards(<int>[2]).toMap()));
    FSRS().init();
    FSRS().produceCard(3, forceRate: Rating.good);

    final Map<String, dynamic> backup = AppData().storage.export();
    final Map<String, dynamic> decoded =
        jsonDecode(backup['fsrsData'] as String) as Map<String, dynamic>;
    // JSON 后端：flushPendingWrites 会把防抖内容写进 prefs，因此也是最新数据。
    final List<dynamic> cards = decoded['cards'] as List<dynamic>;
    expect(
      cards.map((dynamic c) => (c as Map<String, dynamic>)['cardId']).toSet(),
      <int>{2, 3},
    );
    expect(SharedPreferences.usedKeys.contains('fsrsData'), isTrue);
  });

  test('openDriftStore 在原生平台真实建库（drift_flutter + sqlite3）', () async {
    // 必须显式指定库路径：drift 在后台 isolate 里打开数据库，拿不到
    // flutter test 里 mock 的 path_provider，否则会落到开发机的真实文档目录。
    // 这里统一用 /tmp/opencode 下的临时目录（已批准的仓库外临时区）。
    final io.Directory dir = io.Directory(testDbDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final String dbPath = '$testDbDir/fsrs_${DateTime.now().microsecondsSinceEpoch}.sqlite';
    addTearDown(() {
      for (final String suffix in <String>['', '-wal', '-shm']) {
        final io.File f = io.File('$dbPath$suffix');
        if (f.existsSync()) f.deleteSync();
      }
    });

    debugForceDriftInTests = true;
    addTearDown(() => debugForceDriftInTests = false);

    final String legacyJson = jsonEncode(_configWithCards(<int>[1, 2]).toMap());
    final FsrsStore? store =
        await openDriftStore(legacyJson: legacyJson, databasePath: dbPath);
    expect(store, isNotNull, reason: '原生测试环境应能打开 SQLite');
    addTearDown(() => store!.close());

    final FSRSConfig? loaded = await store!.load();
    expect(loaded!.cards.map((Card c) => c.cardId).toList(), <int>[1, 2]);

    // 关库后用**同一份** fsrsData 重新打开：幂等，不会被二次导入覆盖。
    await store.close();
    final FsrsStore? reopened =
        await openDriftStore(legacyJson: legacyJson, databasePath: dbPath);
    expect(reopened, isNotNull);
    addTearDown(() => reopened!.close());
    expect((await reopened!.load())!.cards.map((Card c) => c.cardId).toList(),
        <int>[1, 2]);

    // 关库后换一份卡片更多的 fsrsData（模拟「降级旧版本又学了新词」）：
    // 必须重新导入，否则旧版本期间产生的进度会被静默丢弃。
    await reopened.close();
    final String afterDowngradeJson =
        jsonEncode(_configWithCards(<int>[1, 2, 7]).toMap());
    final FsrsStore? afterDowngrade =
        await openDriftStore(legacyJson: afterDowngradeJson, databasePath: dbPath);
    expect(afterDowngrade, isNotNull);
    addTearDown(() => afterDowngrade!.close());
    expect(
        (await afterDowngrade!.load())!.cards.map((Card c) => c.cardId).toList(),
        <int>[1, 2, 7]);

    // 反过来：外部 blob 的卡片数更少，也要按内容导入 —— 卡片数会因为删词、
    // 重置词库而合法减少，用「数量」判新旧会误判成陈旧快照、进而让 cardId
    // 与词条错位（比重复习更危险）。
    await afterDowngrade.close();
    final String trimmed =
        jsonEncode(_configWithCards(<int>[1]).toMap());
    final FsrsStore? trimmedStore =
        await openDriftStore(legacyJson: trimmed, databasePath: dbPath);
    expect(trimmedStore, isNotNull);
    addTearDown(() => trimmedStore!.close());
    expect((await trimmedStore!.load())!.cards.map((Card c) => c.cardId).toList(),
        <int>[1]);
  });
}
