// 阅读题列表页（入口）：展示所有已导入的阅读题，右上角进入新增流程。

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/models/reading.dart';
import 'package:arabic_learning/screens/test/reading/reading_add_page.dart';
import 'package:arabic_learning/screens/test/reading/reading_question_page.dart';
import 'package:arabic_learning/screens/test/reading/reading_shared.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppSemanticColors;
import 'package:arabic_learning/widgets/kit.dart' show Button, TextContainer;
import 'package:arabic_learning/widgets/motion.dart' show StaggeredEntrance;
import 'package:flutter/material.dart';

class ReadingTestPage extends StatefulWidget {
  const ReadingTestPage({super.key});

  @override
  State<ReadingTestPage> createState() => _ReadingTestPage();
}

class _ReadingTestPage extends State<ReadingTestPage> {
  @override
  Widget build(BuildContext context) {
    AppData appData = AppData();

    return Scaffold(
      appBar: AppBar(title: Text("阅读理解"), actions: [
        IconButton(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ReadingTestAddLeading())), 
          icon: Icon(Icons.add)
        )
      ]),
      body: SafeArea(top: false, child: ListView.builder(
        itemCount: appData.readingData.units.length + 1,
        itemBuilder: (context, index) {
          if(index == appData.readingData.units.length) {
            return TextContainer(text: "没有更多阅读题了，请点击右上角加号添加");
          }
          return StaggeredEntrance(
            index: index,
            child: ReadingUnitButton(unit: appData.readingData.units[index], listIndex: index),
          );
        }
      )),
    );
  }
}

class ReadingUnitButton extends StatelessWidget {
  final ReadingUnit unit;

  /// 列表项位置：仅用于拼接唯一 Hero tag，不影响业务逻辑。
  final int? listIndex;
  const ReadingUnitButton({super.key, required this.unit, this.listIndex});

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    List<String> tags = [];
    for(ReadingQuestion question in unit.questions){
      if(!tags.contains(question.type)) tags.add(question.type);
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppSemanticColors semantic = context.semanticColors;
    late Color difficultyColor;
    switch(unit.difficulty){
      case >= 9 :{
        difficultyColor = scheme.error;
        break;
      }
      case >= 7 :{
        difficultyColor = scheme.tertiary;
        break;
      }
      case >= 5 :{
        difficultyColor = semantic.warning;
        break;
      }
      case >= 3 :{
        difficultyColor = semantic.success;
        break;
      }
      case >= 1 :{
        difficultyColor = scheme.primary;
        break;
      }
      case >= 0 : {
        difficultyColor = scheme.secondary;
        break;
      }
    }

    int correctTime = 0;
    for(int x in unit.corrects){
      correctTime += x;
    }

    return Container(
      margin: EdgeInsets.all(16.0),
      width: mediaQuery.size.width,
      child: Center(
        child: Button(
          size: Size.fromWidth(mediaQuery.size.width * 0.9),
          onPressed: () {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => ReadingQuestionPage(unit: unit, listIndex: listIndex))
            );
          }, 
          padding: EdgeInsetsGeometry.all(0.0),
          child: Row(
            children: [
              Container(
                width: mediaQuery.size.width * 0.2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentGeometry.centerLeft,
                    end: AlignmentGeometry.centerRight,
                    colors: [
                      difficultyColor,
                      Colors.transparent
                    ]
                  ),
                  borderRadius: StaticsVar.br
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: mediaQuery.size.width * 0.02),
                    // 装饰性难度数字：固定 64 号；FittedBox 宽度约束不紧（Row
                    // 内自然宽度），contain 只会缩小不会放大，故保留。
                    FittedBox(
                      fit: BoxFit.contain,
                      child: Text(
                        unit.difficulty.toString(), 
                        style: TextStyle(fontSize: 64, shadows: [Shadow(blurRadius: 5, color: Theme.of(context).colorScheme.primaryContainer)])
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Hero(
                        tag: readingUnitHeroTag(unit, listIndex: listIndex),
                        // 飞行中 Overlay 内没有 AppBar 的 DefaultTextStyle 与源侧
                        // FittedBox，需显式单行 + 缩放，否则标题会换行并被飞行框
                        // 裁切，落地时突然显示完整标题。
                        flightShuttleBuilder: (BuildContext flightContext, Animation<double> animation, HeroFlightDirection direction, BuildContext fromHeroContext, BuildContext toHeroContext) {
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              unit.title,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              textDirection: unit.title.textDirection,
                              style: Theme.of(flightContext).appBarTheme.titleTextStyle,
                            ),
                          );
                        },
                        child: Text(
                          unit.title,
                          maxLines: 1,
                          textDirection: unit.title.textDirection,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: [
                        TagMark(
                          tag: unit.type == 1 ? "阅读理解" : "完形填空",
                          background: scheme.primaryContainer,
                          foreground: scheme.onPrimaryContainer,
                        ),
                        ...List.generate(tags.length, (index) => TagMark(
                          tag: tags[index],
                          background: scheme.secondaryContainer,
                          foreground: scheme.onSecondaryContainer,
                        )),
                      ]
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Icon(Icons.arrow_forward_ios),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer
                    ),
                    padding: EdgeInsets.all(8.0),
                    child: Text("历史正确率:${unit.corrects.isEmpty ? "无数据" : (correctTime/(unit.corrects.length * unit.questions.length)).toStringAsFixed(2)}",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onPrimaryContainer)),
                  )
                ],
              )
            ],
          )
        ),
      ),
    );
  }
}

class TagMark extends StatelessWidget {
  final String tag;
  final Color background;
  final Color foreground;
  const TagMark({super.key, required this.tag, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: StaticsVar.br
      ),
      padding: EdgeInsets.all(4.0),
      child: Text(tag, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground)),
    );
  }
}
