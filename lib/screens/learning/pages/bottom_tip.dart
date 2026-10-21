// 题目底部「查看详解 / 下一题」操作条：从 learning_pages_build.dart 拆分而来。
import 'package:arabic_learning/widgets/shared.dart' show RevealableActionBar;
import 'package:flutter/material.dart';

class BottomTip extends StatelessWidget {
  final bool isShowNext;
  final bool isLast;
  final void Function() onTipClicked;
  final void Function() onNextClicked;
  const BottomTip({super.key, required this.isShowNext, required this.isLast, required this.onNextClicked, required this.onTipClicked});

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return RevealableActionBar(
      revealed: isShowNext,
      tipWidth: (value) => mediaQuery.size.width * (0.8 - (0.45 * value)),
      tipLabel: (_) => "查看详解",
      tipLabelExpanded: true,
      tipBackgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      tipIcon: Icon(Icons.view_list),
      onTipClicked: onTipClicked,
      gapWidth: (value) => mediaQuery.size.width * 0.05 * value,
      nextThreshold: 0.0,
      nextWidth: (value) => mediaQuery.size.width * (0.45 * value),
      nextIcon: Icon(isLast ? Icons.done : Icons.navigate_next),
      nextIconDirection: AxisDirection.right,
      nextLabel: isLast ? "完成" : "下一个",
      nextBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
      onNextClicked: onNextClicked,
    );
  }
}
