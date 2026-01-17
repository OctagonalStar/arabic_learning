import 'package:arabic_learning/sub_pages_builder/setting_pages/questions_setting_page.dart' show QuestionsSettingPage;
import 'package:arabic_learning/vars/config_structure.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:arabic_learning/sub_pages_builder/learning_pages/fsrs_pages.dart' show ForeFSRSSettingPage;
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
                    fixedSize: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.2),
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
                fixedSize: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: StaticsVar.br,
                ),
              ),
              onPressed: (){
                context.read<Global>().uiLogger.info("跳转: LearningPage => ForeFSRSSettingPage");
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => ForeFSRSSettingPage()
                  )
                );
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
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
            fixedSize: Size(mediaQuery.size.width * 0.7, mediaQuery.size.height * 0.2),
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
          label: Text("词汇总览", style: TextStyle(fontSize: 40.0, fontWeight: FontWeight.bold)),
        ),
      ]
    );
  }
}


Future<void> shiftToStudy(BuildContext context) async {
  context.read<Global>().uiLogger.info("准备转向学习页面");
  final List<ClassItem> selectedClasses = await popSelectClasses(context, withCache: false);
  if(selectedClasses.isEmpty || !context.mounted) return;
  final List<WordItem> words = getSelectedWords(context, doShuffle: false, doDouble: false, forceSelectClasses: selectedClasses);
  context.read<Global>().uiLogger.info("完成单词挑拣，共${words.length}个");
  if(words.isEmpty) return;
  context.read<Global>().uiLogger.info("跳转: LearningPage => InLearningPage");
  final bool? finished = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => InLearningPage(words: words),
    ),
  );
  if(!context.mounted) return;
  context.read<Global>().uiLogger.info("返回完成情况: $finished");
  if(finished??false) {
    context.read<Global>().updateLearningStreak();
  }
}

