import 'dart:math';

import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/change_notifier_models.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:provider/provider.dart';



// 学习主入口页面
class InLearningPage extends StatefulWidget {
  final int studyType; // 0:Mix 1: 中译阿 2: 阿译中
  final List<Map<String, dynamic>> words;
  const InLearningPage({super.key, required this.studyType, required this.words});
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
    final int total = widget.words.length;
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
                  end: context.read<InLearningPageCounterModel>().currentPage / (total - 1),
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
                child: Text("${total - context.watch<InLearningPageCounterModel>().currentPage}"),
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
          controller: context.read<InLearningPageCounterModel>().controller,
          onPageChanged: (index) {
            context.read<InLearningPageCounterModel>().setPage(index);
          },
          itemBuilder: (context, index) {
            if(index < buildedCache.length) return buildedCache[index];
            // Map<String, dynamic> wordData = Provider.of<Global>(context).wordData;
            // List<int> selectedWords = context.read<InLearningPageCounterModel>().selectedWords; // 已选择的单词 [int: 在词库中的索引]

            Map<String, dynamic> t = widget.words[index]; // 正确答案在词库中的索引
            late bool testType; // true: 中文->阿拉伯, false: 阿拉伯->中文
            if(widget.studyType == 0) {
              if (testedAr.contains(t['id'])) {
                testType = true;
              } else if(testedCh.contains(t['id'])){
                testType = false;
              } else {
                testType = rnd.nextBool();
                if (testType) {
                  testedCh.add(t['id']);
                } else {
                  testedAr.add(t['id']);
                }
              }
            } else if (widget.studyType == 1) {
              testType = true;
            } else {
              testType = false;
            }
            context.read<InLearningPageCounterModel>().currentType = testType; // for the font identify :P
            List<String> strList = [];
            int aindex = rnd.nextInt(4); // 正确答案在选项中的索引
            List<int> rndLst = [t['id']]; // 已抽取的 绝对索引
            for (int i = 0; i < aindex; i++) {
              Map<String, dynamic> r = widget.words[rnd.nextInt(total)];
              while (rndLst.contains(r['id'])){
                r = widget.words[rnd.nextInt(total)];
              }
              rndLst.add(r['id']);
              strList.add(r[testType ? "arabic" : "chinese"]);
            }
            strList.add(t[testType ? "arabic" : "chinese"]);
            for (int i = aindex + 1; i < 4; i++) {
              Map<String, dynamic> r = widget.words[rnd.nextInt(total)];
              while (rndLst.contains(r['id'])){
                r = widget.words[rnd.nextInt(total)];
              }
              rndLst.add(r['id']);
              strList.add(r[testType ? "arabic" : "chinese"]);
            }
            Widget learningPageWidget = Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: questionConstructer(context, 
                                          aindex,
                                          [
                                            t[testType ? "chinese" : "arabic"], // 0
                                            ...strList, // 1 2 3 4
                                            t["explanation"], // 5
                                            t["subClass"], // 6
                                            t['id'].toString(), // 7
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

List<Widget> questionConstructer(BuildContext context, int index, List<String> data, bool isWithOutAudio) {
  final mediaQuery = MediaQuery.of(context);
  late int showingMode; // 0: 1 Row, 1: 2 Rows, 2: 4 Rows
  late bool overFlowPossible = false;
  bool playing = false;

  for(int i = 1; i < 5; i++) {
    if(data[i].length * 16 > mediaQuery.size.width * (context.read<Global>().isWideScreen ? 0.21 : 0.8)){
      overFlowPossible = true;
      break;
    }
  }

  if (context.read<Global>().isWideScreen) {
    if(overFlowPossible){
      showingMode = 1;
    } else {
      showingMode = 0;
    }
  } else {
    if(overFlowPossible){
      showingMode = 2;
    } else {
      showingMode = 1;
    }
  }
  return [
    Text(
      isWithOutAudio ? "通过中文选择阿拉伯语" : "通过阿拉伯语选择中文",
      style: TextStyle(fontSize: 18.0),
    ),
    Container(
      margin: EdgeInsets.all(16.0),
      width: mediaQuery.size.width * 0.8,
      height: mediaQuery.size.height * (showingMode == 2 ? 0.2 : 0.4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary,
        borderRadius: StaticsVar.br,
      ),
      child: isWithOutAudio 
        ? Center(
          child: Container(
            padding: EdgeInsets.all(mediaQuery.size.width * 0.05), 
            child: FittedBox(
              fit: BoxFit.scaleDown, 
              child: Text(
                data[0], 
                style: TextStyle(fontSize: 128.0, fontWeight: FontWeight.bold)
              )
            )
          ),
        )
        :Center(
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            return TextButton.icon(
              icon: Icon(playing ? Icons.multitrack_audio : Icons.volume_up, size: 24.0),
              label: FittedBox(fit: BoxFit.contain ,child: Text(data[0], style: context.read<Global>().settingData['regular']['font'] == 1 ? GoogleFonts.markaziText(fontSize: 128.0, fontWeight: FontWeight.bold) : TextStyle(fontSize: 128.0, fontWeight: FontWeight.bold))),
              style: TextButton.styleFrom(
                fixedSize: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * (showingMode == 2 ? 0.2 : 0.4)),
                shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
              ),
              onPressed: () async {
                if (playing) {
                  return;
                }
                setLocalState(() {
                  playing = true;
                });
                late List<dynamic> temp;
                temp = await playTextToSpeech(data[0], context);
                if(!temp[0] && context.mounted) {
                  alart(context, temp[1]);
                }
                setLocalState(() {
                  playing = false;
                });
              },
            );
          }
        )
      ),
    ),
    SizedBox(height: mediaQuery.size.height * 0.01),
    ChangeNotifierProvider(
      create: (_) => ClickedListener.init(color: Theme.of(context).colorScheme.primaryContainer),
      builder: (context, child) {
        return choseButtons(context, index, data, showingMode);
      },
    ),
  ];
}

class ClickedListener extends ChangeNotifier {
  late List<Color> cl;

  ClickedListener.init({required Color color}) {
    cl = [color, color, color, color];
  }
  bool isClicked = false;
  bool chosed = false;
  void clicked() {
    isClicked = true;
    notifyListeners();
  }
}

// 这是当初的技术债，之后有时间重构 # TODO: #-1 Refactor this to use global_shared chose buttons
// 按钮组
Widget choseButtons(BuildContext context, int index, List<String> data, int showingMode) {
  // data:
  // [0] 正确阿拉伯文
  // [1, 2, 3, 4] 中文选项
  // [5] 解释/例句
  // [6] 来源
  // [7] 单词在词库中的ID
  // index+1: 1, 2, 3, 4 对应正确答案的索引
  final MediaQueryData mediaQuery = MediaQuery.of(context);
  late Widget base;
  Widget bottomWidget = TweenAnimationBuilder<double>(
    tween: Tween<double>(
      begin: 0.0,
      end: context.watch<ClickedListener>().isClicked ? 1.0 : 0.0,
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
              viewAnswer(mediaQuery, context, [data[0], data[index + 1], data[5], data[6]]);
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
          value == 0.0 ? SizedBox() : ElevatedButton(
            style: ElevatedButton.styleFrom(
              fixedSize: Size(mediaQuery.size.width * (0.45 * value), mediaQuery.size.height * 0.1),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
            ),
            onPressed: () {
              if(context.read<InLearningPageCounterModel>().isLastPage) {
                Provider.of<InLearningPageCounterModel>(context, listen: false).finished = true;
                List<int> data = [
                  context.read<InLearningPageCounterModel>().totalPages, 
                  context.read<InLearningPageCounterModel>().conrrects.length, 
                  ((DateTime.now().millisecondsSinceEpoch - context.read<InLearningPageCounterModel>().startTime)/1000.0).toInt()
                ];
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => ConcludePage(
                      data: data,
                    )
                  )
                );
              } else {
                var counter = Provider.of<InLearningPageCounterModel>(context, listen: false);
                counter.controller.animateToPage(counter.currentPage + 1, duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
              }
            },
            child: FittedBox(
              fit: BoxFit.contain,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(context.read<InLearningPageCounterModel>().isLastPage ? Icons.done : Icons.navigate_next, size: 16.0),
                  SizedBox(width: mediaQuery.size.width * 0.01),
                  Text(context.read<InLearningPageCounterModel>().isLastPage ? "完成" : "下一个"),
                ],
              ),
            ),
          )
        ],
      );
    }
  );

  var rcl = context.read<ClickedListener>();
  var cl = context.watch<ClickedListener>().cl;
  void chose(int i, Function setLocalState) {
    if(!rcl.chosed) {
      rcl.chosed = true;
      if(index == i) context.read<InLearningPageCounterModel>().conrrects.add(int.parse(data[7]));
    }
    setLocalState(() {
      cl[i] = Colors.amberAccent;
    });
    Future.delayed(Duration(milliseconds: 500), (){
      if(index == i) {
      setLocalState(() {
        rcl.clicked();
        cl[i] = Colors.greenAccent;
      });
      } else {
        setLocalState(() {
        cl[i] = Colors.redAccent;
        });
        Future.delayed(Duration(milliseconds: 500), (){
          if (!context.mounted) return;
          viewAnswer(mediaQuery ,context, [data[0], data[index + 1], data[5], data[6]]);
          rcl.clicked();
        });
      }
    });
  }

  if(showingMode == 0){
    // 对于宽屏幕 且无溢出风险 则单行显示4个按钮
    List<Widget> widgetList = [];
    for(int i = 0; i < 4; i++) {
      widgetList.add(buttonBox(cl, i, chose, mediaQuery, data, mediaQuery.size.width * 0.21));
    }
    base = Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: widgetList,
        ),
        SizedBox(height: mediaQuery.size.height * 0.01),
        bottomWidget,
      ],
    );
  } else if(showingMode == 1){
    // 窄屏幕 或 有溢出风险则两行显示
    List<List<Widget>> rowList = [[], []];
    for(int r = 0; r < 2; r++) {
      for(int i = 0; i < 2; i++) {
        rowList[r].add(buttonBox(cl, 2 * r + i, chose, mediaQuery, data, mediaQuery.size.width * 0.45));
      }
    }
    base = Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,children: rowList[0]),
        SizedBox(height: mediaQuery.size.height * 0.01),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,children: rowList[1]),
        SizedBox(height: mediaQuery.size.height * 0.01),
        bottomWidget,
      ]
    );
  } else if (showingMode == 2) {
    // 窄屏幕 且 有溢出风险则四行显示
    List<Widget> widgetList = [];
    for(int i = 0; i < 4; i++) {
      widgetList.add(buttonBox(cl, i, chose, mediaQuery, data, mediaQuery.size.width * 0.9));
    }
    base = Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ...widgetList,
          SizedBox(height: mediaQuery.size.height * 0.01),
          bottomWidget,
        ],
      ),
    );
  }
  return base;
}

StatefulBuilder buttonBox(List<Color> cl, int i, void Function(int i, Function setLocalState) chose, MediaQueryData mediaQuery, List<String> data, double width) {
  return StatefulBuilder(
        builder: (context, setLocalState) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 500),
            curve: StaticsVar.curve,
            decoration: BoxDecoration(
              color: cl[i],
              borderRadius: StaticsVar.br,
            ),
            child: ElevatedButton(
              onPressed: () {
                chose(i, setLocalState);
              },
              style: ElevatedButton.styleFrom(
                fixedSize: Size(width, mediaQuery.size.height * 0.1),
                backgroundColor: Colors.transparent,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: StaticsVar.br,
                ),
              ),
              child: Center(child: FittedBox(fit: BoxFit.scaleDown ,child: Text(data[i+1], style: (context.read<Global>().settingData["regular"]["font"] == 1 && context.read<InLearningPageCounterModel>().currentType) ? GoogleFonts.markaziText(fontSize: 44.0) : TextStyle(fontSize: 24.0)))),
            ),
          );
        }
      );
}

void viewAnswer(MediaQueryData mediaQuery, BuildContext context, List<String> data) async {
  showBottomSheet(
    context: context, 
    shape: RoundedSuperellipseBorder(side: BorderSide(width: 1.0, color: Theme.of(context).colorScheme.onSurface), borderRadius: StaticsVar.br),
    enableDrag: true,
    builder: (context) {
      return Container(
        padding: EdgeInsets.only(top: mediaQuery.size.height * 0.05),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onPrimary,
          borderRadius: StaticsVar.br,
        ),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(width: mediaQuery.size.width * 0.05),
                Expanded(
                  child: Column(
                    crossAxisAlignment: context.read<Global>().isWideScreen ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                    children: [
                      Text(data[0], style: TextStyle(fontSize: 36.0, fontWeight: FontWeight.bold),),
                      Text(data[1], style: TextStyle(fontSize: 36.0, fontWeight: FontWeight.bold),),
                      Text("例句:\t${data[2]}", style: TextStyle(fontSize: 20.0),),
                      Text("所属课程:\t${data[3]}", style: TextStyle(fontSize: 20.0),),
                    ]
                  ),
                ),
                SizedBox(width: mediaQuery.size.width * 0.05),
              ],
            ),
            Expanded(child: SizedBox()),
            ElevatedButton(
              onPressed: () {Navigator.pop(context);}, 
              style: ElevatedButton.styleFrom(
                fixedSize: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.1),
                shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
              ),
              child: Text("我知道了"),
            )
          ],
        ),
      );
    },
  );
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Center(child: Text("学习完成")),
      ),
      body: Center(
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
      ),
    );
  }
}