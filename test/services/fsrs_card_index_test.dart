// FSRS 卡片查表（cardId → 下标）的正确性测试。
//
// 重点：
// 1. 2000 张卡下「查表结果」与朴素线性实现逐项等价；
// 2. 重复 cardId 脏数据的容错语义与改造前完全一致（先出现者为准）；
// 3. 所有改表路径（赋值 / 答题新增 / 答题复习 / 重映射 / 清空 / 重新加载）
//    之后索引都不过期。
//
// 性能相关的断言一律用「扫描长度」而不是墙钟时间（见「最坏情形」用例）。

import 'dart:convert';

import 'package:arabic_learning/package_replacement/storage.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/plan_store.dart' show PlanStore;
import 'package:fsrs/fsrs.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

/// 改造前的朴素实现：按 cardId 线性查找下标。
int _naiveIndexWhere(List<Card> cards, int cardId) =>
    cards.indexWhere((Card card) => card.cardId == cardId);

/// 改造前的朴素实现：按 cardId 线性判断是否含卡片。
bool _naiveIsContained(List<Card> cards, int cardId) =>
    cards.any((Card card) => card.cardId == cardId);

/// 改造前的朴素实现：按 cardId 线性取第一条日志。
ReviewLog? _naiveFirstLog(List<ReviewLog> logs, int cardId) {
  for (final ReviewLog candidate in logs) {
    if (candidate.cardId == cardId) return candidate;
  }
  return null;
}

/// 改造前的朴素实现：对齐卡片与日志（O(n²)）。
List<({Card card, ReviewLog log})> _naiveAlignedCards(
  List<Card> cards,
  List<ReviewLog> logs,
) {
  final List<({Card card, ReviewLog log})> out = [];
  for (final Card card in cards) {
    final ReviewLog? log = _naiveFirstLog(logs, card.cardId);
    out.add((
      card: card,
      log: ReviewLog(
        cardId: card.cardId,
        rating: log?.rating ?? Rating.good,
        reviewDateTime: log?.reviewDateTime ?? DateTime.now(),
        reviewDuration: log?.reviewDuration,
      ),
    ));
  }
  return out;
}

FSRSConfig _configWithIds(List<int> ids, {Scheduler? scheduler}) {
  return FSRSConfig(
    enabled: true,
    // `buildFromMap` 会无条件解析 scheduler，落盘再读时必须带上它。
    scheduler: scheduler ?? Scheduler(),
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
    FSRS().init();
  });

  setUp(() async {
    // 每个用例都从空配置出发（显式赋值，同时刷新索引）。
    await AppData()
        .storage
        .setString('fsrsData', jsonEncode(FSRSConfig().toMap()));
    FSRS().config = FSRSConfig();
  });

  group('查表与朴素实现等价（2000 张卡）', () {
    // 稀疏 id：模拟「删过词 / 只学了一部分」的真实分布，避免 id 恰好等于下标。
    final List<int> ids = <int>[
      for (int i = 0; i < 2000; i++) i * 3,
    ];

    test('isContained 逐项与线性 any 一致', () {
      FSRS().config = _configWithIds(ids);
      final List<Card> cards = FSRS().config.cards;

      // 命中：全部已有 id。
      for (final int id in ids) {
        expect(
          FSRS().isContained(id),
          _naiveIsContained(cards, id),
          reason: 'id=$id 的命中判定与线性实现不一致',
        );
      }
      // 未命中：全部空缺 id（含边界外）。
      for (int id = 0; id < ids.length; id++) {
        if (id % 3 == 0) continue;
        expect(FSRS().isContained(id), _naiveIsContained(cards, id));
      }
      expect(FSRS().isContained(-1), isFalse);
      expect(FSRS().isContained(1 << 30), isFalse);
    });

    test('getCardBirthday 与线性 firstWhere 一致', () {
      FSRS().config = _configWithIds(ids);
      for (final int id in <int>[0, 3, 2997, 7, 2998]) {
        expect(
          FSRS().getCardBirthday(id),
          _naiveFirstLog(FSRS().config.reviewLogs, id)?.reviewDateTime,
          reason: 'id=$id 的生日取值与 firstWhere 不一致',
        );
      }
    });

    test('countCardsFor 与线性计数一致', () {
      FSRS().config = _configWithIds(ids);
      final Set<int> probe = <int>{0, 3, 6, 1, 2, 5999, -1};
      expect(
        FSRS().countCardsFor(probe),
        FSRS().config.cards.where((Card c) => probe.contains(c.cardId)).length,
      );
      expect(FSRS().countCardsFor(<int>{}), 0);
      expect(FSRS().countCardsFor(ids.toSet()), ids.length);
    });

    test('alignedCards 逐项与朴素 O(n²) 实现等价（含顺序）', () {
      FSRS().config = _configWithIds(ids);
      final List<({Card card, ReviewLog log})> actual = FSRS().alignedCards();
      final List<({Card card, ReviewLog log})> expected = _naiveAlignedCards(
        FSRS().config.cards,
        FSRS().config.reviewLogs,
      );

      expect(actual.length, expected.length);
      for (int i = 0; i < expected.length; i++) {
        expect(actual[i].card.cardId, expected[i].card.cardId,
            reason: '第 $i 项的卡片顺序变化');
        expect(actual[i].log.cardId, expected[i].log.cardId);
        expect(actual[i].log.rating, expected[i].log.rating);
        expect(actual[i].log.reviewDateTime, expected[i].log.reviewDateTime);
        expect(actual[i].log.reviewDuration, expected[i].log.reviewDuration);
      }
    });

    test('alignedCards 最坏情形（日志错位）仍等价，且朴素实现要扫 O(n²)', () {
      // 日志整体错位：第 i 张卡（id = 3i）的日志落在后面，朴素实现每张卡
      // 都要线性扫描才能找到/确认找不到 —— 这正是改造前 O(n²) 的来源。
      final List<Card> cards = <Card>[
        for (final int id in ids) Card(cardId: id, state: State.learning),
      ];
      final List<ReviewLog> skewedLogs = <ReviewLog>[
        for (int i = 1; i < ids.length; i++)
          ReviewLog(
            cardId: ids[i],
            rating: Rating.hard,
            reviewDateTime: DateTime.utc(2026, 1, 1),
          ),
      ];
      FSRS().config = FSRSConfig(cards: cards, reviewLogs: skewedLogs);

      // 记录朴素实现的扫描长度（只作对比，不参与对实现的断言）。
      int naiveComparisons = 0;
      for (final Card card in cards) {
        for (final ReviewLog candidate in skewedLogs) {
          naiveComparisons++;
          if (candidate.cardId == card.cardId) break;
        }
      }
      expect(naiveComparisons, greaterThan(ids.length * ids.length ~/ 4),
          reason: '朴素实现在日志错位时是 O(n²)，这正是要消除的开销');

      // 改造后仍逐项等价：第一张卡（id=0）没有日志 → 补默认值。
      final List<({Card card, ReviewLog log})> actual = FSRS().alignedCards();
      final List<({Card card, ReviewLog log})> expected =
          _naiveAlignedCards(cards, skewedLogs);
      expect(actual.length, expected.length);
      for (int i = 0; i < expected.length; i++) {
        expect(actual[i].card.cardId, expected[i].card.cardId);
        expect(actual[i].log.cardId, expected[i].log.cardId);
        expect(actual[i].log.rating, expected[i].log.rating);
        // 缺失日志时两边都取 `DateTime.now()`，具体时刻必然不同，只比有无。
        if (_naiveFirstLog(skewedLogs, cards[i].cardId) != null) {
          expect(actual[i].log.reviewDateTime, expected[i].log.reviewDateTime);
        }
      }
      expect(actual.first.card.cardId, 0);
      expect(actual.first.log.rating, Rating.good, reason: '缺失日志补默认 good');
    });
  });

  group('重复 cardId 脏数据的容错语义不变', () {
    test('init 清理重复 id 时以先出现者为准', () async {
      // 手工写一份含重复 cardId 的 fsrsData，走真实加载路径。
      final Map<String, dynamic> raw = _configWithIds(<int>[5, 5, 7]).toMap();
      await AppData().storage.setString('fsrsData', jsonEncode(raw));

      FSRS().init();

      expect(
        FSRS().config.cards.map((Card c) => c.cardId).toList(),
        <int>[5, 7],
        reason: '重复 cardId 只保留首次出现的那张',
      );
      expect(FSRS().config.reviewLogs.length, 2);
      // 清理后的索引必须立即可用。
      expect(FSRS().isContained(5), isTrue);
      expect(FSRS().isContained(7), isTrue);
      expect(FSRS().countCardsFor(<int>{5, 7}), 2);
    });

    test('绕过 init 直接赋值重复卡：查表取先出现者，与 indexWhere 一致', () {
      FSRS().config = FSRSConfig(
        cards: <Card>[
          Card(cardId: 1, state: State.review, stability: 11),
          Card(cardId: 1, state: State.learning, stability: 22),
        ],
        reviewLogs: <ReviewLog>[
          ReviewLog(
            cardId: 1,
            rating: Rating.easy,
            reviewDateTime: DateTime.utc(2026, 1, 1),
          ),
          ReviewLog(
            cardId: 1,
            rating: Rating.again,
            reviewDateTime: DateTime.utc(2026, 2, 2),
          ),
        ],
      );

      expect(_naiveIndexWhere(FSRS().config.cards, 1), 0);
      expect(FSRS().isContained(1), isTrue);
      // 生日取第一条日志（firstWhere 语义）。
      expect(FSRS().getCardBirthday(1), DateTime.utc(2026, 1, 1));
      // 计数按「行」统计，重复行算两次（与改造前 where().length 一致）。
      expect(FSRS().countCardsFor(<int>{1}), 2);
      // 对齐列表保留两行、都取第一条日志。
      final List<({Card card, ReviewLog log})> aligned = FSRS().alignedCards();
      expect(aligned.length, 2);
      expect(aligned[0].card.stability, 11);
      expect(aligned[1].card.stability, 22);
      expect(aligned.every((e) => e.log.rating == Rating.easy), isTrue);
    });

    test('重复卡在 produceCard 后仍指向先出现者（增量维护不覆盖）', () {
      FSRS().config = FSRSConfig(
        enabled: true,
        scheduler: Scheduler(),
        cards: <Card>[
          Card(cardId: 2, state: State.learning),
          Card(cardId: 2, state: State.learning),
        ],
        reviewLogs: <ReviewLog>[
          ReviewLog(
            cardId: 2,
            rating: Rating.good,
            reviewDateTime: DateTime.utc(2026, 1, 1),
          ),
          ReviewLog(
            cardId: 2,
            rating: Rating.good,
            reviewDateTime: DateTime.utc(2026, 1, 2),
          ),
        ],
      );

      FSRS().produceCard(2, forceRate: Rating.good);

      // 只复习第一行；第二行原样保留，索引仍指向第一行。
      expect(FSRS().config.cards.length, 2);
      expect(FSRS().config.reviewLogs.length, 2);
      expect(FSRS().isContained(2), isTrue);
      expect(
        FSRS().getCardBirthday(2),
        FSRS().config.reviewLogs[0].reviewDateTime,
      );
    });
  });

  group('索引在各改表路径后不过期', () {
    test('produceCard 新增卡片后可立即查到', () {
      FSRS().config = FSRSConfig(enabled: true, scheduler: Scheduler());
      expect(FSRS().isContained(42), isFalse);

      FSRS().produceCard(42, forceRate: Rating.good);

      expect(FSRS().isContained(42), isTrue);
      expect(FSRS().config.cards.single.cardId, 42);
      expect(FSRS().getCardBirthday(42), isNotNull);
      expect(FSRS().countCardsFor(<int>{42}), 1);
    });

    test('produceCard 复习已有卡片不改变位置与数量', () {
      FSRS().config = _configWithIds(<int>[0, 1, 2], scheduler: Scheduler());
      FSRS().produceCard(1, forceRate: Rating.easy);

      expect(
        FSRS().config.cards.map((Card c) => c.cardId).toList(),
        <int>[0, 1, 2],
      );
      expect(FSRS().config.reviewLogs.length, 3);
      expect(FSRS().isContained(1), isTrue);
      expect(
        FSRS().getCardBirthday(1),
        FSRS().config.reviewLogs[1].reviewDateTime,
      );
    });

    test('remapWordIds / setAlignedCards / clearCards 后索引与列表同步', () {
      FSRS().config = _configWithIds(<int>[0, 1, 3]);
      FSRS().remapWordIds(<int, int>{0: 0, 3: 1});

      expect(FSRS().config.cards.map((Card c) => c.cardId).toList(), <int>[0, 1]);
      expect(FSRS().isContained(1), isTrue, reason: '重映射后的新 id 必须可查');
      expect(FSRS().isContained(3), isFalse, reason: '被丢弃的旧 id 必须查不到');
      expect(FSRS().getCardBirthday(1), isNotNull);

      FSRS().setAlignedCards(const <({Card card, ReviewLog log})>[]);
      expect(FSRS().isContained(0), isFalse);
      expect(FSRS().countCardsFor(<int>{0, 1}), 0);

      FSRS().config = _configWithIds(<int>[4, 5]);
      expect(FSRS().clearCards(), 2);
      expect(FSRS().isContained(4), isFalse);
      expect(FSRS().config.cards, isEmpty);
    });

    test('copyWith 不改列表时沿用索引（设置页反复赋值不重建）', () {
      FSRS().config = _configWithIds(<int>[0, 1, 2]);

      // 与设置页滑块一致：只改标量，cards/reviewLogs 仍是同一批实例。
      FSRS().config = FSRS().config.copyWith(pushAmount: 3);
      FSRS().config = FSRS().config.copyWith(desiredRetention: 0.85);

      expect(FSRS().config.pushAmount, 3);
      expect(FSRS().config.desiredRetention, 0.85);
      // 索引必须仍然正确（跳过重建不等于失效）。
      expect(FSRS().isContained(0), isTrue);
      expect(FSRS().isContained(2), isTrue);
      expect(FSRS().countCardsFor(<int>{0, 1, 2}), 3);
      expect(FSRS().alignedCards().length, 3);
    });

    test('initAsync(reload) 重新加载后索引指向新数据', () async {
      await AppData().storage.setString(
        'fsrsData',
        jsonEncode(_configWithIds(<int>[8, 9]).toMap()),
      );
      FSRS().config = _configWithIds(<int>[0]);

      await FSRS().initAsync(reload: true);

      expect(FSRS().isContained(8), isTrue);
      expect(FSRS().isContained(9), isTrue);
      expect(FSRS().isContained(0), isFalse, reason: '旧索引不能残留');
      expect(SharedPreferences.usedKeys.contains('fsrsData'), isTrue);
    });
  });

  group('flushPendingWrites 多订阅者', () {
    test('FSRS 与 PlanStore 的钩子都会注册且不重复', () async {
      // 两个服务在各自 init 里注册；AppData.init() 已调用过两者。
      await PlanStore().init();
      FSRS().init();
      final int before = SharedPreferences.flushPendingWrites.length;
      expect(before, greaterThanOrEqualTo(2),
          reason: 'FSRS 与 PlanStore 各应注册一个落盘钩子');
      // 注册是幂等的：重复 init 不会重复追加。
      await PlanStore().init();
      FSRS().init();
      expect(SharedPreferences.flushPendingWrites.length, before);
    });
  });
}
