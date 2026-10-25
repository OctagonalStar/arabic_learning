import 'package:flutter/material.dart';

import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/shared.dart' show ButtonLabel;
import 'package:arabic_learning/theme/tokens.dart' show AppRadius;

/// 题型编号 → 显示名称的唯一来源。
///
/// 0: 单词卡片学习；1: 中译阿 选择题；2: 阿译中 选择题；
/// 3: 中译阿 拼写题。
const Map<int, String> kQuestionTypeLabels = {
  0: "单词卡片学习",
  1: "中译阿 选择题",
  2: "阿译中 选择题",
  3: "中译阿 拼写题",
};

/// 题型序号链的展示列表（可长按拖动排序、可删除单项）。
///
/// 仅负责渲染与转发手势，不持有状态：
/// - 排序后的索引修正与配置落盘由调用方的 [onReorder] 处理；
/// - 「至少保留一项」等校验与提示由调用方的 [onRemove] 处理。
class QuestionChainListView extends StatelessWidget {
  final List<int> sections;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onRemove;

  /// 已知题型集合；仅用于未知类型的显示兜底。
  final List<int> allowedTypes;

  /// 列表为空时的占位提示；为空时不渲染占位。
  final String? emptyHint;

  const QuestionChainListView({
    super.key,
    required this.sections,
    required this.onReorder,
    required this.onRemove,
    this.allowedTypes = const [0, 1, 2, 3],
    this.emptyHint,
  });

  String _labelOf(int type) {
    return allowedTypes.contains(type)
        ? (kQuestionTypeLabels[type] ?? "未知类型")
        : "未知类型";
  }

  @override
  Widget build(BuildContext context) {
    if(sections.isEmpty && emptyHint != null) {
      return Center(
        child: Text(
          emptyHint!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant
          )
        )
      );
    }

    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final List<Widget> listTiles = [];
    bool isEven = true;
    for(int index = 0; index < sections.length; index++) {
      listTiles.add(
        Container(
          key: Key(index.toString()),
          padding: EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: isEven ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.all(Radius.circular(16.0))
          ),
          height: mediaQuery.size.height * 0.08,
          child: Row(
            children: [
              Expanded(child: Text(_labelOf(sections[index]))),
              IconButton(
                onPressed: () => onRemove(index),
                icon: Icon(Icons.delete)
              ),
              SizedBox(width: mediaQuery.size.width * 0.1)
            ],
          ),
        )
      );
      isEven = !isEven;
    }

    return ReorderableListView(
      onReorderItem: (oldIndex, newIndex) => onReorder(oldIndex, newIndex),
      children: listTiles,
    );
  }
}

/// 题干 FAB 展开后的「添加题型」按钮组。
///
/// [expandValue] 沿用外层 FAB 展开动画值（0..1）：小于 0.3 时不显示，
/// 尺寸随展开值线性变化。
class QuestionTypeAddMenu extends StatelessWidget {
  final double expandValue;
  final void Function(int type) onAdd;
  final List<int> allowedTypes;

  const QuestionTypeAddMenu({
    super.key,
    required this.expandValue,
    required this.onAdd,
    this.allowedTypes = const [0, 1, 2, 3],
  });

  String _labelOf(int type) => kQuestionTypeLabels[type] ?? "未知类型";

  @override
  Widget build(BuildContext context) {
    if(expandValue <= 0.3) return const SizedBox.shrink();

    final MediaQueryData mediaQuery = MediaQuery.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(allowedTypes.length, (i) {
        final int type = allowedTypes[i];
        return Button(
          size: Size(70 + 150 * expandValue, mediaQuery.size.height * 0.1 * expandValue),
          shape: i == 0 ? RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(top: Radius.circular(AppRadius.card))) : BeveledRectangleBorder(),
          onPressed: () => onAdd(type),
          icon: Icon(Icons.add),
          // 依主题 labelLarge(14)；ButtonLabel 默认 scaleDown 只缩不放，
          // 各展开项字号不随文案长度变化。
          child: ButtonLabel(child: Text("添加 ${_labelOf(type)}")),
        );
      }),
    );
  }
}
