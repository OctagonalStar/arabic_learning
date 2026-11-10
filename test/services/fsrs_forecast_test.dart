import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:fsrs/fsrs.dart' show Card;
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
    FSRS().init();
  });

  test('getOverdueCount 只统计已过期卡片', () {
    final DateTime now = DateTime.now();
    FSRS().config = FSRSConfig(
      cards: <Card>[
        Card(cardId: 0, due: now.subtract(const Duration(minutes: 5))),
        Card(cardId: 1, due: now.add(const Duration(days: 1))),
      ],
    );

    expect(FSRS().getOverdueCount(), 1);
  });

  test('getForecastCounts 按自然日分桶，逾期计入今天', () {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    FSRS().config = FSRSConfig(
      cards: <Card>[
        Card(cardId: 0, due: now.subtract(const Duration(minutes: 5))),
        Card(cardId: 1, due: today.add(const Duration(days: 1, hours: 12))),
        Card(cardId: 2, due: today.add(const Duration(days: 2, hours: 12))),
        Card(cardId: 3, due: today.add(const Duration(days: 10, hours: 12))),
      ],
    );

    final List<int> week = FSRS().getForecastCounts(7);
    expect(week, hasLength(7));
    expect(week[0], 1, reason: '逾期卡片计入今天');
    expect(week[1], 1);
    expect(week[2], 1);
    expect(week.skip(3).fold<int>(0, (int a, int b) => a + b), 0);

    final List<int> month = FSRS().getForecastCounts(30);
    expect(month, hasLength(30));
    expect(month[10], 1);
  });

  test('无卡片时返回空统计', () {
    FSRS().config = FSRSConfig();

    expect(FSRS().getOverdueCount(), 0);
    expect(FSRS().getForecastCounts(7), everyElement(0));
  });
}
