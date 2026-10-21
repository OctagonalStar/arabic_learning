// 分类标签与筛选（原 widgets/kit.dart 拆分）。
// 承载只读标签组 [CategoryChips] 与多选筛选区 [CategoryFilter]（均为纯展示，
// 筛选语义由调用方决定）。
// 由 widgets/kit.dart 统一 export，调用方仍从 kit.dart 导入。

import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppRadius, AppSpacing;
import 'package:flutter/material.dart';

/// 分类标签组件
/// 
/// 将 [categories] 中的字符串原样渲染为标签，不做任何分组或含义解释
/// 
/// [categories] :分类字符串列表，为空时不渲染任何内容
/// 
/// [dense] :紧凑模式，使用更小的字号与内边距，适用于空间受限的卡片
/// 
/// [scale] :在 [dense] 基准尺寸上的额外缩放（默认 1.0 保持既有外观），
/// 供大卡片等空间充裕的场景放大字号 / 内边距 / 圆角与间距；不覆盖
/// `MediaQuery.textScaler`，系统无障碍文字缩放仍会叠加生效
class CategoryChips extends StatelessWidget {
  final List<String> categories;
  final bool dense;
  final double scale;
  const CategoryChips({super.key, required this.categories, this.dense = false, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    if(categories.isEmpty) return const SizedBox.shrink();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle baseStyle =
        (dense ? Theme.of(context).textTheme.labelSmall : Theme.of(context).textTheme.labelMedium) ??
            const TextStyle();
    // 显式放大的字号让系统 textScaler 在其之上继续叠加（不替换系统值）。
    final TextStyle labelStyle = baseStyle.copyWith(
      color: scheme.onSecondaryContainer,
      fontSize: (baseStyle.fontSize ?? 12.0) * scale,
    );
    return Wrap(
      spacing: (dense ? 4.0 : 6.0) * scale,
      runSpacing: (dense ? 4.0 : 6.0) * scale,
      children: List<Widget>.generate(categories.length, (int index) {
        final String category = categories[index];
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: (dense ? 6.0 : 10.0) * scale,
            vertical: (dense ? 1.0 : 4.0) * scale,
          ),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.card * scale),
          ),
          child: Text(
            category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        );
      }),
    );
  }
}

/// 多选筛选 chip（统一外观）
///
/// 三个调用点（分类筛选、检索页「仅收藏」、复习题型多选）原本各自手写同一份
/// `FilterChip` 参数：labelMedium 文案 + 无勾选图标 + 紧凑密度 + 选中/未选中的
/// 容器色与描边。抽成组件后外观只有一处定义，改动不会只落到某一个页面。
///
/// [onSelected] 直接透传 `FilterChip.onSelected`（布尔值是「新的选中态」），
/// 选中集合的维护仍由调用方负责。
class SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          // 未选中时与 chipTheme.labelStyle 的 onSurfaceVariant 保持一致
          color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: scheme.secondaryContainer,
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: StaticsVar.br,
        side: BorderSide(
          color: selected ? scheme.secondary : scheme.outlineVariant,
        ),
      ),
      onSelected: onSelected,
    );
  }
}

/// 分类筛选组件
/// 
/// [available] :可供选择的分类列表（展示顺序由调用方决定，组件不硬编码顺序）
/// 
/// [selected] :当前已选择的分类集合
/// 
/// [onChanged] :选择变化时的回调，传出新的完整集合（调用方负责持有状态）
/// 
/// [title] :筛选区标题，默认为「分类筛选」
/// 
/// [description] :筛选区说明文案，为 null 时不渲染说明行
/// 
/// 组件本身不决定筛选语义（AND / OR 由调用方实现）；
/// 空集合表示不筛选；非空时会出现“清除筛选”按钮。
class CategoryFilter extends StatelessWidget {
  final List<String> available;
  final Set<String> selected;
  final void Function(Set<String>) onChanged;
  final String title;
  final String? description;
  const CategoryFilter({
    super.key,
    required this.available,
    required this.selected,
    required this.onChanged,
    this.title = "分类筛选",
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    if(available.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.all(8.0),
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: StaticsVar.br,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_outlined, size: 18.0),
              SizedBox(width: 4.0),
              // 标题可定制：课程选择处使用「标签筛选」，其余调用方沿用默认「分类筛选」
              Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
              Spacer(),
              if(selected.isNotEmpty) TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size(0.0, 0.0),
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => onChanged(<String>{}),
                child: Text("清除筛选", style: Theme.of(context).textTheme.labelMedium),
              )
            ],
          ),
          // 说明行可选：为 null 时完全不渲染，默认调用方的观感与旧版一致
          if(description != null) Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxs, bottom: AppSpacing.xxs),
            child: Text(
              description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Wrap(
            spacing: 6.0,
            runSpacing: 6.0,
            children: List<Widget>.generate(available.length, (int index) {
              final String category = available[index];
              final bool isSelected = selected.contains(category);
              return SelectChip(
                label: category,
                selected: isSelected,
                onSelected: (bool value) {
                  final Set<String> next = Set<String>.of(selected);
                  if(value) {
                    next.add(category);
                  } else {
                    next.remove(category);
                  }
                  onChanged(next);
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
