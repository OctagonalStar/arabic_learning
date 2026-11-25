// 听抄训练入口：从阅读理解题库选择一篇文章。

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/navigation.dart';
import 'package:arabic_learning/core/recitation_text.dart' show splitSentences;
import 'package:arabic_learning/models/reading.dart';
import 'package:arabic_learning/screens/test/dictation/dictation_config_page.dart';
import 'package:arabic_learning/screens/test/reading_test_page.dart' show ReadingTestPage;
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/theme/tokens.dart';
import 'package:arabic_learning/theme/typography.dart';
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/motion.dart' show StaggeredEntrance;
import 'package:arabic_learning/widgets/shared.dart' show EmptyHintCard;
import 'package:material_ui/material_ui.dart';

class DictationListPage extends StatefulWidget {
  const DictationListPage({super.key});

  @override
  State<DictationListPage> createState() => _DictationListPageState();
}

class _DictationListPageState extends State<DictationListPage> {
  Future<void> _openReading() async {
    await pushPage(context, ReadingTestPage());
    // 从阅读题库返回后刷新，刚添加的文章要立刻可听抄。
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final List<ReadingUnit> units = AppData()
        .readingData
        .units
        .where((ReadingUnit unit) => unit.passage.trim().isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text("听抄训练")),
      body: SafeArea(
        top: false,
        child: units.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EmptyHintCard("还没有可用于听抄的文章"),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Button(
                        icon: Icon(Icons.auto_stories),
                        onPressed: _openReading,
                        child: Text("去添加阅读理解文章"),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: units.length,
                itemBuilder: (BuildContext context, int index) {
                  return StaggeredEntrance(
                    index: index,
                    child: _DictationUnitButton(unit: units[index]),
                  );
                },
              ),
      ),
    );
  }
}

class _DictationUnitButton extends StatelessWidget {
  final ReadingUnit unit;

  const _DictationUnitButton({required this.unit});

  @override
  Widget build(BuildContext context) {
    final int sentenceCount = splitSentences(unit.passage).length;
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Button(
        size: Size.fromHeight(112.0),
        padding: const EdgeInsets.all(AppSpacing.sm),
        onPressed: () => pushPage(context, DictationConfigPage(unit: unit)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: unit.title.textDirection,
                    style: arabicTextStyle(
                      context,
                      unit.title,
                      base: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "${unit.type == 1 ? "阅读理解" : "完形填空"} · "
                    "$sentenceCount 句 · 难度 ${unit.difficulty}",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios),
          ],
        ),
      ),
    );
  }
}
