import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/core/date_utils.dart';
import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppRadius;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/overlays.dart' show alart;
import 'package:arabic_learning/widgets/shared.dart' show StatCard;
import 'package:arabic_learning/services/words.dart';
import 'package:arabic_learning/services/tts.dart';
import 'package:arabic_learning/screens/setting/setting_screen.dart';
import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 HomePage");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    FSRS fsrs = FSRS();
    
    return Column(
      children: [
        DailyWord(),
        SizedBox(height: mediaQuery.size.height * 0.01),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            StatCard(
              width: mediaQuery.size.width * 0.30,
              height: mediaQuery.size.height * 0.18,
              spacing: mediaQuery.size.height * 0.03,
              label: '连胜天数',
              value: getStrokeDays(AppData().config.learning).toString(),
              statusIcon: AppData().config.learning.lastDate == daysSinceEpoch()
                ? Icon(Icons.done, size: 15.0, color: context.semanticColors.success)
                : Icon(Icons.error_outline, size: 15.0, color: context.semanticColors.warning),
            ),
            StatCard(
              width: mediaQuery.size.width * 0.50,
              height: mediaQuery.size.height * 0.18,
              spacing: mediaQuery.size.height * 0.03,
              label: '已学词汇',
              value: fsrs.config.enabled ? fsrs.config.cards.length.toString() : "未启用",
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            StatCard(
              width: mediaQuery.size.width * 0.50,
              height: mediaQuery.size.height * 0.18,
              spacing: mediaQuery.size.height * 0.03,
              label: '规律性学习',
              value: fsrs.config.enabled ? "${fsrs.getWillDueCount().toString()}个待复习" : "未启用",
            ),
            StatCard(
              width: mediaQuery.size.width * 0.30,
              height: mediaQuery.size.height * 0.18,
              spacing: mediaQuery.size.height * 0.03,
              label: '单词总数',
              value: AppData().wordCount.toString(),
            ),
          ]
        )
      ],
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
    context.read<Global>().uiLogger.fine("构建 DailyWord组件");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    Random rnd = Random(seed);
    late WordItem data;
    late String dailyWord;
    AppData appData = AppData();
    if(appData.wordCount != 0) {
      data = appData.wordData.words[rnd.nextInt(appData.wordCount)];
      dailyWord = data.arabic;
    }

    return Button(
      onPressed: () async {
        if(playing) return;
        if(appData.wordCount != 0) {
          setState(() {
            playing = true;
          });
          try {
            await playTextToSpeech(dailyWord);
          } catch (e) {
            if(context.mounted) alart(context, e.toString());
          }
          setState(() {
            playing = false;
          });
        } else {
          context.read<Global>().uiLogger.info("跳转: DailyWord => SettingPage");
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => Scaffold(appBar: AppBar(title: Text("设置")) , body: SettingPage())));
        }
      },
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.card))),
      size: Size(mediaQuery.size.width * 0.9, mediaQuery.size.height * 0.3),
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
              children: AppData().wordCount == 0 ? [Text("当前未导入词库数据\n请点此以跳转设置页面导入")]
                : [
                Text(
                  data.arabic,
                  style: TextStyle(fontSize: 52.0, fontFamily: context.read<Global>().arFont),
                ),
                SizedBox(height: mediaQuery.size.height * 0.005),
                Text(
                  data.chinese,
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