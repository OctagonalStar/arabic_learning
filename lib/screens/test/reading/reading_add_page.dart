// 新增阅读题流程：三步向导（题目类型 → 题目来源 → 填写配置）。

import 'package:arabic_learning/screens/test/reading/reading_config_page.dart';
import 'package:arabic_learning/screens/test/reading/reading_shared.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:arabic_learning/widgets/type_choose_card.dart';
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';

class ReadingTestAddLeading extends StatefulWidget {
  const ReadingTestAddLeading({super.key});

  @override
  State<ReadingTestAddLeading> createState() => _ReadingTestAddLeading();
}

class _ReadingTestAddLeading extends State<ReadingTestAddLeading> {
  final QuestionConfig qconfig = QuestionConfig();

  final PageController _pageController = PageController();

  VoidCallback defType(int type, int toPage){
    if(toPage == 1 && (type > 2 || type < 1)) throw Exception("Unknown Question Type: $type");
    if(toPage == 2 && (type > 3 || type < 1)) throw Exception("Unknown Source Type: $type");
    return (){
      switch (toPage){
        case 1: qconfig.testType = type;
        case 2: qconfig.sourceType = type;
      }
      
      _pageController.animateToPage(toPage, duration: AppMotion.medium, curve: AppMotion.standardCurve);
    };
  }

  String scaffoldTitle(){
    switch ((_pageController.hasClients ? _pageController.page ?? 0 : 0).round()) {
      case 0 : return "选择题目类型";
      case 1 : return "选择题目来源";
      case 2 : return "填写相关信息";
    }
    return "Unknown";
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 卡片高度按页面可用高度推导并限制在 [140, 220]：
    // 矮屏下缩短并可整页滚动，避免 0.2 倍屏高在小高度下撑破 Column。
    Widget buildTypePage({
      required List<Widget> Function(double cardHeight, double cardWidth) cards,
      required MainAxisAlignment alignment,
    }) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double cardHeight = clampDouble(constraints.maxHeight * 0.2, 140.0, 220.0);
          final double cardWidth = constraints.maxWidth * 0.8;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: alignment,
                children: cards(cardHeight, cardWidth),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(scaffoldTitle())),
      body: SafeArea(top: false, child: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(),
        children: [
          buildTypePage(
            alignment: MainAxisAlignment.spaceEvenly,
            cards: (double cardHeight, double cardWidth) => <Widget>[
              TypeChooseCard(
                mainTitle: Text("阅读理解", style: Theme.of(context).textTheme.headlineMedium), 
                onTap: defType(1, 1),
                subTitle: Text("根据给出的文章，选择最合适的答案", style: Theme.of(context).textTheme.bodyMedium),
                width: cardWidth,
                height: cardHeight,
              ),
              TypeChooseCard(
                mainTitle: Text("完形填空", style: Theme.of(context).textTheme.headlineMedium), 
                onTap: defType(2, 1),
                subTitle: Text("使用恰当的词语，填补文中的空白", style: Theme.of(context).textTheme.bodyMedium),
                width: cardWidth,
                height: cardHeight,
              ),
            ],
          ),
          buildTypePage(
            alignment: MainAxisAlignment.spaceBetween,
            cards: (double cardHeight, double cardWidth) => <Widget>[
              TypeChooseCard(
                mainTitle: Text("使用AI API生成", style: Theme.of(context).textTheme.headlineMedium), 
                onTap: defType(1, 2), 
                subTitle: Text("调用兼容OpenAI标准的接口，直接请求题目生成\n快，题目质量高，错误率低\n可能要向提供商缴费\n如果你不知道\"API\"是什么，那么你不会用这个", style: Theme.of(context).textTheme.bodyMedium), 
                width: cardWidth, 
                height: cardHeight
              ),
              TypeChooseCard(
                mainTitle: Text("使用AI Prompt生成", style: Theme.of(context).textTheme.headlineMedium), 
                onTap: defType(2, 2), 
                subTitle: Text("配置题目相关难度后会生成一段AI提示词，由你复制到其他AI软件中，再将结果复制回程序使用\n方便，免费\n质量由你的提供商决定\n警告：不要使用某包，测试中其生成质量远低于其他模型，特别是高难度下", style: Theme.of(context).textTheme.bodyMedium), 
                width: cardWidth, 
                height: cardHeight
              ),
              TypeChooseCard(
                mainTitle: Text("使用现有JSON导入", style: Theme.of(context).textTheme.headlineMedium), 
                onTap: defType(3, 2), 
                subTitle: Text("在使用AI Prompt方式获取到结果后选择此项粘贴", style: Theme.of(context).textTheme.bodyMedium), 
                width: cardWidth, 
                height: cardHeight
              ),
            ],
          ),
          QuestionConfigPage(qconfig: qconfig),
        ],
      )),
    );
  }
}
