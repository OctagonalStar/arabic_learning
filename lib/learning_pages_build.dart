import 'dart:convert';
import 'package:arabic_learning/change_notifier_models.dart';
import 'package:arabic_learning/global.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:arabic_learning/statics_var.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';


List<Widget> questionConstructer(BuildContext context, int index, List<String> data, bool isWithOutAudio) {
  final mediaQuery = MediaQuery.of(context);
  final player = AudioPlayer();
  bool playing = false;
  late int showingMode; // 0: 1 Row, 1: 2 Rows, 2: 4 Rows
  late bool overFlowPossible = false;

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
        child: TextButton.icon(
          icon: Icon(Icons.volume_up, size: 24.0),
          style: TextButton.styleFrom(
            fixedSize: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * (showingMode == 2 ? 0.2 : 0.4)),
            shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
          ),
          onPressed: () async {
            if (playing) {
              return;
            }
            playing = true;
            void alart(context, String e) {
              showDialog(
                context: context, 
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text("提示"),
                    content: Text("备用音频源获取失败\n$e"),
                    actions: [
                      TextButton(
                        child: Text("确定"),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      )
                    ],
                  );
                }
              );
            }
            if (Provider.of<Global>(context, listen: false).settingData["audio"]["useBackupSource"]) {
              try {
                final response = await http.get(Uri.parse("https://textreadtts.com/tts/convert?accessKey=FREE&language=arabic&speaker=speaker2&text=${data[0]}"));
                if (response.statusCode == 200) {
                  final data = jsonDecode(response.body);
                  if(data["code"] == 1 && context.mounted) {
                    alart(context, "文本长度超过API限制");
                    return;
                  }
                  await player.setUrl(data["audio"]);
                  if (!context.mounted) return;
                  await player.setSpeed(Provider.of<Global>(context, listen: false).settingData["audio"]["playRate"]);
                  await player.play();
                } else {
                  if (!context.mounted) return;
                  alart(context, response.statusCode.toString());
                }
              } catch (e) {
                if (!context.mounted) return;
                alart(context, e.toString());
              }
            } else {
              FlutterTts flutterTts = FlutterTts();
              if(!(await flutterTts.getLanguages).toString().contains("ar")) {
                if (!context.mounted) return;
                showDialog(
                  context: context, 
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text("提示"),
                      content: Text("你的设备似乎未安装阿拉伯语语言或不支持阿拉伯语文本转语音功能，语音可能无法正常播放。\n你可以尝试在 设置 - 系统语言 - 添加语言 中添加阿拉伯语。\n实在无法使用可在设置页面启用备用音频源(需要网络)"),
                      actions: [
                        TextButton(
                          child: Text("确定"),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        )
                      ],
                    );
                  }
                );
              }
              await flutterTts.setLanguage("ar");
              await flutterTts.setPitch(1.0);
              if (!context.mounted) return;
              await flutterTts.setSpeechRate(Provider.of<Global>(context, listen: false).settingData["audio"]["playRate"] / 2);
              await flutterTts.speak(data[0]);
            }
            playing = false;
          },
          label: FittedBox(fit: BoxFit.contain ,child: Text(data[0], style: context.read<Global>().settingData['regular']['font'] == 1 ? GoogleFonts.markaziText(fontSize: 128.0, fontWeight: FontWeight.bold) : TextStyle(fontSize: 128.0, fontWeight: FontWeight.bold)))
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
              if(context.read<PageCounterModel>().isLastPage) {
                Provider.of<PageCounterModel>(context, listen: false).finished = true;
                List<int> data = [
                  context.read<PageCounterModel>().totalPages, 
                  context.read<PageCounterModel>().conrrects.length, 
                  ((DateTime.now().millisecondsSinceEpoch - context.read<PageCounterModel>().startTime)/1000.0).toInt()
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
                var counter = Provider.of<PageCounterModel>(context, listen: false);
                counter.controller.animateToPage(counter.currentPage + 1, duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
              }
            },
            child: FittedBox(
              fit: BoxFit.contain,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(context.read<PageCounterModel>().isLastPage ? Icons.done : Icons.navigate_next, size: 16.0),
                  SizedBox(width: mediaQuery.size.width * 0.01),
                  Text(context.read<PageCounterModel>().isLastPage ? "完成" : "下一个"),
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
      if(index == i) context.read<PageCounterModel>().conrrects.add(int.parse(data[7]));
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
              child: Center(child: FittedBox(fit: BoxFit.scaleDown ,child: Text(data[i+1], style: (context.read<Global>().settingData["regular"]["font"] == 1 && context.read<PageCounterModel>().currentType) ? GoogleFonts.markaziText(fontSize: 44.0) : TextStyle(fontSize: 24.0)))),
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