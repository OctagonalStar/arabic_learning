// 新增阅读题流程：三步向导（题目类型 → 题目来源 → 填写配置）。

import 'package:arabic_learning/screens/test/reading/reading_config_page.dart';
import 'package:arabic_learning/screens/test/reading/reading_shared.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion, AppSpacing;
import 'package:arabic_learning/widgets/type_choose_card.dart';
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:material_ui/material_ui.dart';

class ReadingTestAddLeading extends StatefulWidget {
  const ReadingTestAddLeading({super.key});

  @override
  State<ReadingTestAddLeading> createState() => _ReadingTestAddLeading();
}

class _ReadingTestAddLeading extends State<ReadingTestAddLeading> {
  final QuestionConfig qconfig = QuestionConfig();

  final PageController _pageController = PageController();

  VoidCallback defType(int type, int toPage) {
    if (toPage == 1 && (type > 2 || type < 1)) {
      throw Exception("Unknown Question Type: $type");
    }
    if (toPage == 2 && (type > 3 || type < 1)) {
      throw Exception("Unknown Source Type: $type");
    }
    return () {
      switch (toPage) {
        case 1:
          qconfig.testType = type;
        case 2:
          qconfig.sourceType = type;
      }

      _pageController.animateToPage(
        toPage,
        duration: AppMotion.medium,
        curve: AppMotion.standardCurve,
      );
    };
  }

  String scaffoldTitle() {
    switch ((_pageController.hasClients ? _pageController.page ?? 0 : 0)
        .round()) {
      case 0:
        return "选择题目类型";
      case 1:
        return "选择题目来源";
      case 2:
        return "填写相关信息";
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
          final double cardHeight = clampDouble(
            constraints.maxHeight * 0.2,
            140.0,
            220.0,
          );
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
      body: SafeArea(
        top: false,
        child: PageView(
          controller: _pageController,
          physics: NeverScrollableScrollPhysics(),
          children: [
            buildTypePage(
              alignment: MainAxisAlignment.spaceEvenly,
              cards: (double cardHeight, double cardWidth) => <Widget>[
                TypeChooseCard(
                  icon: Icons.menu_book,
                  mainTitle: Text(
                    "阅读理解",
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  onTap: defType(1, 1),
                  subTitle: Text(
                    "根据给出的文章，选择最合适的答案",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  width: cardWidth,
                  height: cardHeight,
                ),
                TypeChooseCard(
                  icon: Icons.edit_note,
                  mainTitle: Text(
                    "完形填空",
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  onTap: defType(2, 1),
                  subTitle: Text(
                    "使用恰当的词语，填补文中的空白",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  width: cardWidth,
                  height: cardHeight,
                ),
              ],
            ),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - AppSpacing.sm * 2,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          "选择题目来源",
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          "已有生成结果就直接导入；没有就让 AI 现场生成或先拿提示词。",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TypeChooseCard(
                          icon: Icons.cloud_sync,
                          mainTitle: Text(
                            "AI API 直连",
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          subTitle: Text(
                            "调用兼容 OpenAI 标准的接口，自动生成并导入；需要自备地址、密钥与额度。",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          onTap: defType(1, 2),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TypeChooseCard(
                          icon: Icons.auto_awesome,
                          mainTitle: Text(
                            "AI 提示词",
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          subTitle: Text(
                            "按难度生成提示词，复制到任意 AI 软件，再把返回的 JSON 粘回来。",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          onTap: defType(2, 2),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TypeChooseCard(
                          icon: Icons.data_object,
                          emphasized: true,
                          mainTitle: Text(
                            "导入现有 JSON",
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          subTitle: Text(
                            "已经有生成结果时，直接粘贴 JSON 导入。",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          onTap: defType(3, 2),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            QuestionConfigPage(qconfig: qconfig),
          ],
        ),
      ),
    );
  }
}
