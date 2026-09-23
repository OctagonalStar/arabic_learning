import 'package:arabic_learning/core/adaptive.dart' show AdaptiveTabBody;
import 'package:arabic_learning/theme/typography.dart';
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/shared.dart' show ButtonLabel;
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/screens/test/listening_test_page.dart' show ForeListeningSettingPage;
import 'package:arabic_learning/screens/test/local_pk_page.dart' show LocalPKSelectPage;
import 'package:arabic_learning/screens/test/reading_test_page.dart' show ReadingTestPage;
class TestPage extends StatelessWidget {
  const TestPage({super.key});
  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 TestPage");
    // 按钮高度按 Tab 可用高度推导（原 0.15/0.1 比例），矮横屏下自动压缩。
    return AdaptiveTabBody(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double gap = clampDouble(height * 0.05, 12.0, 40.0);
        final double rowHeight = clampDouble(height * 0.15, 72.0, 180.0);
        final double fullHeight = clampDouble(height * 0.1, 56.0, 130.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Button(
                  icon: Icon(Icons.connect_without_contact, size: 36.0),
                  size: Size(width * 0.4, rowHeight),
                  onPressed: () {
                    context.read<Global>().uiLogger.info("跳转: TestPage => LocalPKSelectPage");
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => LocalPKSelectPage()
                      )
                    );
                  },
                  child: ButtonLabel(child: Text('联机', style: withoutColor(Theme.of(context).textTheme.headlineLarge!))),
                ),
                Button(
                  // 阅读理解入口：用“翻开的书”区别于自主听写的音频图标。
                  icon: Icon(Icons.auto_stories, size: 36.0),
                  size: Size(width * 0.45, rowHeight),
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
              ],
            ),
            SizedBox(height: gap),
            Button(
              icon: Icon(Icons.multitrack_audio, size: 36.0),
              size: Size(width * 0.8, fullHeight),
              onPressed: () {
                context.read<Global>().uiLogger.info("跳转: TestPage => ForeListeningSettingPage");
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => ForeListeningSettingPage()
                  )
                );
              },
              child: ButtonLabel(child: Text('自主听写', style: withoutColor(Theme.of(context).textTheme.headlineLarge!))),
            ),
          ],
        );
      },
    );
  }
}
