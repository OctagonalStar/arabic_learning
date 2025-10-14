import 'package:arabic_learning/global.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  final void Function(int) toPage;
  const HomePage({super.key, required this.toPage});
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Column(
      children: [
        Container(
          width: mediaQuery.size.width * 0.9,
          height: mediaQuery.size.height * 0.3,
          alignment: Alignment.center,
          margin: EdgeInsets.all(16.0),
          padding: EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(25.0),
          ),
          child: Column(
            children: [
              Text(
                '每日一词',
                style: TextStyle(fontSize: 18.0),
              ),
              SizedBox(height: mediaQuery.size.height * 0.02),
              Text(
                'مرحبا ',
                style: Provider.of<Global>(context, listen: false).settingData["regular"]["font"] == 1 ? GoogleFonts.markaziText(fontSize: 52.0, fontWeight: FontWeight.bold) : TextStyle(fontSize: 52.0, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: mediaQuery.size.height * 0.005),
              Text(
                'Marhaban',
                style: TextStyle(fontSize: 18.0),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: mediaQuery.size.height * 0.005),
              Text(
                '你好',
                style: TextStyle(fontSize: 18.0),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        SizedBox(height: mediaQuery.size.height * 0.01),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: mediaQuery.size.width * 0.32,
              height: mediaQuery.size.height * 0.18,
              margin: EdgeInsets.all(8.0),
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(25.0),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('连胜天数', style: TextStyle(fontSize: 12.0)),
                      Icon(Icons.error_outline, size: 15.0, color: Colors.amber, semanticLabel: "今天还没学习~"),
                    ],
                  ),
                  SizedBox(height: mediaQuery.size.height * 0.03),
                  Text('{int}', style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Container(
              width: mediaQuery.size.width * 0.56,
              height: mediaQuery.size.height * 0.18,
              margin: EdgeInsets.all(8.0),
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(25.0),
              ),
              child: Column(
                children: [
                  Text('已学词汇', style: TextStyle(fontSize: 12.0)),
                  SizedBox(height: mediaQuery.size.height * 0.03),
                  Text('{int}', style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: mediaQuery.size.height * 0.01),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: mediaQuery.size.width * 0.54,
              height: mediaQuery.size.height * 0.18,
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25.0),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: EdgeInsets.all(16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                ),
                onPressed: () {
                  toPage(1);
                },
                child: Column(
                children: [
                  Text("准备好学习了?", style: TextStyle(fontSize: 12.0, color: Colors.white70)),
                  SizedBox(height: mediaQuery.size.height * 0.015),
                  Text('开始学习\n→', style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ),
            Container(
              width: mediaQuery.size.width * 0.34,
              height: mediaQuery.size.height * 0.18,
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25.0),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.all(16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                ),
                onPressed: () {
                  toPage(2);
                },
                child: Column(
                children: [
                  Text("感觉不错?", style: TextStyle(fontSize: 12.0, color: Colors.white70)),
                  SizedBox(height: mediaQuery.size.height * 0.015),
                  Text('开始测试\n→', style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            )
          ],
        ),
      ],
    );
  }
}
