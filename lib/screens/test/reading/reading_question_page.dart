// 阅读题作答页：左（上）文章 + 右（下）题目分页，末页检查答案并提交。

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/selection.dart';
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/models/reading.dart';
import 'package:arabic_learning/screens/test/reading/reading_conclude_page.dart';
import 'package:arabic_learning/screens/test/reading/reading_shared.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppBreakpoints, AppMotion;
import 'package:arabic_learning/widgets/kit.dart' show Button, TextContainer;
import 'package:arabic_learning/widgets/shared.dart' show ButtonLabel;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

class ReadingQuestionPage extends StatefulWidget {
  final ReadingUnit unit;

  /// 从阅读题列表进入时携带的列表项位置：用于匹配列表项标题的 Hero tag。
  /// 其他入口为 null（tag 前缀 `x`），不会与列表项发生 Hero 飞行。
  final int? listIndex;
  const ReadingQuestionPage({super.key, required this.unit, this.listIndex});

  @override
  State<ReadingQuestionPage> createState() => _ReadingQuestionPage();
}
class _ReadingQuestionPage extends State<ReadingQuestionPage> {
  PageController pageController = PageController();
  late List<SingleSelectionNotifier> choose;
  List<List<String>> options = [];

  @override
  void initState() {
    choose = List<SingleSelectionNotifier>.generate(widget.unit.questions.length, (_) => SingleSelectionNotifier());

    for(ReadingQuestion x in widget.unit.questions){
      options.add(List<String>.from(x.answers)..shuffle());
    }

    // 不再强制横屏：定向策略由 lib/main.dart 的全局规则决定
    // （手机竖屏、平板/桌面自由），窄竖屏下走上下分栏降级布局。
    super.initState();
  }

  @override
  void dispose() {
    // choose 中的 notifier 由本 State 创建（Provider 使用 .value，不会代为释放），
    // 与 pageController 一样需要在此显式释放。
    for (final SingleSelectionNotifier notifier in choose) {
      notifier.dispose();
    }
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 与列表项标题共享 Hero：飞行中显式样式保持一致，避免 overlay 丢失
        // AppBar 的 DefaultTextStyle 导致中途跳变。
        title: Hero(
          tag: readingUnitHeroTag(widget.unit, listIndex: widget.listIndex),
          // 与列表项 Hero 共用同一 shuttle：push/pop 两个方向都单行缩放，
          // 避免飞行中软换行 + 紧致飞行框裁切。
          flightShuttleBuilder: (BuildContext flightContext, Animation<double> animation, HeroFlightDirection direction, BuildContext fromHeroContext, BuildContext toHeroContext) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.unit.title,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textDirection: widget.unit.title.textDirection,
                style: Theme.of(flightContext).appBarTheme.titleTextStyle,
              ),
            );
          },
          child: Text(
            widget.unit.title,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            textDirection: widget.unit.title.textDirection,
            style: Theme.of(context).appBarTheme.titleTextStyle,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool sideBySide = constraints.maxWidth >= AppBreakpoints.mobile;
            // 左右分栏时题目栏仅占 35% 宽，选项按钮沿用原 0.2 倍屏宽；
            // 上下降级布局中题目栏占满整宽，按钮放大到 0.4 倍便于点选。
            final double optionButtonWidth = constraints.maxWidth * (sideBySide ? 0.2 : 0.4);
            final Markdown passage = Markdown(
              data: widget.unit.passage,
              styleSheet: MarkdownStyleSheet(textScaler: readingTextScaler(constraints.maxWidth)),
            );
            final Widget questions = PageView.builder(
              controller: pageController,
              itemCount: widget.unit.questions.length+1,
              itemBuilder: (context, int index) {
                return ListView(
                  padding: EdgeInsets.all(16.0),
                  children: [
                    if(index != widget.unit.questions.length) TextContainer(text: widget.unit.questions[index].riddle, style: Theme.of(context).textTheme.headlineLarge),
                    if(index != widget.unit.questions.length) ChangeNotifierProvider<SingleSelectionNotifier>.value(
                      value: choose[index],
                      builder: (context, child) {
                        return Table(
                          columnWidths: {
                            0: FixedColumnWidth(60),
                            1: FlexColumnWidth()
                          },
                          children: List.generate(widget.unit.questions[index].answers.length, (i) {
                            return TableRow(
                              decoration: BoxDecoration(
                                color: context.watch<SingleSelectionNotifier>().value == i ? Theme.of(context).colorScheme.primaryContainer : null,
                                borderRadius: StaticsVar.br
                              ),
                              children: [
                                TextContainer(text: ["A", "B", "C", "D", "E", "F", "G"].elementAt(i)),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Button(
                                    onPressed: () {
                                      if(context.read<SingleSelectionNotifier>().value == i) {
                                        context.read<SingleSelectionNotifier>().changeTo(null);
                                      } else {
                                        context.read<SingleSelectionNotifier>().changeTo(i);
                                      }
                                    },
                                    size: Size.fromWidth(optionButtonWidth),
                                    child: Text(options[index][i], style: Theme.of(context).textTheme.headlineMedium),
                                  ),
                                )
                              ]
                            );
                          }),
                        );
                      },
                    ),
                    if(index == widget.unit.questions.length) TextContainer(text: "检查答案"),
                    if(index == widget.unit.questions.length) ...List.generate(
                      widget.unit.questions.length,
                      (int i) => TextContainer(
                        text: "题目\n${widget.unit.questions[i].riddle}\n你的答案\n${choose[i].value==null ? "未选择" : options[i][choose[i].value!]}"
                      )
                    ),
                    if(index == widget.unit.questions.length) Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Button(
                        onPressed: () {
                          int correctCount = 0;
                          for(int i = 0;i < choose.length; i++){
                            if(choose[i].value == null ? false : options[i][choose[i].value!] == widget.unit.questions[i].answers[0]) {
                              correctCount++;
                            }
                          }
                          widget.unit.corrects.add(correctCount);
                          AppData().saveReadingData();
                          Navigator.pushReplacement(
                            context, 
                            MaterialPageRoute(builder: (context) => ReadingResultPage(unit: widget.unit, selection: List<int?>.generate(choose.length, (index) => choose[index].value), options: options))
                          );
                        },
                        icon: Icon(Icons.done_all),
                        child: Text("提交"),
                      ),
                    ),
                    TweenAnimationBuilder(
                      tween: Tween<double>(
                        begin: 0,
                        end: index == 0 ? 0 : 0.5
                      ),
                      duration: AppMotion.mediumLong,
                      curve: AppMotion.standardCurve,
                      builder: (context, double i, child) {
                        return  Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if(index != 0 && i > 0.3) Button(
                              size: Size.fromWidth(constraints.maxWidth * 0.3 * i),
                              icon: Icon(Icons.arrow_back_ios),
                              iconDirection: AxisDirection.left,
                              onPressed: () => pageController.previousPage(duration: AppMotion.mediumLong, curve: AppMotion.standardCurve),
                              child: ButtonLabel(child: Text("上一题")),
                            ),
                            if(index != widget.unit.questions.length) Button(
                              size: Size.fromWidth(constraints.maxWidth * 0.3 * (1 - i)),
                              icon: Icon(Icons.arrow_forward_ios),
                              iconDirection: AxisDirection.right,
                              onPressed: () => pageController.nextPage(duration: AppMotion.mediumLong, curve: AppMotion.standardCurve),
                              child: ButtonLabel(child: Text(index == widget.unit.questions.length-1 ? "检查答案" : "下一题")),
                            ),
                          ],
                        );
                      }
                    )
                  ],
                );
              }
            );
            // 宽度不足（窄竖屏 / 矮横屏）时 65% + Expanded 的左右分栏会过于拥挤，
            // 降级为上下布局：文章占上半屏（可滚动），题目占剩余空间。
            if(sideBySide) {
              return Row(
                children: [
                  SizedBox(
                    width: constraints.maxWidth * 0.65,
                    height: constraints.maxHeight,
                    child: passage,
                  ),
                  Divider(),
                  Expanded(child: questions),
                ],
              );
            }
            return Column(
              children: [
                SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight * 0.5,
                  child: passage,
                ),
                Divider(),
                Expanded(child: questions),
              ],
            );
          },
        ),
      ),
    );
  }
}
