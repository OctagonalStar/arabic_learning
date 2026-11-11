// 课文背诵列表页（入口）：展示所有已导入课文，右上角进入导入流程。
// 删除只移除课文本身；成绩按内容哈希存储，会随历史保留。

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/models/recitation_text.dart';
import 'package:arabic_learning/screens/test/recitation/recitation_add_page.dart';
import 'package:arabic_learning/screens/test/recitation/recitation_detail_page.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/recitation_service.dart';
import 'package:arabic_learning/services/recitation_store.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppBreakpoints, AppRadius, AppSpacing, AppSemanticColors;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/motion.dart'
    show CrossFadeSwitcher, StaggeredEntrance;
import 'package:arabic_learning/widgets/overlays.dart' show alert;
import 'package:arabic_learning/core/navigation.dart';
import 'package:flutter/material.dart';
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

  Future<void> _openUnit(RecitationTextUnit unit) async {
    await pushPage(
      context,
      RecitationDetailPage(unit: unit),
    );
    if (mounted) setState(() {});
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
                  itemBuilder: (context, index) => StaggeredEntrance(
                    index: index,
                    child: Center(
                      child: SizedBox(
                        width: width,
                        child: _UnitCard(
                          unit: units[index],
                          onOpen: () => _openUnit(units[index]),
                          onDelete: () => _deleteUnit(units[index]),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final RecitationTextUnit unit;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _UnitCard({
    required this.unit,
    required this.onOpen,
    required this.onDelete,
  });

  Color _difficultyColor(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppSemanticColors semantic = context.semanticColors;
    switch (unit.difficulty) {
      case >= 90: return scheme.error;
      case >= 70: return scheme.tertiary;
      case >= 50: return semantic.warning;
      case >= 30: return semantic.success;
      case >= 10: return scheme.primary;
      default: return scheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<RecitationRecord> records = RecitationStore()
        .recordsFor(RecitationService.textHash(unit.reference));
    final int? lastScore =
        records.isEmpty ? null : records.last.score;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      elevation: 2.0,
      surfaceTintColor: Colors.transparent,
      shadowColor: scheme.shadow,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: onOpen,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: _difficultyColor(context).withValues(alpha: 0.15),
                  borderRadius: AppRadius.controlBorder,
                ),
                child: Text(
                  "${unit.difficulty}",
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: _difficultyColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Text(
                        "${unit.sentences.length} 句 · ${unit.wordCount} 词"
                        "${lastScore == null ? "" : " · 最近 $lastScore"}",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (unit.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Wrap(
                          spacing: AppSpacing.xxs,
                          runSpacing: AppSpacing.xxs,
                          children: [
                            for (final String tag in unit.tags)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.secondaryContainer,
                                  borderRadius: AppRadius.controlBorder,
                                ),
                                child: Text(
                                  tag,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: scheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (String value) {
                  if (value == "delete") onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: "delete", child: Text("删除")),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
