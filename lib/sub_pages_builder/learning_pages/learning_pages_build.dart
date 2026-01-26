import 'dart:math';

import 'package:arabic_learning/funcs/fsrs_func.dart' show FSRS;
import 'package:arabic_learning/funcs/utili.dart' show BKSearch, StringExtensions, getLevenshtein, getRandomWords;
import 'package:arabic_learning/vars/config_structure.dart';
import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' show Rating;
import 'package:provider/provider.dart';

import 'package:arabic_learning/vars/statics_var.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/funcs/ui.dart';



/// 学习主入口页面
class InLearningPage extends StatefulWidget {
  /*
  题型说明 
    0: 单词卡片
    1: 中译阿 选择题
    2: 阿译中 选择题
    3: 中译阿 拼写题
  */
  final List<WordItem> words;
  const InLearningPage({super.key, required this.words});
  @override
  State<InLearningPage> createState() => _InLearningPageState();
}

class _InLearningPageState extends State<InLearningPage> {
  Random rnd = Random();
  List<TestItem> testList = [];
  bool clicked = false;
  int correctCount = 0;
  late final DateTime startTime;
  bool finished = false;
  final PageController controller = PageController(initialPage: 0);

  void onSolve({required WordItem targetWord, 
                required bool isCorrect, 
                required int takentime,
                required FSRS fsrs,
                bool isTypingQuestion = false}){
    if(isCorrect) correctCount++;
    if(fsrs.config.enabled) {
      if(fsrs.isContained(targetWord.id)){
        if(isTypingQuestion) {
          fsrs.reviewCard(targetWord.id, takentime, isCorrect, forceRate: isCorrect ? Rating.good : Rating.again);
        } else {
          fsrs.reviewCard(targetWord.id, takentime, isCorrect);
        }
      } else {
        if(isCorrect) fsrs.addWordCard(targetWord.id);
      }
      
    }
  }

  @override
  void initState() {
    // 加载测试词
    final SubQuizConfig questionsSetting = context.read<Global>().globalConfig.quiz.zhar;
    List<List<TestItem>> questionsInSections = List.generate(questionsSetting.questionSections.length, (_) => []);

    for(int sectionIndex = 0; sectionIndex < questionsSetting.questionSections.length; sectionIndex++) {
      for(WordItem wordItem in widget.words) {
        questionsInSections[sectionIndex].add(
          TestItem.buildTestItem(
            wordItem, 
            questionsSetting.questionSections[sectionIndex], 
            context.read<Global>().wordData, 
            questionsSetting.preferSimilar, 
            rnd
          )
        );
      }
    }

    // shuffle part
    if(questionsSetting.shuffleExternaly) questionsInSections.shuffle();
    for(List<TestItem> testItems in questionsInSections) {
      if(questionsSetting.shuffleInternaly) testItems.shuffle();
      testList.addAll(testItems);
    }
    if(questionsSetting.shuffleGlobally) testList.shuffle();
    startTime  = DateTime.now();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 InLearningPage");
    final mediaQuery = MediaQuery.of(context);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if(!didPop) Navigator.pop(context, finished);
        result = finished;
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: (((controller.hasClients ? controller.page?.ceil() : 0) ?? 0)+1) >= testList.length ? Center(child: Text("学习完成"))
          : Row(
            children: [
              ElevatedButton(
                onPressed: (){
                  showDialog(
                    context: context, 
                    builder: (context) {
                      return AlertDialog(
                        title: Text("提示"),
                        content: Text("确定要结束学习吗？"),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text("取消"),
                          ),
                          TextButton(
                            onPressed: () {
                              context.read<Global>().uiLogger.info("用户取消学习");
                              Navigator.pop(context);
                              Navigator.pop(context, finished);
                            },
                            child: Text("确定"),
                          )
                        ],
                      );
                    },
                  );
                },
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
                    end: ((controller.hasClients ? controller.page?.ceil() : 0) ?? 0) / (testList.length - 1),
                  ),
                  duration: const Duration(milliseconds: 500),
                  curve: StaticsVar.curve,
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                      value: 0.05 + value * 0.95,
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      color: Theme.of(context).colorScheme.secondary,
                      minHeight: mediaQuery.size.height * 0.04,
                      borderRadius: StaticsVar.br,
                    );
                  },
                )
              ),
              SizedBox(
                width: mediaQuery.size.width * 0.05,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text("${testList.length - ((controller.hasClients ? controller.page?.ceil() : 0) ?? 0) - 1}"),
                ),
              )
            ],
          ),
        ),
        body: Center(
          child: PageView.builder(
            scrollDirection: Provider.of<Global>(context).isWideScreen ? Axis.vertical : Axis.horizontal,
            physics: NeverScrollableScrollPhysics(),
            // itemCount: testList.length,
            controller: controller,
            itemBuilder: (context, index) {
              if(index == testList.length) {
                finished = true;
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
                  bottomWidget: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      fixedSize: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.1),
                      shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
                    ),
                    onPressed: (){
                      controller.nextPage(duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
                      correctCount++;
                      setState(() {});
                    },
                    icon: Icon(Icons.arrow_forward),
                    label: Text("下一题"),
                  ),
                );
              } else if(testItem.testType == 1 || testItem.testType == 2) {
                // ar-zh choose questions
                return ChoiceQuestions(
                  mainWord: testItem.testType == 1 ? testItem.testWord.chinese :  testItem.testWord.arabic, 
                  choices: testItem.options!, 
                  allowAudio: testItem.testType == 2, 
                  onSelected: (value) {
                    bool ans = value == testItem.correctIndex;
                    if(!ans) {
                      Future.delayed(Duration(seconds: 1), (){if(context.mounted) viewAnswer(context, testItem.testWord);});
                    }
                    onSolve(targetWord: testItem.testWord, isCorrect: ans, takentime: DateTime.now().difference(quizStart).inMilliseconds, fsrs: context.read<Global>().globalFSRS);
                    Future.delayed(Duration(milliseconds: 700) ,(){setState(() {
                      clicked = true;
                    });});
                    return ans;
                  },
                  allowMutipleSelect: true,
                  hint: testItem.testType == 1 ? "通过中文选择阿拉伯语" : "通过阿拉伯语选择中文",
                  bottomWidget: BottomTip(
                    isShowNext: clicked, 
                    isLast: controller.page?.ceil() == testList.length - 1, 
                    onNextClicked: (){
                      controller.nextPage(duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
                      setState(() {
                        clicked = false;
                      });
                    }, 
                    onTipClicked: (){
                      viewAnswer(context, testItem.testWord);
                    }
                  )
                );
              } else if(testItem.testType == 3) {
                // spell question
                return SpellQuestion(
                  word: testItem.testWord,
                  hint: "拼写以下单词",
                  onCheck: (text) {
                    setState(() {
                      clicked = true;
                    });
                    if(text == testItem.testWord.arabic) {
                      onSolve(targetWord: testItem.testWord, isCorrect: true, takentime: DateTime.now().difference(quizStart).inMilliseconds, fsrs: context.read<Global>().globalFSRS, isTypingQuestion: true);
                      return true;
                    } else {
                      onSolve(targetWord: testItem.testWord, isCorrect: false, takentime: DateTime.now().difference(quizStart).inMilliseconds, fsrs: context.read<Global>().globalFSRS, isTypingQuestion: true);
                      viewAnswer(context, testItem.testWord);
                      return false;
                    }
                  },
                  bottomWidget: BottomTip(
                    isShowNext: clicked, 
                    isLast: controller.page?.ceil() == testList.length - 1, 
                    onNextClicked: (){
                      controller.nextPage(duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
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
                  onSelected: (value) {
                    if(value == -1) {
                      setState(() {
                        testList.removeWhere((TestItem wtestItem) => (wtestItem.testType == 4 && index < testList.indexOf(wtestItem)));
                        clicked = true;
                      });
                      return false;
                    }
                    bool ans = value == testItem.correctIndex;
                    if(!ans) {
                      Future.delayed(Duration(seconds: 1), (){if(context.mounted) viewAnswer(context, testItem.testWord);});
                    } 
                    onSolve(targetWord: testItem.testWord, isCorrect: ans, takentime: DateTime.now().difference(quizStart).inMilliseconds, fsrs: context.read<Global>().globalFSRS);
                    Future.delayed(Duration(milliseconds: 700) ,(){setState(() {
                      clicked = true;
                    });});
                    return ans;
                  },
                  allowMutipleSelect: true,
                  hint: "听下面的音频，选择最合适的选项",
                  bottom: BottomTip(
                    isShowNext: clicked, 
                    isLast: controller.page?.ceil() == testList.length - 1, 
                    onNextClicked: (){
                      controller.nextPage(duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
                      setState(() {
                        clicked = false;
                      });
                    }, 
                    onTipClicked: (){
                      viewAnswer(context, testItem.testWord);
                    }
                  )
                );
              }
              return Center(
                child: TextContainer(text: "真奇怪，你不应该到这里来的，有时间给开发者反馈下吧..."),
              );
            },
          )
        )
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
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: 0.0,
        end: isShowNext ? 1.0 : 0.0,
      ),
      duration: const Duration(milliseconds: 500),
      curve: StaticsVar.curve,
      builder: (context, value, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                fixedSize: Size(mediaQuery.size.width * (0.8 - (0.45 * value)), mediaQuery.size.height * 0.1),
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: StaticsVar.br,
                ),
              ),
              onPressed: onTipClicked, 
              child: FittedBox(
                fit: BoxFit.contain,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.view_list, size: 16.0, semanticLabel: "查看详解"),
                    SizedBox(width: mediaQuery.size.width * 0.01),
                    Text("查看详解"),
                  ],
                ),
              )
            ),
            SizedBox(width: mediaQuery.size.width * 0.05 * value),
            if(value != 0.0) ElevatedButton(
              style: ElevatedButton.styleFrom(
                fixedSize: Size(mediaQuery.size.width * (0.45 * value), mediaQuery.size.height * 0.1),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
              ),
              onPressed: onNextClicked,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isLast ? Icons.done : Icons.navigate_next, size: 16.0),
                    SizedBox(width: mediaQuery.size.width * 0.01),
                    Text(isLast ? "完成" : "下一个"),
                  ],
                ),
              ),
            )
          ],
        );
      }
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

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          visible1 = true;
        });
        Future.delayed(Duration(milliseconds: 200), () {
          setState(() {
            visible2 = true;
          });
          Future.delayed(Duration(milliseconds: 200), () {
            setState(() {
              visible3 = true;
            });
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 ConcludePage");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSlide(
            offset: visible1 ? Offset(-0.2, 0) : const Offset(-1.5, 0.2),
            duration: Duration(seconds: 1),
            curve: StaticsVar.curve,
            child: Container(
              width: mediaQuery.size.width * 0.8,
              height: mediaQuery.size.height * 0.2,
              padding: EdgeInsets.all(16.0),
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary,
                borderRadius: StaticsVar.br,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.surfaceBright,
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  )
                ]
              ),
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.0, end: visible1 ? 1.0 : 0.0),
                duration: Duration(seconds: 4),
                curve: StaticsVar.curve,
                builder: (context, value, child) {
                  return Row(
                      children: [
                        Expanded(child: SizedBox()),
                        Text("已完成单词:  ", style: TextStyle(fontSize: 20.0)),
                        Text((widget.data[0] * value).ceil().toString(), style: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold)),
                        SizedBox(width: mediaQuery.size.width * 0.05),
                        CircularProgressIndicator(value: value)
                      ],
                    );
                }
              ),
            ),
          ),
          SizedBox(height: mediaQuery.size.height * 0.05),
          AnimatedSlide(
            offset: visible2 ? Offset(0.2, 0) : const Offset(1.5, 0.2),
            duration: Duration(seconds: 1),
            curve: StaticsVar.curve,
            child: Container(
              width: mediaQuery.size.width * 0.8,
              height: mediaQuery.size.height * 0.2,
              padding: EdgeInsets.all(16.0),
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSecondary,
                borderRadius: StaticsVar.br,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.surfaceBright,
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  )
                ]
              ),
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.0, end: visible2 ? 1.0 : 0.0),
                duration: Duration(seconds: 4),
                curve: StaticsVar.curve,
                builder: (context, value, child) {
                  return Row(
                      children: [
                        CircularProgressIndicator(value: value * (widget.data[1]/widget.data[0])),
                        SizedBox(width: mediaQuery.size.width * 0.05),
                        Text("回答正确数:  ", style: TextStyle(fontSize: 20.0)),
                        Text((widget.data[1] * value).ceil().toString(), style: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold)),
                        Expanded(child: SizedBox()),
                      ],
                    );
                }
              ),
            ),
          ),
          SizedBox(height: mediaQuery.size.height * 0.05),
          AnimatedSlide(
            offset: visible3 ? Offset(-0.2, 0) : const Offset(-1.5, 0.2),
            duration: Duration(seconds: 1),
            curve: StaticsVar.curve,
            child: Container(
              width: mediaQuery.size.width * 0.8,
              height: mediaQuery.size.height * 0.2,
              padding: EdgeInsets.all(16.0),
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary,
                borderRadius: StaticsVar.br,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.surfaceBright,
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  )
                ]
              ),
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.0, end: visible3 ? 1.0 : 0.0),
                duration: Duration(seconds: 4),
                curve: StaticsVar.curve,
                builder: (context, value, child) {
                  return Row(
                      children: [
                        Expanded(child: SizedBox()),
                        Text("总耗时:  ", style: TextStyle(fontSize: 20.0)),
                        Text("${(widget.data[2] * value).ceil().toString()} 秒", style: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold)),
                        SizedBox(width: mediaQuery.size.width * 0.05),
                        CircularProgressIndicator(value: value)
                      ],
                    );
                }
              ),
            ),
          ),
          Expanded(child: SizedBox()),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              fixedSize: Size(mediaQuery.size.width, mediaQuery.size.height * 0.1),
              shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
            ),
            onPressed: (){
              Navigator.pop(context, true);
            },
            child: Text("返回主页")
          ),
        ],
      ),
    );
  }
}

@immutable
class TestItem {
  /// 测试单词
  final WordItem testWord;

  /// 测试类型
  /// 0: 单词卡片
  /// 1: 中译阿 选择题
  /// 2: 阿译中 选择题
  /// 3: 拼写题
  /// 4: 听力题
  final int testType;

  /// 选择题和听力题的选项
  final List<String>? options;

  /// 选择题和听力题的正确血选项索引号
  final int? correctIndex;

  const TestItem({
    required this.testWord,
    required this.testType,
    this.options,
    this.correctIndex
  });

  static TestItem buildTestItem(WordItem word, int testType, DictData wordData,bool preferSimilar,Random rnd){
    if(testType == 0 || testType == 3){
      return TestItem(testWord: word, testType: testType);
    } else {
      final List<WordItem> optionWords = getRandomWords(4, wordData, include: word, preferClass: !preferSimilar, rnd: rnd);
      return TestItem(
        testWord: word, 
        testType: testType,
        options: List.generate(4, (int index) => ((testType == 2 || (testType == 4 && rnd.nextBool())) ? optionWords[index].chinese : optionWords[index].arabic), growable: false),
        correctIndex: optionWords.indexOf(word)
      );
    }
  }
}

class WordCardOverViewPage extends StatefulWidget {
  const WordCardOverViewPage({super.key});

  @override
  State<StatefulWidget> createState() => _WordCardOverViewPage();
}

class _WordCardOverViewPage extends State<WordCardOverViewPage> {
  final TextEditingController searchController = TextEditingController();
  bool inSearch = false;

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 WordCardOverViewPage: inSearch{$inSearch}");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Scaffold(
      appBar: AppBar(
        bottom: inSearch ? PreferredSize(
          preferredSize: Size(mediaQuery.size.width, 75), 
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: inSearch ? 1.0 : 0.0), 
            duration: Duration(milliseconds: 300), 
            curve: StaticsVar.curve,
            builder: (context, value, child){
              return Center(
                child: SizedBox(
                  width: mediaQuery.size.width * value,
                  child: TextField(
                    textDirection: searchController.text.isArabic() ? TextDirection.rtl : TextDirection.ltr,
                    controller: searchController,
                    autofocus: true,
                    expands: false,
                    maxLines: 1,
                    decoration: InputDecoration(
                      labelText: "词汇检索",
                      hintText: "阿语单词或中文释义",
                      border: OutlineInputBorder(
                        borderRadius: StaticsVar.br,
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                      ),
                      suffix: ElevatedButton(
                        onPressed: () => setState(() {}), 
                        child: Text("查找")
                      ),
                    ),
                    onSubmitted: (text) {
                      setState(() {});
                    },
                    onChanged: context.read<Global>().globalConfig.learning.wordLookupRealtime ? (text) {
                      setState(() {});
                    } : null,
                  ),
                ),
              );
            }
          )
        ) : null,
        title: Text(inSearch ? "单词检索" : "单词总览"),
        actions: [
          IconButton(
            onPressed: () => setState(() => inSearch = !inSearch),
            icon: inSearch ? Icon(Icons.search_off) : Icon(Icons.search)
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context, 
                builder: (context) {
                  return BottomSheet(
                    onClosing: () {
                      
                    },
                    builder: (context) {
                      int forceCloumn = context.read<Global>().globalConfig.learning.overviewForceColumn;
                      bool lookupRealtime = context.read<Global>().globalConfig.learning.wordLookupRealtime;
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
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
                                  fixedSize: Size(mediaQuery.size.width * 0.6, 100)
                                ),
                                onPressed: (){
                                  setState(() {
                                    context.read<Global>().globalConfig = context.read<Global>().globalConfig.copyWith(
                                      learning: context.read<Global>().globalConfig.learning.copyWith(
                                        overviewForceColumn: forceCloumn,
                                        wordLookupRealtime: lookupRealtime
                                      )
                                    );
                                    context.read<Global>().updateSetting(refresh: false);
                                  });
                                  Navigator.pop(context);
                                }, 
                                icon: Icon(Icons.done),
                                label: Text("确认"),
                              )
                            ],
                          );
                        }
                      );
                    },
                  );
                }
              );
            }, 
            icon: Icon(Icons.settings)
          )
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => inSearch = !inSearch),
        child: inSearch ? Icon(Icons.search_off) : Icon(Icons.search)
      ),

      body: inSearch ? WordLookupLayout(lookfor: searchController.text.removeAracicExtensionPart()) : WordCardOverViewLayout()
    );
  }
}

class WordCardOverViewLayout extends StatefulWidget {
  const WordCardOverViewLayout({super.key});

  @override
  State<StatefulWidget> createState() => _WordCardOverViewLayout();
}

class _WordCardOverViewLayout extends State<WordCardOverViewLayout> {
  final ScrollController jsonController = ScrollController();
  final ScrollController classController = ScrollController();
  bool allowJsonScorll = true;
  bool allowClassScorll = false;

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);

    return ListView.builder(
      physics: allowJsonScorll ? null : NeverScrollableScrollPhysics(),
      controller: jsonController,
      itemCount: context.read<Global>().wordData.classes.length + 1,
      itemBuilder: (context, jsonIndex) {
        if(jsonIndex == context.read<Global>().wordData.classes.length) {
          return SizedBox(height: mediaQuery.size.height);
        }
        final SourceItem jsonSource = context.read<Global>().wordData.classes[jsonIndex];
        return ExpansionTile(
          title: Text(jsonSource.sourceJsonFileName.trim()),
          minTileHeight: 64,
          onExpansionChanged: (value) {
            setState(() {
              allowClassScorll = value;
              allowJsonScorll = !value; // 展开json后锁定首个ListView，禁止滑动
            });
            jsonController.animateTo(
              (66 * jsonIndex).toDouble(), 
              duration: Duration(milliseconds: 200), 
              curve: StaticsVar.curve
            );
          },
          children: [
            SizedBox(
              height: mediaQuery.size.height * 0.9,
              child: ListView.builder(
                physics: allowClassScorll ? null : NeverScrollableScrollPhysics(),
                controller: classController,
                itemCount: jsonSource.subClasses.length + 1,
                itemBuilder: (context, classIndex) {
                  if(classIndex == jsonSource.subClasses.length) {
                    return SizedBox(height: mediaQuery.size.height); // 避免0.9空间估计不足
                  }
                  final ClassItem classItem = jsonSource.subClasses[classIndex];
                  return ExpansionTile(
                    title: Text(classItem.className.trim()),
                    minTileHeight: 62,
                    onExpansionChanged: (value) {
                      setState(() {
                        allowClassScorll = !value;
                      });
                      if(value) {
                        classController.animateTo(
                          (64 * classIndex).toDouble(), 
                          duration: Duration(milliseconds: 200), 
                          curve: StaticsVar.curve
                        );
                        jsonController.animateTo(
                          (66 * (jsonIndex + 1)).toDouble(), 
                          duration: Duration(milliseconds: 200), 
                          curve: StaticsVar.curve
                        );
                      } else {
                        jsonController.animateTo(
                          (66 * jsonIndex).toDouble(), 
                          duration: Duration(milliseconds: 200), 
                          curve: StaticsVar.curve
                        );
                      }
                    },
                    children: [
                      SizedBox(
                        height: mediaQuery.size.height * 0.8,
                        child: GridView.builder(
                          itemCount: classItem.wordIndexs.length,
                          gridDelegate: context.read<Global>().globalConfig.learning.overviewForceColumn == 0 ? SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: mediaQuery.size.width ~/ 300) : SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: context.read<Global>().globalConfig.learning.overviewForceColumn), 
                          itemBuilder: (context, index) {
                            return Container(
                              margin: EdgeInsets.all(8.0),
                              child: WordCard(
                                word: context.read<Global>().wordData.words[classItem.wordIndexs[index]],
                                useMask: false,
                                width: mediaQuery.size.width / (context.read<Global>().globalConfig.learning.overviewForceColumn == 0 ? (mediaQuery.size.width ~/ 300) : context.read<Global>().globalConfig.learning.overviewForceColumn),
                                height: mediaQuery.size.width / (context.read<Global>().globalConfig.learning.overviewForceColumn == 0 ? (mediaQuery.size.width ~/ 300) : context.read<Global>().globalConfig.learning.overviewForceColumn),
                              ),
                            );
                          }
                        ),
                      ),
                      SizedBox(height: mediaQuery.size.height * 0.5)
                    ],
                  );
                }
              ),
            ),
          ],
        );
      }
    );
  }
}

class WordLookupLayout extends StatelessWidget {
  final String lookfor;
  const WordLookupLayout({super.key, required this.lookfor});

  @override
  Widget build(BuildContext context) {
    if(lookfor.isEmpty) return SizedBox();
    MediaQueryData mediaQuery = MediaQuery.of(context);
    List<WordItem> match = [];
    if(lookfor.isArabic()) {
      match.addAll(BKSearch.search(
        WordItem(arabic: lookfor, chinese: lookfor, explanation: "", id: 0, className: ""), 
        threshold: 4~/(lookfor.length * 0.5 + 1) // 输入越多 容差越小
      )); // 从BK树找

      for(WordItem word in context.read<Global>().wordData.words) {
        if(match.contains(word)) continue;
        if(word.arabic.removeAracicExtensionPart().contains(lookfor.removeAracicExtensionPart())) {
          match.add(word);
          continue;
        }
        if(lookfor.length >=3 && getLevenshtein(lookfor.removeAracicExtensionPart(), word.arabic.removeAracicExtensionPart()) < 6~/(lookfor.length * 0.5 + 1)) {
          match.add(word);
          continue;
        }
      }
      match.sort((WordItem a, WordItem b) => 
        getLevenshtein(lookfor.removeAracicExtensionPart(), a.arabic.removeAracicExtensionPart()) - getLevenshtein(lookfor.removeAracicExtensionPart(), b.arabic.removeAracicExtensionPart())
      );
    } else {
      for(WordItem word in context.read<Global>().wordData.words) {
        if(match.contains(word)) continue;
        if(word.chinese.contains(lookfor)) {
          match.add(word);
          continue;
        }
        if(lookfor.length >=3 && getLevenshtein(lookfor, word.chinese) < 4) {
          if(!lookfor.split("").any((String char) => word.chinese.contains(char))) continue;
          match.add(word);
          continue;
        }
      }
      match.sort((WordItem a, WordItem b) => 
        a.chinese.contains(lookfor) ? -1 : a.chinese.contains(lookfor) ? 1 : getLevenshtein(lookfor, a.chinese) - getLevenshtein(lookfor, b.chinese)
      );
    }
    
    context.read<Global>().uiLogger.finer("单词检索结果: $match");
    if(!context.read<Global>().globalConfig.learning.wordLookupRealtime){
      Future.delayed(Durations.medium1, () {
        if(context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("检索到${match.length}个结果"), duration: Duration(seconds: 1),),
          );
        }
      }); 
    }

    return GridView.builder(
      itemCount: match.length,
      gridDelegate: context.read<Global>().globalConfig.learning.overviewForceColumn == 0 ? SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: mediaQuery.size.width ~/ 300) : SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: context.read<Global>().globalConfig.learning.overviewForceColumn), 
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.all(8.0),
          child: WordCard(
            word: match[index],
            useMask: false,
            width: mediaQuery.size.width / (context.read<Global>().globalConfig.learning.overviewForceColumn == 0 ? (mediaQuery.size.width ~/ 300) : context.read<Global>().globalConfig.learning.overviewForceColumn),
            height: mediaQuery.size.width / (context.read<Global>().globalConfig.learning.overviewForceColumn == 0 ? (mediaQuery.size.width ~/ 300) : context.read<Global>().globalConfig.learning.overviewForceColumn),
          ),
        );
      }
    );
  }
}
