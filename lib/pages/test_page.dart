import 'package:arabic_learning/funcs/ui.dart' show Button;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/sub_pages_builder/test_pages/listening_test_page.dart' show ForeListeningSettingPage;
import 'package:arabic_learning/sub_pages_builder/test_pages/local_pk_page.dart' show LocalPKSelectPage;
import 'package:arabic_learning/sub_pages_builder/test_pages/reading_test_page.dart' show ReadingTestPage;
class TestPage extends StatelessWidget {
  const TestPage({super.key});
  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 TestPage");
    final mediaQuery = MediaQuery.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: mediaQuery.size.height * 0.05),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Button(
              icon: Icon(Icons.connect_without_contact, size: 36.0),
              size: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.15),
              onPressed: () {
                context.read<Global>().uiLogger.info("跳转: TestPage => LocalPKSelectPage");
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => LocalPKSelectPage()
                  )
                );
              },
              child: FittedBox(child: Text('联机', style: TextStyle(fontSize: 34.0))),
            ),
            Button(
              icon: Icon(Icons.multitrack_audio, size: 36.0),
              size: Size(mediaQuery.size.width * 0.45, mediaQuery.size.height * 0.15),
              onPressed: () {
                context.read<Global>().uiLogger.info("跳转: TestPage => ReadingTestLeading");
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => ReadingTestPage()
                  )
                );
              },
              child: FittedBox(child: Text('阅读理解', style: TextStyle(fontSize: 34.0))),
            ),
          ],
        ),
        SizedBox(height: mediaQuery.size.height * 0.05),
        Button(
          icon: Icon(Icons.multitrack_audio, size: 36.0),
          size: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.1),
          onPressed: () {
            context.read<Global>().uiLogger.info("跳转: TestPage => ForeListeningSettingPage");
            Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => ForeListeningSettingPage()
              )
            );
          },
          child: Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text('自主听写', style: TextStyle(fontSize: 34.0)))),
        ),
      ],
    );
  }
}
