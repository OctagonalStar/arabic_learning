// 学习主页面：从 learning_pages_build.dart 拆分而来（仅搬迁，未改动行为）。
import 'dart:async';
import 'dart:math';

import 'package:arabic_learning/models/config.dart' show QuizConfig;
import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/core/adaptive.dart' show AdaptiveScope;
import 'package:arabic_learning/core/statics.dart' show StaticsVar;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/learning_session.dart'
    show LearningSessionCheckpoint, LearningSessionStore;
import 'package:arabic_learning/services/tts.dart' show playTextToSpeech;
import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:arabic_learning/widgets/kit.dart' show Button, TextContainer;
import 'package:arabic_learning/widgets/overlays.dart' show viewAnswer;
import 'package:arabic_learning/widgets/questions.dart'
    show ChoiceQuestions, ListeningQuestion, SpellQuestion, TestItem, WordCardQuestion;
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' show Rating;
import 'package:provider/provider.dart';

import 'bottom_tip.dart';
import 'conclude_page.dart';

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

  /// [_allItems] 的对象 → 下标映射。TestItem 未重写 ==，按对象身份定位；
  /// 暂存时逐题 indexOf 是 O(n²)，题目多时会让「暂存并退出」明显卡顿。
  late final Map<TestItem, int> _allItemIndex = <TestItem, int>{
    for (int i = 0; i < _allItems.length; i++) _allItems[i]: i,
  };

  /// 已提交答案的题目（按对象记录：testList 会被「跳过听力题」就地删改，下标会前移）。
  final Set<TestItem> _answeredItems = <TestItem>{};

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
    return _answeredItems.contains(testList[page]) ? min(page + 1, testList.length) : page;
  }

  /// 生成当前进度断点；题目位置按「完整题目列表」的下标记录。
  LearningSessionCheckpoint _buildCheckpoint() {
    final DateTime now = DateTime.now();
    return LearningSessionCheckpoint(
      seed: _sessionSeed,
      wordKeys: widget.words.map(LearningSessionCheckpoint.wordKey).toList(growable: false),
      quiz: _quiz,
      countInReview: widget.countInReview,
      itemIndices: testList.map((TestItem item) => _allItemIndex[item]!).toList(growable: false),
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
                      _answeredItems.add(testItem);
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
                  context.read<Global>().uiLogger.finest(() => "自动播放单词发音: [${testItem.testWord.arabic}]");
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
                    if(ans) _answeredItems.add(testItem);
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
                    _answeredItems.add(testItem);
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
                      _answeredItems.add(testItem);
                      setState(() {
                        // 跳过后移除其后的听力题，避免同一段音频被反复播放。
                        // 用线性遍历替代 removeWhere + indexOf（原写法是 O(n²)）。
                        final List<TestItem> kept = testList.sublist(0, index + 1);
                        for (int i = index + 1; i < testList.length; i++) {
                          if (testList[i].testType != 4) kept.add(testList[i]);
                        }
                        testList = kept;
                        if (_pageIndex > testList.length) {
                          _pageIndex = testList.length;
                        }
                        clicked = true;
                      });
                      return false;
                    }
                    chosenIndexByItem[testItem] = value;
                    bool ans = value == testItem.correctIndex;
                    if(ans) _answeredItems.add(testItem);
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

enum _LearningExitChoice { pause, discard }
