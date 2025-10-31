import 'dart:math';
import 'package:arabic_learning/funcs/fsrs_func.dart';
import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:fl_chart/fl_chart.dart';

class LearningFSRSPage extends StatelessWidget {
  const LearningFSRSPage({super.key});

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
                    "标准: \n- 期望提取率为 80%\n- 2秒内答对为优秀\n- 8秒内答对为良好",
                    0,
                    getChosenScheme,
                    setState,
                  ),
                  difficultyButton(
                    context,
                    "良好 (Fine)",
                    "标准: \n- 期望提取率为 85%\n- 1秒内答对为优秀\n- 5秒内答对为良好",
                    1,
                    getChosenScheme,
                    setState,
                  ),
                  difficultyButton(
                    context,
                    "一般 (OK~)",
                    "标准: \n- 期望提取率为 90%\n- 0.8秒内答对为优秀\n- 3秒内答对为良好",
                    2,
                    getChosenScheme,
                    setState,
                  ),
                  difficultyButton(
                    context,
                    "困难 (Emm...)",
                    "标准: \n- 期望提取率为 95%\n- 0.5秒内答对为优秀\n- 1.6秒内答对为良好",
                    3,
                    getChosenScheme,
                    setState,
                  ),
                  difficultyButton(
                    context,
                    "地狱 (Impossible)",
                    "标准: \n- 期望提取率为 99%\n- 0.3秒内答对为优秀\n- 1秒内答对为良好",
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
            label: const Text("下一步"),
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
    Random sharedRnd = Random();
    if(!isAnyDue) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("规律学习"),
        ),
        body: Center(
          child: TextContainer(text: "当前没有需要复习的卡片！", style: TextStyle(fontSize: 20.0, color: Colors.greenAccent)),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("规律学习"),
      ),
      body: PageView.builder(
        itemCount: fsrs.getWillDueCards().length,
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
  @override
  Widget build(BuildContext context) {
    DateTime start = DateTime.now();
    MediaQueryData mediaQuery = MediaQuery.of(context);
    bool choosed = false;
    List<Map<String, dynamic>> wordData = context.read<Global>().wordData["Words"];
    List<String> options = [context.read<Global>().wordData["Words"][widget.wordID]["chinese"] as String,
                      context.read<Global>().wordData["Words"][widget.rnd.nextInt(context.read<Global>().wordCount)]["chinese"] as String,
                      context.read<Global>().wordData["Words"][widget.rnd.nextInt(context.read<Global>().wordCount)]["chinese"] as String,
                      context.read<Global>().wordData["Words"][widget.rnd.nextInt(context.read<Global>().wordCount)]["chinese"] as String]..shuffle();
    while(options.hasDuplicate()) {
      options = [context.read<Global>().wordData["Words"][widget.wordID]["chinese"] as String,
                      context.read<Global>().wordData["Words"][widget.rnd.nextInt(context.read<Global>().wordCount)]["chinese"] as String,
                      context.read<Global>().wordData["Words"][widget.rnd.nextInt(context.read<Global>().wordCount)]["chinese"] as String,
                      context.read<Global>().wordData["Words"][widget.rnd.nextInt(context.read<Global>().wordCount)]["chinese"] as String]..shuffle();
    }
    int correct = options.indexOf(context.read<Global>().wordData["Words"][widget.wordID]["chinese"] as String);
    return Scaffold(
      appBar: AppBar(
        title: const Text("复习"),
      ),
      body: Column(
        children: [
          TextContainer(text: "单词ID: ${widget.wordID}", style: TextStyle(fontSize: 18.0)),
          SizedBox(height: mediaQuery.size.height * 0.02),
          TextContainer(text: wordData[widget.wordID]["arabic"], style: TextStyle(fontSize: 32.0)),
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
            isAllowAudio: false,
            isShowAnimation: true,
            options: options,
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
  const FSRSOverViewPage({super.key});

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
            onPressed: () {
              // Go to learn new words
            },
          ),
        // TextContainer(text: "统计数据")
        ],
      )
    );
  }
}