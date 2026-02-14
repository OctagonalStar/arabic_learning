import 'dart:math';

import 'package:arabic_learning/sub_pages_builder/setting_pages/questions_setting_page.dart' show QuestionsSettingPage;
import 'package:arabic_learning/vars/config_structure.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
                    fixedSize: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(top: Radius.circular(25.0))),
                  ),
                  onPressed: () {
                    shiftToStudy(context);
                  },
                  child: FittedBox(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.task_alt),
                        Text('学习',style: TextStyle(fontSize: 40.0, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.onSecondary.withAlpha(150),
                    fixedSize: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0)))
                  ),
                  onPressed: (){
                    context.read<Global>().uiLogger.info("跳转: SettingPage => QuestionsSettingPage");
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => QuestionsSettingPage()));
                  }, 
                  icon: Icon(Icons.quiz),
                  label: Text("配置题型"),
                )
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
                fixedSize: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.25),
                shape: RoundedRectangleBorder(
                  borderRadius: StaticsVar.br,
                ),
              ),
              onPressed: (){
                if(context.read<Global>().globalFSRS.getWillDueCount() != 0) {
                  context.read<Global>().uiLogger.info("跳转: LearningPage => ForeFSRSSettingPage");
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => ForeFSRSSettingPage()
                    )
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("目前没有要复习的单词"), duration: Duration(seconds: 1),),
                  );
                }
              },
              child: FittedBox(
                fit: BoxFit.contain,
                child: Column(
                  children: [
                    Icon(Icons.history_edu),
                    Text("复习",style: TextStyle(fontSize: 40.0, fontWeight: FontWeight.bold)),
                  ],
                )
              ),
            ),
          ],
        ),
        SizedBox(height: mediaQuery.size.height * 0.05),
        if(context.read<Global>().globalFSRS.config.pushAmount != 0) ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
            fixedSize: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.15),
            shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
          ),
          onPressed: (){
            final DateTime now = DateTime.now();
            final int seed = now.year * 10000 + now.month * 100 + now.day;
            final List<WordItem> pushWords = [];
            final Random rnd = Random(seed);
            for(int i = 0; i < context.read<Global>().globalFSRS.config.pushAmount; i++){
              int chosen = rnd.nextInt(context.read<Global>().wordData.words.length);
              if(!context.read<Global>().globalFSRS.isContained(chosen)) {
                pushWords.add(context.read<Global>().wordData.words.elementAt(chosen));
              }
            }
            if(pushWords.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("今日的推送已完成"), duration: Duration(seconds: 1),),
              );
              return;
            }
            context.read<Global>().uiLogger.info("跳转: LearningPage => FSRSLearningPage");
            Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => FSRSLearningPage(fsrs: context.read<Global>().globalFSRS, words: pushWords)
              )
            );
          },
          icon: Icon(Icons.push_pin, size: 24),
          label: FittedBox(child: Text("学习推送单词", style: TextStyle(fontSize: 40.0))),
        ),
        SizedBox(height: mediaQuery.size.height * 0.05),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
            fixedSize: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.2),
            shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
          ),
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
          label: Text("词汇总览", style: TextStyle(fontSize: 40.0)),
        ),
      ]
    );
  }
}


Future<void> shiftToStudy(BuildContext context) async {
  context.read<Global>().uiLogger.info("准备转向学习页面");
  final ClassSelection classSelection = await popSelectClasses(context, withCache: false, withReviewChoose: true);
  if(classSelection.selectedClass.isEmpty || !context.mounted) return;
  final List<WordItem> words = getSelectedWords(context, doShuffle: false, doDouble: false, forceSelectClasses: classSelection.selectedClass);
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

