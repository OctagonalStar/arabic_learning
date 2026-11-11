import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/widgets/review_forecast_chart.dart';
import 'package:fsrs/fsrs.dart' show Card;
import 'package:flutter/material.dart' hide Card;
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

  setUp(() {
    FSRS().config = FSRSConfig();
  });

  Widget host() => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReviewForecastChart(width: 300, height: 160),
          ),
        ),
      );

  testWidgets('无复习计划时显示空状态，窄卡片不溢出', (WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('暂无复习计划'), findsOneWidget);
    for (final int d in ReviewForecastChart.dayOptions) {
      expect(find.text('$d'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('有数据时绘制折线，并可切换 30 天档位', (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    FSRS().config = FSRSConfig(
      cards: <Card>[
        Card(cardId: 0, due: now.subtract(const Duration(hours: 1))),
        Card(cardId: 1, due: now.add(const Duration(days: 3))),
      ],
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('暂无复习计划'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();

    expect(find.text('暂无复习计划'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
