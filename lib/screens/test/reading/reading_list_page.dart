// 阅读题列表页（入口）：展示所有已导入的阅读题，右上角进入新增流程。

import 'package:arabic_learning/core/navigation.dart';
import 'package:arabic_learning/models/reading.dart';
import 'package:arabic_learning/screens/test/reading/reading_add_page.dart';
import 'package:arabic_learning/screens/test/reading/reading_question_page.dart';
import 'package:arabic_learning/screens/test/reading/reading_shared.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppBreakpoints, AppSpacing;
import 'package:arabic_learning/widgets/kit.dart' show TextContainer;
import 'package:arabic_learning/widgets/motion.dart' show StaggeredEntrance;
import 'package:arabic_learning/widgets/unit_card.dart';
import 'package:material_ui/material_ui.dart';

class ReadingTestPage extends StatefulWidget {
  const ReadingTestPage({super.key});

  @override
  State<ReadingTestPage> createState() => _ReadingTestPage();
}

class _ReadingTestPage extends State<ReadingTestPage> {
  String _subtitle(ReadingUnit unit) {
    final int correctTime = unit.corrects.fold(
      0,
      (int sum, int value) => sum + value,
    );
    final String accuracy = unit.corrects.isEmpty || unit.questions.isEmpty
        ? "无数据"
        : (correctTime / (unit.corrects.length * unit.questions.length))
              .toStringAsFixed(2);
    return "${unit.questions.length} 题 · 历史正确率 $accuracy";
  }

  List<String> _tags(ReadingUnit unit) {
    final List<String> tags = <String>[
      unit.type == 1 ? "阅读理解" : "完形填空",
    ];
    for (final ReadingQuestion question in unit.questions) {
      if (!tags.contains(question.type)) tags.add(question.type);
    }
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    final AppData appData = AppData();
    final double width = AppBreakpoints.contentWidth(context);
    final List<ReadingUnit> units = appData.readingData.units;

    return Scaffold(
      appBar: AppBar(
        title: const Text("阅读理解"),
        actions: [
          IconButton(
            onPressed: () => replacePage(context, ReadingTestAddLeading()),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: units.length + 1,
          itemBuilder: (BuildContext context, int index) {
            return Center(
              child: SizedBox(
                width: width,
                child: index == units.length
                    ? const TextContainer(text: "没有更多阅读题了，请点击右上角加号添加")
                    : StaggeredEntrance(
                        index: index,
                        child: UnitCard(
                          title: units[index].title,
                          difficulty: units[index].difficulty * 10,
                          difficultyColorValue: units[index].difficulty * 10,
                          subtitle: _subtitle(units[index]),
                          tags: _tags(units[index]),
                          heroTag: readingUnitHeroTag(
                            units[index],
                            listIndex: index,
                          ),
                          titleStyle: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          onOpen: () => pushPage(
                            context,
                            ReadingQuestionPage(
                              unit: units[index],
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
