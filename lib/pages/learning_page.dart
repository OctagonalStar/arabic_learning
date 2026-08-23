import 'dart:math';

import 'package:arabic_learning/funcs/fsrs_func.dart';
import 'package:arabic_learning/sub_pages_builder/setting_pages/questions_setting_page.dart' show QuestionsSettingPage;
import 'package:arabic_learning/vars/config_structure.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/sub_pages_builder/learning_pages/fsrs_pages.dart' show FSRSLearningPage, ForeFSRSSettingPage;
import 'package:arabic_learning/sub_pages_builder/learning_pages/learning_pages_build.dart';

class LearningPage extends StatelessWidget {
  const LearningPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 LearningPage");
    final mediaQuery = MediaQuery.of(context);

    return Column(
      children: [
        SizedBox(height: mediaQuery.size.height * 0.05),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                Button(
                  backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
                  size: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(top: Radius.circular(25.0))),
                  onPressed: () {
                    shiftToStudy(context);
                  },
                  icon: Icon(Icons.task_alt),
                  iconDirection: AxisDirection.up,
                  child: Expanded(
                    child: FittedBox(
                      child: Text('学习',style: TextStyle(fontSize: 40.0, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                Button(
                  backgroundColor: Theme.of(context).colorScheme.onSecondary.withAlpha(150),
                  size: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0))),
                  onPressed: (){
                    context.read<Global>().uiLogger.info("跳转: SettingPage => QuestionsSettingPage");
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => QuestionsSettingPage()));
                  }, 
                  icon: Icon(Icons.quiz),
                  child: Text("配置题型"),
                )
              ],
            ),
            Button(
              backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
              size: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.25),
              onPressed: (){
                context.read<Global>().uiLogger.info("跳转: LearningPage => ForeFSRSSettingPage");
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => ForeFSRSSettingPage()
                  )
                );
              },
              icon: Icon(Icons.history_edu),
              iconDirection: AxisDirection.up,
              child: Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text("复习",style: TextStyle(fontSize: 40.0, fontWeight: FontWeight.bold))
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: mediaQuery.size.height * 0.05),
        if(FSRS().config.pushAmount != 0) Button(
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          size: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.15),
          onPressed: (){
            if(AppData().wordData.words.isEmpty) {
              showSnackBar(context, "词库为空，无法推送！请先导入词库");
              return;
            }
            final DateTime now = DateTime.now();
            final int seed = now.year * 10000 + now.month * 100 + now.day;
            final Set<WordItem> pushWords = {};
            final Random rnd = Random(seed);
            int tries = 0;
            while(pushWords.length < FSRS().config.pushAmount && tries < FSRS().config.pushAmount * 10){
              int chosen = rnd.nextInt(AppData().wordData.words.length);
              DateTime? cardBirthday = FSRS().getCardBirthday(chosen);
              if(cardBirthday == null || cardBirthday.difference(DateTime.now()).inDays == 0) {
                pushWords.add(AppData().wordData.words.elementAt(chosen));
              }
              tries++;
            }
            pushWords.removeWhere((WordItem item) => FSRS().isContained(item.id));
            if(pushWords.isEmpty) {
              showSnackBar(context, "今日的推送已完成");
              return;
            }
            context.read<Global>().uiLogger.info("跳转: LearningPage => FSRSLearningPage");
            Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => FSRSLearningPage(fsrs: FSRS(), words: pushWords.toList())
              )
            );
          },
          icon: Icon(Icons.push_pin, size: 24),
          child: Expanded(child: FittedBox(child: Text("学习推送单词", style: TextStyle(fontSize: 40.0)))),
        ),
        SizedBox(height: mediaQuery.size.height * 0.05),
        Button(
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          size: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.2),
          onPressed: (){
            context.read<Global>().uiLogger.info("跳转: LearningPage => WordCardOverViewPage");
            Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => WordCardOverViewPage()
              )
            );
          },
          icon: Icon(Icons.abc, size: 24),
          child: Text("词汇总览", style: TextStyle(fontSize: 40.0)),
        ),
      ]
    );
  }
}


Future<void> shiftToStudy(BuildContext context) async {
  context.read<Global>().uiLogger.info("准备转向学习页面");
  final ClassSelection classSelection = await popSelectClasses(context, withCache: false, withReviewChoose: true);
  if(classSelection.selectedClass.isEmpty || !context.mounted) return;
  final List<WordItem> words = getSelectedWords(AppData().wordData, classSelection.selectedClass, doShuffle: false, doDouble: false);
  context.read<Global>().uiLogger.info("完成单词挑拣，共${words.length}个");
  if(words.isEmpty) return;
  context.read<Global>().uiLogger.info("跳转: LearningPage => InLearningPage");
  final bool? finished = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => InLearningPage(words: words, countInReview: classSelection.countInReview),
    ),
  );
  if(!context.mounted) return;
  context.read<Global>().uiLogger.info("返回完成情况: $finished");
  if(finished??false) {
    context.read<Global>().updateLearningStreak();
  }
}

