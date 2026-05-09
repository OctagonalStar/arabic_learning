import 'package:arabic_learning/funcs/fsrs_func.dart';
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
        if(FSRS().config.pushAmount != 0) ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
            fixedSize: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.15),
            shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
          ),
          onPressed: (){
            final AppData appData = AppData();
            final FSRS fsrs = FSRS();
            if(appData.wordData.words.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("词库为空，无法推送！请先导入词库"), duration: Duration(seconds: 1)),
              );
              return;
            }

            final bool hasRestrictedClasses = fsrs.config.selectedSources.isNotEmpty;

            // 1. 收集候选词 ID（受限词库 or 全部词库）
            List<int> candidateIds;
            if (hasRestrictedClasses) {
              candidateIds = [];
              for (final source in appData.wordData.classes) {
                if (fsrs.config.selectedSources.contains(source.sourceJsonFileName)) {
                  for (final subclass in source.subClasses) {
                    candidateIds.addAll(subclass.wordIndexs);
                  }
                }
              }
            } else {
              candidateIds = List.generate(appData.wordData.words.length, (i) => i);
            }

            // 2. 过滤掉已加入 FSRS 的词，得到全部可推送的新词
            final List<int> availableIds = candidateIds
                .where((id) => !fsrs.isContained(id))
                .toList();

            if(availableIds.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("所有单词均已加入复习队列，暂无新词可推送"),
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }

            // 3. 随机打乱，取前 min(pushAmount, available) 个
            availableIds.shuffle();
            final int count = availableIds.length < fsrs.config.pushAmount
                ? availableIds.length
                : fsrs.config.pushAmount;
            final List<WordItem> pushWords = availableIds
                .take(count)
                .map((id) => appData.wordData.words[id])
                .toList();

            context.read<Global>().uiLogger.info("跳转: LearningPage => FSRSLearningPage，推送 $count 个新词");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FSRSLearningPage(fsrs: FSRS(), words: pushWords),
              ),
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

