import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/favorites.dart' show FavoriteStore;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/widgets/flip_word_card.dart' show FlipWordCard;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

/// 单词卡片右上角收藏星标的行为测试：
/// - 未收藏空心 / 已收藏实心；
/// - 点击星标切换收藏，且不得触发卡片的翻卡展开；
/// - 星标不干扰原有翻卡手势。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const WordItem word = WordItem(
    arabic: 'كِتَابٌ',
    chinese: '书',
    explanation: '书本；书籍',
    className: '第一课',
    id: 2,
  );

  setUpAll(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
  });

  setUp(() {
    // 单例状态在测试间共享，重置内存与存储。
    FavoriteStore().clear();
  });

  Future<void> pumpCard(WidgetTester tester, {double? width, double? height}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<Global>(
        create: (BuildContext context) => Global(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: FlipWordCard(word: word, width: width, height: height),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('未收藏显示空心星；点击后收藏且不触发展开', (WidgetTester tester) async {
    await pumpCard(tester);

    expect(find.byIcon(Icons.star_border), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNothing);

    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pumpAndSettle();

    expect(FavoriteStore().contains(2), isTrue, reason: '点击星标应写入收藏');
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsNothing);
    // 触发展开才会出现的背面提示不应存在：星标点击优先于卡片翻卡手势。
    expect(find.text('点击卡片或空白处关闭'), findsNothing, reason: '点击星标不应触发展开');
    expect(tester.takeException(), isNull);
  });

  testWidgets('已收藏显示实心星；再次点击取消收藏', (WidgetTester tester) async {
    FavoriteStore().toggle(2);
    await pumpCard(tester);

    expect(find.byIcon(Icons.star), findsOneWidget);

    await tester.tap(find.byIcon(Icons.star));
    await tester.pumpAndSettle();

    expect(FavoriteStore().contains(2), isFalse);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
    expect(find.text('点击卡片或空白处关闭'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击卡片主体仍可展开（星标不干扰翻卡）', (WidgetTester tester) async {
    await pumpCard(tester);

    await tester.tap(find.text('点击查看更多信息'));
    await tester.pumpAndSettle();

    expect(find.text('点击卡片或空白处关闭'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('极小的 120x120 网格卡片上星标不溢出', (WidgetTester tester) async {
    await pumpCard(tester, width: 120, height: 120);

    expect(find.byIcon(Icons.star_border), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
