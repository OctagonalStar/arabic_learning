import 'dart:convert';
import 'dart:io';

import 'package:arabic_learning/change_notifier_models.dart';
import 'package:arabic_learning/global.dart';
import 'package:arabic_learning/learning_pages_build.dart';
import 'package:flutter/material.dart';
import 'package:arabic_learning/statics_var.dart';
import 'package:path_provider/path_provider.dart';
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
          Container(
            width: mediaQuery.size.width * 0.9,
            height: mediaQuery.size.height * 0.2,
            alignment: Alignment.center,
            margin: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: StaticsVar.br,
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onPrimary,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: StaticsVar.br,
                ),
              ),
              onPressed: () async {
                final directory = await getApplicationDocumentsDirectory();
                final tempConfig = File('${directory.path}/${StaticsVar.tempConfigPath}');
                if (!await tempConfig.exists()) {
                  await tempConfig.create(recursive: true);
                  await tempConfig.writeAsString(jsonEncode(StaticsVar.tempConfig));
                }
                final jsonString = await tempConfig.readAsString();
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MixLearningPage(courseList: courseList),
                  ),
                );
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
                      '还有{int}个单词待学习~',
                      style: TextStyle(fontSize: 12.0),
                    ),
                  ],
                ),
              ),
            )
          ),
          SizedBox(height: mediaQuery.size.height * 0.01),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: mediaQuery.size.width * 0.42,
                height: mediaQuery.size.height * 0.18,
                margin: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: StaticsVar.br,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: StaticsVar.br,
                    ),
                  ),
                  onPressed: () {
                    // TODO: to arabic learning page
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => InDevelopingPage()
                      )
                    );
                  }, 
                  child: Column(
                    children: [
                      Icon(Icons.arrow_back, size: 24.0),
                      Text("阿译中学习", style: TextStyle(fontSize: 32.0)),
                      SizedBox(height: mediaQuery.size.height * 0.01),
                    ],
                  ),
                ),
              ),
              Container(
                width: mediaQuery.size.width * 0.42,
                height: mediaQuery.size.height * 0.18,
                margin: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: StaticsVar.br,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: StaticsVar.br,
                    ),
                  ),
                  onPressed: () {
                    // TODO: to chinese learning page
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => InDevelopingPage()
                      )
                    );
                  },
                  child: Column(
                    children: [
                      Icon(Icons.arrow_forward, size: 24.0),
                      Text("中译阿学习", style: TextStyle(fontSize: 32.0)),
                      SizedBox(height: mediaQuery.size.height * 0.01),
                    ],
                  ),
                )
              )
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


class MixLearningPage extends StatefulWidget {
  final List<List<String>> courseList;
  const MixLearningPage({super.key, required this.courseList});
  @override
  State<MixLearningPage> createState() => _MixLearningPageState();
}

class _MixLearningPageState extends State<MixLearningPage> {
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final globalVar = Provider.of<Global>(context);
    List<int> selectedWords = [];
    for(List<String> c in widget.courseList) {
      selectedWords.addAll(globalVar.wordData["Classes"][c[0]][c[1]].cast<int>());
    }
    final List<Widget> pages = learningPageBuilder(mediaQuery, context, selectedWords..shuffle(), globalVar.wordData);
    return ChangeNotifierProvider<PageCounterModel>(
      create: (_) => PageCounterModel(),
      child: Builder(
        builder: (context) {
          var counter = context.watch<PageCounterModel>();
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
                        begin: 0.0,
                        end: counter.currentPage / (pages.length - 1),
                      ),
                      duration: const Duration(milliseconds: 500),
                      curve: StaticsVar.curve,
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                          color: Theme.of(context).colorScheme.secondary,
                          minHeight: mediaQuery.size.height * 0.04,
                          borderRadius: StaticsVar.br,
                        );
                      },
                    )
                  ),
                ],
              ),
            ),
            body: Center(
              child: PageView.builder(
                scrollDirection: globalVar.isWideScreen ? Axis.vertical : Axis.horizontal,
                physics: NeverScrollableScrollPhysics(),
                itemCount: pages.length,
                controller: counter.controller,
                onPageChanged: (index) {
                  counter.setPage(index);
                },
                itemBuilder: (context, index) {
                  return pages[index];
                },
              )
            )
          );
        }
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
  
  return widgetList;
}