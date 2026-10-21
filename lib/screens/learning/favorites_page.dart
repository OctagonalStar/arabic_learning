// 收藏单词页：网格展示已收藏的单词卡片，支持卡片星标取消收藏与一键清空。
//
// 数据源为全局单例 [FavoriteStore]（按收藏顺序返回位置下标 id），渲染时映射到
// [AppData().wordData.words]；越界 id（词库被裁剪后的残留）直接跳过。

import 'dart:math';

import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/favorites.dart' show FavoriteStore;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/theme/tokens.dart' show AppSpacing;
import 'package:arabic_learning/widgets/flip_word_card.dart' show FlipWordCard;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/overlays.dart' show alart;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 收藏网格列数：与词汇总览 `_overviewGridColumns` 同一规则——用户固定列数
/// （>0）优先，否则按可用宽度约每 300 逻辑像素一列，至少一列。
int _favoriteGridColumns(double availableWidth) {
  final int forced = AppData().config.learning.overviewForceColumn;
  if (forced > 0) return forced;
  return max(1, availableWidth ~/ 300);
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  /// 空状态提示（样式与 `SynonymPage` 的空状态一致）。
  Widget _emptyHint(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
          "暂无收藏单词",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 FavoritesPage");
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final List<WordItem> words = AppData().wordData.words;
    // 按收藏顺序取词；越界 id 跳过（词库裁剪后的残留不应导致崩溃）。
    final List<WordItem> favorites = <WordItem>[];
    for (final int id in FavoriteStore().ids) {
      if (id >= 0 && id < words.length) favorites.add(words[id]);
    }

    return Scaffold(
      appBar: AppBar(title: const Text("收藏单词")),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: favorites.isEmpty
                ? Center(child: _emptyHint(context))
                : LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final int columns = _favoriteGridColumns(constraints.maxWidth);
                      // cell 为正方形；卡片显式取 cell 宽度，与总览网格一致。
                      final double cellWidth = max(
                        (constraints.maxWidth - AppSpacing.xs * 2 - AppSpacing.xs * (columns - 1)) / columns,
                        1.0,
                      );
                      return GridView.builder(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        itemCount: favorites.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: AppSpacing.xs,
                          crossAxisSpacing: AppSpacing.xs,
                          childAspectRatio: 1.0,
                        ),
                        itemBuilder: (BuildContext context, int index) {
                          return Center(
                            child: FlipWordCard(
                              word: favorites[index],
                              width: cellWidth,
                              height: cellWidth,
                              // 取消收藏后立即从本页移除该卡片。
                              onFavoriteChanged: () => setState(() {}),
                            ),
                          );
                        },
                      );
                    },
                  ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Button(
                size: Size.fromHeight(mediaQuery.size.height * 0.08),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                onPressed: () {
                  alart(context, "确定清空全部收藏吗？此操作不可撤销。", destructive: true, onConfirmed: () {
                    context.read<Global>().uiLogger.info("清空全部收藏");
                    setState(() {
                      FavoriteStore().clear();
                    });
                  });
                },
                child: const Text("清空全部收藏"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
