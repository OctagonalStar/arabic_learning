import 'dart:async';
import 'dart:math';

import 'package:arabic_learning/services/fsrs.dart' show FSRS;
import 'package:arabic_learning/services/favorites.dart' show FavoriteStore;
import 'package:arabic_learning/services/search.dart' show BKSearch;
import 'package:arabic_learning/core/extensions.dart' show StringExtensions;
import 'package:arabic_learning/services/words.dart' show collectAllCategories, wordMatchesCategories;
import 'package:arabic_learning/services/tts.dart' show playTextToSpeech;
import 'package:arabic_learning/models/config.dart';
import 'package:arabic_learning/models/dict.dart';
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' show Rating;
import 'package:provider/provider.dart';

import 'package:arabic_learning/core/adaptive.dart' show AdaptiveScope;
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion, AppSpacing;
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/learning_session.dart' show LearningSessionCheckpoint, LearningSessionStore;
import 'package:arabic_learning/widgets/flip_word_card.dart' show FlipWordCard;
import 'package:arabic_learning/widgets/kit.dart' show Button, CategoryFilter, TextContainer;
import 'package:arabic_learning/widgets/motion.dart' show StaggeredEntrance;
import 'package:arabic_learning/widgets/overlays.dart' show showSnackBar, viewAnswer;
import 'package:arabic_learning/widgets/questions.dart' show ChoiceQuestions, ListeningQuestion, SpellQuestion, TestItem, WordCardQuestion;
import 'package:arabic_learning/widgets/shared.dart' show ConclusionCard, RevealableActionBar, appInputDecoration;



/// 学习主入口页面
///
/// 支持「暂存恢复」：传入 [resume] 时按断点中的随机种子与题型配置重建题目，
/// 只保留断点记录的剩余题目，并回到断点记录的页面位置继续作答。
class InLearningPage extends StatefulWidget {
  /*
  题型说明 
    0: 单词卡片
    1: 中译阿 选择题
    2: 阿译中 选择题
    3: 中译阿 拼写题
    4: 听力题
  */
  final List<WordItem> words;
  final bool countInReview;

  /// 上次暂存的学习断点；为 null 表示开始一次新的学习。
  final LearningSessionCheckpoint? resume;

  const InLearningPage({super.key, required this.words, required this.countInReview, this.resume});
  @override
  State<InLearningPage> createState() => _InLearningPageState();
}

class _InLearningPageState extends State<InLearningPage> {
  /// 本次会话的随机种子：恢复时沿用断点种子，保证题目顺序可重建。
  late final int _sessionSeed;

  /// 本次会话固定的题型配置（恢复时取断点中的快照）。
  late final QuizConfig _quiz;

  List<TestItem> testList = [];
  bool clicked = false;
  int correctCount = 0;
  late final DateTime startTime;
  bool finished = false;
  late final PageController controller;
  final bool isAutoPlay = AppData().config.audio.autoPlay;
  final List<TestItem> playedList = [];

  /// 当前展示的 testList 下标（== testList.length 表示结算页）。
  /// 由 [PageView.onPageChanged] 维护，避免首帧 controller 尚未挂载时读到 0。
  late int _pageIndex;

  /// 洗牌完成、尚未因「跳过听力题」删改之前的完整题目列表。
  /// 断点里的 itemIndices 是这份列表的下标，恢复时据此取回剩余题目。
  List<TestItem> _allItems = [];

  /// 已提交答案的 testList 下标（用于判断当前页是否已作答）。
  final Set<int> _answeredIndexes = <int>{};

  /// 退出确认弹窗是否已打开，避免重复弹出。
  bool _exitDialogOpen = false;

  /// 断点是否已清理（进入结算页后只清理一次）。
  bool _checkpointCleared = false;

  /// 按 [TestItem] 对象记录已选索引（testList 可能被就地删改，按对象更稳）。
  final Map<TestItem, int> chosenIndexByItem = <TestItem, int>{};


  void onSolve({required WordItem targetWord, 
                required bool isCorrect, 
                required int takentime,
                bool isTypingQuestion = false}){
    if(isCorrect) correctCount++;
    FSRS fsrs = FSRS();
    if(widget.countInReview && fsrs.config.enabled) {
      if(isTypingQuestion) {
        fsrs.produceCard(targetWord.id, forceRate: isCorrect ? Rating.good : Rating.again);
      } else {
        fsrs.produceCard(targetWord.id, duration: takentime, isCorrect: isCorrect);
      }
    }
  }

  @override
  void initState() {
    // 题型配置与随机种子在进入页面时固定：恢复断点时沿用断点中的快照，
    // 保证重建出的题目与选项顺序与暂存时完全一致。
    _quiz = widget.resume?.quiz ?? AppData().config.quiz;
    _sessionSeed = widget.resume?.seed ?? DateTime.now().microsecondsSinceEpoch;
    final Random rnd = Random(_sessionSeed);

    // 加载测试词
    final QuizConfig questionsSetting = _quiz;
    List<List<TestItem>> questionsInSections = List.generate(questionsSetting.questionSections.length, (_) => []);

    for(int sectionIndex = 0; sectionIndex < questionsSetting.questionSections.length; sectionIndex++) {
      for(WordItem wordItem in widget.words) {
        questionsInSections[sectionIndex].add(
          TestItem.buildTestItem(
            wordItem, 
            questionsSetting.questionSections[sectionIndex], 
            AppData().wordData, 
            questionsSetting.preferSimilar, 
            rnd
          )
        );
      }
    }

    // shuffle part：所有洗牌都使用同一个种子随机数，保证恢复时顺序一致。
    if(questionsSetting.shuffleExternaly) questionsInSections.shuffle(rnd);
    for(List<TestItem> testItems in questionsInSections) {
      if(questionsSetting.shuffleInternaly) testItems.shuffle(rnd);
      testList.addAll(testItems);
    }
    if(questionsSetting.shuffleGlobally) testList.shuffle(rnd);

    // 洗牌后的完整题目列表：断点下标以它为参照。
    _allItems = List<TestItem>.of(testList);

    final LearningSessionCheckpoint? resume = widget.resume;
    if(resume != null) {
      final bool valid = resume.itemIndices.every((int index) => index >= 0 && index < _allItems.length);
      if(valid) {
        // 只保留断点中未完成的题目（被「跳过听力题」移除的题目不会回来）。
        testList = resume.itemIndices.map((int index) => _allItems[index]).toList();
        correctCount = resume.correctCount;
        // 已消耗时长接续计：结算页展示的总耗时不含暂存期间。
        startTime = DateTime.now().subtract(Duration(seconds: resume.elapsedSeconds));
        _pageIndex = min(max(resume.pageIndex, 0), testList.length);
        controller = PageController(initialPage: _pageIndex);
      } else {
        // 断点与当前题型配置/词库不匹配：丢弃断点，按完整题目列表重新开始。
        testList = List<TestItem>.of(_allItems);
        correctCount = 0;
        startTime = DateTime.now();
        _pageIndex = 0;
        controller = PageController(initialPage: _pageIndex);
        unawaited(LearningSessionStore.clear());
      }
    } else {
      startTime = DateTime.now();
      _pageIndex = 0;
      controller = PageController(initialPage: _pageIndex);
    }
    super.initState();
  }

  /// 当前所在的题目下标（== testList.length 即结算页）。
  int get _currentPage => _pageIndex;

  /// 暂存时应记录的「下次展示下标」：当前页已作答则前进一页。
  int get _checkpointPage {
    final int page = _currentPage;
    if(page >= testList.length) return testList.length;
    return _answeredIndexes.contains(page) ? min(page + 1, testList.length) : page;
  }

  /// 生成当前进度断点；题目位置按「完整题目列表」的下标记录。
  LearningSessionCheckpoint _buildCheckpoint() {
    final DateTime now = DateTime.now();
    return LearningSessionCheckpoint(
      seed: _sessionSeed,
      wordKeys: widget.words.map(LearningSessionCheckpoint.wordKey).toList(growable: false),
      quiz: _quiz,
      countInReview: widget.countInReview,
      itemIndices: testList.map((TestItem item) => _allItems.indexOf(item)).toList(growable: false),
      pageIndex: _checkpointPage,
      correctCount: correctCount,
      elapsedSeconds: now.difference(startTime).inSeconds,
      savedAtMillis: now.millisecondsSinceEpoch,
    );
  }

  /// 退出学习：已完成后直接返回，否则询问「暂存 / 直接退出」。
  Future<void> _requestExit() async {
    if(_exitDialogOpen) return;
    if(finished || _currentPage >= testList.length) {
      Navigator.pop(context, true);
      return;
    }
    _exitDialogOpen = true;
    final _LearningExitChoice? choice = await showDialog<_LearningExitChoice>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text("结束学习？"),
        content: const Text("可以暂存当前进度，下次进入学习时继续。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _LearningExitChoice.discard),
            child: const Text("直接退出"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, _LearningExitChoice.pause),
            child: const Text("暂存并退出"),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if(!mounted || choice == null) return;

    if(choice == _LearningExitChoice.pause) {
      await LearningSessionStore.save(_buildCheckpoint());
      if(!mounted) return;
      context.read<Global>().uiLogger.info("学习进度已暂存");
      Navigator.pop(context, false);
    } else {
      await LearningSessionStore.clear();
      if(!mounted) return;
      context.read<Global>().uiLogger.info("用户取消学习");
      Navigator.pop(context, false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 InLearningPage");
    final mediaQuery = MediaQuery.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if(!didPop) unawaited(_requestExit());
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          // 仅在结算页显示「学习完成」；最后一题仍保留关闭按钮（可暂存退出）。
          title: _pageIndex >= testList.length ? Center(child: Text("学习完成"))
          : Row(
            children: [
              Button(
                onPressed: _requestExit,
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
                    end: testList.length > 1 ? _pageIndex / (testList.length - 1) : 1.0,
                  ),
                  duration: AppMotion.extraLong2,
                  curve: AppMotion.standardCurve,
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                      value: 0.05 + value * 0.95,
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      color: Theme.of(context).colorScheme.secondary,
                      minHeight: clampDouble(mediaQuery.size.height * 0.04, 8.0, 24.0),
                      borderRadius: StaticsVar.br,
                    );
                  },
                )
              ),
              SizedBox(
                width: mediaQuery.size.width * 0.05,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text("${testList.length - _pageIndex - 1}"),
                ),
              )
            ],
          ),
        ),
        body: SafeArea(top: false, child: Center(
          child: PageView.builder(
            scrollDirection: AdaptiveScope.of(context).isWide ? Axis.vertical : Axis.horizontal,
            physics: NeverScrollableScrollPhysics(),
            controller: controller,
            onPageChanged: (int index) {
              setState(() => _pageIndex = index);
            },
            itemBuilder: (context, index) {
              if(index == testList.length) {
                finished = true;
                // 进入结算页即视为本次学习结束：清掉断点，避免下次误恢复。
                if(!_checkpointCleared) {
                  _checkpointCleared = true;
                  unawaited(LearningSessionStore.clear());
                }
                List<int> data = [
                  testList.length, 
                  correctCount, 
                  DateTime.now().difference(startTime).inSeconds
                ];
                return ConcludePage(data: data);
              }
              final TestItem testItem = testList[index];
              final DateTime quizStart = DateTime.now();
              if(testItem.testType == 0) {
                // wordCard
                return WordCardQuestion(
                  word: testItem.testWord,
                  hint: "尝试自行回忆以下单词",
                  bottomWidget: Button(
                    size: Size(mediaQuery.size.width * 0.8, clampDouble(mediaQuery.size.height * 0.1, 48.0, 96.0)),
                    onPressed: (){
                      _answeredIndexes.add(index);
                      controller.nextPage(duration: AppMotion.medium, curve: AppMotion.standardCurve);
                      correctCount++;
                      setState(() {});
                    },
                    icon: Icon(Icons.arrow_forward),
                    child: Text("下一题"),
                  ),
                );
              } else if(testItem.testType == 1 || testItem.testType == 2) {
                // ar-zh choose questions
                if(isAutoPlay && testItem.testType == 2 && !playedList.contains(testItem)) {
                  context.read<Global>().uiLogger.fine("自动播放单词发音: [${testItem.testWord.arabic}]");
                  playTextToSpeech(testItem.testWord.arabic);
                  playedList.add(testItem);
                }

                return ChoiceQuestions(
                  mainWord: testItem.testType == 1 ? testItem.testWord.chinese :  testItem.testWord.arabic, 
                  choices: testItem.options!, 
                  allowAudio: testItem.testType == 2, 
                  optionWords: testItem.optionWords,
                  onSelected: (value) {
                    chosenIndexByItem[testItem] = value;
                    bool ans = value == testItem.correctIndex;
                    // 多选/听力题答错后仍可重试，只有答对（会锁定）才算完成本题；
                    // 否则暂存后应回到本题，而不是跳过。
                    if(ans) _answeredIndexes.add(index);
                    if(!ans) {
                      Future.delayed(Duration(seconds: 1), (){if(context.mounted) viewAnswer(context, testItem.testWord, chosenWrong: testItem.optionWords![value]);});
                    }
                    onSolve(targetWord: testItem.testWord, isCorrect: ans, takentime: DateTime.now().difference(quizStart).inMilliseconds);
                    Future.delayed(Duration(milliseconds: 700) ,(){if(!mounted) return; setState(() {
                      clicked = true;
                    });});
                    return ans;
                  },
                  allowMutipleSelect: true,
                  hint: testItem.testType == 1 ? "通过中文选择阿拉伯语" : "通过阿拉伯语选择中文",
                  bottomWidget: BottomTip(
                    isShowNext: clicked, 
                    isLast: _pageIndex == testList.length - 1,
                    onNextClicked: (){
                      controller.nextPage(duration: AppMotion.medium, curve: AppMotion.standardCurve);
                      setState(() {
                        clicked = false;
                      });
                    }, 
                    onTipClicked: (){
                      viewAnswer(context, testItem.testWord, chosenWrong: (chosenIndexByItem[testItem] != null && chosenIndexByItem[testItem] != testItem.correctIndex) ? testItem.optionWords![chosenIndexByItem[testItem]!] : null);
                    }
                  )
                );
              } else if(testItem.testType == 3) {
                // spell question
                return SpellQuestion(
                  word: testItem.testWord,
                  hint: "拼写以下单词",
                  onCheck: (text) {
                    _answeredIndexes.add(index);
                    setState(() {
                      clicked = true;
                    });
                    if(text == testItem.testWord.arabic) {
                      onSolve(targetWord: testItem.testWord, isCorrect: true, takentime: DateTime.now().difference(quizStart).inMilliseconds);
                      return true;
                    } else {
                      onSolve(targetWord: testItem.testWord, isCorrect: false, takentime: DateTime.now().difference(quizStart).inMilliseconds);
                      viewAnswer(context, testItem.testWord);
                      return false;
                    }
                  },
                  bottomWidget: BottomTip(
                    isShowNext: clicked, 
                    isLast: _pageIndex == testList.length - 1,
                    onNextClicked: (){
                      controller.nextPage(duration: AppMotion.medium, curve: AppMotion.standardCurve);
                      setState(() {
                        clicked = false;
                      });
                    }, 
                    onTipClicked: (){
                      viewAnswer(context, testItem.testWord);
                    }
                  )
                );
              } else if(testItem.testType == 4){
                // 听力题
                return ListeningQuestion(
                  mainWord: testItem.testWord.arabic, 
                  choices: testItem.options!, 
                  optionWords: testItem.optionWords,
                  onSelected: (value) {
                    if(value == -1) {
                      // 跳过本题：后续听力题会被移除，本题视为已处理。
                      _answeredIndexes.add(index);
                      setState(() {
                        testList.removeWhere((TestItem wtestItem) => (wtestItem.testType == 4 && index < testList.indexOf(wtestItem)));
                        clicked = true;
                      });
                      return false;
                    }
                    chosenIndexByItem[testItem] = value;
                    bool ans = value == testItem.correctIndex;
                    if(ans) _answeredIndexes.add(index);
                    if(!ans) {
                      Future.delayed(Duration(seconds: 1), (){if(context.mounted) viewAnswer(context, testItem.testWord, chosenWrong: testItem.optionWords![value]);});
                    } 
                    onSolve(targetWord: testItem.testWord, isCorrect: ans, takentime: DateTime.now().difference(quizStart).inMilliseconds);
                    Future.delayed(Duration(milliseconds: 700) ,(){if(!mounted) return; setState(() {
                      clicked = true;
                    });});
                    return ans;
                  },
                  allowMutipleSelect: true,
                  hint: "听下面的音频，选择最合适的选项",
                  bottom: BottomTip(
                    isShowNext: clicked, 
                    isLast: _pageIndex == testList.length - 1,
                    onNextClicked: (){
                      controller.nextPage(duration: AppMotion.medium, curve: AppMotion.standardCurve);
                      setState(() {
                        clicked = false;
                      });
                    }, 
                    onTipClicked: (){
                      viewAnswer(context, testItem.testWord, chosenWrong: (chosenIndexByItem[testItem] != null && chosenIndexByItem[testItem] != testItem.correctIndex) ? testItem.optionWords![chosenIndexByItem[testItem]!] : null);
                    }
                  )
                );
              }
              return Center(
                child: TextContainer(text: "真奇怪，你不应该到这里来的，有时间给开发者反馈下吧..."),
              );
            },
          )
        ))
      ),
    );
  }
}

class BottomTip extends StatelessWidget {
  final bool isShowNext;
  final bool isLast;
  final void Function() onTipClicked;
  final void Function() onNextClicked;
  const BottomTip({super.key, required this.isShowNext, required this.isLast, required this.onNextClicked, required this.onTipClicked});

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return RevealableActionBar(
      revealed: isShowNext,
      tipWidth: (value) => mediaQuery.size.width * (0.8 - (0.45 * value)),
      tipLabel: (_) => "查看详解",
      tipLabelExpanded: true,
      tipBackgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      tipIcon: Icon(Icons.view_list),
      onTipClicked: onTipClicked,
      gapWidth: (value) => mediaQuery.size.width * 0.05 * value,
      nextThreshold: 0.0,
      nextWidth: (value) => mediaQuery.size.width * (0.45 * value),
      nextIcon: Icon(isLast ? Icons.done : Icons.navigate_next),
      nextIconDirection: AxisDirection.right,
      nextLabel: isLast ? "完成" : "下一个",
      nextBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
      onNextClicked: onNextClicked,
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

  /// 三段式卡片入场计时器：页面提前销毁时统一取消，避免对已卸载的 State setState。
  Timer? _revealTimer1;
  Timer? _revealTimer2;
  Timer? _revealTimer3;

  @override
  void initState() {
    super.initState();
    _revealTimer1 = Timer(Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        visible1 = true;
      });
      _revealTimer2 = Timer(Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() {
          visible2 = true;
        });
        _revealTimer3 = Timer(Duration(milliseconds: 200), () {
          if (!mounted) return;
          setState(() {
            visible3 = true;
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _revealTimer1?.cancel();
    _revealTimer2?.cancel();
    _revealTimer3?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 ConcludePage");
    // 结果卡尺寸按页面实际可用约束推导并夹在合理区间；高度不足时整页可滚动，
    // 避免矮横屏下三张卡片 + 间距 + 按钮超出视口。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double cardHeight = clampDouble(height * 0.2, 88.0, 170.0);
        final double gap = clampDouble(height * 0.05, 12.0, 36.0);
        final double buttonHeight = clampDouble(height * 0.1, 48.0, 96.0);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ConclusionCard(
                    visible: visible1,
                    slideFromLeft: true,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    width: width * 0.8,
                    height: cardHeight,
                    contentBuilder: (context, value) => Row(
                      children: [
                        Expanded(child: SizedBox()),
                        Text("已完成单词:  ", style: Theme.of(context).textTheme.titleLarge),
                        Text((widget.data[0] * value).ceil().toString(), style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                        SizedBox(width: width * 0.05),
                        CircularProgressIndicator(value: value)
                      ],
                    ),
                  ),
                  SizedBox(height: gap),
                  ConclusionCard(
                    visible: visible2,
                    slideFromLeft: false,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    width: width * 0.8,
                    height: cardHeight,
                    contentBuilder: (context, value) => Row(
                      children: [
                        CircularProgressIndicator(value: value * (widget.data[1]/widget.data[0])),
                        SizedBox(width: width * 0.05),
                        Text("回答正确数:  ", style: Theme.of(context).textTheme.titleLarge),
                        Text((widget.data[1] * value).ceil().toString(), style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                        Expanded(child: SizedBox()),
                      ],
                    ),
                  ),
                  SizedBox(height: gap),
                  ConclusionCard(
                    visible: visible3,
                    slideFromLeft: true,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    width: width * 0.8,
                    height: cardHeight,
                    contentBuilder: (context, value) => Row(
                      children: [
                        Expanded(child: SizedBox()),
                        Text("总耗时:  ", style: Theme.of(context).textTheme.titleLarge),
                        Text("${(widget.data[2] * value).ceil().toString()} 秒", style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                        SizedBox(width: width * 0.05),
                        CircularProgressIndicator(value: value)
                      ],
                    ),
                  ),
                  Expanded(child: SizedBox()),
                  Button(
                    size: Size(width, buttonHeight),
                    onPressed: (){
                      Navigator.pop(context, true);
                    },
                    child: Text("返回主页")
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class WordCardOverViewPage extends StatefulWidget {
  const WordCardOverViewPage({super.key});

  @override
  State<StatefulWidget> createState() => _WordCardOverViewPage();
}

class _WordCardOverViewPage extends State<WordCardOverViewPage> {
  final TextEditingController searchController = TextEditingController();
  /// 搜索输入框焦点由页面显式管理：进入搜索时聚焦、退出或打开词卡时取消，
  /// 避免输入法在弹层关闭后自动重新唤起。
  final FocusNode _searchFocusNode = FocusNode();
  bool inSearch = false;

  /// 已提交给检索的查询串（实时模式下经防抖更新，避免每次按键都触发检索）
  String _query = "";
  Timer? _searchDebounce;

  void _toggleSearch() {
    _searchDebounce?.cancel();
    setState(() {
      inSearch = !inSearch;
      _query = inSearch ? searchController.text : "";
    });
    if (inSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && inSearch) _searchFocusNode.requestFocus();
      });
    } else {
      _searchFocusNode.unfocus();
    }
  }

  /// 实时模式：输入停顿 200ms 后再检索
  void _onSearchChanged(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if(mounted) setState(() => _query = text);
    });
  }

  /// 立即检索（点击「查找」或回车）
  void _searchNow(String text) {
    _searchDebounce?.cancel();
    setState(() => _query = text);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocusNode.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 WordCardOverViewPage: inSearch{$inSearch}");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Scaffold(
      // 搜索框位于 AppBar，键盘弹出时不应压缩 body：否则网格 LayoutBuilder
      // 会按缩短后的高度重算卡片尺寸，导致搜索结果卡片整体缩放/重排。
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        bottom: inSearch ? PreferredSize(
          preferredSize: Size(mediaQuery.size.width, 75), 
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: inSearch ? 1.0 : 0.0), 
            duration: AppMotion.quick, 
            curve: AppMotion.standardCurve,
            builder: (context, value, child){
              return Center(
                child: SizedBox(
                  width: mediaQuery.size.width * value,
                  child: TextField(
                    textDirection: searchController.text.textDirection,
                    controller: searchController,
                    focusNode: _searchFocusNode,
                    expands: false,
                    maxLines: 1,
                    decoration: appInputDecoration(
                      context,
                      labelText: "词汇检索",
                      hintText: "阿语单词或中文释义",
                      suffix: Button(
                        onPressed: () => _searchNow(searchController.text), 
                        child: Text("查找")
                      ),
                    ),
                    onSubmitted: (text) {
                      _searchNow(text);
                    },
                    onChanged: AppData().config.learning.wordLookupRealtime ? _onSearchChanged : null,
                  ),
                ),
              );
            }
          )
        ) : null,
        title: Text(inSearch ? "单词检索" : "单词总览"),
        actions: [
          IconButton(
            onPressed: _toggleSearch,
            icon: inSearch ? Icon(Icons.search_off) : Icon(Icons.search)
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context, 
                builder: (context) {
                  // 主题的 bottomSheetTheme 已统一提供拖拽横条（showDragHandle: true），
                  // 这里不能再嵌套 BottomSheet，否则会渲染出两条拖拽横条。
                  int forceCloumn = AppData().config.learning.overviewForceColumn;
                  bool lookupRealtime = AppData().config.learning.wordLookupRealtime;
                  return StatefulBuilder(
                        builder: (context, setLocalState) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text("设置固定列数"),
                                  Slider(
                                    min: 0,
                                    max: 5,
                                    divisions: 5,
                                    value: forceCloumn.toDouble(), 
                                    onChanged: (value){
                                      setLocalState(() {
                                        forceCloumn = value.ceil();
                                      });
                                    },
                                    onChangeEnd: (value) {
                                      context.read<Global>().uiLogger.info("设置固定列数为$value");
                                    },
                                  ),
                                  Text(forceCloumn == 0 ? "0(自动)" : forceCloumn.toString()),
                                ],
                              ),
                              Row(
                                children: [
                                  Text("搜索时实时显示结果"),
                                  Switch(
                                    value: lookupRealtime, 
                                    onChanged: (value){
                                      setLocalState(() {
                                        lookupRealtime = value;
                                      });
                                      context.read<Global>().uiLogger.info("设置实时查找为$value");
                                    }
                                  )
                                ],
                              ),
                              Button(
                                size: Size(mediaQuery.size.width * 0.6, 100),
                                onPressed: (){
                                  setState(() {
                                    AppData().config = AppData().config.copyWith(
                                      learning: AppData().config.learning.copyWith(
                                        overviewForceColumn: forceCloumn,
                                        wordLookupRealtime: lookupRealtime
                                      )
                                    );
                                    context.read<Global>().updateSetting(refresh: false);
                                  });
                                  Navigator.pop(context);
                                }, 
                                icon: Icon(Icons.done),
                                child: Text("确认"),
                              )
                            ],
                          );
                        }
                      );
                }
              );
            }, 
            icon: Icon(Icons.settings)
          )
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _toggleSearch,
        child: inSearch ? Icon(Icons.search_off) : Icon(Icons.search)
      ),

      body: SafeArea(
        top: false,
        child: inSearch ? WordLookupLayout(lookfor: _query) : WordCardOverViewLayout(),
      )
    );
  }
}

class WordCardOverViewLayout extends StatelessWidget {
  const WordCardOverViewLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final AppData appData = AppData();
    // 单一滚动列表：词库 -> 班级 -> 网格全部在同一滚动视图中按“内容固有高度”
    // 展开，不再用两个嵌套 ListView + 固定像素 animateTo（旧实现会把被展开的
    // 行顶出屏幕、下方留下大片空白）。展开时用 [_revealOnExpand] 让该行对齐
    // 视口顶部，保证展开内容可见。
    return ListView.builder(
      itemCount: appData.wordData.classes.length,
      itemBuilder: (BuildContext context, int jsonIndex) {
        final SourceItem jsonSource = appData.wordData.classes[jsonIndex];
        return ExpansionTile(
          title: Text(jsonSource.name.trim()),
          minTileHeight: 64,
          onExpansionChanged: (value) {
            if (value) _revealOnExpand(context);
          },
          children: [
            for (final ClassItem classItem in jsonSource.subClasses)
              Builder(
                builder: (BuildContext classContext) {
                  return ExpansionTile(
                    title: Text(classItem.className.trim()),
                    minTileHeight: 62,
                    onExpansionChanged: (value) {
                      if (value) _revealOnExpand(classContext);
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _WordOverviewGrid(classItem: classItem),
                      ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// 展开后把当前行对齐到视口顶部，避免展开内容落在屏幕外。
///
/// 放在帧回调里执行：ExpansionTile 展开只向下增高，行首位置不变，因此即便
/// 展开动画尚未结束，对齐行首也能得到稳定结果。
void _revealOnExpand(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.0,
      duration: AppMotion.mediumShort,
      curve: AppMotion.standardCurve,
    );
  });
}

/// 词汇总览 / 查找网格列数：用户固定列数（>0）优先，否则按可用宽度约每
/// 300 逻辑像素一列，至少一列。
int _overviewGridColumns(double availableWidth) {
  final int forced = AppData().config.learning.overviewForceColumn;
  if(forced > 0) return forced;
  return max(1, availableWidth ~/ 300);
}

/// 词汇总览中单个班级的网格：按可用宽度自适应列数，cell 为正方形，整块高度
/// 由“行数 × cell 边长”推导（`SizedBox` 固定高度 + 不可滚动 GridView），
/// 因此可嵌在外层滚动列表中按内容自然展开，且保持懒加载。
class _WordOverviewGrid extends StatelessWidget {
  const _WordOverviewGrid({required this.classItem});

  final ClassItem classItem;

  /// 网格四周内边距与 cell 间距。
  static const double _pad = 4.0;
  static const double _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final AppData appData = AppData();
    if (classItem.wordIndexs.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = _overviewGridColumns(constraints.maxWidth);
        // cell 宽度 = (可用宽度 - 左右内边距 - 列间距) / 列数；正方形故高度相等。
        final double cellWidth = max(
          (constraints.maxWidth - _pad * 2 - _gap * (columns - 1)) / columns,
          1.0,
        );
        final int rows = (classItem.wordIndexs.length + columns - 1) ~/ columns;
        final double gridHeight =
            _pad * 2 + rows * cellWidth + max(0, rows - 1) * _gap;
        return SizedBox(
          height: gridHeight,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(_pad),
            itemCount: classItem.wordIndexs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: _gap,
              crossAxisSpacing: _gap,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              return StaggeredEntrance(
                index: index,
                child: Center(
                  child: FlipWordCard(
                    word: appData.wordData.words[classItem.wordIndexs[index]],
                    width: cellWidth,
                    height: cellWidth,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}


class WordLookupLayout extends StatefulWidget {
  final String lookfor;
  const WordLookupLayout({super.key, required this.lookfor});

  @override
  State<WordLookupLayout> createState() => _WordLookupLayoutState();
}

class _WordLookupLayoutState extends State<WordLookupLayout> {
  /// 当前选择的分类（AND 语义，空集合=不筛选）
  Set<String> selectedCategories = <String>{};

  /// 仅显示已收藏的单词。
  bool _onlyFavorite = false;

  @override
  Widget build(BuildContext context) {
    // 使用索引化检索（归一化预计算 + 字符倒排 + 整词 BK-Tree），替代原全表扫描
    final String lookfor = widget.lookfor.trim();
    if(lookfor.isEmpty) return SizedBox();
    List<WordItem> match = BKSearch.lookup(lookfor);

    // 分类筛选（AND）：所有检索途径的结果统一过滤
    if(selectedCategories.isNotEmpty) {
      match = match.where((WordItem word) => wordMatchesCategories(word, selectedCategories)).toList();
    }

    // 仅收藏筛选：在分类筛选之后继续收窄结果（命中判断 O(1)）。
    if(_onlyFavorite) {
      match = match.where((WordItem word) => FavoriteStore().contains(word.id)).toList();
    }

    context.read<Global>().uiLogger.finer("单词检索结果: ${match.length} 条");
    if(!AppData().config.learning.wordLookupRealtime){
      // 固定展示延迟属业务时序（等待列表渲染完成），不参与动效 token 化。
      Future.delayed(Durations.medium1, () {
        if(context.mounted) {
          showSnackBar(context, "检索到${match.length}个结果");
        }
      }); 
    }

    final List<String> availableCategories = collectAllCategories();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // 「仅收藏」开关始终可见（无分类可筛选时也在），样式与分类 chip 一致。
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, 0),
          child: Row(
            children: [
              FilterChip(
                label: Text(
                  "仅收藏",
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _onlyFavorite ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
                  ),
                ),
                selected: _onlyFavorite,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                selectedColor: scheme.secondaryContainer,
                backgroundColor: scheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: StaticsVar.br,
                  side: BorderSide(
                    color: _onlyFavorite ? scheme.secondary : scheme.outlineVariant,
                  ),
                ),
                onSelected: (bool value) {
                  setState(() {
                    _onlyFavorite = value;
                  });
                },
              ),
            ],
          ),
        ),
        if(availableCategories.isNotEmpty) CategoryFilter(
          available: availableCategories,
          selected: selectedCategories,
          onChanged: (Set<String> value) {
            setState(() {
              selectedCategories = value;
            });
          },
        ),
        Expanded(
          child: (match.isEmpty && (selectedCategories.isNotEmpty || _onlyFavorite))
            ? Center(child: Text("当前筛选条件下没有匹配的单词", style: Theme.of(context).textTheme.bodyLarge))
            : LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  // 列数与 cell 尺寸由网格区域可用宽高共同决定：
                  // cell 边长 = min(宽/列数, 高)，保证方形卡片不高于可视区域。
                  final int columns = _overviewGridColumns(constraints.maxWidth);
                  final double cellWidth = constraints.maxWidth / columns;
                  final double side = max(min(cellWidth, constraints.maxHeight), 1.0);
                  final double cardSide = max(side - 16.0, 0.0);
                  return GridView.builder(
                    itemCount: match.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: cellWidth / side,
                    ),
                    itemBuilder: (context, index) {
                      // 检索结果可能很长：只对首屏前 N 项做交错入场。
                      return StaggeredEntrance(
                        index: index,
                        child: Center(
                          child: FlipWordCard(
                            word: match[index],
                            width: cardSide,
                            height: cardSide,
                            // 取消收藏后重新应用「仅收藏」筛选。
                            onFavoriteChanged: () => setState(() {}),
                          ),
                        ),
                      );
                    }
                  );
                },
              ),
        ),
      ],
    );
  }
}

enum _LearningExitChoice { pause, discard }
