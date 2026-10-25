import 'package:arabic_learning/core/adaptive.dart' show AdaptiveTabBody;
import 'package:arabic_learning/theme/typography.dart';
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/shared.dart' show ButtonLabel;
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/screens/test/reading_test_page.dart' show ReadingTestPage;
class TestPage extends StatelessWidget {
  const TestPage({super.key});
  @override
  Widget build(BuildContext context) {
    // 小程序试用版只保留「阅读理解」入口（无网络/无 TTS，其他测试形式已移除）。
    // 按钮高度仍按 Tab 可用高度推导，矮横屏下自动压缩。
    return AdaptiveTabBody(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double buttonHeight = clampDouble(height * 0.15, 72.0, 180.0);
        return Center(
          child: Button(
            // 阅读理解入口：用“翻开的书”图标。
            icon: Icon(Icons.auto_stories, size: 36.0),
            size: Size(width * 0.6, buttonHeight),
            onPressed: () {
              context.read<Global>().uiLogger.info("跳转: TestPage => ReadingTestLeading");
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => ReadingTestPage()
                )
              );
            },
            child: ButtonLabel(child: Text('阅读理解', style: withoutColor(Theme.of(context).textTheme.headlineLarge!))),
          ),
        );
      },
    );
  }
}
