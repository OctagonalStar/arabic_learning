import 'package:arabic_learning/core/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dueDayText 按自然日给出逾期 / 今天 / 天后文案', () {
    final DateTime now = DateTime(2026, 11, 10, 23, 50);
    expect(dueDayText(DateTime(2026, 11, 8, 9), now: now), '已逾期 2 天');
    expect(dueDayText(DateTime(2026, 11, 10, 1), now: now), '今天');
    expect(dueDayText(DateTime(2026, 11, 13, 8), now: now), '3 天后');
  });
}
