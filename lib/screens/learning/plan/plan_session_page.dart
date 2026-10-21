import 'dart:async' show unawaited;
import 'dart:math' show Random;

import 'package:arabic_learning/core/adaptive.dart' show AdaptiveScope;
import 'package:arabic_learning/core/statics.dart' show StaticsVar;
import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/models/plan.dart' show PlanChain;
import 'package:arabic_learning/screens/learning/learning_pages_build.dart'
    show BottomTip;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/plan_scheduler.dart'
    show PlanStatus, evaluateNow, nextGroupWords;
import 'package:arabic_learning/services/plan_store.dart' show PlanStore;
import 'package:arabic_learning/services/tts.dart' show playTextToSpeech;
import 'package:arabic_learning/theme/tokens.dart'
    show AppMotion, AppRadius, AppSpacing;
import 'package:arabic_learning/widgets/kit.dart' show Button, TextContainer;
import 'package:arabic_learning/widgets/overlays.dart'
    show showSnackBar, viewAnswer;
import 'package:arabic_learning/widgets/questions.dart'
    show
        ChoiceQuestions,
        ListeningQuestion,
        SpellQuestion,
        TestItem,
        WordCardQuestion;
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' show Rating;
import 'package:provider/provider.dart';

import 'plan_question_builder.dart'
    show buildPlanTestItems, countNewLearnedWords;

/// 计划学习：单组答题会话。
///
/// 出题顺序为 section-major（外层题型、内层单词），与学习页一致地渲染
/// 题型 0..4；非卡片题作答后写入 FSRS，并在本组结束时统计「新增已学词」
/// 写入当日计划进度。页面通过 `Navigator.pop(context, bool)` 告知调用方
/// 本组是否至少新增了 1 个 FSRS 卡片。
class PlanSessionPage extends StatefulWidget {
  /// 本组单词（由调用方通过 `nextGroupWords()` 取得）。
  final List<WordItem> words;

  /// 本组使用学习链条。
  final PlanChain chain;

  const PlanSessionPage({super.key, required this.words, required this.chain});

  @override
  State<PlanSessionPage> createState() => _PlanSessionPageState();
}

class _PlanSessionPageState extends State<PlanSessionPage> {
  /// 答题区 → 结算页的切换时长（约 260ms）。
  static const Duration _switchDuration = Duration(milliseconds: 260);

  /// 入场时的上移位移（相对自身高度的比例，约 16px / 视口高度）。
  static const Offset _switchSlideOffset = Offset(0.0, 0.035);

  /// 两个稳定 key：只有 `_finished` 翻转时 AnimatedSwitcher 才切换子树，
  /// 题目内部的 setState 不会误触发结算页动画。
  static const ValueKey<String> _questionsKey = ValueKey<String>(
    'plan_session_questions',
  );
  static const ValueKey<String> _conclusionKey = ValueKey<String>(
    'plan_session_conclusion',
  );

  final Random _rnd = Random();
  final PageController _controller = PageController();

  /// 本组题目（section-major）。
  final List<TestItem> _testList = <TestItem>[];

  /// 按 [TestItem] 对象记录已选索引（选项组件可能被重建）。
  final Map<TestItem, int> _chosenIndexByItem = <TestItem, int>{};

  /// 已自动播放过发音的听力题，避免重建时重复朗读。
  final List<TestItem> _playedList = <TestItem>[];

  final DateTime _startTime = DateTime.now();
  final bool _autoPlay = AppData().config.audio.autoPlay;

  /// 本组单词在进入页面时已经进入 FSRS 的 id，用于计算新增已学词。
  late final Set<int> _beforeIds;

  /// 非空时展示阻断页（不生成题目）。
  String? _blockedMessage;

  int _correctCount = 0;

  /// 已作答的题目下标：按题维护「下一步」是否揭示，
  /// 避免翻页时把上一题的底部操作栏动画收缩到 0 宽（会触发按钮内 Row 溢出）。
  final Set<int> _answeredIndexes = <int>{};
  bool _finished = false;
  PlanStatus? _status;

  /// 进入页面时的当日组号 / 当日总组数（会话进行中保持不变）。
  int _groupNo = 1;
  int _groupTotal = 1;

  /// 记录完成后预取的下一组单词；为空表示无法继续（含周期完成）。
  List<WordItem> _nextWords = const <WordItem>[];

  /// 记录进度只会执行一次：完成页 / 返回 / 系统返回共用同一个 Future。
  Future<int>? _recording;
  bool _startingNext = false;

  @override
  void initState() {
    super.initState();
    final FSRS fsrs = FSRS();
    if (!fsrs.inited || !fsrs.config.enabled) {
      _blockedMessage = "计划学习依赖复习系统的已学记录。请先在设置中启用复习系统后再开始计划学习。";
      _beforeIds = <int>{};
      return;
    }
    if (widget.words.isEmpty) {
      _blockedMessage = "本组没有可学习的单词，请回到计划页重新开始。";
      _beforeIds = <int>{};
      return;
    }

    _testList.addAll(
      buildPlanTestItems(
        words: widget.words,
        chain: widget.chain,
        wordData: AppData().wordData,
        preferSimilar: AppData().config.quiz.preferSimilar,
        rnd: _rnd,
      ),
    );
    if (_testList.isEmpty) {
      _blockedMessage = "当前学习链条没有可用题型，请回到计划页重新配置。";
      _beforeIds = <int>{};
      return;
    }

    _beforeIds = widget.words
        .where((WordItem word) => fsrs.isContained(word.id))
        .map((WordItem word) => word.id)
        .toSet();

    // 组号取自进入页面时的当日快照：`doneWords ~/ groupSize + 1`，
    // 并 clamp 到当日总组数，避免最后一组不足 groupSize 时越界。
    final PlanStatus status = evaluateNow();
    _status = status;
    final int size = status.groupSize < 1 ? 1 : status.groupSize;
    _groupTotal = status.groupsToday < 1 ? 1 : status.groupsToday;
    final int groupNo = status.doneWords ~/ size + 1;
    _groupNo = groupNo < 1 ? 1 : (groupNo > _groupTotal ? _groupTotal : groupNo);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 当前页（用于 AppBar 进度；无客户端时按第一题算）。
  int get _currentIndex =>
      _controller.hasClients ? (_controller.page?.round() ?? 0) : 0;

  /// 非卡片题作答：统计正确数 + 写 FSRS + 触发连胜。
  ///
  /// 与学习页 `onSolve` 保持一致：拼写题用强制评分（good / again），
  /// 其余题按用时与正误计算评分。卡片题不走这里。
  void _onSolve({
    required WordItem targetWord,
    required bool isCorrect,
    required int takenTime,
    bool isTypingQuestion = false,
  }) {
    if (isCorrect) _correctCount++;
    final FSRS fsrs = FSRS();
    if (isTypingQuestion) {
      fsrs.produceCard(
        targetWord.id,
        forceRate: isCorrect ? Rating.good : Rating.again,
      );
    } else {
      fsrs.produceCard(
        targetWord.id,
        duration: takenTime,
        isCorrect: isCorrect,
      );
    }
    // 门禁会在当日最低量未达标时自动拦截，这里无需提前判断。
    if (mounted) context.read<Global>().updateLearningStreak();
  }

  /// 前往下一题；已是最后一题则进入完成页。
  void _advance(int index) {
    if (index >= _testList.length - 1) {
      unawaited(_finishSession());
      return;
    }
    _controller.nextPage(
      duration: AppMotion.medium,
      curve: AppMotion.standardCurve,
    );
    // 仅用于刷新 AppBar 进度；各题自身的「下一步」状态按 index 独立维护。
    setState(() {});
  }

  /// 进入完成页（只记录一次进度）。
  Future<void> _finishSession() async {
    if (_finished) return;
    await _ensureRecorded();
    if (!mounted || _finished) return;
    setState(() {
      _finished = true;
    });
  }

  /// 返回上一级：先记录进度，再以 `delta > 0` 作为返回值。
  Future<void> _exitSession() async {
    final int delta = await _ensureRecorded();
    if (!mounted) return;
    Navigator.pop(context, delta > 0);
  }

  /// 保证本组进度只记录一次；重复调用复用同一个 Future。
  Future<int> _ensureRecorded() {
    return _recording ??= _recordResult();
  }

  Future<int> _recordResult() async {
    if (_blockedMessage != null) return 0;
    final int delta = countNewLearnedWords(
      words: widget.words,
      beforeIds: _beforeIds,
      isLearned: FSRS().isContained,
    );
    // 先取 Global 再 await，避免 await 之后使用已失效的 context。
    final Global global = context.read<Global>();
    await PlanStore().recordProgress(delta);
    global.updateLearningStreak();
    final PlanStatus status = evaluateNow();
    // 预取下一组：仅在周期未完成时取词，供完成页「继续第 N 组」判断可用性。
    final List<WordItem> next = status.cycleComplete
        ? const <WordItem>[]
        : nextGroupWords();
    if (mounted) {
      setState(() {
        _status = status;
        _nextWords = next;
      });
    }
    return delta;
  }

  /// 「继续第 N 组」：记录已完成后取下一组；周期结束 / 无未学词时不跳转。
  Future<void> _startNextGroup() async {
    if (_startingNext) return;
    _startingNext = true;
    await _ensureRecorded();
    if (!mounted) return;

    final PlanStatus status = _status ?? evaluateNow();
    if (status.cycleComplete) {
      _startingNext = false;
      return;
    }
    final List<WordItem> next = _nextWords.isNotEmpty
        ? _nextWords
        : nextGroupWords();
    if (next.isEmpty) {
      _startingNext = false;
      showSnackBar(context, "本周期已无未学单词");
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => PlanSessionPage(words: next, chain: widget.chain),
      ),
    );
  }

  /// 关闭按钮的二次确认；「确定」与系统返回走同一条记录 + 退出路径。
  Future<void> _confirmExit() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("提示"),
          content: const Text("确定要结束学习吗？"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("确定"),
            ),
          ],
        );
      },
    );
    if (confirmed == true) await _exitSession();
  }

  @override
  Widget build(BuildContext context) {
    if (_blockedMessage != null) return _buildBlockedPage(context);
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await _exitSession();
      },
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: SafeArea(
          top: false,
          // 最后一题 → 结算页：淡入 + 轻微上移；答题区反向淡出。
          // 两个子树各自持有稳定 key，仅 `_finished` 翻转时才会触发切换。
          child: AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : _switchDuration,
            switchInCurve: AppMotion.standardCurve,
            switchOutCurve: AppMotion.standardCurve,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: _switchSlideOffset,
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _finished
                ? KeyedSubtree(
                    key: _conclusionKey,
                    child: _buildConclusion(context),
                  )
                : KeyedSubtree(
                    key: _questionsKey,
                    child: Center(
                      child: PageView.builder(
                        scrollDirection: AdaptiveScope.of(context).isWide
                            ? Axis.vertical
                            : Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        controller: _controller,
                        itemCount: _testList.length,
                        itemBuilder: (BuildContext context, int index) {
                          return _buildQuestion(
                            context,
                            _testList[index],
                            index,
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final int total = _testList.length;
    final int index = _currentIndex;
    final double progress = total <= 1
        ? 1.0
        : clampDouble(index / (total - 1), 0.0, 1.0);
    return AppBar(
      automaticallyImplyLeading: false,
      title: _finished
          ? const Center(child: Text("学习完成"))
          : Row(
              children: [
                Button(
                  onPressed: () => unawaited(_confirmExit()),
                  child: const Icon(
                    Icons.close,
                    size: 24.0,
                    semanticLabel: 'Back',
                  ),
                ),
                SizedBox(width: mediaQuery.size.width * 0.01),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: progress),
                    duration: AppMotion.extraLong2,
                    curve: AppMotion.standardCurve,
                    builder:
                        (BuildContext context, double value, Widget? child) {
                          return LinearProgressIndicator(
                            value: 0.05 + value * 0.95,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            color: Theme.of(context).colorScheme.secondary,
                            minHeight: clampDouble(
                              mediaQuery.size.height * 0.04,
                              8.0,
                              24.0,
                            ),
                            borderRadius: StaticsVar.br,
                          );
                        },
                  ),
                ),
                SizedBox(
                  width: clampDouble(mediaQuery.size.width * 0.1, 72.0, 160.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Text(
                      "${total - index - 1}·第 $_groupNo/$_groupTotal 组",
                      maxLines: 1,
                      softWrap: false,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// 阻断页：FSRS 未启用 / 本组无单词 / 链条无可用题型。
  Widget _buildBlockedPage(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        Navigator.pop(context, false);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text("计划学习"),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextContainer(
                    text: _blockedMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Button(
                    size: Size(
                      clampDouble(mediaQuery.size.width * 0.6, 0.0, 320.0),
                      clampDouble(mediaQuery.size.height * 0.1, 48.0, 72.0),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("返回"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 题型分发：与 `learning_pages_build.dart` 中 InLearningPage 的组件选择
  /// 与回调参数保持一致（本项目第 4 处题型分发，允许重复，不改原文件）。
  Widget _buildQuestion(BuildContext context, TestItem testItem, int index) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final DateTime quizStart = DateTime.now();
    final bool isLast = index >= _testList.length - 1;

    if (testItem.testType == 0) {
      // 单词卡片：只计正确数，不写 FSRS。
      return WordCardQuestion(
        word: testItem.testWord,
        hint: "尝试自行回忆以下单词",
        bottomWidget: Button(
          size: Size(
            mediaQuery.size.width * 0.8,
            clampDouble(mediaQuery.size.height * 0.1, 48.0, 96.0),
          ),
          onPressed: () {
            _correctCount++;
            _advance(index);
          },
          icon: const Icon(Icons.arrow_forward),
          child: const Text("下一题"),
        ),
      );
    }

    if (testItem.testType == 1 || testItem.testType == 2) {
      // 中译阿 / 阿译中选择题。
      if (_autoPlay &&
          testItem.testType == 2 &&
          !_playedList.contains(testItem)) {
        context.read<Global>().uiLogger.finest(
          () => "自动播放单词发音: [${testItem.testWord.arabic}]",
        );
        playTextToSpeech(testItem.testWord.arabic);
        _playedList.add(testItem);
      }

      return ChoiceQuestions(
        mainWord: testItem.testType == 1
            ? testItem.testWord.chinese
            : testItem.testWord.arabic,
        choices: testItem.options!,
        allowAudio: testItem.testType == 2,
        optionWords: testItem.optionWords,
        onSelected: (int value) {
          _chosenIndexByItem[testItem] = value;
          final bool ans = value == testItem.correctIndex;
          if (!ans) {
            Future.delayed(const Duration(seconds: 1), () {
              if (!mounted || !context.mounted) return;
              viewAnswer(
                context,
                testItem.testWord,
                chosenWrong: testItem.optionWords![value],
              );
            });
          }
          _onSolve(
            targetWord: testItem.testWord,
            isCorrect: ans,
            takenTime: DateTime.now().difference(quizStart).inMilliseconds,
          );
          Future.delayed(const Duration(milliseconds: 700), () {
            if (mounted) {
              setState(() {
                _answeredIndexes.add(index);
              });
            }
          });
          return ans;
        },
        allowMutipleSelect: true,
        hint: testItem.testType == 1 ? "通过中文选择阿拉伯语" : "通过阿拉伯语选择中文",
        bottomWidget: BottomTip(
          isShowNext: _answeredIndexes.contains(index),
          isLast: isLast,
          onNextClicked: () => _advance(index),
          onTipClicked: () {
            viewAnswer(
              context,
              testItem.testWord,
              chosenWrong:
                  (_chosenIndexByItem[testItem] != null &&
                      _chosenIndexByItem[testItem] != testItem.correctIndex)
                  ? testItem.optionWords![_chosenIndexByItem[testItem]!]
                  : null,
            );
          },
        ),
      );
    }

    if (testItem.testType == 3) {
      // 中译阿拼写题。
      return SpellQuestion(
        word: testItem.testWord,
        hint: "拼写以下单词",
        onCheck: (String text) {
          setState(() {
            _answeredIndexes.add(index);
          });
          final bool correct = text == testItem.testWord.arabic;
          _onSolve(
            targetWord: testItem.testWord,
            isCorrect: correct,
            takenTime: DateTime.now().difference(quizStart).inMilliseconds,
            isTypingQuestion: true,
          );
          if (!correct) viewAnswer(context, testItem.testWord);
          return correct;
        },
        bottomWidget: BottomTip(
          isShowNext: _answeredIndexes.contains(index),
          isLast: isLast,
          onNextClicked: () => _advance(index),
          onTipClicked: () {
            viewAnswer(context, testItem.testWord);
          },
        ),
      );
    }

    if (testItem.testType == 4) {
      // 听力题：跳过（-1）不写 FSRS，并移除后续听力题（与学习页一致）。
      return ListeningQuestion(
        mainWord: testItem.testWord.arabic,
        choices: testItem.options!,
        optionWords: testItem.optionWords,
        onSelected: (int value) {
          if (value == -1) {
            setState(() {
              _testList.removeWhere(
                (TestItem item) =>
                    item.testType == 4 && index < _testList.indexOf(item),
              );
              _answeredIndexes.add(index);
            });
            return false;
          }
          _chosenIndexByItem[testItem] = value;
          final bool ans = value == testItem.correctIndex;
          if (!ans) {
            Future.delayed(const Duration(seconds: 1), () {
              if (!mounted || !context.mounted) return;
              viewAnswer(
                context,
                testItem.testWord,
                chosenWrong: testItem.optionWords![value],
              );
            });
          }
          _onSolve(
            targetWord: testItem.testWord,
            isCorrect: ans,
            takenTime: DateTime.now().difference(quizStart).inMilliseconds,
          );
          Future.delayed(const Duration(milliseconds: 700), () {
            if (mounted) {
              setState(() {
                _answeredIndexes.add(index);
              });
            }
          });
          return ans;
        },
        allowMutipleSelect: true,
        hint: "听下面的音频，选择最合适的选项",
        bottom: BottomTip(
          isShowNext: _answeredIndexes.contains(index),
          isLast: isLast,
          onNextClicked: () => _advance(index),
          onTipClicked: () {
            viewAnswer(
              context,
              testItem.testWord,
              chosenWrong:
                  (_chosenIndexByItem[testItem] != null &&
                      _chosenIndexByItem[testItem] != testItem.correctIndex)
                  ? testItem.optionWords![_chosenIndexByItem[testItem]!]
                  : null,
            );
          },
        ),
      );
    }

    return Center(child: TextContainer(text: "真奇怪，你不应该到这里来的，有时间给开发者反馈下吧..."));
  }

  /// 完成页：本组统计 + 今日最低量进度 + 返回计划（主）/ 继续下一组（次）。
  Widget _buildConclusion(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final int total = _testList.length;
    final int seconds = DateTime.now().difference(_startTime).inSeconds;
    final PlanStatus? status = _status;
    final int doneWords = status?.doneWords ?? 0;
    final int minWords = status?.minWords ?? 0;
    final bool todayDone = minWords > 0 && doneWords >= minWords;
    final bool cycleComplete = status?.cycleComplete ?? false;
    final double todayProgress = minWords > 0
        ? clampDouble(doneWords / minWords, 0.0, 1.0)
        : 0.0;
    final String timeText = seconds >= 60
        ? "${seconds ~/ 60} 分 ${seconds % 60} 秒"
        : "$seconds 秒";
    // 下一组组号：记录后的 doneWords 已包含本组新增量。
    final int groupSize = status?.groupSize ?? 0;
    final int size = groupSize < 1 ? 1 : groupSize;
    final int nextGroupNo = doneWords ~/ size + 1;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double cardWidth = clampDouble(width * 0.9, 0.0, 520.0);
        final double buttonWidth = clampDouble(width * 0.8, 0.0, 360.0);
        final double buttonHeight = clampDouble(height * 0.1, 48.0, 72.0);

        Widget stat(String label, String value) {
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: cardWidth,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: StaticsVar.br,
                    ),
                    child: Row(
                      children: [
                        stat("本组题数", "$total"),
                        stat("正确数", "$_correctCount"),
                        stat("用时", timeText),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: cardWidth,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: StaticsVar.br,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "今日进度",
                                style: textTheme.titleMedium?.copyWith(
                                  color: scheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                            Text(
                              "$doneWords / $minWords",
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppRadius.control / 2,
                          ),
                          child: LinearProgressIndicator(
                            value: todayProgress,
                            minHeight: 10,
                            backgroundColor: scheme.onSecondaryContainer
                                .withValues(alpha: 0.12),
                            color: scheme.secondary,
                          ),
                        ),
                        if (todayDone) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            "今日最低目标已完成",
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (cycleComplete) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      "本周期已完成，请回到计划页重新配置",
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Button(
                    size: Size(buttonWidth, buttonHeight),
                    onPressed: () => unawaited(_exitSession()),
                    icon: const Icon(Icons.arrow_back),
                    child: const Text("返回计划"),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Button(
                    size: Size(buttonWidth, buttonHeight),
                    onPressed:
                        cycleComplete || _nextWords.isEmpty || _startingNext
                        ? null
                        : () => unawaited(_startNextGroup()),
                    icon: const Icon(Icons.play_arrow),
                    backgroundColor: scheme.secondaryContainer,
                    child: Text("继续第 $nextGroupNo 组"),
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
