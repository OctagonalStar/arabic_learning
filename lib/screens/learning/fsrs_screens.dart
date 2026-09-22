import 'dart:math';

import 'package:arabic_learning/models/dict.dart';
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' show Rating;
import 'package:provider/provider.dart';

import 'package:arabic_learning/widgets/flip_word_card.dart' show FlipWordCard;
import 'package:arabic_learning/widgets/kit.dart' show Button, CategoryFilter, TextContainer;
import 'package:arabic_learning/widgets/overlays.dart' show alart, viewAnswer;
import 'package:arabic_learning/widgets/questions.dart' show ChoiceQuestions, ListeningQuestion, SpellQuestion, TestItem, WordCardQuestion;
import 'package:arabic_learning/widgets/shared.dart' show RevealableActionBar, SettingCard;
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/words.dart';
import 'package:arabic_learning/services/fsrs.dart';

class ForeFSRSSettingPage extends StatelessWidget {
  final bool forceChoosing;
  const ForeFSRSSettingPage({super.key, this.forceChoosing = false});

  /// 复习/推送题型标签（与学习页面的措辞区分，避免沿用“学习”字样）
  static const Map<int, String> reviewCastMap = {
    0: "单词卡片",
    1: "中译阿 选择题",
    2: "阿译中 选择题",
    3: "中译阿 拼写题",
    4: "听力题",
  };

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 ForeFSRSSettingPage");
    final FSRS fsrs = FSRS();
    if(fsrs.config.enabled && !forceChoosing) {
      return MainFSRSPage(fsrs: fsrs);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("单词规律复习设置"),
      ),
      body: SafeArea(top: false, child: StatefulBuilder(
        builder: (context, setState) {
          final List<String> availableCategories = collectAllCategories();
          return ListView(
            children: [
              TextContainer(text: "参数配置", textAlign: TextAlign.center),
              SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                margin: EdgeInsets.all(8.0),
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
              SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                margin: EdgeInsets.all(8.0),
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
              SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                margin: EdgeInsets.all(8.0),
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
              SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                margin: EdgeInsets.all(8.0),
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
              SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                margin: EdgeInsets.all(8.0),
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
                    Text("当天是否学习新单词对连胜计数没有影响 学不学可以看你心情"),
                    if(fsrs.config.pushAmount != 0 && availableCategories.isNotEmpty) ...[
                      Divider(),
                      Text("推送词分类筛选：仅从所选分类中推送新词；不选择表示不筛选。可多选，需同时满足所选全部分类。", style: Theme.of(context).textTheme.bodyMedium),
                      CategoryFilter(
                        available: availableCategories,
                        selected: fsrs.config.pushCategories.toSet(),
                        onChanged: (Set<String> value) {
                          setState(() {
                            fsrs.config = fsrs.config.copyWith(pushCategories: value.toList());
                          });
                        },
                      )
                    ]
                  ],
                ),
              ),
              if(!fsrs.config.selfEvaluate) SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                margin: EdgeInsets.all(8.0),
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
              if(!fsrs.config.selfEvaluate) SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                margin: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("复习/推送随机题型", style: Theme.of(context).textTheme.bodyLarge),
                    SizedBox(height: 4.0),
                    Text("勾选多个题型后，复习与每日推送会在每个单词上随机选用其中一种；至少保留一项；其中「单词卡片」在复习中以自我评级（记得很清楚/还记得/回忆困难/忘了）呈现。", style: Theme.of(context).textTheme.bodyMedium),
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 6.0,
                      children: List<Widget>.generate(reviewCastMap.length, (int index) {
                        final bool isSelected = fsrs.config.reviewQuestionSections.contains(index);
                        return FilterChip(
                          label: Text(
                            reviewCastMap[index]!,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: isSelected
                                ? Theme.of(context).colorScheme.onSecondaryContainer
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          selected: isSelected,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          selectedColor: Theme.of(context).colorScheme.secondaryContainer,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: StaticsVar.br,
                            side: BorderSide(
                              color: isSelected
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          onSelected: (bool value) {
                            final Set<int> next = fsrs.config.reviewQuestionSections.toSet();
                            if(value) {
                              next.add(index);
                            } else {
                              next.remove(index);
                            }
                            if(next.isEmpty) {
                              alart(context, "至少保留一项");
                              return;
                            }
                            // 仅修改集合本身，不触发 createScheduler（那会启用 FSRS 并重建 Scheduler）
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                reviewQuestionSections: (next.toList()..sort()),
                              );
                            });
                            fsrs.save();
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
              SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                margin: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("强化记忆循环", style: Theme.of(context).textTheme.bodyLarge)),
                        Switch(
                          value: fsrs.config.reinforceMemory, 
                          onChanged: (value){
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                reinforceMemory: value
                              );
                            });
                          }
                        )
                      ],
                    ),
                    Text("开启后同一个到期卡片在队列中将按交错顺序出现多次（3次），加深印象。"),
                    Text("关闭后每个词汇当次复习只在队列里出现一次。")
                  ],
                ),
              ),
              Button(
                size: Size.fromHeight(100),
                onPressed: (){
                  fsrs.createScheduler(prefs: AppData().storage);
                  alart(context, "设置完成，重新进入规律学习页面即可开始", onConfirmed: (){Navigator.popUntil(context, (route) => route.isFirst);});
                }, 
                icon: Icon(Icons.done),
                child: Text("确认"),
              ),
              if (fsrs.config.enabled) Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Button(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                  size: Size.fromHeight(80),
                  shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
                  onPressed: (){
                    showDialog(
                      context: context, 
                      builder: (context) => AlertDialog(
                        title: Text("重置并停用 FSRS?"),
                        content: Text("这将永久清除所有规律学习进度及配置，且不可恢复！"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: Text("取消")),
                          TextButton(
                            onPressed: () {
                              fsrs.config = FSRSConfig(enabled: false);
                              fsrs.save();
                              Navigator.popUntil(context, (route) => route.isFirst);
                            }, 
                            child: Text("确认清空", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.error))
                          )
                        ],
                      )
                    );
                  },
                  icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
                  child: Text("重置并停用", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.error)),
                ),
              )
            ]
          );
        }
      )),
    );
  }
}

class MainFSRSPage extends StatefulWidget {
  final FSRS fsrs;
  const MainFSRSPage({super.key, required this.fsrs});

  @override
  State<MainFSRSPage> createState() => _MainFSRSPageState();
}

class _MainFSRSPageState extends State<MainFSRSPage> {
  List<int> queue = [];
  final PageController controller = PageController();
  final Random sharedRnd = Random();
  final int initalReviewNum = FSRS().getWillDueCount();

  @override
  void initState() {
    super.initState();
    _extendQueue();
  }

  void _extendQueue() {
    final List<int> uniqueIds = widget.fsrs.config.cards
        .where((card) => widget.fsrs.willDueIn(card) < 1)
        .map((card) => card.cardId)
        .toList();
        
    if (uniqueIds.isEmpty) return;
    
    if (widget.fsrs.config.reinforceMemory) {
      queue.addAll([
        for (int i = 0; i < 3; i++) ...uniqueIds
      ]..shuffle());
    } else {
      queue.addAll(uniqueIds..shuffle());
    }
  }

  void _refresh() {
    setState(() {
      queue.clear();
      _extendQueue();
    });
    if (controller.hasClients) {
      controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 MainFSRSPage, 动态队列长度: ${queue.length}");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    void Function(void Function()) refreshProgress =(_)=>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text("复习"),
            if(queue.isNotEmpty) StatefulBuilder(
              builder: (context, setLocalState) {
                refreshProgress = setLocalState;
                context.read<Global>().uiLogger.fine("刷新复习进度条");
                return TweenAnimationBuilder(
                  tween: Tween<double>(
                    begin: 0,
                    end: (initalReviewNum-widget.fsrs.getWillDueCount())/initalReviewNum
                  ), 
                  duration: AppMotion.medium,
                  curve: AppMotion.standardCurve,
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                    value: value,
                    minHeight: 15,
                    borderRadius: StaticsVar.br,
                  );
                }
                );
              }
            )
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: "强制刷新",
            onPressed: _refresh,
          ),
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
      body: SafeArea(top: false, child: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: controller,
        physics: const PageScrollPhysics(),
        onPageChanged: (value) {
          refreshProgress(()=>());
        },
        itemBuilder: (context, index) {
          // Page 0: 引导页
          if (index == 0) {
            if (queue.isEmpty) {
              return Center(
                child: TextContainer(text: "当前无任何待复习的内容\n可以休息会儿或者去[学习推送]里加些新词"),
              );
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextContainer(
                    text: "已载入待复习队列\n上滑页面开始复习",
                    size: Size(mediaQuery.size.width * 0.8, clampDouble(mediaQuery.size.height * 0.4, 140.0, 340.0)),
                    textAlign: TextAlign.center,
                  ),
                  Icon(Icons.arrow_upward, size: 48.0, color: Theme.of(context).colorScheme.onSurfaceVariant)
                ],
              ),
            );
          }

          int arrayIndex = index - 1;

          // 动态扩充：当滑到底时触发延展
          if (arrayIndex >= queue.length) {
            _extendQueue();
          }

          // 扩充了还是不够，说明真的穷尽了
          if (arrayIndex >= queue.length) {
            if (arrayIndex == queue.length) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextContainer(
                      text: "太棒了！当前没有任何卡片需要复习！\n若刚复习完请等待下一个间隔",
                      size: Size(mediaQuery.size.width * 0.8, clampDouble(mediaQuery.size.height * 0.4, 140.0, 340.0)),
                      textAlign: TextAlign.center,
                    ),
                    Button(
                      onPressed: _refresh,
                      icon: Icon(Icons.refresh),
                      child: Text("全盘刷新"),
                    )
                  ],
                ),
              );
            }
            // 返回 null 阻断 PageView 继续下滑
            return null;
          }

          // 常规复习页
          // key 需以 index 前缀保证唯一（强化记忆时同一 wordID 可重复出现），
          // 同时在 index 对应的单词变化时强制重建 State，避免 initState 固定的
          // testType/item 与实际 wordID 错位。
          return FSRSReviewCardPage(
            key: ValueKey('review-$index-${queue[arrayIndex]}'),
            wordID: queue[arrayIndex],
            fsrs: widget.fsrs,
            rnd: sharedRnd,
            controller: controller,
          );
        }
      ))
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
  int? chosenIndex;
  bool choosed = false;
  final DateTime start = DateTime.now();

  /// 本词随机选定的题型（[initState] 固化，避免重建时题型漂移）
  late final int testType;

  /// 是否以自我评级卡片呈现（自我评级模式，或随机到单词卡片）
  late final bool selfRated;

  /// 本词的题目数据
  late final TestItem item;

  /// 作答或点击详解时记录结束时间；二者都会赋值，故不能是 `late final`
  /// （重复赋值会抛 `Field 'end' has already been initialized`）。
  DateTime? end;

  /// 拼写题防止重复判题（判题后提交按钮仍可点击）
  bool spellAnswered = false;
  bool spellResult = false;

  /// 选择题/听力题防止重复作答（听力「跳过」按钮在作答后仍可点击，
  /// 重复调用会对同一张卡片重复 reviewCard，产生重复/损坏的复习记录）。
  /// 不复用 [choosed]：详解会提前置位 choosed，但仍需允许首次作答。
  bool answered = false;

  @override
  void initState() {
    super.initState();
    final FSRSConfig cfg = widget.fsrs.config;
    testType = cfg.selfEvaluate ? 0 : TestItem.pickType(cfg.reviewQuestionSections, widget.rnd);
    selfRated = cfg.selfEvaluate || testType == 0;
    item = TestItem.buildTestItem(
      AppData().wordData.words[widget.wordID],
      testType,
      AppData().wordData,
      cfg.preferSimilar,
      widget.rnd,
    );
  }

  String _hint() => "单词ID: ${widget.wordID}${choosed ? " 用时: ${end!.difference(start).inMilliseconds}毫秒" : ""}";

  /// 选择题/听力题统一作答（含听力跳过 value == -1）
  bool _onChoiceSelected(int value) {
    if(answered) return false;
    answered = true;
    _reveal();
    context.read<Global>().updateLearningStreak();
    if(value == -1) {
      // 听力跳过得记为失败，否则卡片仍到期，_extendQueue 会无限重加
      widget.fsrs.produceCard(widget.wordID, forceRate: Rating.again);
      return false;
    }
    chosenIndex = value;
    final int correct = item.correctIndex ?? -1;
    if(correct == value) {
      widget.fsrs.produceCard(widget.wordID, duration: end!.difference(start).inMilliseconds, isCorrect: true);
      return true;
    }
    widget.fsrs.produceCard(widget.wordID, duration: end!.difference(start).inMilliseconds, isCorrect: false);
    return false;
  }

  void _reveal() {
    setState(() {
      choosed = true;
      end = DateTime.now();
    });
  }

  Widget _bottomBar(MediaQueryData mediaQuery, List<WordItem> wordData, int correct) {
    return RevealableActionBar(
      revealed: choosed,
      showTipButton: !selfRated,
      tipWidth: (value) => mediaQuery.size.width * 0.9 - mediaQuery.size.width * 0.5 * value,
      tipLabel: (value) => value == 0.0 ? "忘了？" : "详解",
      onTipClicked: (){
        final List<WordItem>? optionWords = item.optionWords;
        final WordItem? chosenWrong = (optionWords != null && correct >= 0 && chosenIndex != null && chosenIndex != correct)
            ? optionWords[chosenIndex!]
            : null;
        viewAnswer(context, wordData[widget.wordID], chosenWrong: chosenWrong);
        setState(() {
          choosed = true;
          end = DateTime.now();
        });
      },
      gapWidth: (value) => mediaQuery.size.width*0.02*value,
      gapHeight: clampDouble(mediaQuery.size.height * 0.1, 16.0, 72.0),
      nextThreshold: 0.3,
      nextWidth: (value) => mediaQuery.size.width * (selfRated ? 0.8 : 0.5) * value,
      nextIcon: Icon(Icons.arrow_downward),
      nextLabel: "下一题",
      onNextClicked: () {
        widget.controller.nextPage(duration: AppMotion.medium, curve: AppMotion.standardCurve);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 FSRSReviewCardPage");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    final List<WordItem> wordData = AppData().wordData.words;

    // 每次 build 都重新计算：late final 只在首次 build 赋值，重建后读取会抛
    // LateInitializationError（点击详解无反应并报错）。
    final int correct = item.correctIndex ?? -1;
    final Widget question;

    if(selfRated) {
      question = ChoiceQuestions(
        mainWord: "[selfEvaluate]",
        midWidget: FlipWordCard(word: wordData[widget.wordID], width: mediaQuery.size.width * 0.8, height: clampDouble(mediaQuery.size.height * 0.4, 150.0, 340.0), enableFlip: false, masked: !choosed),
        choices: const ["记得很清楚", "还记得", "回忆困难", "忘了"],
        allowAudio: true,
        allowAnitmation: false,
        allowMutipleSelect: false,
        hint: _hint(),
        onSelected: (value) {
          setState(() {
            choosed = true;
            chosenIndex = value;
            end = DateTime.now();
          });
          context.read<Global>().updateLearningStreak();
          widget.fsrs.produceCard(widget.wordID, forceRate: (const [Rating.easy, Rating.good, Rating.hard, Rating.again]).elementAt(value));
          return true;
        },
        bottomWidget: _bottomBar(mediaQuery, wordData, correct),
      );
    } else if(testType == 1 || testType == 2) {
      question = ChoiceQuestions(
        mainWord: testType == 1 ? item.testWord.chinese : item.testWord.arabic,
        choices: item.options!,
        // 中译阿题面为中文，禁止音频，避免 TTS 朗读中文含义
        allowAudio: testType == 2,
        allowAnitmation: true,
        allowMutipleSelect: false,
        hint: _hint(),
        onSelected: _onChoiceSelected,
        bottomWidget: _bottomBar(mediaQuery, wordData, correct),
      );
    } else if(testType == 3) {
      question = SpellQuestion(
        word: item.testWord,
        hint: "拼写以下单词",
        onCheck: (text) {
          if(spellAnswered) return spellResult;
          spellAnswered = true;
          setState(() {
            choosed = true;
            end = DateTime.now();
          });
          context.read<Global>().updateLearningStreak();
          spellResult = text == item.testWord.arabic;
          widget.fsrs.produceCard(widget.wordID, forceRate: spellResult ? Rating.good : Rating.again);
          return spellResult;
        },
        bottomWidget: _bottomBar(mediaQuery, wordData, correct),
      );
    } else if(testType == 4) {
      question = ListeningQuestion(
        mainWord: item.testWord.arabic,
        choices: item.options!,
        allowMutipleSelect: false,
        hint: "听下面的音频，选择最合适的选项",
        onSelected: _onChoiceSelected,
        bottom: _bottomBar(mediaQuery, wordData, correct),
      );
    } else {
      // 正常配置不会走到这里（题型已被 _normalizeSections 限制为 0-4）
      question = Center(child: TextContainer(text: "未知题型"));
    }

    return Material(child: question);
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
  final Random rnd = Random();
  bool corrected = false;

  /// 每个词随机固定一种题型
  final List<TestItem> testItems = [];
  List<int?> chosenWrong = [];

  @override
  void initState() {
    for(WordItem word in widget.words) {
      final int type = TestItem.pickType(widget.fsrs.config.reviewQuestionSections, rnd);
      testItems.add(TestItem.buildTestItem(word, type, AppData().wordData, widget.fsrs.config.preferSimilar, rnd));
      chosenWrong.add(null);
    }
    super.initState();
  }

  Widget _bottomBar(MediaQueryData mediaQuery, int index, int correct) {
    return RevealableActionBar(
      revealed: corrected,
      tipWidth: (value) => mediaQuery.size.width * 0.9 - mediaQuery.size.width * 0.5 * value,
      tipLabel: (value) => value == 0.0 ? "提示" : "查看详解",
      onTipClicked: (){
        final List<WordItem>? optionWords = testItems[index].optionWords;
        final WordItem? chosenWrongWord = (optionWords != null && chosenWrong[index] != null && chosenWrong[index] != correct)
            ? optionWords[chosenWrong[index]!]
            : null;
        viewAnswer(context, widget.words[index], chosenWrong: chosenWrongWord);
      },
      gapWidth: (value) => mediaQuery.size.width * 0.02 * value,
      nextThreshold: 0.2,
      nextWidth: (value) => mediaQuery.size.width * 0.5 * value,
      nextIcon: Icon(index == widget.words.length-1 ? Icons.done_all : Icons.arrow_downward),
      nextLabel: index == widget.words.length-1 ? "完成学习" : "下一题",
      onNextClicked: (){
        if(index == widget.words.length-1) {
          controllerHor.nextPage(duration: AppMotion.medium, curve: AppMotion.standardCurve);
        }
        controllerQuestions.nextPage(duration: AppMotion.medium, curve: AppMotion.standardCurve);
      },
    );
  }

  @override
  void dispose() {
    controllerHor.dispose();
    controllerLearning.dispose();
    controllerQuestions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    if(widget.words.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: SafeArea(top: false, child: Center(child: TextContainer(text: "你选择的所有的单词都已经学习过了\n等复习吧"))),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("规律学习"),
      ),
      body: SafeArea(top: false, child: PageView(
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
                  FlipWordCard(word: widget.words[index], masked: true),
                  Expanded(child: SizedBox()),
                  Button(
                    size: Size(mediaQuery.size.width * 0.8, clampDouble(mediaQuery.size.height * 0.15, 64.0, 170.0)),
                    icon: Icon(index == widget.words.length-1 ? Icons.arrow_forward : Icons.arrow_downward),
                    onPressed: (){
                      if(index == widget.words.length-1) {
                        controllerHor.nextPage(duration: AppMotion.medium, curve: AppMotion.standardCurve);
                      } else {
                      controllerLearning.nextPage(duration: AppMotion.medium, curve: AppMotion.standardCurve);
                      }
                    }, 
                    child: Text(index == widget.words.length-1 ? "开始答题" : "下一个"),
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
              final TestItem testItem = testItems[index];
              final int correct = testItem.correctIndex ?? -1;
              if(testItem.testType == 1 || testItem.testType == 2) {
                return ChoiceQuestions(
                  mainWord: testItem.testType == 1 ? testItem.testWord.chinese : testItem.testWord.arabic,
                  choices: testItem.options!,
                  // 中译阿题面为中文，禁止音频，避免 TTS 朗读中文含义
                  allowAudio: testItem.testType == 2,
                  allowAnitmation: true,
                  allowMutipleSelect: true,
                  hint: testItem.testType == 1 ? "通过中文选择阿拉伯语" : "通过阿拉伯语选择中文",
                  onSelected: (value) {
                    if(value == correct) {
                      setState(() {
                        corrected = true;
                      });
                      widget.fsrs.produceCard(testItem.testWord.id);
                      return true;
                    } else {
                      chosenWrong[index] = value;
                      return false;
                    }
                  },
                  bottomWidget: _bottomBar(mediaQuery, index, correct),
                );
              } else if(testItem.testType == 3) {
                return SpellQuestion(
                  word: testItem.testWord,
                  hint: "拼写以下单词",
                  onCheck: (text) {
                    final bool ok = text == testItem.testWord.arabic;
                    if(!ok) {
                      // 拼写判题后输入框只读且只有一次机会，答错也必须放行，避免卡死队列
                      viewAnswer(context, testItem.testWord);
                    }
                    setState(() {
                      corrected = true;
                    });
                    widget.fsrs.produceCard(testItem.testWord.id);
                    return ok;
                  },
                  bottomWidget: _bottomBar(mediaQuery, index, correct),
                );
              } else if(testItem.testType == 4) {
                return ListeningQuestion(
                  mainWord: testItem.testWord.arabic,
                  choices: testItem.options!,
                  allowMutipleSelect: true,
                  hint: "听下面的音频，选择最合适的选项",
                  onSelected: (value) {
                    if(value == -1) {
                      // 跳过也放行，否则 PageView 被锁死
                      setState(() {
                        corrected = true;
                      });
                      widget.fsrs.produceCard(testItem.testWord.id);
                      return false;
                    }
                    if(value == correct) {
                      setState(() {
                        corrected = true;
                      });
                      widget.fsrs.produceCard(testItem.testWord.id);
                      return true;
                    } else {
                      chosenWrong[index] = value;
                      return false;
                    }
                  },
                  bottom: _bottomBar(mediaQuery, index, correct),
                );
              } else {
                // 单词卡片题（type 0）
                return WordCardQuestion(
                  word: testItem.testWord,
                  hint: "尝试自行回忆以下单词",
                  bottomWidget: Button(
                    size: Size(mediaQuery.size.width * 0.8, clampDouble(mediaQuery.size.height * 0.1, 48.0, 96.0)),
                    onPressed: (){
                      setState(() {
                        corrected = true;
                      });
                      widget.fsrs.produceCard(testItem.testWord.id);
                      // 最后一题必须切到横向 PageView，否则永远到不了完成页
                      if(index == widget.words.length-1) {
                        controllerHor.nextPage(duration: AppMotion.medium, curve: AppMotion.standardCurve);
                      } else {
                        controllerQuestions.nextPage(duration: AppMotion.medium, curve: AppMotion.standardCurve);
                      }
                    },
                    icon: Icon(Icons.arrow_forward),
                    child: Text(index == widget.words.length-1 ? "完成学习" : "下一题"),
                  ),
                );
              }
            }
          ),
          Center(
            child: Column(
              children: [
                TextContainer(text: "该课程学习已完成\n已加入复习计划\n请过几个小时后再次进入规律学习页面复习课程"),
                Button(
                  onPressed: (){
                    Navigator.popUntil(context, (route)=>route.isFirst);
                  }, 
                  icon: Icon(Icons.done_all),
                  child: Text("确认"),
                )
              ],
            )
          )
        ],
      ))
    );
  }
}
