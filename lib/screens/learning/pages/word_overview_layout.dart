// 单词总览的「词库 → 班级 → 网格」布局：从 learning_pages_build.dart 拆分而来。
import 'dart:math';

import 'package:arabic_learning/models/dict.dart' show ClassItem, SourceItem;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:arabic_learning/widgets/flip_word_card.dart' show FlipWordCard;
import 'package:arabic_learning/widgets/motion.dart' show StaggeredEntrance;
import 'package:flutter/material.dart';

import 'overview_grid_metrics.dart';

class WordCardOverViewLayout extends StatelessWidget {
  const WordCardOverViewLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final AppData appData = AppData();
    // 单一滚动列表：词库 -> 班级 -> 网格全部在同一滚动视图中按“内容固有高度”
    // 展开，不再用两个嵌套 ListView + 固定像素 animateTo（旧实现会把被展开的
    // 行顶出屏幕、下方留下大片空白）。展开时用 [_revealOnExpand] 让该行对齐
    // 视口顶部，保证展开内容可见。
    return ListView.builder(
      itemCount: appData.wordData.classes.length,
      itemBuilder: (BuildContext context, int jsonIndex) {
        final SourceItem jsonSource = appData.wordData.classes[jsonIndex];
        return ExpansionTile(
          title: Text(jsonSource.name.trim()),
          minTileHeight: 64,
          onExpansionChanged: (value) {
            if (value) _revealOnExpand(context);
          },
          children: [
            for (final ClassItem classItem in jsonSource.subClasses)
              Builder(
                builder: (BuildContext classContext) {
                  return ExpansionTile(
                    title: Text(classItem.className.trim()),
                    minTileHeight: 62,
                    onExpansionChanged: (value) {
                      if (value) _revealOnExpand(classContext);
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _WordOverviewGrid(classItem: classItem),
                      ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// 展开后把当前行对齐到视口顶部，避免展开内容落在屏幕外。
///
/// 放在帧回调里执行：ExpansionTile 展开只向下增高，行首位置不变，因此即便
/// 展开动画尚未结束，对齐行首也能得到稳定结果。
void _revealOnExpand(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.0,
      duration: AppMotion.mediumShort,
      curve: AppMotion.standardCurve,
    );
  });
}

/// 词汇总览中单个班级的网格：按可用宽度自适应列数，cell 为正方形，整块高度
/// 由“行数 × cell 边长”推导（`SizedBox` 固定高度 + 不可滚动 GridView），
/// 因此可嵌在外层滚动列表中按内容自然展开，且保持懒加载。
class _WordOverviewGrid extends StatelessWidget {
  const _WordOverviewGrid({required this.classItem});

  final ClassItem classItem;

  /// 网格四周内边距与 cell 间距。
  static const double _pad = 4.0;
  static const double _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final AppData appData = AppData();
    if (classItem.wordIndexs.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = overviewGridColumns(constraints.maxWidth);
        // cell 宽度 = (可用宽度 - 左右内边距 - 列间距) / 列数；正方形故高度相等。
        final double cellWidth = max(
          (constraints.maxWidth - _pad * 2 - _gap * (columns - 1)) / columns,
          1.0,
        );
        final int rows = (classItem.wordIndexs.length + columns - 1) ~/ columns;
        final double gridHeight =
            _pad * 2 + rows * cellWidth + max(0, rows - 1) * _gap;
        return SizedBox(
          height: gridHeight,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(_pad),
            itemCount: classItem.wordIndexs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: _gap,
              crossAxisSpacing: _gap,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              return StaggeredEntrance(
                index: index,
                child: Center(
                  child: FlipWordCard(
                    word: appData.wordData.words[classItem.wordIndexs[index]],
                    width: cellWidth,
                    height: cellWidth,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
