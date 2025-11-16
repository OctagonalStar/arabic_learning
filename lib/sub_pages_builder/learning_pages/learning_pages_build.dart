import 'dart:math';

import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/change_notifier_models.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:flutter/material.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:provider/provider.dart';



// 学习主入口页面
class InLearningPage extends StatefulWidget {
  final int studyType;
  /*
  题型说明 
    0: 单词卡片
    1: 中译阿 选择题
    2: 阿译中 选择题
    3: 中译阿 拼写题
  */
  final List<Map<String, dynamic>> words;
  const InLearningPage({super.key, required this.studyType, required this.words});
  @override
  State<InLearningPage> createState() => _InLearningPageState();
}

class _InLearningPageState extends State<InLearningPage> {
  Random rnd = Random();
  List<List<dynamic>> testList = []; // [[word(Map), testType(int), [extraValues]]]
  bool clicked = false;
  int currentPage = 0;
  int correctCount = 0;
  late final int startTime;
  bool finished = false;
  late final int total;
  final PageController controller = PageController(initialPage: 0);

  @override
  void initState() {
    // 加载测试词
    List<dynamic> questionsSetting = context.read<Global>().settingData["quiz"][widget.studyType == 0 ? "zh_ar" : widget.studyType == 1 ? "zh" : "ar"];
    List<List<dynamic>> questionsInSections = List.filled(questionsSetting[0].length, []);
    int sectionIndex = 0;
    for(int testType in questionsSetting[0]) {
      for(Map<String, dynamic> wordData in widget.words) {
        late List<dynamic> extra;
        if(testType == 0) {
          // 单词卡片 没有额外数据
          extra = [];
        } else if(testType == 1 || testType == 2) {
          // 中译阿/阿译中 选择题
          List<String> strList = [];
          int correctIndex = rnd.nextInt(4); // 正确答案在选项中的索引
          List<int> rndLst = [wordData['id']]; // 已抽取的 绝对索引
          for (int i = 0; i < correctIndex; i++) {
            Map<String, dynamic> r = widget.words[rnd.nextInt(widget.words.length)];
            while (rndLst.contains(r['id'])){
              r = widget.words[rnd.nextInt(widget.words.length)];
            }
            rndLst.add(r['id']);
            strList.add(r[testType == 1 ? "arabic" : "chinese"]);
          }
          strList.add(wordData[testType == 1 ? "arabic" : "chinese"]);
          for (int i = correctIndex + 1; i < 4; i++) {
            Map<String, dynamic> r = widget.words[rnd.nextInt(widget.words.length)];
            while (rndLst.contains(r['id'])){
              r = widget.words[rnd.nextInt(widget.words.length)];
            }
            rndLst.add(r['id']);
            strList.add(r[testType == 1 ? "arabic" : "chinese"]);
          }
          extra = [correctIndex, strList];
        } else if(testType == 3) {
          // 拼写题 （还没做）
          extra = [];
        }
        questionsInSections[sectionIndex].add([wordData, testType, extra]);
      }
      // doShuffleInternaly
      if(questionsSetting[1]) questionsInSections[sectionIndex].shuffle();
      testList.addAll([...questionsInSections[sectionIndex]]);
      sectionIndex++;
    }
    if(questionsSetting[2]) testList.shuffle();
    total = testList.length;
    startTime  = DateTime.now().millisecondsSinceEpoch;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: currentPage == total ? Center(child: Text("学习完成"))
        : Row(
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
                  end: currentPage / (total - 1),
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
                child: Text("${total - currentPage}"),
              ),
            )
          ],
        ),
      ),
      body: Center(
        child: PageView.builder(
          scrollDirection: Provider.of<Global>(context).isWideScreen ? Axis.vertical : Axis.horizontal,
          physics: NeverScrollableScrollPhysics(),
          // itemCount: total,
          controller: controller,
          onPageChanged: (index) {
            currentPage++;
          },
          itemBuilder: (context, index) {
            if(index >= testList.length) {
              Provider.of<AreYouFinishedModel>(context, listen: false).finished = true;
              List<int> data = [
                total, 
                correctCount, 
                ((DateTime.now().millisecondsSinceEpoch - startTime)/1000.0).toInt()
              ];
              return ConcludePage(data: data);
            }
            List<dynamic> testItem = testList[index];
            // testItem 0:MainWord; 1:TestType; 2: (extra)[0:CorrectIndex; 1:strList]
            if(testItem[1] == 0) {
              // wordCard
              return WordCardQuestion(
                word: testItem[0],
                hint: "尝试自行回忆以下单词",
                bottomWidget: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    fixedSize: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.1),
                    shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
                  ),
                  onPressed: (){
                    controller.animateToPage(currentPage + 1, duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
                  },
                  icon: Icon(Icons.arrow_forward),
                  label: Text("下一题"),
                ),
              );
            } else if(testItem[1] == 1 || testItem[1] == 2) {
              // ar-zh choose questions
              return ChoiceQuestions(
                mainWord: testItem[0][testItem[1] == 1 ? "chinese" : "arabic"], 
                choices: testItem[2][1], 
                allowAudio: testItem[1] == 2, 
                onSelected: (value) {
                  bool ans = value == testItem[2][0];
                  if(!ans) {
                    Future.delayed(Duration(seconds: 1), (){if(context.mounted) viewAnswer(mediaQuery, context, testItem[0]);});
                  } else {
                    correctCount++;
                  }
                  Future.delayed(Duration(milliseconds: 700) ,(){setState(() {
                    clicked = true;
                  });});
                  return ans;
                },
                allowMutipleSelect: true,
                hint: testItem[1] == 1 ? "通过中文选择阿拉伯语" : "通过阿拉伯语选择中文",
                bottomWidget: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: clicked ? 1.0 : 0.0,
                  ),
                  duration: const Duration(milliseconds: 500),
                  curve: StaticsVar.curve,
                  builder: (context, value, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            fixedSize: Size(mediaQuery.size.width * (0.8 - (0.45 * value)), mediaQuery.size.height * 0.1),
                            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: StaticsVar.br,
                            ),
                          ),
                          onPressed: () {
                            viewAnswer(mediaQuery, context, testItem[0]);
                          }, 
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.view_list, size: 16.0, semanticLabel: "查看详解"),
                                SizedBox(width: mediaQuery.size.width * 0.01),
                                Text("查看详解"),
                              ],
                            ),
                          )
                        ),
                        SizedBox(width: mediaQuery.size.width * 0.05 * value),
                        if(value != 0.0) ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            fixedSize: Size(mediaQuery.size.width * (0.45 * value), mediaQuery.size.height * 0.1),
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
                          ),
                          onPressed: () {
                            clicked = false; // 还原未点击状态
                            controller.animateToPage(currentPage + 1, duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
                          },
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(currentPage == total-1 ? Icons.done : Icons.navigate_next, size: 16.0),
                                SizedBox(width: mediaQuery.size.width * 0.01),
                                Text(currentPage == total-1 ? "完成" : "下一个"),
                              ],
                            ),
                          ),
                        )
                      ],
                    );
                  }
                ),
              );
            } else if(testItem[1] == 3) {
              // spell question
              return SpellQuestion(
                word: testItem[0],
                hint: "拼写以下单词",
                onCheck: (text) {
                  setState(() {
                    clicked = true;
                  });
                  if(text == testItem[0]["arabic"]) {
                    correctCount++;
                    return true;
                  } else {
                    viewAnswer(mediaQuery, context, testItem[0]);
                    return false;
                  }
                },
                bottomWidget: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: clicked ? 1.0 : 0.0,
                  ),
                  duration: const Duration(milliseconds: 500),
                  curve: StaticsVar.curve,
                  builder: (context, value, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            fixedSize: Size(mediaQuery.size.width * (0.8 - (0.45 * value)), mediaQuery.size.height * 0.1),
                            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: StaticsVar.br,
                            ),
                          ),
                          onPressed: () {
                            viewAnswer(mediaQuery, context, testItem[0]);
                          }, 
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.view_list, size: 16.0, semanticLabel: "查看详解"),
                                SizedBox(width: mediaQuery.size.width * 0.01),
                                Text("查看详解"),
                              ],
                            ),
                          )
                        ),
                        SizedBox(width: mediaQuery.size.width * 0.05 * value),
                        if(value != 0.0) ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            fixedSize: Size(mediaQuery.size.width * (0.45 * value), mediaQuery.size.height * 0.1),
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
                          ),
                          onPressed: () {
                            clicked = false; // 还原未点击状态
                            controller.animateToPage(currentPage + 1, duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
                          },
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(currentPage == total-1 ? Icons.done : Icons.navigate_next, size: 16.0),
                                SizedBox(width: mediaQuery.size.width * 0.01),
                                Text(currentPage == total-1 ? "完成" : "下一个"),
                              ],
                            ),
                          ),
                        )
                      ],
                    );
                  }
                ),
              );
            }
            return Center(
              child: TextContainer(text: "真奇怪，你不应该到这里来的，有时间给开发者反馈下吧"),
            );
          },
        )
      )
    );
  }
}

class ConcludePage extends StatefulWidget {
  final List<int> data; // [wordCount, correctCount, secondsCount]
  const ConcludePage({super.key, required this.data});

  @override
  State<ConcludePage> createState() => _ConcludePageState();
}

class _ConcludePageState extends State<ConcludePage> {
  bool visible1 = false;
  bool visible2 = false;
  bool visible3 = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          visible1 = true;
        });
        Future.delayed(Duration(milliseconds: 200), () {
          setState(() {
            visible2 = true;
          });
          Future.delayed(Duration(milliseconds: 200), () {
            setState(() {
              visible3 = true;
            });
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSlide(
            offset: visible1 ? Offset(-0.2, 0) : const Offset(-1.5, 0.2),
            duration: Duration(seconds: 1),
            curve: StaticsVar.curve,
            child: Container(
              width: mediaQuery.size.width * 0.8,
              height: mediaQuery.size.height * 0.2,
              padding: EdgeInsets.all(16.0),
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary,
                borderRadius: StaticsVar.br,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.surfaceBright,
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  )
                ]
              ),
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.0, end: visible1 ? 1.0 : 0.0),
                duration: Duration(seconds: 4),
                curve: StaticsVar.curve,
                builder: (context, value, child) {
                  return Row(
                      children: [
                        Expanded(child: SizedBox()),
                        Text("已完成单词:  ", style: TextStyle(fontSize: 20.0)),
                        Text((widget.data[0] * value).ceil().toString(), style: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold)),
                        SizedBox(width: mediaQuery.size.width * 0.05),
                        CircularProgressIndicator(value: value)
                      ],
                    );
                }
              ),
            ),
          ),
          SizedBox(height: mediaQuery.size.height * 0.05),
          AnimatedSlide(
            offset: visible2 ? Offset(0.2, 0) : const Offset(1.5, 0.2),
            duration: Duration(seconds: 1),
            curve: StaticsVar.curve,
            child: Container(
              width: mediaQuery.size.width * 0.8,
              height: mediaQuery.size.height * 0.2,
              padding: EdgeInsets.all(16.0),
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSecondary,
                borderRadius: StaticsVar.br,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.surfaceBright,
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  )
                ]
              ),
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.0, end: visible2 ? 1.0 : 0.0),
                duration: Duration(seconds: 4),
                curve: StaticsVar.curve,
                builder: (context, value, child) {
                  return Row(
                      children: [
                        CircularProgressIndicator(value: value * (widget.data[1]/widget.data[0])),
                        SizedBox(width: mediaQuery.size.width * 0.05),
                        Text("回答正确数:  ", style: TextStyle(fontSize: 20.0)),
                        Text((widget.data[1] * value).ceil().toString(), style: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold)),
                        Expanded(child: SizedBox()),
                      ],
                    );
                }
              ),
            ),
          ),
          SizedBox(height: mediaQuery.size.height * 0.05),
          AnimatedSlide(
            offset: visible3 ? Offset(-0.2, 0) : const Offset(-1.5, 0.2),
            duration: Duration(seconds: 1),
            curve: StaticsVar.curve,
            child: Container(
              width: mediaQuery.size.width * 0.8,
              height: mediaQuery.size.height * 0.2,
              padding: EdgeInsets.all(16.0),
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary,
                borderRadius: StaticsVar.br,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.surfaceBright,
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  )
                ]
              ),
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.0, end: visible3 ? 1.0 : 0.0),
                duration: Duration(seconds: 4),
                curve: StaticsVar.curve,
                builder: (context, value, child) {
                  return Row(
                      children: [
                        Expanded(child: SizedBox()),
                        Text("总耗时:  ", style: TextStyle(fontSize: 20.0)),
                        Text("${(widget.data[2] * value).ceil().toString()} 秒", style: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold)),
                        SizedBox(width: mediaQuery.size.width * 0.05),
                        CircularProgressIndicator(value: value)
                      ],
                    );
                }
              ),
            ),
          ),
          Expanded(child: SizedBox()),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              fixedSize: Size(mediaQuery.size.width, mediaQuery.size.height * 0.1),
              shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
            ),
            onPressed: (){
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: Text("返回主页")
          ),
        ],
      ),
    );
  }
}