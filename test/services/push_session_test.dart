import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/package_replacement/storage.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/push_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

/// 构造仅含分类标签的小词库（id 按位置生成）。
DictData _dict(List<String> categories) {
  return DictData(
    words: List<WordItem>.generate(
      categories.length,
      (int i) => WordItem(
        arabic: 'w$i',
        chinese: 'c$i',
        explanation: '',
        className: 'c',
        id: i,
        categories: [categories[i]],
      ),
      growable: false,
    ),
    classes: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
  });

  setUp(() async {
    await PushSessionStore.clear();
    // 受控的 FSRS 配置：无卡片、无日志、推送 3 个、不筛选分类
    FSRS().config = FSRSConfig(cards: [], reviewLogs: [], pushAmount: 3, pushCategories: const []);
  });

  group('pushDayKey', () {
    test('按年月日拼成 yyyyMMdd', () {
      expect(pushDayKey(DateTime(2026, 9, 23)), 20260923);
      expect(pushDayKey(DateTime(2026, 1, 2)), 20260102);
      expect(pushDayKey(DateTime(2026, 12, 31)), 20261231);
    });
  });

  group('PushCheckpoint', () {
    test('toMap/fromMap 往返一致', () {
      const PushCheckpoint cp = PushCheckpoint(day: 20260923, phase: 1, wordId: 7, wordCount: 20);
      expect(cp.toMap(), <String, dynamic>{'day': 20260923, 'phase': 1, 'wordId': 7, 'wordCount': 20});

      final PushCheckpoint? restored = PushCheckpoint.fromMap(cp.toMap());
      expect(restored, isNotNull);
      expect(restored!.day, 20260923);
      expect(restored.phase, 1);
      expect(restored.wordId, 7);
      expect(restored.wordCount, 20);
    });

    test('字段缺失或类型异常返回 null', () {
      expect(PushCheckpoint.fromMap(<String, dynamic>{}), isNull);
      expect(
        PushCheckpoint.fromMap(<String, dynamic>{'day': 'x', 'phase': 1, 'wordId': 1, 'wordCount': 1}),
        isNull,
      );
      expect(
        PushCheckpoint.fromMap(<String, dynamic>{'day': 1, 'phase': 1, 'wordId': 1}),
        isNull,
      );
      expect(
        PushCheckpoint.fromMap(<String, dynamic>{'day': 1, 'phase': 1.5, 'wordId': 1, 'wordCount': 1}),
        isNull,
      );
    });
  });

  group('PushSessionStore', () {
    test('save → load → clear', () async {
      expect(PushSessionStore.load(), isNull);

      const PushCheckpoint cp = PushCheckpoint(day: 20260923, phase: 1, wordId: 3, wordCount: 10);
      await PushSessionStore.save(cp);

      final PushCheckpoint? loaded = PushSessionStore.load();
      expect(loaded, isNotNull);
      expect(loaded!.day, 20260923);
      expect(loaded.phase, 1);
      expect(loaded.wordId, 3);
      expect(loaded.wordCount, 10);

      await PushSessionStore.clear();
      expect(PushSessionStore.load(), isNull);
    });

    test('损坏或非对象数据返回 null', () async {
      await AppData().storage.setString(PushSessionStore.key, 'not-json');
      expect(PushSessionStore.load(), isNull);

      await AppData().storage.setString(PushSessionStore.key, '{"day":1}');
      expect(PushSessionStore.load(), isNull);

      await AppData().storage.setString(PushSessionStore.key, '[1,2,3]');
      expect(PushSessionStore.load(), isNull);
    });

    test('pushSessionData 已加入备份白名单', () {
      expect(SharedPreferences.usedKeys.contains(PushSessionStore.key), isTrue);
    });
  });

  group('buildDailyPushPlan', () {
    test('候选充足时返回非空计划', () {
      final DailyPushPlan plan = buildDailyPushPlan(
        now: DateTime(2026, 9, 23, 10),
        fsrs: FSRS(),
        wordData: _dict(<String>['a', 'a', 'a', 'a', 'a']),
      );
      expect(plan.noCandidates, isFalse);
      expect(plan.words, isNotEmpty);
      expect(plan.words.length, lessThanOrEqualTo(3));
    });

    test('同一天重复调用结果一致（日期种子）', () {
      final DictData dict = _dict(<String>['a', 'a', 'a', 'a', 'a']);
      final DateTime now = DateTime(2026, 9, 23, 10);
      final DailyPushPlan first = buildDailyPushPlan(now: now, fsrs: FSRS(), wordData: dict);
      final DailyPushPlan second = buildDailyPushPlan(now: DateTime(2026, 9, 23, 23), fsrs: FSRS(), wordData: dict);
      expect(
        second.words.map((WordItem w) => w.id).toList(),
        first.words.map((WordItem w) => w.id).toList(),
      );
    });

    test('分类筛选排除全部候选时 noCandidates 为真', () {
      FSRS().config = FSRSConfig(cards: [], reviewLogs: [], pushAmount: 3, pushCategories: const ['不存在']);
      final DailyPushPlan plan = buildDailyPushPlan(
        now: DateTime(2026, 9, 23),
        fsrs: FSRS(),
        wordData: _dict(<String>['a', 'b', 'c']),
      );
      expect(plan.noCandidates, isTrue);
      expect(plan.words, isEmpty);
    });

    test('空词库 noCandidates 为真', () {
      final DailyPushPlan plan = buildDailyPushPlan(
        now: DateTime(2026, 9, 23),
        fsrs: FSRS(),
        wordData: const DictData(words: <WordItem>[], classes: []),
      );
      expect(plan.noCandidates, isTrue);
      expect(plan.words, isEmpty);
    });
  });
}
