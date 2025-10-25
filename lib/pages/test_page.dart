import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:arabic_learning/sub_pages_builder/test_pages/listening_test_page.dart';
import 'package:flutter/material.dart';

class TestPage extends StatelessWidget {
  const TestPage({super.key});
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              width: mediaQuery.size.width * 0.42,
              height: mediaQuery.size.height * 0.45,
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                borderRadius: StaticsVar.br,
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: StaticsVar.br,
                  ),
                ),
                onPressed: () {
                  // TODO: #3 to write test page
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => InDevelopingPage()
                    )
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.zoom_in, size: 36.0),
                        Icon(Icons.edit, size: 36.0),
                      ],
                    ),
                    Text('认写\n测试', style: TextStyle(fontSize: 34.0, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.multitrack_audio, size: 36.0),
              label: Text('自主\n听写', style: TextStyle(fontSize: 34.0)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onPrimary,
                fixedSize: Size(mediaQuery.size.width * 0.42, mediaQuery.size.height * 0.45,),
                shape: RoundedRectangleBorder(
                  borderRadius: StaticsVar.br,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => ForeListeningSettingPage()
                  )
                );
              },
            )
          ],
        ),
        SizedBox(height: mediaQuery.size.height * 0.005),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              width: mediaQuery.size.width * 0.58,
              height: mediaQuery.size.height * 0.16,
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                borderRadius: StaticsVar.br,
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: StaticsVar.br,
                  ),
                ),
                onPressed: () {
                  // TODO: #4 to history page
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => InDevelopingPage()
                    )
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 36.0),
                    SizedBox(width: 8.0),
                    Text('历史战绩', style: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            Container(
              width: mediaQuery.size.width * 0.32,
              height: mediaQuery.size.height * 0.16,
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                borderRadius: StaticsVar.br,
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: StaticsVar.br,
                  ),
                ),
                onPressed: () {
                  // TODO: #6 to keyboard page
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => InDevelopingPage()
                    )
                  );
                }, 
                child: FittedBox(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.keyboard, size: 24.0),
                      Text('盲打\n测试', style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              )
            )
          ],
        )
      ],
    );
  }
}
