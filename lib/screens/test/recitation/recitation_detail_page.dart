// 课文详情页：AppBar 标题为课文标题，TabBar 切换「学习 / 背诵」。

import 'package:arabic_learning/models/recitation_text.dart';
import 'package:arabic_learning/screens/test/recitation/recitation_recite_tab.dart';
import 'package:arabic_learning/screens/test/recitation/recitation_study_tab.dart';
import 'package:flutter/material.dart';

class RecitationDetailPage extends StatelessWidget {
  final RecitationTextUnit unit;
  const RecitationDetailPage({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(unit.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: const TabBar(
            tabs: <Widget>[Tab(text: "学习"), Tab(text: "背诵")],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            RecitationStudyTab(unit: unit),
            RecitationReciteTab(unit: unit),
          ],
        ),
      ),
    );
  }
}
