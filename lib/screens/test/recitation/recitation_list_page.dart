// 课文背诵列表页（入口）：展示所有已导入课文，右上角进入导入流程。
// 删除只移除课文本身；成绩按内容哈希存储，会随历史保留。

import 'package:arabic_learning/models/recitation_text.dart';
import 'package:arabic_learning/screens/test/recitation/recitation_add_page.dart';
import 'package:arabic_learning/screens/test/recitation/recitation_detail_page.dart';
import 'package:arabic_learning/screens/test/recitation/recitation_shared.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/recitation_service.dart';
import 'package:arabic_learning/services/recitation_store.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppBreakpoints, AppSpacing;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/motion.dart'
    show CrossFadeSwitcher, StaggeredEntrance;
import 'package:arabic_learning/widgets/overlays.dart' show alert;
import 'package:arabic_learning/widgets/unit_card.dart';
import 'package:arabic_learning/core/navigation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class RecitationListPage extends StatefulWidget {
  const RecitationListPage({super.key});

  @override
  State<RecitationListPage> createState() => _RecitationListPageState();
}

class _RecitationListPageState extends State<RecitationListPage> {
  Future<void> _openAdd() async {
    await pushPage(
      context,
      RecitationAddPage(),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openUnit(RecitationTextUnit unit, int listIndex) async {
    await pushPage(
      context,
      RecitationDetailPage(unit: unit, listIndex: listIndex),
    );
    if (mounted) setState(() {});
  }

  String _subtitle(RecitationTextUnit unit) {
    final List<RecitationRecord> records = RecitationStore().recordsFor(
      RecitationService.textHash(unit.reference),
    );
    final int? lastScore = records.isEmpty ? null : records.last.score;
    return "${unit.sentences.length} 句 · ${unit.wordCount} 词"
        "${lastScore == null ? "" : " · 最近 $lastScore"}";
  }

  void _deleteUnit(RecitationTextUnit unit) {
    final Global global = context.read<Global>();
    alert(
      context,
      "确定删除「${unit.title}」吗？历史成绩会保留。",
      destructive: true,
      onConfirmed: () async {
        AppData().recitationTextData.units.remove(unit);
        await AppData().saveRecitationTextData();
        global.uiLogger.info("删除背诵课文: ${unit.title}");
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double width = AppBreakpoints.contentWidth(context);
    final List<RecitationTextUnit> units = AppData().recitationTextData.units;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "课文背诵",
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(onPressed: _openAdd, icon: const Icon(Icons.add)),
        ],
      ),
      body: SafeArea(
        top: false,
        // 导入或删空首篇课文时整页淡入淡出，避免直接跳变。
        child: CrossFadeSwitcher(
          child: units.isEmpty
              ? Center(
                  key: const ValueKey<String>('empty'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("还没有课文，先导入一篇吧",
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Button(
                          onPressed: _openAdd,
                          child: const Text("导入课文"),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  key: const ValueKey<String>('list'),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: units.length,
                  itemBuilder: (context, index) {
                    final RecitationTextUnit unit = units[index];
                    return StaggeredEntrance(
                      index: index,
                      child: Center(
                        child: SizedBox(
                          width: width,
                          child: UnitCard(
                            title: unit.title,
                            difficulty: unit.difficulty,
                            subtitle: _subtitle(unit),
                            tags: unit.tags,
                            heroTag: recitationUnitHeroTag(
                              unit,
                              listIndex: index,
                            ),
                            onOpen: () => _openUnit(unit, index),
                            onDelete: () => _deleteUnit(unit),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
