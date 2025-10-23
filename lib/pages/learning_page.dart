import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
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
              backgroundColor: Theme.of(context).colorScheme.onPrimary,
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
                  backgroundColor: Theme.of(context).colorScheme.onPrimary,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  shadowColor: Colors.transparent,
                  fixedSize: Size(mediaQuery.size.width * 0.42, mediaQuery.size.height * 0.18),
                  shape: RoundedRectangleBorder(
                    borderRadius: StaticsVar.br,
                  ),
                ),
                onPressed: (){
                  // TODO: #5 to ant-forget page
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => InDevelopingPage()
                    )
                  );
                },
                icon: Icon(Icons.history_edu, size: 24.0),
                label: FittedBox(fit: BoxFit.fitWidth ,child: Text("抗遗忘学习", style: TextStyle(fontSize: 32.0))),
              ),
              Column(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
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
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
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
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
              fixedSize: Size(mediaQuery.size.width * 0.9, mediaQuery.size.height * 0.2)
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChangeNotifierProvider(
                    create: (_) => ClassSelectModel()..init(),
                    child: ClassSelector(),
                  ),
                ),
              );
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


void shiftToStudy(BuildContext context, int studyType) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString("tempConfig") ?? jsonEncode(StaticsVar.tempConfig);
  final courseList = (jsonDecode(jsonString)["SelectedClasses"] as List)
      .cast<List>()
      .map((e) => e.cast<String>().toList())
      .toList();
  if(!context.mounted){
    return;
  }
  if(courseList.isEmpty){ 
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('请先选择你要学习的课程'),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => ClassSelectModel()..init(),
          child: ClassSelector(),
        ),
      ),
    );
    return ;
  }
  PageCounterModel valSetter = PageCounterModel(courseList: courseList, wordData: context.read<Global>().wordData, isMixStudy: studyType == 0);
  valSetter.init();
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChangeNotifierProvider.value(
        value: valSetter,
        child: InLearningPage(studyType: studyType,)
      ),
    ),
  ) as List<String>?;
  if(valSetter.finished && context.mounted) {
    context.read<Global>().saveLearningProgress(valSetter.selectedWords);
  }
}


// 学习主入口页面
class InLearningPage extends StatefulWidget {
  final int studyType; // 0:Mix 1: 中译阿 2: 阿译中
  const InLearningPage({super.key, required this.studyType});
  @override
  State<InLearningPage> createState() => _InLearningPageState();
}

class _InLearningPageState extends State<InLearningPage> {
  Random rnd = Random();
  List<int> testedAr = [];
  List<int> testedCh = [];
  List<Widget> buildedCache = [];
  @override
  Widget build(BuildContext context) {
    final int total = context.read<PageCounterModel>().totalPages;
    final mediaQuery = MediaQuery.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ElevatedButton(
              onPressed: (){
                showDialog(
                  context: context, 
                  builder: (context) {
                    return AlertDialog(
                      title: Text("提示"),
                      content: Text("确定要结束学习吗？"),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text("取消"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          child: Text("确定"),
                        )
                      ],
                    );
                  },
                );
              },
              child: Icon(
                Icons.close,
                size: 24.0,
                semanticLabel: 'Back',
              )
            ),
            SizedBox(width: mediaQuery.size.width * 0.01),
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0.00,
                  end: context.read<PageCounterModel>().currentPage / (total - 1),
                ),
                duration: const Duration(milliseconds: 500),
                curve: StaticsVar.curve,
                builder: (context, value, child) {
                  return LinearProgressIndicator(
                    value: 0.05 + value * 0.95,
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    color: Theme.of(context).colorScheme.secondary,
                    minHeight: mediaQuery.size.height * 0.04,
                    borderRadius: StaticsVar.br,
                  );
                },
              )
            ),
            SizedBox(
              width: mediaQuery.size.width * 0.05,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text("${total - context.watch<PageCounterModel>().currentPage}"),
              ),
            )
          ],
        ),
      ),
      body: Center(
        child: PageView.builder(
          scrollDirection: Provider.of<Global>(context).isWideScreen ? Axis.vertical : Axis.horizontal,
          physics: NeverScrollableScrollPhysics(),
          itemCount: total,
          controller: context.read<PageCounterModel>().controller,
          onPageChanged: (index) {
            context.read<PageCounterModel>().setPage(index);
          },
          itemBuilder: (context, index) {
            if(index < buildedCache.length) return buildedCache[index];
            Map<String, dynamic> wordData = Provider.of<Global>(context).wordData;
            List<int> selectedWords = context.read<PageCounterModel>().selectedWords; // 已选择的单词 [int: 在词库中的索引]
            int t = selectedWords[index]; // 正确答案在词库中的索引
            late bool testType; // true: 中文->阿拉伯, false: 阿拉伯->中文
            if(widget.studyType == 0) {
              if (testedAr.contains(t)) {
                testType = true;
              } else if(testedCh.contains(t)){
                testType = false;
              } else {
                testType = rnd.nextBool();
                if (testType) {
                  testedCh.add(t);
                } else {
                  testedAr.add(t);
                }
              }
            } else if (widget.studyType == 1) {
              testType = true;
            } else {
              testType = false;
            }
            context.read<PageCounterModel>().currentType = testType;
            List<String> strList = [];
            int aindex = rnd.nextInt(4); // 正确答案在选项中的索引
            List<int> rndLst = [t]; // 已抽取的索引
            for (int i = 0; i < aindex; i++) {
              int r = selectedWords[rnd.nextInt(total)];
              while (rndLst.contains(r)){
                r = selectedWords[rnd.nextInt(total)];
              }
              rndLst.add(r);
              strList.add(wordData["Words"][r][testType ? "arabic" : "chinese"]);
            }
            strList.add(wordData["Words"][t][testType ? "arabic" : "chinese"]);
            for (int i = aindex + 1; i < 4; i++) {
              int r = selectedWords[rnd.nextInt(total)];
              while (rndLst.contains(r)){
                r = selectedWords[rnd.nextInt(total)];
              }
              rndLst.add(r);
              strList.add(wordData["Words"][r][testType ? "arabic" : "chinese"]);
            }
            Widget learningPageWidget = Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: questionConstructer(context, 
                                          aindex,
                                          [
                                            wordData["Words"][t][testType ? "chinese" : "arabic"], // 0
                                            ...strList, // 1 2 3 4
                                            wordData["Words"][t]["explanation"], // 5
                                            wordData["Words"][t]["subClass"], // 6
                                            t.toString(),
                                          ],
                                          testType));
            buildedCache.add(learningPageWidget);
            return learningPageWidget;
          },
        )
      )
    );
  }
}


class ClassSelector extends StatelessWidget { 
  const ClassSelector({super.key});
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    if(!context.watch<ClassSelectModel>().initialized) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('选择特定课程单词'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: classesSelectionList(context, mediaQuery)
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              fixedSize: Size(mediaQuery.size.width, mediaQuery.size.height * 0.1),
              shape: ContinuousRectangleBorder(borderRadius: StaticsVar.br),
            ),
            child: Text('确认'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

List<Widget> classesSelectionList(BuildContext context, MediaQueryData mediaQuery) {
  Map<String, dynamic> wordData = context.read<Global>().wordData;
  List<Widget> widgetList = [];
  for (String sourceName in wordData["Classes"].keys) {
    widgetList.add(
      Container(
        margin: EdgeInsets.all(16.0),
        padding: EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onPrimary,
          borderRadius: StaticsVar.br,
        ),
        child: Text(
          sourceName,
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
    bool isEven = true;
    for(String className in wordData["Classes"][sourceName].keys){
      widgetList.add(
        Container(
          margin: EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isEven ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: CheckboxListTile(
            title: Text(className),
            value: context.watch<ClassSelectModel>().selectedClasses.any((e) => e[0] == sourceName && e[1] == className,),
            onChanged: (value) {
              value! ? context.read<ClassSelectModel>().addClass([sourceName, className]) 
                      : context.read<ClassSelectModel>().removeClass([sourceName, className]);
            },
          ),
        ),
      );
      isEven = !isEven;
    }
  }
  if(widgetList.isEmpty) {
    widgetList.add(
      Center(child: Text('啥啥词库都没导入，你学个啥呢？\n自己去 设置 -> 数据设置 -> 导入词库', style: TextStyle(fontSize: 24.0, color: Colors.redAccent),))
    );
  }
  return widgetList;
}