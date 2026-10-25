import 'dart:math';

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';

import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/push_session.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:arabic_learning/widgets/flip_word_card.dart' show FlipWordCard;
import 'package:arabic_learning/widgets/kit.dart' show Button, TextContainer;
import 'package:arabic_learning/widgets/overlays.dart' show viewAnswer;
import 'package:arabic_learning/widgets/questions.dart' show ChoiceQuestions, SpellQuestion, TestItem, WordCardQuestion;
import 'package:arabic_learning/widgets/shared.dart' show RevealableActionBar;

// 学习新东西的页面： 展示释义 -> 选择题
class FSRSLearningPage extends StatefulWidget {
  final List<WordItem> words;
  final FSRS fsrs;

  /// 断点恢复参数：横向阶段（0=卡片, 1=答题）与两个纵向页索引。
  final int initialPhase;
  final int initialLearningIndex;
  final int initialQuestionIndex;

  const FSRSLearningPage({
    super.key,
    required this.words,
    required this.fsrs,
    this.initialPhase = 0,
    this.initialLearningIndex = 0,
    this.initialQuestionIndex = 0,
  });

  @override
  State<FSRSLearningPage> createState() => _FSRSLearningPageState();
}
class _FSRSLearningPageState extends State<FSRSLearningPage> {
  late final PageController controllerHor;
  late final PageController controllerLearning;
  late final PageController controllerQuestions;
  final Random rnd = Random();
  bool corrected = false;

  /// 每个词随机固定一种题型
  final List<TestItem> testItems = [];
  List<int?> chosenWrong = [];

  @override
  void initState() {
    // 断点恢复：阶段与页索引按当前词数收敛到合法范围
    final int n = widget.words.length;
    final int phase = widget.initialPhase.clamp(0, 2);
    final int maxIndex = n > 0 ? n - 1 : 0;
    final int li = widget.initialLearningIndex.clamp(0, maxIndex);
    final int qi = widget.initialQuestionIndex.clamp(0, maxIndex);
    controllerHor = PageController(initialPage: phase);
    controllerLearning = PageController(initialPage: li);
    controllerQuestions = PageController(initialPage: qi);

    for(WordItem word in widget.words) {
      final int type = TestItem.pickType(widget.fsrs.config.reviewQuestionSections, rnd);
      testItems.add(TestItem.buildTestItem(word, type, AppData().wordData, widget.fsrs.config.preferSimilar, rnd));
      chosenWrong.add(null);
    }
    // 进入即写入本次断点（词库为空时不写）
    if(n > 0) {
      final int anchor = phase == 0 ? li : qi;
      PushSessionStore.save(PushCheckpoint(day: pushDayKey(DateTime.now()), phase: phase, wordId: widget.words[anchor].id, wordCount: n));
    }
    super.initState();
  }

  Widget _bottomBar(BuildContext context, MediaQueryData mediaQuery, int index, int correct) {
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
        onPageChanged: (value) {
          // 阶段 2=完成：清除断点；阶段 1=答题：以当前答题词写入断点
          if(value == 2) {
            PushSessionStore.clear();
          } else if(value == 1) {
            final int n = widget.words.length;
            if(n > 0) {
              final int idx = controllerQuestions.hasClients
                  ? controllerQuestions.page!.round().clamp(0, n - 1)
                  : 0;
              PushSessionStore.save(PushCheckpoint(day: pushDayKey(DateTime.now()), phase: 1, wordId: widget.words[idx].id, wordCount: n));
            }
          }
        },
        children: [
          // 学习阶段的
          PageView.builder(
            scrollDirection: Axis.vertical,
            controller: controllerLearning,
            itemCount: widget.words.length,
            onPageChanged: (value) {
              // 卡片阶段翻页即更新断点锚点
              PushSessionStore.save(PushCheckpoint(day: pushDayKey(DateTime.now()), phase: 0, wordId: widget.words[value].id, wordCount: widget.words.length));
            },
            itemBuilder: (context, index) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FlipWordCard(word: widget.words[index], masked: true),
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
              // 答题阶段翻页即更新断点锚点
              PushSessionStore.save(PushCheckpoint(day: pushDayKey(DateTime.now()), phase: 1, wordId: widget.words[value].id, wordCount: widget.words.length));
            },
            itemBuilder: (context, index) {
              final TestItem testItem = testItems[index];
              final int correct = testItem.correctIndex ?? -1;
              if(testItem.testType == 1 || testItem.testType == 2) {
                return ChoiceQuestions(
                  mainWord: testItem.testType == 1 ? testItem.testWord.chinese : testItem.testWord.arabic,
                  choices: testItem.options!,
                  allowAnitmation: true,
                  allowMutipleSelect: true,
                  optionWords: testItem.optionWords,
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
                  bottomWidget: _bottomBar(context, mediaQuery, index, correct),
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
                  bottomWidget: _bottomBar(context, mediaQuery, index, correct),
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
