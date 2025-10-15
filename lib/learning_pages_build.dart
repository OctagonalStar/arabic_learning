import 'dart:convert';
import 'dart:math';
import 'package:arabic_learning/global.dart';
import 'package:arabic_learning/learning_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:arabic_learning/statics_var.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

List<Widget> learningPageBuilder(MediaQueryData mediaQuery, BuildContext context, List<int> testData, Map<String, dynamic> data) {
  List<Widget> list = [];
  Random rnd = Random();
  for (int t = 0; t < testData.length; t++) {
    int test = testData[t];
    List<String> strList = [];
    int aindex = rnd.nextInt(4);
    List<int> rndLst = [t];
    for (int i = 0; i < aindex; i++) {
      int r = rnd.nextInt(testData.length);
      while (rndLst.contains(r)){
        r = rnd.nextInt(testData.length);
      }
      rndLst.add(r);
      strList.add(data["Words"][testData[r]]["chinese"]);
    }
    strList.add(data["Words"][test]["chinese"]);
    for (int i = aindex + 1; i < 4; i++) {
      int r = rnd.nextInt(testData.length);
      while (rndLst.contains(r)){
        r = rnd.nextInt(testData.length);
      }
      rndLst.add(r);
      strList.add(data["Words"][testData[r]]["chinese"]);
    }
    list.add(
      Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: arToChConstructer(mediaQuery, 
                                    context, 
                                    [
                                      data["Words"][test]["arabic"], // 0
                                      ...strList, // 1 2 3 4
                                      data["Words"][test]["explanation"], // 5
                                      data["Words"][test]["subClass"] // 6
                                    ], 
                                    aindex
                                    )
      )
    );
  }
  return list;
}


List<Widget> arToChConstructer(MediaQueryData mediaQuery, BuildContext context, List<String> data, int index) {
  bool playing = false;
  final player = AudioPlayer();
  return [
    Text(
      "通过阿拉伯语选择中文",
      style: TextStyle(fontSize: 18.0),
    ),
    Container(
      margin: EdgeInsets.all(16.0),
      width: mediaQuery.size.width * 0.8,
      height: mediaQuery.size.height * 0.4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: StaticsVar.br,
      ),
      child: Center(
        child: TextButton.icon(
          icon: Icon(Icons.volume_up, size: 24.0),
          style: TextButton.styleFrom(
            fixedSize: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.4),
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
                  if(data["message"] != "OK") Exception("API返回错误: ${data["message"]}");
                  await player.setUrl(data["audio"]);
                  await player.setSpeed(Provider.of<Global>(context, listen: false).settingData["audio"]["playRate"]);
                  await player.play();
                } else {
                  alart(context, response.statusCode.toString());
                }
              } catch (e) {
                alart(context, e.toString());
              }
            } else {
              FlutterTts flutterTts = FlutterTts();
              if(!(await flutterTts.getLanguages).toString().contains("ar")) {
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
              await flutterTts.setSpeechRate(0.5);
              await flutterTts.speak(data[0]);
            }
            playing = false;
          },
          label: Text(data[0], style: TextStyle(fontSize: 64.0, fontWeight: FontWeight.bold))
        )
      ),
    ),
    SizedBox(height: mediaQuery.size.height * 0.01),
    ChangeNotifierProvider(
      create: (_) => ClickedListener.init(color: Theme.of(context).colorScheme.primaryContainer),
      builder: (context, child) {
        return choseButtons(mediaQuery, context, data, index);
      },
    ),
  ];
}

class ClickedListener extends ChangeNotifier {
  late List<Color> cl;

  ClickedListener.init({required Color color}) {
    cl = [color, color, color, color];
  }
  bool _isClicked = false;
  bool get isClicked => _isClicked;
  void clicked() {
    _isClicked = true;
    notifyListeners();
  }
}


Widget choseButtons(MediaQueryData mediaQuery, BuildContext context, List<String> data, int index) {
  
  late Widget base;
  
  List<Widget> widgetList = [];
  Widget bottomWidget = TweenAnimationBuilder<double>(
    tween: Tween<double>(
      begin: 0.0,
      end: Provider.of<ClickedListener>(context, listen: true).isClicked ? 1.0 : 0.0,
      // 别刷新 别刷新 别刷新 别刷新 别刷新 别刷新 别刷新 别刷新
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
              var counter = Provider.of<PageCounterModel>(context, listen: false);
              counter.controller.animateToPage(counter.currentPage + 1, duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
              // counter.increment();
            },
            child: FittedBox(
              fit: BoxFit.contain,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.navigate_next, size: 16.0, semanticLabel: "下一个"),
                  SizedBox(width: mediaQuery.size.width * 0.01),
                  Text("下一个"),
                ],
              ),
            ),
          )
        ],
      );
    }
  );
  var cl = Provider.of<ClickedListener>(context, listen: true).cl;
  if(Provider.of<Global>(context, listen: false).isWideScreen){
    for(int i = 0; i < 4; i++) {
      widgetList.add(StatefulBuilder(
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
                  
                  setLocalState(() {
                    cl[i] = Colors.amberAccent;
                  });
                  Future.delayed(Duration(milliseconds: 500), (){
                    if(index == i) {
                    setLocalState(() {
                      Provider.of<ClickedListener>(context, listen: false).clicked();
                      cl[i] = Colors.greenAccent;
                    });
                    } else {
                      setLocalState(() {
                      cl[i] = Colors.redAccent;
                      });
                      Future.delayed(Duration(milliseconds: 500), (){
                        viewAnswer(mediaQuery ,context, [data[0], data[index + 1], data[5], data[6]]);
                        Provider.of<ClickedListener>(context, listen: false).clicked();
                      });
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  fixedSize: Size(mediaQuery.size.width * 0.21, mediaQuery.size.height * 0.1),
                  backgroundColor: Colors.transparent,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: StaticsVar.br,
                  ),
                ),
                child: Center(child: Text(data[i+1])),
              ),
            );
          }
        )
      );
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
  } else {
    List<List<Widget>> rowList = [[], []];
    for(int r = 0; r < 2; r++) {
      for(int i = 0; i < 2; i++) {
        rowList[r].add(StatefulBuilder(
          builder: (context, setLocalState) {
            return AnimatedContainer(
              duration: Duration(milliseconds: 500),
              curve: StaticsVar.curve,
              decoration: BoxDecoration(
                color: cl[r*2 + i],
                borderRadius: StaticsVar.br,
              ),
              child: ElevatedButton(
                onPressed: () {
                  setLocalState(() {
                    cl[r*2 + i] = Colors.amberAccent;
                  });
                  // 你刷新你的 别突变就行
                  Future.delayed(Duration(milliseconds: 500), (){
                    if(index == r*2 + i) {
                    setLocalState(() {
                      Provider.of<ClickedListener>(context, listen: false).clicked();
                      cl[r*2 + i] = Colors.greenAccent;
                    });
                    } else {
                      setLocalState(() {
                      cl[r*2 + i] = Colors.redAccent;
                      });
                      Future.delayed(Duration(milliseconds: 500), (){
                        viewAnswer(mediaQuery ,context, [data[0], data[index + 1], data[5], data[6]]);
                        Provider.of<ClickedListener>(context, listen: false).clicked();
                      });
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  fixedSize: Size(mediaQuery.size.width * 0.45, mediaQuery.size.height * 0.1),
                  backgroundColor: Colors.transparent,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: StaticsVar.br,
                  ),
                ),
                child: Center(child: Text(data[r*2 + i +1])),
              ),
            );
          }
        )
        );
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
  }
  return base;
}

void viewAnswer(MediaQueryData mediaQuery, BuildContext context, List<String> data) async {
  showBottomSheet(
    context: context, 
    // backgroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
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
                      Text("阿拉伯语:\t${data[0]}", style: TextStyle(fontSize: 36.0, fontWeight: FontWeight.bold),),
                      Text("中文:\t${data[1]}", style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),),
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