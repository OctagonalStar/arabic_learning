import 'package:arabic_learning/vars/config_structure.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/vars/statics_var.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';

class ForeListeningSettingPage extends StatefulWidget {
  const ForeListeningSettingPage({super.key});

  @override
  State<StatefulWidget> createState() => _ForeListeningSettingPage();
}

class _ForeListeningSettingPage extends State<ForeListeningSettingPage> {
  double playRate = 1.0;
  int playTimes = 3;
  int interval = 5;
  int intervalBetweenWords = 10;
  List<ClassItem> selectedClasses = [];
  

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 ForeListeningSettingPage");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    int wordCount = getSelectedWords(context, forceSelectClasses: selectedClasses).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('自主听写预设置'),
      ),
      body: Center(
        child: ListView(
          children: [
            TextContainer(text: "请先完成以下选项以开始听写:"),
            Container(
              margin: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: StaticsVar.br,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextContainer(text: "1. 发音符号测试"),
                  IconButton(
                    onPressed: () {
                      context.read<Global>().uiLogger.info("进行听写发音测试");
                      playTextToSpeech("وَ", context);
                    }, 
                    icon: Icon(Icons.volume_up, size: 100)
                  ),
                  TextContainer(text: "点击以上按钮，等待约10秒。期间如果你能听到u和开口短音符音(wa)，则说明你当前音源支持发音符号。若不行请查阅“常见问题”"),
                    ],
                  )
                  
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16.0),
                minimumSize: Size.fromHeight(mediaQuery.size.height * 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: StaticsVar.br,
                ),
              ),
              onPressed: () async {
                selectedClasses = await popSelectClasses(context, withCache: false);
                setState(() {});
              }, 
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(child: Text("2. 选择听写课程", style: TextStyle(fontSize: 18.0),)),
                      Icon(Icons.arrow_forward),
                    ],
                  ),
                ],
              )
            ),
            Container(
              margin: EdgeInsets.all(16.0),
              padding: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: StaticsVar.br,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextContainer(text: "3. 听写设置"),
                  Row(
                    children: [
                      Expanded(child: Text("单词播放语速")),
                      SizedBox(
                        width: mediaQuery.size.width * 0.6,
                        child: Slider(
                          value: playRate,
                          min: 0.5,
                          max: 1.5,
                          divisions: 10,
                          label: playRate.toStringAsFixed(1),
                          onChanged: (double value) {
                            setState(() {
                              playRate = value;
                            });
                          }
                        ),
                      ),
                      Text("${playRate.toStringAsFixed(1)}倍"),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: Text("单词播放次数")),
                      SizedBox(
                        width: mediaQuery.size.width * 0.6,
                        child: Slider(
                          value: playTimes.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: playTimes.toString(),
                          onChanged: (double value) {
                            setState(() {
                              playTimes = value.toInt();
                            });
                          }
                        ),
                      ),
                      Text("${playTimes.toString()}次"),
                    ]
                  ),
                  Row(
                    children: [
                      Expanded(child: Text("不同单词间隔时间(秒)")),
                      SizedBox(
                        width: mediaQuery.size.width * 0.6,
                        child: Slider(
                          value: intervalBetweenWords.toDouble(),
                          min: 1,
                          max: 20,
                          divisions: 19,
                          label: intervalBetweenWords.toString(),
                          onChanged: (double value) {
                            setState(
                              () {
                                intervalBetweenWords = value.toInt();
                              }
                            );
                          }
                        ),
                      ),
                      Text("${intervalBetweenWords.toString()}秒"),
                    ]
                  ),
                  Row(
                    children: [
                      Expanded(child: Text("同一单词间隔时间(秒)")),
                      SizedBox(
                        width: mediaQuery.size.width * 0.6,
                        child: Slider(
                          value: interval.toDouble(),
                          min: 1,
                          max: 15,
                          divisions: 14,
                          label: interval.toString(),
                          onChanged: (double value) {
                            setState(
                              () {
                                interval = value.toInt();
                              }
                            );
                          }
                        ),
                      ),
                      Text("${interval.toString()}秒"),
                    ]
                  ),
                  TextContainer(text: "已选择了 $wordCount 个单词，大致需要${((wordCount * playTimes * (interval + 1) + wordCount * intervalBetweenWords)) ~/ 60}分钟 完成"),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16.0),
                fixedSize: Size.fromHeight(100.0),
                shape: RoundedRectangleBorder(
                  borderRadius: StaticsVar.br,
                ),
              ),
              icon: Icon(Icons.rocket_launch, size: 32.0,),
              label: Text("听写，启动！", style: TextStyle(fontSize: 24.0),),
              onPressed: () {
                if(selectedClasses.isEmpty) {
                  alart(context, "是哪个小可爱没选课程就来听写了");
                  return;
                }
                context.read<Global>().uiLogger.info("准备开始进行听写: 播放速度: $playRate;播放次数: $playTimes;播放间隔: $interval;词间隔: $intervalBetweenWords");
                context.read<Global>().uiLogger.info("跳转 ForeListeningSettingPage => MainListeningPage");
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => MainListeningPage(
                      playRate: playRate, 
                      playTimes: playTimes, 
                      interval: interval, 
                      intervalBetweenWords: intervalBetweenWords, 
                      words: getSelectedWords(context, forceSelectClasses: selectedClasses, doShuffle: true)
                    )
                  )
                );
              },
            ),
          ],
        )
      ),
    );
  }
}

class MainListeningPage extends StatefulWidget {
  final double playRate;
  final int playTimes;
  final int interval;
  final int intervalBetweenWords;
  final List<WordItem> words;
  const MainListeningPage({super.key, required this.playRate, required this.playTimes, required this.interval, required this.intervalBetweenWords, required this.words});



  @override
  State<MainListeningPage> createState() => _MainListeningPageState();
}

class _MainListeningPageState extends State<MainListeningPage> {
  int index = 0;
  String state = "请点击开始按钮以开始听写";
  String counter = "";
  List<int> marks = [];
  int stage = 0;
  // 0: 播放前
  // 1: 播放中
  // 2: 听写完成
  // 3: 答案页面
  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 MainListeningPage");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    if(stage == 3) {
      context.read<Global>().uiLogger.info("构建 MainListeningPage:答案页面");
      // 答案页面
      // creat list view:
      List<Widget> list = [
        Container(
          padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.teal,
            ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("序号"),
              Text("中文"),
              Text("单词"),
            ],
          ),
        )
      ];
      for(int i = 0; i < widget.words.length; i++) {
        WordItem word = widget.words[i];
        list.add(
          Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: marks.contains(i) ? Colors.amber.withAlpha(125) : i.isEven ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSecondary,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text((i + 1).toString()),
                Text(word.chinese),
                Text(word.arabic),
              ],
            ),
          )
        );
      }
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text("听写完成"),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                children: list,
              ),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.arrow_back, size: 32.0,),
              label: Text("返回主页"),
              style: ElevatedButton.styleFrom(
                fixedSize: Size(mediaQuery.size.width * 0.9, mediaQuery.size.height * 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: StaticsVar.br,
                ),
              ),
              onPressed: () {
                Navigator.popUntil(context, (Route route) {return route.isFirst;});
              },
            )
          ],
        )
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: TweenAnimationBuilder<double>(
            tween: Tween(
              begin: 0.0,
              end: index/(widget.words.length * widget.playTimes),
            ),
            duration: Duration(seconds: 1), 
            builder: (context, value, child) {
              return LinearProgressIndicator(
                borderRadius: StaticsVar.br,
                minHeight: 25.0,
                value: value,
              );
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextContainer(text: "当前播放数/总数: $index/${(widget.words.length * widget.playTimes)}",textAlign: TextAlign.center,),
              TextContainer(text: state, style: TextStyle(fontSize: 32.0), size: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.4),textAlign: TextAlign.center,),
              TextContainer(text: counter, style: TextStyle(fontSize: 36.0, color: Colors.redAccent), size: Size(mediaQuery.size.width * 0.6, mediaQuery.size.height * 0.1),textAlign: TextAlign.center,),
              ElevatedButton.icon(
                icon: Icon(stage == 1 ? Icons.flag : Icons.play_arrow, size: 32.0,),
                label: Text(stage == 1 ? "标记当前单词" : (stage == 2 ? "查看答案" : "开始听写(20秒倒计时)")),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.all(16.0),
                  fixedSize: Size.fromHeight(mediaQuery.size.height * 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: StaticsVar.br,
                  ),
                ),
                onPressed: (){
                  if(stage == 1) {
                    marks.add((index / widget.playTimes).floor());
                  } else if(stage == 2) {
                    setState(() {
                      stage = 3;
                    });
                  } else {
                    setState(() {
                      stage++;
                    });
                    circlePlay(context);
                  }
                })
            ],
          ),
        )
      ),
    );
  }

  void circlePlay(BuildContext context) async {
    setState(() {
      state = "听写即将开始\n请准备好纸笔，调整设备音量\n听写*不设暂停*\n在下方20秒倒计时后，听写正式开始";
    });
    for (int i = 200; i >= 0; i--) {
      setState(() {
        counter = (i/10).toString();
      });
      // if(i == 100 && context.mounted) playTextToSpeech("سيبدأ الإملاء خلال 10 ثوانٍ. يرجى الاستعداد.", context);
      await Future.delayed(Duration(milliseconds: 100));
    }
    for (WordItem x in widget.words) {
      for(int t = 0; t < widget.playTimes; t++){ 
        index++;
        setState((){
          state = "正在播放音频...";
          counter = "-";
        });
        if(!context.mounted) return;
        await playTextToSpeech(x.arabic, context, speed: widget.playRate);
        // await Future.delayed(Duration(seconds: 1));
        setState((){
          state = "播放间隔中...";
        });
        for(int i = widget.interval * 10; i >= 0; i--) {
          setState(() {
            counter = (i / 10).toString();
          });
          await Future.delayed(Duration(milliseconds: 100));
        }
      }
      setState((){
        state = "即将进入下一个单词...";
      });
      for(int i = (widget.intervalBetweenWords - widget.interval) * 10; i >= 0; i--) {
        setState(() {
          counter = (i / 10).toString();
        });
        await Future.delayed(Duration(milliseconds: 100));
      }
    }
    setState((){
      state = "听写已完成";
      counter = "-";
      stage ++;
    });
  }
}