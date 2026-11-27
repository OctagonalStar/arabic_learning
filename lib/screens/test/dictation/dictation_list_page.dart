// 听抄训练入口：从阅读理解题库或课文背诵中选择一篇文章。

import 'package:arabic_learning/core/navigation.dart';
import 'package:arabic_learning/core/recitation_text.dart' show splitSentences;
import 'package:arabic_learning/screens/test/dictation/dictation_config_page.dart';
import 'package:arabic_learning/screens/test/dictation/dictation_shared.dart';
import 'package:arabic_learning/screens/test/reading_test_page.dart' show ReadingTestPage;
import 'package:arabic_learning/screens/test/recitation/recitation_list_page.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppBreakpoints, AppSpacing;
import 'package:arabic_learning/theme/typography.dart';
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/motion.dart' show StaggeredEntrance;
import 'package:arabic_learning/widgets/shared.dart' show EmptyHintCard;
import 'package:arabic_learning/widgets/unit_card.dart';
import 'package:material_ui/material_ui.dart';

class DictationListPage extends StatefulWidget {
  const DictationListPage({super.key});

  @override
  State<DictationListPage> createState() => _DictationListPageState();
}

class _DictationListPageState extends State<DictationListPage> {
  Future<void> _openReading() async {
    await pushPage(context, ReadingTestPage());
    if (mounted) setState(() {});
  }

  Future<void> _openRecitation() async {
    await pushPage(context, RecitationListPage());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final List<DictationArticle> articles = <DictationArticle>[
      for (final unit in AppData().readingData.units)
        if (unit.passage.trim().isNotEmpty) DictationArticle.fromReading(unit),
      for (final unit in AppData().recitationTextData.units)
        if (unit.reference.trim().isNotEmpty)
          DictationArticle.fromRecitation(unit),
    ];
    final double width = AppBreakpoints.contentWidth(context);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("听抄训练")),
      body: SafeArea(
        top: false,
        child: articles.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EmptyHintCard("还没有可用于听抄的文章"),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Button(
                        icon: const Icon(Icons.auto_stories),
                        onPressed: _openReading,
                        child: const Text("添加阅读理解文章"),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Button(
                        icon: const Icon(Icons.menu_book),
                        onPressed: _openRecitation,
                        child: const Text("添加课文背诵文章"),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: articles.length,
                itemBuilder: (BuildContext context, int index) {
                  final DictationArticle article = articles[index];
                  return Center(
                    child: SizedBox(
                      width: width,
                      child: StaggeredEntrance(
                        index: index,
                        child: UnitCard(
                          title: article.title,
                          difficulty: article.difficultyPercent,
                          difficultyColorValue: article.difficultyPercent,
                          subtitle: "${splitSentences(article.passage).length} 句",
                          tags: <String>[article.sourceLabel],
                          heroTag: dictationArticleHeroTag(
                            article,
                            listIndex: index,
                          ),
                          titleStyle: arabicTextStyle(
                            context,
                            article.title,
                            base: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onOpen: () => pushPage(
                            context,
                            DictationConfigPage(
                              article: article,
                              listIndex: index,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
