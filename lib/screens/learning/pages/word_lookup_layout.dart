// 单词检索结果布局：从 learning_pages_build.dart 拆分而来。
import 'dart:math';

import 'package:arabic_learning/core/statics.dart' show StaticsVar;
import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/favorites.dart' show FavoriteStore;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/search.dart' show BKSearch;
import 'package:arabic_learning/services/words.dart'
    show collectAllCategories, wordMatchesCategories;
import 'package:arabic_learning/theme/tokens.dart' show AppSpacing;
import 'package:arabic_learning/widgets/flip_word_card.dart' show FlipWordCard;
import 'package:arabic_learning/widgets/kit.dart' show CategoryFilter;
import 'package:arabic_learning/widgets/motion.dart' show StaggeredEntrance;
import 'package:arabic_learning/widgets/overlays.dart' show showSnackBar;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'overview_grid_metrics.dart';

class WordLookupLayout extends StatefulWidget {
  final String lookfor;
  const WordLookupLayout({super.key, required this.lookfor});

  @override
  State<WordLookupLayout> createState() => _WordLookupLayoutState();
}

class _WordLookupLayoutState extends State<WordLookupLayout> {
  /// 当前选择的分类（AND 语义，空集合=不筛选）
  Set<String> selectedCategories = <String>{};

  /// 仅显示已收藏的单词。
  bool _onlyFavorite = false;

  @override
  Widget build(BuildContext context) {
    // 使用索引化检索（归一化预计算 + 字符倒排 + 整词 BK-Tree），替代原全表扫描
    final String lookfor = widget.lookfor.trim();
    if(lookfor.isEmpty) return SizedBox();
    List<WordItem> match = BKSearch.lookup(lookfor);

    // 分类筛选（AND）：所有检索途径的结果统一过滤
    if(selectedCategories.isNotEmpty) {
      match = match.where((WordItem word) => wordMatchesCategories(word, selectedCategories)).toList();
    }

    // 仅收藏筛选：在分类筛选之后继续收窄结果（命中判断 O(1)）。
    if(_onlyFavorite) {
      match = match.where((WordItem word) => FavoriteStore().contains(word.id)).toList();
    }

    context.read<Global>().uiLogger.finest(() => "单词检索结果: ${match.length} 条");
    if(!AppData().config.learning.wordLookupRealtime){
      // 固定展示延迟属业务时序（等待列表渲染完成），不参与动效 token 化。
      Future.delayed(Durations.medium1, () {
        if(context.mounted) {
          showSnackBar(context, "检索到${match.length}个结果");
        }
      }); 
    }

    final List<String> availableCategories = collectAllCategories();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // 「仅收藏」开关始终可见（无分类可筛选时也在），样式与分类 chip 一致。
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, 0),
          child: Row(
            children: [
              FilterChip(
                label: Text(
                  "仅收藏",
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _onlyFavorite ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
                  ),
                ),
                selected: _onlyFavorite,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                selectedColor: scheme.secondaryContainer,
                backgroundColor: scheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: StaticsVar.br,
                  side: BorderSide(
                    color: _onlyFavorite ? scheme.secondary : scheme.outlineVariant,
                  ),
                ),
                onSelected: (bool value) {
                  setState(() {
                    _onlyFavorite = value;
                  });
                },
              ),
            ],
          ),
        ),
        if(availableCategories.isNotEmpty) CategoryFilter(
          available: availableCategories,
          selected: selectedCategories,
          onChanged: (Set<String> value) {
            setState(() {
              selectedCategories = value;
            });
          },
        ),
        Expanded(
          child: match.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off, size: 40.0, color: scheme.onSurfaceVariant),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      (selectedCategories.isNotEmpty || _onlyFavorite)
                        ? "当前筛选条件下没有匹配的单词"
                        : "没有找到与「$lookfor」匹配的单词",
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      "可以换一个关键词，或调整筛选条件后重试",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  // 列数与 cell 尺寸由网格区域可用宽高共同决定：
                  // cell 边长 = min(宽/列数, 高)，保证方形卡片不高于可视区域。
                  final int columns = overviewGridColumns(constraints.maxWidth);
                  final double cellWidth = constraints.maxWidth / columns;
                  final double side = max(min(cellWidth, constraints.maxHeight), 1.0);
                  final double cardSide = max(side - 16.0, 0.0);
                  return GridView.builder(
                    itemCount: match.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: cellWidth / side,
                    ),
                    itemBuilder: (context, index) {
                      // 检索结果可能很长：只对首屏前 N 项做交错入场。
                      return StaggeredEntrance(
                        index: index,
                        child: Center(
                          child: FlipWordCard(
                            word: match[index],
                            width: cardSide,
                            height: cardSide,
                            // 取消收藏后重新应用「仅收藏」筛选。
                            onFavoriteChanged: () => setState(() {}),
                          ),
                        ),
                      );
                    }
                  );
                },
              ),
        ),
      ],
    );
  }
}
