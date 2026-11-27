import 'package:arabic_learning/widgets/unit_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('统一列表卡展示难度、标题、摘要、标签并可打开', (WidgetTester tester) async {
    int opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnitCard(
            title: "测试文章",
            difficulty: 40,
            subtitle: "3 句",
            tags: const <String>["阅读理解"],
            onOpen: () => opened++,
          ),
        ),
      ),
    );

    expect(find.text("40"), findsOneWidget);
    expect(find.text("测试文章"), findsOneWidget);
    expect(find.text("3 句"), findsOneWidget);
    expect(find.text("阅读理解"), findsOneWidget);

    await tester.tap(find.text("测试文章"));
    expect(opened, 1);
  });

  testWidgets('传入 onDelete 时显示删除菜单', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnitCard(
            title: "课文",
            difficulty: 80,
            subtitle: "2 句",
            onOpen: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
  });
}
