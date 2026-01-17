import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/vars/config_structure.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class QuestionsSettingPage extends StatefulWidget {
  const QuestionsSettingPage({super.key});

  @override
  State<StatefulWidget> createState() => _QuestionsSettingPage();
}

class _QuestionsSettingPage extends State<QuestionsSettingPage> {
  List<dynamic>? selectedTypes;
  bool floatButtonFlod = true;
  static const Map<int, String> castMap = {0: "单词卡片学习", 1: "中译阿 选择题", 2: "阿译中 选择题", 3: "中译阿 拼写题"};


  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 QuestionsSettingPage:$selectedTypes");
    late final SubQuizConfig section;
    section = context.read<Global>().globalConfig.quiz.zhar;
    MediaQueryData mediaQuery = MediaQuery.of(context);
    selectedTypes ??= section.questionSections;
    List<Widget> listTiles = [];
    bool isEven = true;
    for(int index = 0; index < selectedTypes!.length; index++) {
      listTiles.add(
        Container(
          key: Key(index.toString()),
          padding: EdgeInsets.all(8.0),
          // margin: EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            color: isEven ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSecondary,
            borderRadius: BorderRadius.all(Radius.circular(16.0))
          ),
          height: mediaQuery.size.height * 0.08,
          child: Row(
            children: [
              Expanded(child: Text(castMap[selectedTypes![index]] ?? "未知类型")),
              IconButton(
                onPressed: (){
                  if(selectedTypes!.length == 1) {
                    alart(context, "至少保留一项");
                  } else {
                    context.read<Global>().uiLogger.fine("移除题型项目: $index");
                    setState(() {
                      selectedTypes!.removeAt(index.toInt());
                    });
                  }
                }, 
                icon: Icon(Icons.delete)
              ),
              SizedBox(width: mediaQuery.size.width * 0.1)
            ],
          ),
        )
      );
      isEven = !isEven;
    }
    

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        context.read<Global>().updateSetting(refresh: false);
      },
      child: Scaffold(
        appBar: AppBar(title: Text("题型配置")),
        body: Column(
          children: [
            if(!context.read<Global>().isWideScreen) TextContainer(text: "长按可拖动排序", style: TextStyle(color: Colors.grey), animated: true),
            Expanded(
              child: ReorderableListView(
                onReorder: (oldIndex, newIndex) {
                  context.read<Global>().uiLogger.info("重排题型项目: $oldIndex => $newIndex");
                  setState(() {
                    if(oldIndex < newIndex) newIndex--; // 修正索引
                    int old = selectedTypes!.removeAt(oldIndex);
                    selectedTypes!.insert(newIndex, old);
                  });
                },
                children: listTiles, 
              ),
            ),
            Row(
              children: [
                Switch(
                  value: section.shuffleInternaly, 
                  onChanged: (value) {
                    context.read<Global>().uiLogger.info("题型内题目乱序: $value");
                    setState(() {
                      context.read<Global>().globalConfig = context.read<Global>().globalConfig.copyWith(
                        quiz: context.read<Global>().globalConfig.quiz.copyWith(
                          zhar: context.read<Global>().globalConfig.quiz.zhar.copyWith(
                            shuffleInternaly: value
                          )
                        )
                      );
                    });
                  }
                ),
                Expanded(child: Text("题型内题目乱序")),
              ],
            ),
            Row(
              children: [
                Switch(
                  value: section.shuffleExternaly, 
                  onChanged: (value) {
                    context.read<Global>().uiLogger.info("题型乱序: $value");
                    setState(() {
                      context.read<Global>().globalConfig = context.read<Global>().globalConfig.copyWith(
                        quiz: context.read<Global>().globalConfig.quiz.copyWith(
                          zhar: context.read<Global>().globalConfig.quiz.zhar.copyWith(
                            shuffleExternaly: value
                          )
                        )
                      );
                    });
                  }
                ),
                Expanded(child: Text("题型乱序")),
              ],
            ),
            Row(
              children: [
                Switch(
                  value: section.shuffleGlobally, 
                  onChanged: (value) {
                    context.read<Global>().uiLogger.info("全局乱序: $value");
                    setState(() {
                      context.read<Global>().globalConfig = context.read<Global>().globalConfig.copyWith(
                        quiz: context.read<Global>().globalConfig.quiz.copyWith(
                          zhar: context.read<Global>().globalConfig.quiz.zhar.copyWith(
                            shuffleGlobally: value
                          )
                        )
                      );
                    });
                  }
                ),
                Expanded(child: Text("全局乱序")),
              ],
            ),
            Row(
              children: [
                Switch(
                  value: section.preferSimilar, 
                  onChanged: (value) {
                    context.read<Global>().uiLogger.info("偏好相似: $value");
                    setState(() {
                      context.read<Global>().globalConfig = context.read<Global>().globalConfig.copyWith(
                        quiz: context.read<Global>().globalConfig.quiz.copyWith(
                          zhar: context.read<Global>().globalConfig.quiz.zhar.copyWith(
                            preferSimilar: value
                          )
                        )
                      );
                    });
                  }
                ),
                Expanded(child: Text("偏好易混词而非同课词")),
              ],
            )
          ],
        ),
        floatingActionButton: TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0.0,
            end: floatButtonFlod ? 0.0 : 1.0
          ), 
          duration: Duration(milliseconds: 500),
          curve: Curves.bounceOut, 
          builder: (context, value, child) {
            return Container(
              // width: mediaQuery.size.width * 0.07 + mediaQuery.size.width * 0.1 * value,
              // height: mediaQuery.size.height * 0.1 + mediaQuery.size.height * 0.45 * value, //实际稍高一些 避免默认margin导致的溢出
              decoration: BoxDecoration(
                color: Colors.transparent,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if(value > 0.3) ...List.generate(4, (i) {
                    return ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        fixedSize: Size(70 + 150 * value, mediaQuery.size.height * 0.1 * value),
                        backgroundColor: Theme.of(context).colorScheme.onPrimary,
                        shape: i == 0 ? RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(top: Radius.circular(25.0))) : BeveledRectangleBorder()
                      ),
                      onPressed: (){
                        context.read<Global>().uiLogger.info("添加题型类型: $i");
                        setState(() {
                          selectedTypes!.add(i);
                        });
                      }, 
                      icon: Icon(Icons.add),
                      label: FittedBox(child: Text("添加 ${castMap[i]}")),
                    );
                  }),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      fixedSize: Size(70 + 150 * value, 70),
                      backgroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0), top: value < 0.4 ? Radius.circular(25.0) : Radius.zero))
                    ),
                    onPressed: (){
                      context.read<Global>().uiLogger.fine("切换题型悬浮按钮状态");
                      setState(() {
                        floatButtonFlod = !floatButtonFlod;
                      });
                    }, 
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(value > 0.5 ?  Icons.deselect : Icons.add), 
                        if(value > 0.5) FittedBox(child: Text("收起"))
                      ],
                    ),
                  )
                ],
              ),
            );
          }
        )
      ),
    );
  }
}

