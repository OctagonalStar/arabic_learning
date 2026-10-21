// 阅读题结算页：逐题展示你的答案 / 正确答案 / 解析，三段动画依次入场。

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/models/reading.dart';
import 'package:arabic_learning/screens/test/reading/reading_shared.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion, AppSemanticColors;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class ReadingResultPage extends StatelessWidget {
  final ReadingUnit unit;
  final List<int?> selection;
  final List<List<String>> options;
  
  static const Interval downProgress = Interval(0.066, 0.233, curve: AppMotion.standardCurve);
  static const Interval slideProgress = Interval(0.233, 0.666, curve: AppMotion.standardCurve);
  static const Interval correctProgress = Interval(0.666, 1, curve: AppMotion.standardCurve);


  const ReadingResultPage({super.key, required this.unit, required this.selection, required this.options});

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    final AppSemanticColors semantic = context.semanticColors;

    List<bool> correctList = [];
    for(int i = 0;i < selection.length; i++){
      correctList.add(selection[i] == null ? false : options[i][selection[i]!] == unit.questions[i].answers[0]);
    }
    double sp = 0;
    double cp = 0;
    double dp = 0;

    return Scaffold(
      appBar: AppBar(title: Text("测试结果-${unit.title}")),
      body: SafeArea(top: false, child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => TweenAnimationBuilder<double>(
        tween: Tween(
          begin: 0.0,
          end: 1.0
        ), 
        // 单一时间轴驱动 dp/sp/cp 三段 Interval，必须线性推进，
        // 保证三段动画的起止时刻严格按设计比例对齐。
        curve: AppMotion.linearCurve,
        duration: AppMotion.slowest, 
        builder: (context, t, child){
          sp = slideProgress.transform(t);
          cp = correctProgress.transform(t);
          dp = downProgress.transform(t);
    
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RepaintBoundary(
                child: Transform.translate(
                  offset: Offset(0, -mediaQuery.size.height * 0.4 * (1-dp)),
                  child: Opacity(
                    opacity: dp,
                    child: SizedBox(
                      width: mediaQuery.size.width,
                      height: clampDouble(constraints.maxHeight * 0.3, 100.0, 260.0),
                      child: Markdown(data: unit.passage, styleSheet: MarkdownStyleSheet(textScaler: readingTextScaler(constraints.maxWidth)))
                    ),
                  ),
                ),
              ),
              Divider(),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(8.0),
                  children: [
                    ...List.generate(
                      unit.questions.length*2,
                      (int index) {
                        if(index.isEven) {
                          index = ((index + 1)/2).toInt();
                          return RepaintBoundary(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Transform.translate(
                                  offset: Offset(-(mediaQuery.size.width * (1-(sp-1*index*(1-sp) < 0 ? 0 : sp-1*index*(1-sp)))), 0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: StaticsVar.br,
                                      color: Theme.of(context).colorScheme.surfaceContainerHigh
                                    ),
                                    padding: EdgeInsets.all(8.0),
                                    width: mediaQuery.size.width * 0.4,
                                    child: Column(
                                      children: [
                                        Text("问题: \n${unit.questions[index].riddle}\n你的答案: \n${selection[index] == null ? "未选择" : options[index][selection[index]!]}", style: Theme.of(context).textTheme.bodyLarge),
                                        SizedBox(
                                          width: mediaQuery.size.width * 0.4,
                                          child: Opacity(
                                            opacity: (cp-1*index*(1-cp) < 0 ? 0 : cp-1*index*(1-cp)),
                                            child: Transform.scale(
                                              scale: 1.5 - 0.5*(cp-1*index*(1-cp) < 0 ? 0 : cp-1*index*(1-cp)),
                                              child: FittedBox(fit: BoxFit.scaleDown, child: Icon(correctList[index] ? Icons.check : Icons.clear, color: correctList[index] ? semantic.success : semantic.error, size: 96))
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                Transform.translate(
                                  offset: Offset(mediaQuery.size.width * (1-(sp-1*index*(1-sp) < 0 ? 0 : sp-1*index*(1-sp))), 0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: StaticsVar.br
                                    ),
                                    width: mediaQuery.size.width * 0.5, 
                                    padding: EdgeInsets.all(8.0),
                                    margin: EdgeInsets.all(8.0),
                                    child: Text("正确答案: \n${unit.questions[index].answers[0]}\n解析: \n${unit.questions[index].analysis}", style: Theme.of(context).textTheme.bodyLarge),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          return RepaintBoundary(
                            child: Opacity(
                              opacity: cp,
                              child: Divider()
                            )
                          );
                        }
                      }
                    ),
                    RepaintBoundary(
                      child: Opacity(
                        opacity: dp,
                        child: Button(
                          size: Size.fromHeight(clampDouble(constraints.maxHeight * 0.1, 48.0, 96.0)),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text("返回"),
                        ),
                      ),
                    )
                  ]
                ),
              ),
            ],
          );
        }
      ))),
    );
  }
}
