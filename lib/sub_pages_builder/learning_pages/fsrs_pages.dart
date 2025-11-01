import 'dart:math';
import 'package:arabic_learning/funcs/fsrs_func.dart';
import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:fl_chart/fl_chart.dart';

class ForeFSRSSettingPage extends StatelessWidget {
  const ForeFSRSSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    int choosedScheme = 5;
    int getChosenScheme([int? scheme]) {
      if (scheme != null) {
        choosedScheme = scheme;
        return choosedScheme;
      }
      return choosedScheme;
    }
    FSRS fsrs = FSRS();
    return FutureBuilder(
      future: fsrs.init(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if(fsrs.isEnabled()) {
          return MainFSRSPage(fsrs: fsrs);
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text("FSRS-抗遗忘学习 预设置"),
          ),
          body: StatefulBuilder(
            builder: (context, setState) {
              return ListView(
                children: [
                  TextContainer(text: "该功能仍处于实验中，存在较多不稳定因素且可能随时被移除", style: TextStyle(color: Colors.redAccent, fontSize: 24)),
                  TextContainer(text: "FSRS（Forgetting Spaced Repetition System）是一种基于遗忘曲线的间隔重复学习系统，旨在帮助用户更有效地记忆信息。通过调整复习间隔，FSRS能够最大限度地提高记忆的持久性，减少遗忘的发生。\n为了让您更个性化地学习，请选择一个适合您的难度方案（**选定之后无法更改**）："),
                  SizedBox(height: mediaQuery.size.height * 0.02),
                  difficultyButton(
                    context,
                    "简单 (Easy)",
                    "标准: \n- 期望提取率为 85%\n- 3秒内答对为优秀\n- 8秒内答对为良好",
                    0,
                    getChosenScheme,
                    setState,
                  ),
                  difficultyButton(
                    context,
                    "良好 (Fine)",
                    "标准: \n- 期望提取率为 90%\n- 2秒内答对为优秀\n- 6秒内答对为良好",
                    1,
                    getChosenScheme,
                    setState,
                  ),
                  difficultyButton(
                    context,
                    "一般 (OK~)",
                    "标准: \n- 期望提取率为 95%\n- 1.5秒内答对为优秀\n- 4秒内答对为良好",
                    2,
                    getChosenScheme,
                    setState,
                  ),
                  difficultyButton(
                    context,
                    "困难 (Emm...)",
                    "标准: \n- 期望提取率为 95%\n- 1秒内答对为优秀\n- 2秒内答对为良好",
                    3,
                    getChosenScheme,
                    setState,
                  ),
                  difficultyButton(
                    context,
                    "地狱 (Impossible)",
                    "标准: \n- 期望提取率为 99%\n- 1秒内答对为优秀\n- 1.5秒内答对为良好",
                    4,
                    getChosenScheme,
                    setState,
                  ),
                ]
              );
            }
          ),
        );
      },
    );
  }
}

Widget difficultyButton(BuildContext context, String label, String subLabel, int scheme, Function getChosenScheme, Function setLocalState) {
  return AnimatedContainer(
    margin: const EdgeInsets.all(16.0),
    duration: const Duration(milliseconds: 500),
    curve: StaticsVar.curve,
    decoration: BoxDecoration(
      color: getChosenScheme() == scheme ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onInverseSurface,
      borderRadius: StaticsVar.br,
    ),
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(16.0),
        //fixedSize: Size.fromHeight(50.0),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: StaticsVar.br,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                Text(subLabel, style: TextStyle(fontSize: 12.0, color: Colors.grey)),
              ],
            )
          ),
          if (getChosenScheme() == scheme) const Icon(Icons.check, size: 24.0),
          if (getChosenScheme() == scheme) ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward, size: 24.0),
            onPressed: () async {
              await FSRS().createScheduler(scheme);
              if(!context.mounted) return;
              alart(context, "设置完成，重新进入规律学习页面即可开始", onConfirmed: (){Navigator.pop(context);});
            },
            label: const Text("确认"),
          )
        ],
      ),
      onPressed: () {
        setLocalState(() {
          getChosenScheme(scheme);
        });
      },
    )
  );
}

class MainFSRSPage extends StatelessWidget {
  final FSRS fsrs;
  const MainFSRSPage({super.key, required this.fsrs});
  
  @override
  Widget build(BuildContext context) {
    bool isAnyDue = fsrs.getWillDueCards().isNotEmpty;
    MediaQueryData mediaQuery = MediaQuery.of(context);
    final PageController controller = PageController();
    Random sharedRnd = Random();
    if(!isAnyDue) {
      return FSRSOverViewPage(fsrs: fsrs);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("规律学习"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          controller.nextPage(duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
        },
        child: Icon(Icons.arrow_downward),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: controller,
        itemBuilder: (context, index) {
          if(index == 0) {
            return Center(
              child: Column(
                children: [
                  TextContainer(text: "你有${fsrs.getWillDueCards().length}个单词即将逾期!\n上滑页面开始复习",size: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.4),textAlign: TextAlign.center),
                  Icon(Icons.arrow_upward, size: 48.0, color: Colors.grey)
                ],
              ),
            );
          }
          final wordID = fsrs.getLeastDueCard();
          if(wordID == -1) {
            Future.delayed(
              Duration(seconds: 1), (){if(context.mounted) alart(context, "今日复习任务已完成", onConfirmed: () {Navigator.pop(context);});});
            return Center(
              child: TextContainer(text: "今日复习任务已完成"),
            );
          }
          return FSRSReviewCardPage(wordID: wordID, fsrs: fsrs, rnd: sharedRnd);
        }
      )
    );
  }
}

// 有东西复习的时候
class FSRSReviewCardPage extends StatefulWidget {
  final int wordID;
  final FSRS fsrs;
  final Random rnd;
  const FSRSReviewCardPage({super.key, required this.wordID, required this.fsrs, required this.rnd});

  @override
  State<FSRSReviewCardPage> createState() => _FSRSReviewCardPageState();
}

class _FSRSReviewCardPageState extends State<FSRSReviewCardPage> {
  List<String>? options;
  @override
  Widget build(BuildContext context) {
    final DateTime start = DateTime.now();
    MediaQueryData mediaQuery = MediaQuery.of(context);
    bool choosed = false;
    final List<dynamic> wordData = context.read<Global>().wordData["Words"];
    options ??= [context.read<Global>().wordData["Words"][widget.wordID]["chinese"] as String,
                      context.read<Global>().wordData["Words"][widget.rnd.nextInt(context.read<Global>().wordCount)]["chinese"] as String,
                      context.read<Global>().wordData["Words"][widget.rnd.nextInt(context.read<Global>().wordCount)]["chinese"] as String,
                      context.read<Global>().wordData["Words"][widget.rnd.nextInt(context.read<Global>().wordCount)]["chinese"] as String]..shuffle();
    while(options!.hasDuplicate()) {
      options = [context.read<Global>().wordData["Words"][widget.wordID]["chinese"] as String,
                      context.read<Global>().wordData["Words"][widget.rnd.nextInt(context.read<Global>().wordCount)]["chinese"] as String,
                      context.read<Global>().wordData["Words"][widget.rnd.nextInt(context.read<Global>().wordCount)]["chinese"] as String,
                      context.read<Global>().wordData["Words"][widget.rnd.nextInt(context.read<Global>().wordCount)]["chinese"] as String]..shuffle();
    }
    final int correct = options!.indexOf(context.read<Global>().wordData["Words"][widget.wordID]["chinese"] as String);
    return Material(
      child: Column(
        children: [
          TextContainer(text: "单词ID: ${widget.wordID}", style: TextStyle(fontSize: 18.0)),
          SizedBox(height: mediaQuery.size.height * 0.01),
          Container(
            width: mediaQuery.size.width * 0.9,
            height: mediaQuery.size.height * 0.3,
            decoration: BoxDecoration(
              borderRadius: StaticsVar.br,
              color: Theme.of(context).colorScheme.onPrimary
            ),
            child: FittedBox(fit: BoxFit.scaleDown ,child: Text(wordData[widget.wordID]["arabic"], style: TextStyle(fontSize: 128),)),
          ),
          SizedBox(height: mediaQuery.size.height * 0.02),
          ChooseButtons(
            onSelected: (value) {
              if(choosed) return null;
              setState(() {
                choosed = true;
              });
              if(value == correct) {
                widget.fsrs.reviewCard(widget.wordID, DateTime.now().difference(start).inMilliseconds, true);
                return true;
              } else {
                widget.fsrs.reviewCard(widget.wordID, DateTime.now().difference(start).inMilliseconds, false);
                return false;
              }
            },
            isShowAnimation: true,
            options: options!,
          ),
          SizedBox(height: mediaQuery.size.height * 0.02),
          choosed ? Icon(Icons.arrow_upward, size: 48.0, color: Colors.greenAccent) : SizedBox(height: mediaQuery.size.height * 0.05),
        ],
      ),
    );
  }
}

// 没有东西复习的时候
class FSRSOverViewPage extends StatefulWidget {
  final FSRS fsrs;
  const FSRSOverViewPage({super.key, required this.fsrs});

  @override
  State<FSRSOverViewPage> createState() => _FSRSOverViewPageState();
}

class _FSRSOverViewPageState extends State<FSRSOverViewPage> {
  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("进度概览"),
      ),
      body: ListView(
        children: [
          TextContainer(text: "目前没有需要复习的单词！"),
          SizedBox(height: mediaQuery.size.height * 0.01),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              fixedSize: Size.fromHeight(mediaQuery.size.height * 0.1)
            ),
            icon: const Icon(Icons.label_important, size: 24.0),
            label: const Text("去学习新单词"),
            onPressed: () async {
              late List<List<String>> selectedClasses;
              late List<Map<String, dynamic>> words;
              selectedClasses = await popSelectClasses(context, withCache: false);
              if(!context.mounted || selectedClasses.isEmpty) return;
              words = getSelectedWords(context, forceSelectClasses: selectedClasses, doShuffle: true, doDouble: false);
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => FSRSLearningPage(words: words, fsrs: widget.fsrs,),
              ));
            },
          ),
        // TextContainer(text: "统计数据")
        ],
      )
    );
  }
}

// 学习新东西的页面： 展示释义 -> 选择题
class FSRSLearningPage extends StatefulWidget {
  final List<Map<String, dynamic>> words;
  final FSRS fsrs;
  const FSRSLearningPage({super.key, required this.words, required this.fsrs});

  @override
  State<FSRSLearningPage> createState() => _FSRSLearningPageState();
}
class _FSRSLearningPageState extends State<FSRSLearningPage> {
  List<Set<dynamic>> wordTest = [];
  List<Set<dynamic>> progressList = [];
  List<Widget> buildedPages = [];
  Random rnd = Random();
  bool allowScoll = true;

  @override
  void initState() {
    super.initState();
    for(int i = 0; i < 2; i++) {
      for (Map<String, dynamic> word in widget.words) {
        if(widget.fsrs.isContained(word['id'])) continue;
        wordTest.add({i, word});
      }
    }
    progressList = [...wordTest];
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    if(wordTest.isEmpty) {
      return Material(
        child: Center(child: TextContainer(text: "你选择的课程中所有的单词都已经学习过了\n等明天复习去")),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("规律学习"),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemBuilder: (context, index) {
          if(index < buildedPages.length) return buildedPages[index];
          if(index == 0) {
            buildedPages.add(Center(
              child: Column(
                children: [
                  TextContainer(text: "上滑页面开始学习新单词\n(不作答的单词不计入学习)"),
                  Expanded(child: SizedBox()),
                  Icon(Icons.arrow_upward, size: 48.0, color: Colors.grey),
                ],
              ),
            ));
            return buildedPages.last;
          }
          if(progressList.isEmpty) {
            buildedPages.add(Center(
              child: Column(
                children: [
                  TextContainer(text: "所有新单词学习完毕！\n新学习的单词请今天重新进入规律学习页面完成复习巩固", style: TextStyle(fontSize: 20.0, color: Colors.greenAccent)),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.popUntil(context, (Route route) {return route.isFirst;});
                    },
                    icon: Icon(Icons.done),
                    label: Text("确认")
                  )
                ],
              ),
            ));
            return buildedPages.last;
          }
          Set<dynamic> current = progressList.removeAt(0);
          Map<String, dynamic> word = current.elementAt(1);
          int stage = current.elementAt(0);
          if(stage == 0) {
            buildedPages.add(Center(
              child: Column(
                children: [
                  WordCard(word: word),
                  Expanded(child: SizedBox()),
                  Icon(Icons.arrow_upward, size: 48.0, color: Colors.grey),
                ],
              ),
            ));
            return buildedPages.last;
          }else {
            bool choosed = false;
            List<String> options = [word["chinese"] as String,
                              wordTest[rnd.nextInt(wordTest.length)].elementAt(1)["chinese"] as String,
                              wordTest[rnd.nextInt(wordTest.length)].elementAt(1)["chinese"] as String,
                              wordTest[rnd.nextInt(wordTest.length)].elementAt(1)["chinese"] as String]..shuffle();
            while(options.hasDuplicate()) {
              options = [word["chinese"] as String,
                              wordTest[rnd.nextInt(wordTest.length)].elementAt(1)["chinese"] as String,
                              wordTest[rnd.nextInt(wordTest.length)].elementAt(1)["chinese"] as String,
                              wordTest[rnd.nextInt(wordTest.length)].elementAt(1)["chinese"] as String]..shuffle();
            }
            int correct = options.indexOf(word["chinese"] as String);
            buildedPages.add(
              Center(
                child: Column(
                  children: [
                    Container(
                      width: mediaQuery.size.width * 0.9,
                      height: mediaQuery.size.height * 0.4,
                      decoration: BoxDecoration(
                        borderRadius: StaticsVar.br,
                        color: Theme.of(context).colorScheme.onPrimary
                      ),
                      child: FittedBox(fit: BoxFit.scaleDown ,child: Text(word["arabic"], style: TextStyle(fontSize: 128),)),
                    ),
                    SizedBox(height: mediaQuery.size.height * 0.02),
                    ChooseButtons(
                      onSelected: (value) {
                        if(choosed) return null;
                        setState(() {
                          choosed = true;
                          allowScoll = true;
                        });
                        if(value == correct) {
                          widget.fsrs.addWordCard(word['id']);
                          return true;
                        } else {
                          progressList.add({1, word});
                          return false;
                        }
                      },
                      isShowAnimation: true,
                      options: options,
                    ),
                  ],
                ),
              ),
            );
            return buildedPages.last;
          }
        }
      )
    );
  }
}

class WordCard extends StatelessWidget {
  final Map<String, dynamic> word;
  const WordCard({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Container(
      margin: const EdgeInsets.all(16.0),
      //padding: const EdgeInsets.all(16.0),
      width: mediaQuery.size.width * 0.9,
      height: mediaQuery.size.height * 0.5,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onInverseSurface,
        borderRadius: StaticsVar.br,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              fixedSize: Size(mediaQuery.size.width * 0.9, mediaQuery.size.height * 0.2),
              backgroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
              padding: const EdgeInsets.all(16.0),
            ),
            icon: const Icon(Icons.volume_up, size: 24.0),
            label: FittedBox(child: Text(word["arabic"], style: TextStyle(fontSize: 64.0))),
            onPressed: (){
              playTextToSpeech(word["arabic"], context);
            },
          ),
          Text(
            ' 中文：${word["chinese"]}\n 示例：${word["explanation"]}\n 归属课程：${word["subClass"]}',
            style: TextStyle(fontSize: mediaQuery.size.height * 0.025),
          )
        ],
      )
    );
  }
}