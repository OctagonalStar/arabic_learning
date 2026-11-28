import 'dart:math';

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:material_ui/material_ui.dart' hide Card;

import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/screens/learning/fsrs/fsrs_review_card_page.dart' show FSRSReviewCardPage;
import 'package:arabic_learning/screens/learning/fsrs/fsrs_setting_page.dart' show ForeFSRSSettingPage;
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:arabic_learning/widgets/kit.dart' show TextContainer;

class MainFSRSPage extends StatefulWidget {
  final FSRS fsrs;
  const MainFSRSPage({super.key, required this.fsrs});

  @override
  State<MainFSRSPage> createState() => _MainFSRSPageState();
}

class _MainFSRSPageState extends State<MainFSRSPage> {
  final PageController controller = PageController();
  final Random sharedRnd = Random();
  FSRS fsrs = FSRS();
  /// 进入页面时已逾期的单词；进度条的分母，为空则不显示进度条。
  late int _overdue;
  late void Function(void Function() fn) _refreshProgress;

  @override
  void initState() {
    super.initState();
    widget.fsrs.clearReinforcePending();
    _overdue = fsrs.getWillDueCount();
  }

  void _nextPage() {
    if (!controller.hasClients) return;
    controller.nextPage(duration: AppMotion.medium, curve: AppMotion.standardCurve);
  }

  void _refresh() {
    if (controller.hasClients) controller.jumpToPage(0);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget _intro(MediaQueryData mediaQuery) {
    if (widget.fsrs.config.cards.isEmpty) {
      return Center(
        child: TextContainer(text: "当前没有可复习的单词\n可以先去[学习推送]里加些新词"),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextContainer(
            text: "上滑页面开始复习",
            size: Size(
              mediaQuery.size.width * 0.8,
              clampDouble(mediaQuery.size.height * 0.4, 140.0, 340.0),
            ),
            textAlign: TextAlign.center,
          ),
          Icon(Icons.arrow_upward, size: 48.0, color: Theme.of(context).colorScheme.onSurfaceVariant)
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text("复习"),
            if (_overdue != 0) StatefulBuilder(
              builder: (context, setLocalState) {
                _refreshProgress = setLocalState;
                int left = FSRS().getWillDueCount();
                if (left == 0) {
                  _overdue = 0;
                  return const SizedBox.shrink();
                }
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: (_overdue - left) / _overdue),
                  duration: AppMotion.medium,
                  curve: AppMotion.standardCurve,
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 15,
                      borderRadius: StaticsVar.br,
                    );
                  },
                );
              },
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
      body: SafeArea(
        top: false,
        child: PageView.builder(
          controller: controller,
          scrollDirection: Axis.vertical,
          itemBuilder: (context, index) {
            if (index == 0) return _intro(mediaQuery);

            // 每次构建都取当前到期最早的卡片：复习过的卡片到期时间已推后，
            // 自然轮到下一张；没作答就滑走的卡片仍是最近的一张，会再次出现。
            final int? wordID = widget.fsrs.nearestDueWordId();
            if (wordID == null) {
              return Center(
                child: TextContainer(text: "当前没有可复习的单词\n可以先去[学习推送]里加些新词"),
              );
            }
            return FSRSReviewCardPage(
              key: ValueKey('review-$index-$wordID'),
              wordID: wordID,
              fsrs: widget.fsrs,
              rnd: sharedRnd,
              onNext: _nextPage,
              onReviewed: (_) => _refreshProgress((){}),
            );
          },
        ),
      ),
    );
  }
}
