import 'package:arabic_learning/statics_var.dart';
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
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: StaticsVar.br,
                  ),
                ),
                onPressed: () {
                  // TODO: to write test page
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.zoom_in, size: 36.0, color: Colors.black),
                        Icon(Icons.edit, size: 36.0, color: Colors.black),
                      ],
                    ),
                    Text('认写\n测试', style: TextStyle(fontSize: 34.0, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            Container(
              width: mediaQuery.size.width * 0.42,
              height: mediaQuery.size.height * 0.45,
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                borderRadius: StaticsVar.br,
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: StaticsVar.br,
                  ),
                ),
                onPressed: () {
                  // TODO: to listen test page
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.earbuds, size: 36.0, color: Colors.black),
                        Icon(Icons.speaker_phone, size: 36.0, color: Colors.black),
                      ],
                    ),
                    Text('听读\n测试', style: TextStyle(fontSize: 34.0, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ],
                ),
              ),
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
                  backgroundColor: Colors.teal,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: StaticsVar.br,
                  ),
                ),
                onPressed: () {
                  // TODO: to history page
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 36.0, color: Colors.black),
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
                  backgroundColor: Colors.indigo,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: StaticsVar.br,
                  ),
                ),
                onPressed: () {
                  // TODO: to keyboard page
                }, 
                child: FittedBox(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.keyboard, size: 24.0, color: Colors.black),
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
