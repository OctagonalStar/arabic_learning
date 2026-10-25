import 'dart:math';

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' show Rating;
import 'package:provider/provider.dart';

import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:arabic_learning/widgets/kit.dart' show TextContainer;
import 'package:arabic_learning/widgets/overlays.dart' show viewAnswer;
import 'package:arabic_learning/widgets/questions.dart' show ChoiceQuestions, SelfRatingQuestion, SpellQuestion, TestItem;
import 'package:arabic_learning/widgets/shared.dart' show RevealableActionBar;

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

  /// 选择题防止重复作答（重复调用会对同一张卡片重复 reviewCard，
  /// 产生重复/损坏的复习记录）。
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

  /// 选择题统一作答。
  bool _onChoiceSelected(int value) {
    if(answered) return false;
    answered = true;
    _reveal();
    context.read<Global>().updateLearningStreak();
    chosenIndex = value;
    final int correct = item.correctIndex ?? -1;
    if(correct == value) {
      widget.fsrs.produceCard(widget.wordID, duration: end!.difference(start).inMilliseconds, isCorrect: true);
      return true;
    }
    widget.fsrs.produceCard(widget.wordID, duration: end!.difference(start).inMilliseconds, isCorrect: false);
    widget.fsrs.penalizeWrongChoice(item.optionWords?[value].id);
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
    MediaQueryData mediaQuery = MediaQuery.of(context);
    final List<WordItem> wordData = AppData().wordData.words;

    // 每次 build 都重新计算：late final 只在首次 build 赋值，重建后读取会抛
    // LateInitializationError（点击详解无反应并报错）。
    final int correct = item.correctIndex ?? -1;
    final Widget question;

    if(selfRated) {
      question = SelfRatingQuestion(
        word: wordData[widget.wordID],
        hint: _hint(),
        // 自我评级卡同样允许翻卡：遮挡释义时点击卡片即可翻开查看详情。
        masked: !choosed,
        cardWidth: mediaQuery.size.width * 0.8,
        cardHeight: clampDouble(mediaQuery.size.height * 0.4, 150.0, 340.0),
        choices: const ["记得很清楚", "还记得", "回忆困难", "忘了"],
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
        allowAnitmation: true,
        allowMutipleSelect: false,
        optionWords: item.optionWords,
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
    } else {
      // 正常配置不会走到这里（题型已被 _normalizeSections 限制为 0-3）
      question = Center(child: TextContainer(text: "未知题型"));
    }

    return Material(child: question);
  }
}
