import 'package:arabic_learning/screens/test/recitation/recitation_add_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('课文背诵导入首屏使用共享类型卡且窄屏不溢出', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: RecitationAddPage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text("粘贴 JSON"), findsOneWidget);
    expect(find.text("复制提示词"), findsOneWidget);
    expect(find.text("导入课文"), findsOneWidget);
  });
}
