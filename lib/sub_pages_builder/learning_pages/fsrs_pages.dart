import 'dart:math';

import 'package:arabic_learning/vars/config_structure.dart';
import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' show Rating;
import 'package:provider/provider.dart';

import 'package:arabic_learning/vars/statics_var.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/funcs/fsrs_func.dart';

class ForeFSRSSettingPage extends StatelessWidget {
  final bool forceChoosing;
  const ForeFSRSSettingPage({super.key, this.forceChoosing = false});

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 ForeFSRSSettingPage");
    final FSRS fsrs = context.read<Global>().globalFSRS;
    if(fsrs.config.enabled && !forceChoosing) {
      return MainFSRSPage(fsrs: fsrs);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("单词规律复习设置"),
      ),
      body: StatefulBuilder(
        builder: (context, setState) {
          return ListView(
            children: [
              TextContainer(text: "参数配置", textAlign: TextAlign.center),
              Container(
                decoration: BoxDecoration(
                  borderRadius: StaticsVar.br,
                  color: Theme.of(context).colorScheme.onPrimary
                ),
                margin: EdgeInsets.all(8.0),
                padding: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("期望提取率", style: Theme.of(context).textTheme.bodyLarge)),
                        Slider(
                          value: fsrs.config.desiredRetention, 
                          max: 0.99,
                          min: 0.75,
                          divisions: 24,
                          onChanged: (value){
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                desiredRetention: (value*100).floorToDouble()/100
                              );
                            });
                          }
                        ),
                        Text((fsrs.config.desiredRetention).toStringAsFixed(2))
                      ],
                    ),
                    Text("期望提取率 是指期望你有多大概率能回忆起某个单词。通常设置值越大，要求的学习间隔越短。"),
                    Text("允许设置范围 0.75-0.99; 建议不低于0.8，不高于0.95")
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: StaticsVar.br,
                  color: Theme.of(context).colorScheme.onSecondary
                ),
                margin: EdgeInsets.all(8.0),
                padding: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("优秀评分限时", style: Theme.of(context).textTheme.bodyLarge)),
                        Slider(
                          value: fsrs.config.easyDuration.toDouble(), 
                          max: 5000.0,
                          min: 1000.0,
                          divisions: 40,
                          onChanged: (value){
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                easyDuration: value.toInt()
                              );
                            });
                          }
                        ),
                        Text(fsrs.config.easyDuration.toString())
                      ],
                    ),
                    Text("优秀评分限时 是指在你回答问题时，回答正确耗时小于多少时评分为优秀(Easy)，单位为毫秒"),
                    Text("允许设置范围 1000-5000; 建议不要设置过高，否则会导致算法认为单词简单而规划间隔过长")
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: StaticsVar.br,
                  color: Theme.of(context).colorScheme.onPrimary
                ),
                margin: EdgeInsets.all(8.0),
                padding: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("良好评分限时", style: Theme.of(context).textTheme.bodyLarge)),
                        Slider(
                          value: fsrs.config.goodDuration.toDouble(), 
                          max: 10000.0,
                          min: 2000.0,
                          divisions: 80,
                          onChanged: (value){
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                goodDuration: value.toInt()
                              );
                            });
                          }
                        ),
                        Text(fsrs.config.goodDuration.toString())
                      ],
                    ),
                    Text("良好评分限时 是指在你回答问题时，回答正确耗时小于多少时评分为良好(Good)，单位为毫秒"),
                    Text("允许设置范围 2000-10000; 建议不要设置过低，否则会导致学习阶段单词难以毕业（导致某单词一直被规划为当天内学习），如果你遇到此类情况，将此值适当调高即可。"),
                    Text("请勿设置一个低于优秀评分的数值")
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: StaticsVar.br,
                  color: Theme.of(context).colorScheme.onSecondary
                ),
                margin: EdgeInsets.all(8.0),
                padding: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("使用自我评级", style: Theme.of(context).textTheme.bodyLarge)),
                        Switch(
                          value: fsrs.config.selfEvaluate, 
                          onChanged: (value){
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                selfEvaluate: value
                              );
                            });
                          }
                        )
                      ],
                    ),
                    Text("自我评级 开启时会向你展示遮挡了中文的单词卡片，由你自行选择你是 记得很清楚/还记得/回忆困难/忘了"),
                    Text("在此模式下，计时仅作展示，不作为评分依据"),
                    Text("适合清楚自己的实力的人启用")
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: StaticsVar.br,
                  color: Theme.of(context).colorScheme.onSecondary
                ),
                margin: EdgeInsets.all(8.0),
                padding: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("每日单词推送", style: Theme.of(context).textTheme.bodyLarge)),
                        Slider(
                          max: 20.0,
                          min: 0.0,
                          divisions: 20,
                          value: fsrs.config.pushAmount.toDouble(), 
                          onChanged: (double value){
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(pushAmount: value.round());
                            });
                          },
                          label: fsrs.config.pushAmount == 0 ? "禁用" : fsrs.config.pushAmount.toString(),
                        )
                      ],
                    ),
                    Text("单词推送 开启后每天会推送新单词 但数量不一定是你所指定的（大概率会少几个） 你可以在学习页面入口进入推送单词学习"),
                    Text("学习的推送单词会加入复习中"),
                    Text("当天是否学习新单词对连胜计数没有影响 学不学可以看你心情")
                  ],
                ),
              ),
              if(!fsrs.config.selfEvaluate) Container(
                decoration: BoxDecoration(
                  borderRadius: StaticsVar.br,
                  color: Theme.of(context).colorScheme.onPrimary
                ),
                margin: EdgeInsets.all(8.0),
                padding: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("偏好易混词", style: Theme.of(context).textTheme.bodyLarge)),
                        Switch(
                          value: fsrs.config.preferSimilar, 
                          onChanged: (value){
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                preferSimilar: value
                              );
                            });
                          }
                        )
                      ],
                    ),
                    Text("偏好易混词 开启时选择题的选项更多地按照词根寻找相似的单词进行测试"),
                    Text("关闭时选择题的选项更多地考察同课程的单词"),
                    Text("该选型仅在自我评级关闭时生效")
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  fixedSize: Size.fromHeight(100),
                  shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
                ),
                onPressed: (){
                  fsrs.createScheduler(prefs: context.read<Global>().prefs);
                  alart(context, "设置完成，重新进入规律学习页面即可开始", onConfirmed: (){Navigator.popUntil(context, (route) => route.isFirst);});
                }, 
                icon: Icon(Icons.done),
                label: Text("确认"),
              )
            ]
          );
        }
      ),
    );
  }
}

class MainFSRSPage extends StatelessWidget {
  final FSRS fsrs;
  const MainFSRSPage({super.key, required this.fsrs});
  
  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 MainFSRSPage");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    final PageController controller = PageController();
    Random sharedRnd = Random();
    return Scaffold(
      appBar: AppBar(
        title: const Text("规律学习"),
        actions: [
          IconButton(
            icon: Icon(Icons.keyboard_option_key),
            onPressed: () {
              showModalBottomSheet(
                context: context, 
                isScrollControlled: true,
                enableDrag: false,
                builder: (context) => ForeFSRSSettingPage(forceChoosing: true)
              );
            },
          ),
        ],
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: controller,
        itemBuilder: (context, index) {
          if(index == 0) {
            return Center(
              child: Column(
                children: [
                  TextContainer(text: "你有${fsrs.getWillDueCount().toString()}个单词需要复习!\n上滑页面开始复习",size: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.4),textAlign: TextAlign.center),
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
          return FSRSReviewCardPage(wordID: wordID, fsrs: fsrs, rnd: sharedRnd, controller: controller,);
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
  final PageController controller;
  const FSRSReviewCardPage({super.key, required this.wordID, required this.fsrs, required this.rnd, required this.controller});

  @override
  State<FSRSReviewCardPage> createState() => _FSRSReviewCardPage();
}

class _FSRSReviewCardPage extends State<FSRSReviewCardPage> {
  List<String>? options;
  bool choosed = false;
  final DateTime start = DateTime.now();
  late final DateTime end;

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 FSRSReviewCardPage");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    final List<WordItem> wordData = context.read<Global>().wordData.words;
    late final int correct;

    // 防止重建后选项丢失
    if(options == null){
      if(widget.fsrs.config.selfEvaluate) {
        options = const ["记得很清楚", "还记得", "回忆困难", "忘了"];
        correct = -1;
      } else {
        List<WordItem> optionWords = getRandomWords(4, context.read<Global>().wordData, include: wordData[widget.wordID], preferClass: !widget.fsrs.config.preferSimilar, rnd: widget.rnd);
        options = List.generate(4, (int index) => optionWords[index].chinese, growable: false);
        correct  = options!.indexOf(context.read<Global>().wordData.words[widget.wordID].chinese);
      }
    }
    
    return Material(
      child: ChoiceQuestions(
        mainWord: widget.fsrs.config.selfEvaluate ? "[selfEvaluate]" : wordData[widget.wordID].arabic, 
        midWidget: widget.fsrs.config.selfEvaluate ? WordCard(word: wordData[widget.wordID], width: mediaQuery.size.width * 0.8, height: mediaQuery.size.height * 0.4, useMask: !choosed) : null,
        choices: options!, 
        allowAudio: true, 
        allowAnitmation: !widget.fsrs.config.selfEvaluate,
        allowMutipleSelect: false,
        hint: "单词ID: ${widget.wordID}${choosed ? " 用时: ${end.difference(start).inMilliseconds}毫秒" : ""}",
        onSelected: (value) {
          setState(() {
            choosed = true;
            end =  DateTime.now();
          });
          context.read<Global>().updateLearningStreak();
          if(widget.fsrs.config.selfEvaluate) {
            widget.fsrs.reviewCard(widget.wordID, end.difference(start).inMilliseconds, true, forceRate: (const [Rating.easy, Rating.good, Rating.hard, Rating.again]).elementAt(value));
            return true;
          } else {
            if(correct == value) {
              widget.fsrs.reviewCard(widget.wordID, end.difference(start).inMilliseconds, true);
              return true;
            } else {
              widget.fsrs.reviewCard(widget.wordID, end.difference(start).inMilliseconds, false);
              return false;
            }
          }
        },
        bottomWidget: TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0.0,
            end: choosed ? 1.0 : 0.0
          ),
          duration: Duration(milliseconds: 500),
          curve: StaticsVar.curve,
          builder: (context, value, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if(!widget.fsrs.config.selfEvaluate) ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    fixedSize: Size(mediaQuery.size.width * 0.9 - mediaQuery.size.width * 0.5 * value, mediaQuery.size.height * 0.1),
                    shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
                  ),
                  onPressed: (){
                    viewAnswer(context, wordData[widget.wordID]);
                    setState(() {
                      choosed = true;
                    });
                  }, 
                  icon: Icon(Icons.tips_and_updates),
                  label: Text(value == 0.0 ? "忘了？" : "详解"),
                ),
                SizedBox(width: mediaQuery.size.width*0.02*value, height: mediaQuery.size.height * 0.1),
                if(value > 0.3) ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    fixedSize: Size(mediaQuery.size.width * (widget.fsrs.config.selfEvaluate ? 0.8 : 0.5) * value, mediaQuery.size.height * 0.1),
                    shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
                  ),
                  onPressed: () {
                    widget.controller.nextPage(duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
                  },
                  icon: Icon(Icons.arrow_downward),
                  label: FittedBox(fit: BoxFit.contain, child: Text("下一题")),
                )
              ],
            );
          }
        )
      )
    );
  }
}

// 学习新东西的页面： 展示释义 -> 选择题
class FSRSLearningPage extends StatefulWidget {
  final List<WordItem> words;
  final FSRS fsrs;
  const FSRSLearningPage({super.key, required this.words, required this.fsrs});

  @override
  State<FSRSLearningPage> createState() => _FSRSLearningPageState();
}
class _FSRSLearningPageState extends State<FSRSLearningPage> {
  final PageController controllerHor = PageController();
  final PageController controllerLearning = PageController();
  final PageController controllerQuestions = PageController();
  bool corrected = false;
  List<List<String>> options = [];

  @override
  void initState() {
    final Random rnd = Random();
    for(WordItem word in widget.words) {
      List<WordItem> optionWords = getRandomWords(4, context.read<Global>().wordData, include: word, preferClass: !widget.fsrs.config.preferSimilar, rnd: rnd);
      List<String> option = List.generate(4, (int index) => optionWords[index].chinese, growable: false);
      options.add(option);
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    if(widget.words.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: TextContainer(text: "你选择的所有的单词都已经学习过了\n等复习吧")),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("规律学习"),
      ),
      body: PageView(
        scrollDirection: Axis.horizontal,
        physics: NeverScrollableScrollPhysics(),
        controller: controllerHor,
        children: [
          // 学习阶段的
          PageView.builder(
            scrollDirection: Axis.vertical,
            controller: controllerLearning,
            itemCount: widget.words.length,
            itemBuilder: (context, index) {
              return Column(
                children: [
                  WordCard(word: widget.words[index]),
                  Expanded(child: SizedBox()),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      fixedSize: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.15),
                      shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
                    ),
                    icon: Icon(index == widget.words.length-1 ? Icons.arrow_forward : Icons.arrow_downward),
                    label: Text(index == widget.words.length-1 ? "开始答题" : "下一个"),
                    onPressed: (){
                      if(index == widget.words.length-1) {
                        controllerHor.nextPage(duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
                      } else {
                      controllerLearning.nextPage(duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
                      }
                    }, 
                  ),
                  SizedBox(height: mediaQuery.size.height * 0.02)
                ],
              );
            }
          ),
          // 测试阶段的
          PageView.builder(
            scrollDirection: Axis.vertical,
            controller: controllerQuestions,
            physics: corrected ? PageScrollPhysics() : NeverScrollableScrollPhysics(),
            itemCount: widget.words.length,
            onPageChanged: (value) {
              setState(() {
                // 防止跳过
                corrected = false;
              });
            },
            itemBuilder: (context, index) {
              final int correct = options[index].indexOf(widget.words[index].chinese);
              return ChoiceQuestions(
                mainWord: widget.words[index].arabic, 
                choices: options[index], 
                allowAudio: true, 
                allowAnitmation: true,
                allowMutipleSelect: true,
                onSelected: (value) {
                  if(value == correct) {
                    setState(() {
                      corrected = true;
                    });
                    widget.fsrs.addWordCard(widget.words[index].id);
                    return true;
                  } else {
                    return false;
                  }
                },
                bottomWidget: TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0.0,
                    end: corrected ? 1.0 : 0.0
                  ),
                  duration: Duration(milliseconds: 500),
                  curve: StaticsVar.curve,
                  builder: (context, value, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            fixedSize: Size(mediaQuery.size.width * 0.9 - mediaQuery.size.width * 0.5 * value, mediaQuery.size.height * 0.1),
                            shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
                          ),
                          onPressed: (){
                            viewAnswer(context, widget.words[index]);
                          }, 
                          icon: Icon(Icons.tips_and_updates),
                          label: Text(value == 0.0 ? "提示" : "查看详解"),
                        ),
                        SizedBox(width: mediaQuery.size.width * 0.02 * value),
                        if(value > 0.2) ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            fixedSize: Size(mediaQuery.size.width * 0.5 * value, mediaQuery.size.height * 0.1),
                            shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
                          ),
                          onPressed: () {
                            if(index == widget.words.length-1) {
                              controllerHor.nextPage(duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
                            }
                            controllerQuestions.nextPage(duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
                          },
                          icon: Icon(index == widget.words.length-1 ? Icons.done_all : Icons.arrow_downward),
                          label: FittedBox(child: Text(index == widget.words.length-1 ? "完成学习" : "下一题")),
                        )
                      ],
                    );
                  },
                )
              );
            }
          ),
          Center(
            child: Column(
              children: [
                TextContainer(text: "该课程学习已完成\n已加入复习计划\n请过几个小时后再次进入规律学习页面复习课程"),
                ElevatedButton.icon(
                  onPressed: (){
                    Navigator.popUntil(context, (route)=>route.isFirst);
                  }, 
                  label: Text("确认"),
                  icon: Icon(Icons.done_all),
                )
              ],
            )
          )
        ],
      )
    );
  }
}
