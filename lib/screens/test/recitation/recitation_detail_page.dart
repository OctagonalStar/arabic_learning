// 课文详情页：AppBar 标题为课文标题，TabBar 切换「学习 / 逐句 / 整篇」。
// 「学习」与「逐句」共用同一个当前句位置（切 tab 后停在同一句），「整篇」自成一套滚动状态。

import 'package:arabic_learning/models/recitation_text.dart';
import 'package:arabic_learning/screens/test/recitation/recitation_recite_tab.dart';
import 'package:arabic_learning/screens/test/recitation/recitation_study_tab.dart';
import 'package:flutter/material.dart';

class RecitationDetailPage extends StatefulWidget {
  final RecitationTextUnit unit;
  const RecitationDetailPage({super.key, required this.unit});

  @override
  State<RecitationDetailPage> createState() => _RecitationDetailPageState();
}

class _RecitationDetailPageState extends State<RecitationDetailPage> {
  // 由本页持有，学习 / 逐句两个 tab 共用；整篇不接这个 notifier。
  final ValueNotifier<int> _position = ValueNotifier<int>(1);

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.unit.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: TabBar(
            labelStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            tabs: const <Widget>[
              Tab(text: "学习"),
              Tab(text: "逐句"),
              Tab(text: "整篇"),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            RecitationStudyTab(unit: widget.unit, position: _position),
            RecitationReciteTab(
              unit: widget.unit,
              mode: RecitationReciteMode.sentence,
              position: _position,
            ),
            RecitationReciteTab(
              unit: widget.unit,
              mode: RecitationReciteMode.whole,
            ),
          ],
        ),
      ),
    );
  }
}
