import 'dart:math';

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';

import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/screens/learning/fsrs/fsrs_review_card_page.dart' show FSRSReviewCardPage;
import 'package:arabic_learning/screens/learning/fsrs/fsrs_setting_page.dart' show ForeFSRSSettingPage;
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:arabic_learning/widgets/kit.dart' show Button, TextContainer;

class MainFSRSPage extends StatefulWidget {
  final FSRS fsrs;
  const MainFSRSPage({super.key, required this.fsrs});

  @override
  State<MainFSRSPage> createState() => _MainFSRSPageState();
}

class _MainFSRSPageState extends State<MainFSRSPage> {
  List<int> queue = [];
  final PageController controller = PageController();
  final Random sharedRnd = Random();
  final int initalReviewNum = FSRS().getWillDueCount();

  @override
  void initState() {
    super.initState();
    _extendQueue();
  }

  void _extendQueue() {
    final List<int> uniqueIds = widget.fsrs.config.cards
        .where((card) => widget.fsrs.willDueIn(card) < 1)
        .map((card) => card.cardId)
        .toList();
        
    if (uniqueIds.isEmpty) return;
    
    if (widget.fsrs.config.reinforceMemory) {
      queue.addAll([
        for (int i = 0; i < 3; i++) ...uniqueIds
      ]..shuffle());
    } else {
      queue.addAll(uniqueIds..shuffle());
    }
  }

  void _refresh() {
    setState(() {
      queue.clear();
      _extendQueue();
    });
    if (controller.hasClients) {
      controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    void Function(void Function()) refreshProgress =(_)=>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text("复习"),
            if(queue.isNotEmpty) StatefulBuilder(
              builder: (context, setLocalState) {
                refreshProgress = setLocalState;
                return TweenAnimationBuilder(
                  tween: Tween<double>(
                    begin: 0,
                    end: (initalReviewNum-widget.fsrs.getWillDueCount())/initalReviewNum
                  ), 
                  duration: AppMotion.medium,
                  curve: AppMotion.standardCurve,
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                    value: value,
                    minHeight: 15,
                    borderRadius: StaticsVar.br,
                  );
                }
                );
              }
            )
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: "强制刷新",
            onPressed: _refresh,
          ),
          IconButton(
            icon: Icon(Icons.keyboard_option_key),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                enableDrag: false,
                builder: (context) => ForeFSRSSettingPage(forceChoosing: true)
              );
            },
          ),
        ],
      ),
      body: SafeArea(top: false, child: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: controller,
        physics: const PageScrollPhysics(),
        onPageChanged: (value) {
          refreshProgress(()=>());
        },
        itemBuilder: (context, index) {
          // Page 0: 引导页
          if (index == 0) {
            if (queue.isEmpty) {
              return Center(
                child: TextContainer(text: "当前无任何待复习的内容\n可以休息会儿或者去[学习推送]里加些新词"),
              );
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextContainer(
                    text: "已载入待复习队列\n上滑页面开始复习",
                    size: Size(mediaQuery.size.width * 0.8, clampDouble(mediaQuery.size.height * 0.4, 140.0, 340.0)),
                    textAlign: TextAlign.center,
                  ),
                  Icon(Icons.arrow_upward, size: 48.0, color: Theme.of(context).colorScheme.onSurfaceVariant)
                ],
              ),
            );
          }

          int arrayIndex = index - 1;

          // 动态扩充：当滑到底时触发延展
          if (arrayIndex >= queue.length) {
            _extendQueue();
          }

          // 扩充了还是不够，说明真的穷尽了
          if (arrayIndex >= queue.length) {
            if (arrayIndex == queue.length) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextContainer(
                      text: "太棒了！当前没有任何卡片需要复习！\n若刚复习完请等待下一个间隔",
                      size: Size(mediaQuery.size.width * 0.8, clampDouble(mediaQuery.size.height * 0.4, 140.0, 340.0)),
                      textAlign: TextAlign.center,
                    ),
                    Button(
                      onPressed: _refresh,
                      icon: Icon(Icons.refresh),
                      child: Text("全盘刷新"),
                    )
                  ],
                ),
              );
            }
            // 返回 null 阻断 PageView 继续下滑
            return null;
          }

          // 常规复习页
          // key 需以 index 前缀保证唯一（强化记忆时同一 wordID 可重复出现），
          // 同时在 index 对应的单词变化时强制重建 State，避免 initState 固定的
          // testType/item 与实际 wordID 错位。
          return FSRSReviewCardPage(
            key: ValueKey('review-$index-${queue[arrayIndex]}'),
            wordID: queue[arrayIndex],
            fsrs: widget.fsrs,
            rnd: sharedRnd,
            controller: controller,
          );
        }
      ))
    );
  }
}
