import 'package:arabic_learning/core/adaptive.dart' show AdaptiveTabBody;
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/screens/setting/questions_setting_page.dart' show QuestionsSettingPage;
import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/models/reading.dart';
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/widgets/kit.dart' show Button, popSelectClasses;
import 'package:arabic_learning/theme/tokens.dart' show AppRadius, AppSpacing;
import 'package:arabic_learning/theme/typography.dart';
import 'package:arabic_learning/widgets/overlays.dart' show showSnackBar;
import 'package:arabic_learning/widgets/shared.dart' show ButtonLabel;
import 'package:arabic_learning/services/words.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/push_session.dart';
import 'package:arabic_learning/screens/learning/favorites_page.dart' show FavoritesPage;
import 'package:arabic_learning/screens/learning/fsrs_screens.dart' show FSRSLearningPage, ForeFSRSSettingPage;
import 'package:arabic_learning/screens/learning/learning_pages_build.dart';
import 'package:arabic_learning/screens/learning/plan/plan_entry_card.dart' show PlanEntryCard;

class LearningPage extends StatelessWidget {
  const LearningPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 LearningPage");

    // 按钮高度按 Tab 可用高度推导（保留原 0.15/0.1/0.25 的比例关系），
    // 矮横屏下整体压缩，手机竖屏/桌面下与原观感接近。
    return AdaptiveTabBody(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double gap = clampDouble(height * 0.05, 12.0, 40.0);
        // 下限 190：保证「学习 / 复习」这类纵向图标+标题按钮的最小可用高度
        // （图标块 + displaySmall 文案），避免按钮内部 Column 溢出。
        final double rowHeight = clampDouble(height * 0.25, 190.0, 280.0);
        final double pushHeight = clampDouble(height * 0.15, 64.0, 170.0);
        final double overviewHeight = clampDouble(height * 0.2, 76.0, 220.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 「计划学习」入口：紧凑单卡，高度按 Tab 可用高度收紧（60..72），
            // 尽量少占用下方按钮的纵向预算。
            const SizedBox(height: AppSpacing.xs),
            PlanEntryCard(
              height: height * 0.1,
            ),
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Button(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      size: Size(width * 0.4, rowHeight * 0.6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(top: Radius.circular(AppRadius.card))),
                      onPressed: () {
                        shiftToStudy(context);
                      },
                      icon: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.task_alt),
                      ),
                      iconDirection: AxisDirection.up,
                      child: ButtonLabel(
                        child: Text('学习', style: withoutColor(Theme.of(context).textTheme.displaySmall!).copyWith(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Button(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      size: Size(width * 0.4, rowHeight * 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(AppRadius.card))),
                      onPressed: (){
                        context.read<Global>().uiLogger.info("跳转: SettingPage => QuestionsSettingPage");
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => QuestionsSettingPage()));
                      }, 
                      icon: Icon(Icons.quiz),
                      child: Text("配置题型"),
                    )
                  ],
                ),
                Button(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  size: Size(width * 0.4, rowHeight),
                  onPressed: (){
                    context.read<Global>().uiLogger.info("跳转: LearningPage => ForeFSRSSettingPage");
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => ForeFSRSSettingPage()
                      )
                    );
                  },
                  icon: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(Icons.history_edu),
                  ),
                  iconDirection: AxisDirection.up,
                  child: ButtonLabel(
                    child: Text("复习",style: withoutColor(Theme.of(context).textTheme.displaySmall!).copyWith(fontWeight: FontWeight.bold))
                  ),
                ),
              ],
            ),
            SizedBox(height: gap),
            if(FSRS().config.pushAmount != 0) ...[
              Button(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                size: Size(width * 0.8, pushHeight),
                onPressed: (){
                  if(AppData().wordData.words.isEmpty) {
                    showSnackBar(context, "词库为空，无法推送！请先导入词库");
                    return;
                  }
                  // 分类筛选在 FSRS 设置中配置；日期种子保证同一天重进得到同一批词
                  final DateTime now = DateTime.now();
                  final DailyPushPlan plan = buildDailyPushPlan(now: now, fsrs: FSRS(), wordData: AppData().wordData);
                  if(plan.noCandidates) {
                    showSnackBar(context, "当前分类筛选下没有可推送的单词，请调整筛选条件");
                    return;
                  }
                  if(plan.words.isEmpty) {
                    PushSessionStore.clear();
                    showSnackBar(context, "今日的推送已完成");
                    return;
                  }
                  // 读取当天断点并换算为恢复位置；词库规模变化视为断点失效
                  final PushCheckpoint? cp = PushSessionStore.load();
                  int initialPhase = 0, initialLearningIndex = 0, initialQuestionIndex = 0;
                  if(cp != null && cp.day == pushDayKey(now) && cp.wordCount == AppData().wordData.words.length && (cp.phase == 0 || cp.phase == 1)) {
                    int anchor = plan.words.indexWhere((WordItem w) => w.id == cp.wordId);
                    if(anchor < 0) anchor = 0;
                    initialPhase = cp.phase;
                    if(cp.phase == 0) {
                      initialLearningIndex = anchor;
                    } else {
                      initialQuestionIndex = anchor;
                    }
                  }
                  context.read<Global>().uiLogger.info("跳转: LearningPage => FSRSLearningPage");
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => FSRSLearningPage(fsrs: FSRS(), words: plan.words, initialPhase: initialPhase, initialLearningIndex: initialLearningIndex, initialQuestionIndex: initialQuestionIndex)
                    )
                  );
                },
                icon: Icon(Icons.push_pin, size: 24),
                // 次级全宽按钮统一 titleLarge(22)：与主 CTA（学习/复习，displaySmall 36）
                // 拉开层级；ButtonLabel 默认 scaleDown 只缩不放，短文本不会被放大填满按钮。
                child: ButtonLabel(child: Text("学习推送单词", style: withoutColor(Theme.of(context).textTheme.titleLarge!))),
              ),
            ],
            SizedBox(height: gap),
            // 「词汇总览 / 收藏单词」并列次级按钮，与上方主按钮行同样的
            // spaceEvenly 排布与 0.4 宽度比例。
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Button(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  size: Size(width * 0.4, overviewHeight),
                  onPressed: (){
                    context.read<Global>().uiLogger.info("跳转: LearningPage => WordCardOverViewPage");
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => WordCardOverViewPage()
                      )
                    );
                  },
                  icon: Icon(Icons.abc, size: 24),
                  // 与「学习推送单词」同为次级按钮，统一 titleLarge(22)；
                  // 半宽下用 ButtonLabel（scaleDown）兜底，避免窄屏文字溢出。
                  child: ButtonLabel(child: Text("词汇总览", style: withoutColor(Theme.of(context).textTheme.titleLarge!))),
                ),
                Button(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  size: Size(width * 0.4, overviewHeight),
                  onPressed: (){
                    context.read<Global>().uiLogger.info("跳转: LearningPage => FavoritesPage");
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => FavoritesPage()
                      )
                    );
                  },
                  icon: Icon(Icons.star, size: 24),
                  child: ButtonLabel(child: Text("收藏单词", style: withoutColor(Theme.of(context).textTheme.titleLarge!))),
                ),
              ],
            ),
          ]
        );
      },
    );
  }
}


Future<void> shiftToStudy(BuildContext context) async {
  context.read<Global>().uiLogger.info("准备转向学习页面");
  final ClassSelection classSelection = await popSelectClasses(context, withCache: false, withReviewChoose: true, withCategoryFilter: true);
  if(classSelection.selectedClass.isEmpty || !context.mounted) return;
  final List<WordItem> selectedWords = getSelectedWords(AppData().wordData, classSelection.selectedClass, doShuffle: false, doDouble: false);
  // 标签筛选（或逻辑）：仅保留含有任一选中标签的单词
  final List<WordItem> words = classSelection.selectedCategories.isEmpty
      ? selectedWords
      : selectedWords.where((WordItem word) => wordMatchesAnyCategory(word, classSelection.selectedCategories)).toList();
  context.read<Global>().uiLogger.info("完成单词挑拣，共${words.length}个");
  if(words.isEmpty) {
    if(classSelection.selectedCategories.isNotEmpty && context.mounted) {
      showSnackBar(context, "当前标签筛选下没有可学习的单词");
    }
    return;
  }
  context.read<Global>().uiLogger.info("跳转: LearningPage => InLearningPage");
  final bool? finished = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => InLearningPage(words: words, countInReview: classSelection.countInReview),
    ),
  );
  if(!context.mounted) return;
  context.read<Global>().uiLogger.info("返回完成情况: $finished");
  if(finished??false) {
    context.read<Global>().updateLearningStreak();
  }
}

