import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/sub_pages_builder/learning_pages/fsrs_pages.dart';
import 'package:arabic_learning/vars/change_notifier_models.dart';
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
              shadowColor: Colors.transparent,
              fixedSize: Size(mediaQuery.size.width * 0.9, mediaQuery.size.height * 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0)),
              ),
            ),
            onPressed: () {
              shiftToStudy(context, 0);
            },
            child: Container(
              width: mediaQuery.size.width * 0.9,
              height: mediaQuery.size.height * 0.2,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sync_alt, size: 24.0),
                  Text(
                    '中阿混合学习',
                    style: TextStyle(fontSize: 40.0, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: mediaQuery.size.height * 0.01),
                  Text(
                    '还有${(context.read<Global>().wordCount - context.read<Global>().settingData["learning"]["KnownWords"].length).toString()}个单词待学习~',
                    style: TextStyle(fontSize: 12.0),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: mediaQuery.size.height * 0.01),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
                  // foregroundColor: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                  shadowColor: Colors.transparent,
                  fixedSize: Size(mediaQuery.size.width * 0.42, mediaQuery.size.height * 0.18),
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
              Column(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withAlpha(150),
                      foregroundColor: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                      shadowColor: Colors.transparent,
                      fixedSize: Size(mediaQuery.size.width * 0.42, mediaQuery.size.height * 0.09),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(top: Radius.circular(25.0))),
                    ),
                    onPressed: () {
                      shiftToStudy(context, 2);
                    }, 
                    icon: Icon(Icons.arrow_back, size: 24.0),
                    label: FittedBox(fit: BoxFit.fitWidth ,child: Text("阿译中学习", style: TextStyle(fontSize: 32.0))),
                  ),
                  SizedBox(height: mediaQuery.size.height * 0.005),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withAlpha(150),
                      foregroundColor: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                      shadowColor: Colors.transparent,
                      fixedSize: Size(mediaQuery.size.width * 0.42, mediaQuery.size.height * 0.09),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0))),
                    ),
                    onPressed: () {
                      shiftToStudy(context, 1);
                    }, 
                    icon: Icon(Icons.arrow_forward, size: 24.0),
                    label: FittedBox(fit: BoxFit.fitWidth ,child: Text("中译阿学习", style: TextStyle(fontSize: 32.0))),
                  ),
                ],
              ),
              
            ]
          ),
          SizedBox(height: mediaQuery.size.height * 0.05),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withAlpha(150),
              shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
              fixedSize: Size(mediaQuery.size.width * 0.9, mediaQuery.size.height * 0.2)
            ),
            onPressed: () {
              popSelectClasses(context, withCache: true);
            },
            child: FittedBox(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list, size: 24.0),
                  SizedBox(width: 10.0),
                  Text("选择课程", style: TextStyle(fontSize: 36.0)),
                ],
              ),
            )
          ),
        ]
      )
    );
  }
}


Future<void> shiftToStudy(BuildContext context, int studyType) async {
  List<Map<String, dynamic>> words = getSelectedWords(context, doShuffle: true, doDouble: studyType == 0);
  if(!context.mounted){
    return;
  }
  if(words.isEmpty){ 
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('请先选择你要学习的课程'),
        duration: Duration(seconds: 2),
      ),
    );
    await popSelectClasses(context, withCache: true);
    if(!context.mounted) return;
    words = getSelectedWords(context, doShuffle: true, doDouble: studyType == 0);
    if(words.isEmpty) return;
  }
  final valSetter = AreYouFinishedModel();
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChangeNotifierProvider.value(
        value: valSetter,
        child: InLearningPage(studyType: studyType, words: words,)
      ),
    ),
  );
  if(valSetter.finished && context.mounted) {
    context.read<Global>().saveLearningProgress(words);
  }
}

