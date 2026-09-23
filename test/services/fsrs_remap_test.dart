import 'package:arabic_learning/models/dict.dart' show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:fsrs/fsrs.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
    // 确保 FSRS 已加载（_inited 置位），随后各用例再覆盖 config。
    FSRS().init();
  });

  test('remapWordIds 丢弃被删词条卡片并保持 cards/reviewLogs 对齐', () {
    FSRS().config = FSRSConfig(
      cards: <Card>[
        Card(cardId: 0, state: State.learning),
        Card(cardId: 1, state: State.learning),
        Card(cardId: 3, state: State.review),
      ],
      reviewLogs: <ReviewLog>[
        ReviewLog(cardId: 0, rating: Rating.good, reviewDateTime: DateTime(2026, 1, 1)),
        ReviewLog(cardId: 1, rating: Rating.good, reviewDateTime: DateTime(2026, 1, 2)),
        ReviewLog(cardId: 3, rating: Rating.hard, reviewDateTime: DateTime(2026, 1, 3)),
      ],
    );

    final int dropped = FSRS().remapWordIds(<int, int>{0: 0, 3: 1});

    expect(dropped, 1, reason: 'wordId=1 不在映射中，其卡片被丢弃');
    expect(FSRS().config.cards.map((Card c) => c.cardId).toList(), <int>[0, 1]);
    expect(FSRS().config.reviewLogs.map((ReviewLog l) => l.cardId).toList(), <int>[0, 1]);
    expect(FSRS().config.reviewLogs[1].rating, Rating.hard, reason: '原 id=3 的日志随卡片迁移');
    expect(FSRS().countCardsFor(<int>{1}), 1);
  });

  test('outOfRangeCardCount 统计越界卡片', () {
    FSRS().config = FSRSConfig(
      cards: <Card>[
        Card(cardId: 0, state: State.learning),
        Card(cardId: 9, state: State.learning),
      ],
      reviewLogs: <ReviewLog>[
        ReviewLog(cardId: 0, rating: Rating.good, reviewDateTime: DateTime(2026, 1, 1)),
        ReviewLog(cardId: 9, rating: Rating.good, reviewDateTime: DateTime(2026, 1, 1)),
      ],
    );

    expect(FSRS().outOfRangeCardCount(5), 1);
    expect(FSRS().outOfRangeCardCount(10), 0);
  });

  test('重置词库并恢复复习进度：按词形把卡片映射到新词条', () {
    AppData().wordData = const DictData(
      words: <WordItem>[
        WordItem(arabic: 'كتاب', chinese: '书', explanation: '', className: 'A', id: 0),
        WordItem(arabic: 'قلم', chinese: '笔', explanation: '', className: 'A', id: 1),
        WordItem(arabic: 'بيت', chinese: '房子', explanation: '', className: 'A', id: 2),
      ],
      classes: <SourceItem>[
        SourceItem(
          sourceJsonFileName: 'a.json',
          displayName: 'A',
          subClasses: <ClassItem>[
            ClassItem(className: 'A', wordIndexs: <int>[0, 1, 2]),
          ],
        ),
      ],
    );
    FSRS().config = FSRSConfig(
      cards: <Card>[
        Card(cardId: 0, state: State.learning),
        Card(cardId: 2, state: State.review),
      ],
      reviewLogs: <ReviewLog>[
        ReviewLog(cardId: 0, rating: Rating.good, reviewDateTime: DateTime(2026, 1, 1)),
        ReviewLog(cardId: 2, rating: Rating.easy, reviewDateTime: DateTime(2026, 1, 2)),
      ],
    );

    final int pending = AppData().resetDictsPreservingFsrs();
    expect(pending, 2);
    expect(AppData().hasPendingFsrsRestore, isTrue);
    expect(AppData().wordData.words, isEmpty);
    expect(FSRS().config.cards, isEmpty, reason: '重置后清空卡片，避免旧位置错配');

    // 模拟重新导入：词条顺序变化，但词形一致（كتاب 从 0 变到 1）。
    AppData().wordData = const DictData(
      words: <WordItem>[
        WordItem(arabic: 'باب', chinese: '门', explanation: '', className: 'B', id: 0),
        WordItem(arabic: 'كِتَابٌ', chinese: '书', explanation: '', className: 'B', id: 1),
        WordItem(arabic: 'بيت', chinese: '房子', explanation: '', className: 'B', id: 2),
      ],
      classes: <SourceItem>[],
    );

    final ({int restored, int dropped}) r = AppData().restoreFsrsFromPending();
    expect(r.restored, 2);
    expect(r.dropped, 0);
    expect(AppData().hasPendingFsrsRestore, isFalse);
    expect(FSRS().config.cards.map((Card c) => c.cardId).toSet(), <int>{1, 2});
    expect(FSRS().config.reviewLogs.length, 2, reason: '日志与卡片保持对齐');
  });

  test('重置后可正常重新导入（空词库列表可增长）并恢复进度', () {
    AppData().wordData = const DictData(
      words: <WordItem>[
        WordItem(arabic: 'كتاب', chinese: '书', explanation: '', className: 'A', id: 0),
      ],
      classes: <SourceItem>[
        SourceItem(
          sourceJsonFileName: 'a.json',
          displayName: 'A',
          subClasses: <ClassItem>[
            ClassItem(className: 'A', wordIndexs: <int>[0]),
          ],
        ),
      ],
    );
    FSRS().config = FSRSConfig(
      cards: <Card>[Card(cardId: 0, state: State.learning)],
      reviewLogs: <ReviewLog>[
        ReviewLog(cardId: 0, rating: Rating.good, reviewDateTime: DateTime(2026, 1, 1)),
      ],
    );

    AppData().resetDictsPreservingFsrs();
    // 走真实导入路径：若空列表不可增长，这里会抛 UnsupportedError。
    AppData().importDictData('{"A":[{"arabic":"كتاب","chinese":"书"}]}', 'a.json');
    expect(AppData().wordData.words.length, 1);

    final ({int restored, int dropped}) r = AppData().restoreFsrsFromPending();
    expect(r.restored, 1);
    expect(r.dropped, 0);
    expect(FSRS().config.cards.single.cardId, 0);
  });
}
