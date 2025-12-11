import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:arabic_learning/sub_pages_builder/test_pages/listening_test_page.dart';

class TestPage extends StatelessWidget {
  const TestPage({super.key});
  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建TestPage");
    final mediaQuery = MediaQuery.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: mediaQuery.size.height * 0.05),
        ElevatedButton.icon(
          icon: Icon(Icons.multitrack_audio, size: 36.0),
          label: FittedBox(child: Text('自主听写', style: TextStyle(fontSize: 34.0))),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
            fixedSize: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: StaticsVar.br,
            ),
          ),
          onPressed: () {
            context.read<Global>().uiLogger.info("跳转: TestPage => ForeListeningSettingPage");
            Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => ForeListeningSettingPage()
              )
            );
          },
        ),
      ],
    );
  }
}
