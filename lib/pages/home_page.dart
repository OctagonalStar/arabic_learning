import 'dart:math';

import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/pages/setting_page.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arabic_learning/funcs/fsrs_func.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建HomePage");
    final themeColor = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final FSRS fsrs = FSRS();
    
    return FutureBuilder(
      future: fsrs.init(context: context),
      builder: (context, asyncSnapshot) {
        return Column(
          children: [
            DailyWord(),
            SizedBox(height: mediaQuery.size.height * 0.01),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  width: mediaQuery.size.width * 0.30,
                  height: mediaQuery.size.height * 0.18,
                  margin: EdgeInsets.all(4.0),
                  padding: EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: themeColor.secondaryContainer.withAlpha(150),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.surfaceBright.withAlpha(150),
                        offset: Offset(2, 4),
                        blurRadius: 8.0,
                      ),
                    ],
                    borderRadius: StaticsVar.br,
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('连胜天数', style: TextStyle(fontSize: 12.0)),
                          context.read<Global>().settingData["learning"]["lastDate"] == DateTime.now().difference(DateTime(2025, 11, 1)).inDays
                            ? Icon(Icons.done, size: 15.0, color: Colors.tealAccent)
                            : Icon(Icons.error_outline, size: 15.0, color: Colors.amber, semanticLabel: "今天还没学习~"),
                        ],
                      ),
                      SizedBox(height: mediaQuery.size.height * 0.03),
                      Text(getStrokeDays(context.read<Global>().settingData).toString(), style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(
                  width: mediaQuery.size.width * 0.50,
                  height: mediaQuery.size.height * 0.18,
                  margin: EdgeInsets.all(4.0),
                  padding: EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: themeColor.secondaryContainer.withAlpha(150),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.surfaceBright.withAlpha(150),
                        offset: Offset(2, 4),
                        blurRadius: 8.0,
                      ),
                    ],
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  child: Column(
                    children: [
                      Text('已学词汇', style: TextStyle(fontSize: 12.0)),
                      SizedBox(height: mediaQuery.size.height * 0.03),
                      Text(context.read<Global>().settingData["learning"]["KnownWords"].length.toString(), style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  width: mediaQuery.size.width * 0.50,
                  height: mediaQuery.size.height * 0.18,
                  margin: EdgeInsets.all(4.0),
                  padding: EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: themeColor.secondaryContainer.withAlpha(150),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.surfaceBright.withAlpha(150),
                        offset: Offset(2, 4),
                        blurRadius: 8.0,
                      ),
                    ],
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  child: Column(
                    children: [
                      Text('规律性学习', style: TextStyle(fontSize: 12.0)),
                      SizedBox(height: mediaQuery.size.height * 0.03),
                      asyncSnapshot.hasData ? Text(asyncSnapshot.data??false ? "${fsrs.getWillDueCount().toString()}个待复习" : "未启用", style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold)) : CircularProgressIndicator(),
                    ],
                  ),
                ),
                Container(
                  width: mediaQuery.size.width * 0.30,
                  height: mediaQuery.size.height * 0.18,
                  margin: EdgeInsets.all(4.0),
                  padding: EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: themeColor.secondaryContainer.withAlpha(150),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.surfaceBright.withAlpha(150),
                        offset: Offset(2, 4),
                        blurRadius: 8.0,
                      ),
                    ],
                    borderRadius: StaticsVar.br,
                  ),
                  child: Column(
                    children: [
                      Text('单词总数', style: TextStyle(fontSize: 12.0)),
                      SizedBox(height: mediaQuery.size.height * 0.03),
                      Text(context.read<Global>().wordCount.toString(), style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold))
                    ],
                  ),
                ),
              ]
            )
          ],
        );
      }
    );
  }
}

class DailyWord extends StatefulWidget {
  const DailyWord({super.key});

  @override
  State<StatefulWidget> createState() => _DailyWord();
}


class _DailyWord extends State<DailyWord> {
  bool playing = false;

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建DailyWord组件");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    Random rnd = Random(seed);
    late Map<String, dynamic> data;
    late String dailyWord;
    if(context.read<Global>().wordCount != 0) {
      data = context.read<Global>().wordData["Words"][rnd.nextInt(context.read<Global>().wordCount)];
      dailyWord = data["arabic"];
    }

    return ElevatedButton(
      onPressed: () async {
        if(playing) return;
        if(context.read<Global>().wordCount != 0) {
          playing = true;
          late List<dynamic> temp;
          temp = await playTextToSpeech(dailyWord, context);
          if(!temp[0] && context.mounted) {
            alart(context, temp[1]);
          }
          playing = false;
        } else {
          context.read<Global>().uiLogger.info("跳转: DailyWord => SettingPage");
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => SettingPage()));
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
        shadowColor: Theme.of(context).colorScheme.surfaceBright.withAlpha(150),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(25.0))),
        fixedSize: Size(mediaQuery.size.width * 0.9, mediaQuery.size.height * 0.3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '每日一词',
            style: TextStyle(fontSize: 18.0),
          ),
          SizedBox(height: mediaQuery.size.height * 0.02),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              children: context.read<Global>().wordCount == 0 ? [Text("当前未导入词库数据\n请点此以跳转设置页面导入")]
                : [
                Text(
                  data["arabic"] ?? "读取出错 data:${data.toString()}",
                  style: TextStyle(fontSize: 52.0, fontFamily: context.read<Global>().arFont),
                ),
                SizedBox(height: mediaQuery.size.height * 0.005),
                Text(
                  data["chinese"] ?? "读取出错 data:${data.toString()}",
                  style: TextStyle(fontSize: 18.0),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: mediaQuery.size.height * 0.03),
                Icon(Icons.volume_up, size: 18.0),
              ],
            )
          ),
        ],
      ),
    );
  }
}