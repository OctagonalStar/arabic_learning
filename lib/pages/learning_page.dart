import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/sub_pages_builder/learning_pages/fsrs_pages.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/sub_pages_builder/learning_pages/learning_pages_build.dart';
import 'package:flutter/material.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:provider/provider.dart';

class LearningPage extends StatelessWidget {
  const LearningPage({super.key});
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
                  shadowColor: Colors.transparent,
                  fixedSize: Size(mediaQuery.size.width * 0.5, mediaQuery.size.height * 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0)),
                  ),
                ),
                onPressed: () {
                  shiftToStudy(context, 0);
                },
                child: FittedBox(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.task_alt, size: 24.0),
                      Text(
                        '综合学习',
                        style: TextStyle(fontSize: 40.0, fontWeight: FontWeight.bold),
                      ),
                      Text("你可以在设置-题型配置页面自行配置题目~", style: TextStyle(color: Colors.grey, fontSize: 8))
                    ],
                  ),
                ),
              ),
              Column(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withAlpha(150),
                      foregroundColor: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                      shadowColor: Colors.transparent,
                      fixedSize: Size(mediaQuery.size.width * 0.35, mediaQuery.size.height * 0.0975),
                      shape: BeveledRectangleBorder(),
                    ),
                    onPressed: () {
                      shiftToStudy(context, 2);
                    }, 
                    icon: Icon(Icons.arrow_back, size: 24.0),
                    label: FittedBox(fit: BoxFit.fitWidth ,child: Text("阿译中专项", style: TextStyle(fontSize: 32.0))),
                  ),
                  SizedBox(height: mediaQuery.size.height * 0.005),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withAlpha(150),
                      foregroundColor: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                      shadowColor: Colors.transparent,
                      fixedSize: Size(mediaQuery.size.width * 0.35, mediaQuery.size.height * 0.0975),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0))),
                    ),
                    onPressed: () {
                      shiftToStudy(context, 1);
                    }, 
                    icon: Icon(Icons.arrow_forward, size: 24.0),
                    label: FittedBox(fit: BoxFit.fitWidth ,child: Text("中译阿专项", style: TextStyle(fontSize: 32.0))),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: mediaQuery.size.height * 0.05),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
                  shadowColor: Colors.transparent,
                  fixedSize: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: StaticsVar.br,
                  ),
                ),
                onPressed: (){
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => ForeFSRSSettingPage()
                    )
                  );
                },
                icon: Icon(Icons.history_edu, size: 24.0),
                label: FittedBox(fit: BoxFit.fitWidth ,child: Text("规律性学习", style: TextStyle(fontSize: 32.0))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
                  shadowColor: Colors.transparent,
                  fixedSize: Size(mediaQuery.size.width * 0.42, mediaQuery.size.height * 0.2),
                  shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
                ),
                onPressed: (){
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => WordCardOverViewPage()
                    )
                  );
                },
                child: FittedBox(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.abc, size: 24),
                      Text("词汇总览", style: TextStyle(fontSize: 40.0, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ), 
              )
            ]
          ),
        ]
      )
    );
  }
}


Future<void> shiftToStudy(BuildContext context, int studyType) async {
  await popSelectClasses(context, withCache: true);
  if(!context.mounted) return;
  final List<Map<String, dynamic>> words = getSelectedWords(context, doShuffle: false, doDouble: false);
  if(words.isEmpty) return;
  final bool? finished = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => InLearningPage(studyType: studyType, words: words),
    ),
  );
  if((finished??false) && context.mounted) {
    context.read<Global>().saveLearningProgress(words);
  }
}

