import 'package:arabic_learning/core/adaptive.dart' show AdaptiveTabBody;
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/screens/setting/questions_setting_page.dart'
    show QuestionsSettingPage;
import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/models/reading.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/widgets/kit.dart' show popSelectClasses;
import 'package:arabic_learning/theme/tokens.dart' show AppSpacing;
import 'package:arabic_learning/widgets/overlays.dart' show showSnackBar;
import 'package:arabic_learning/services/words.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/learning_session.dart'
    show LearningSessionCheckpoint, LearningSessionStore;
import 'package:arabic_learning/services/push_session.dart';
import 'package:arabic_learning/screens/learning/favorites_page.dart'
    show FavoritesPage;
import 'package:arabic_learning/screens/learning/fsrs_screens.dart'
    show FSRSLearningPage, ForeFSRSSettingPage;
import 'package:arabic_learning/screens/learning/learning_pages_build.dart';
import 'package:arabic_learning/screens/learning/plan/plan_entry_card.dart'
    show PlanEntryCard;
import 'package:arabic_learning/screens/setting/dict_manage_page.dart'
    show DictManagePage;
import 'package:arabic_learning/core/navigation.dart';

/// 学习页：计划入口、学习/复习主操作与更多入口。
class LearningPage extends StatelessWidget {
  const LearningPage({super.key});

  static const double _wideBreakpoint = 900.0;
  static const double _maxContentWidth = 960.0;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AdaptiveTabBody(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= _wideBreakpoint;
        final Widget actions = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _ActionCard(
                    background: scheme.primaryContainer,
                    foreground: scheme.onPrimaryContainer,
                    icon: Icons.task_alt,
                    title: '学习',
                    subtitle: '选择词库与题型开始学习',
                    onTap: () => shiftToStudy(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ActionCard(
                    background: scheme.secondaryContainer,
                    foreground: scheme.onSecondaryContainer,
                    icon: Icons.history_edu,
                    title: '复习',
                    subtitle: '按 FSRS 计划复习到期单词',
                    onTap: () => pushPage(context, const ForeFSRSSettingPage()),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    pushPage(context, const QuestionsSettingPage()),
                icon: const Icon(Icons.quiz_outlined),
                label: const Text('配置题型'),
              ),
            ),
          ],
        );

        final Widget more = _MoreCard(
          showPush: FSRS().config.pushAmount != 0,
          onPush: () => _openPush(context),
          onOverview: () => pushPage(context, const WordCardOverViewPage()),
          onFavorites: () => pushPage(context, const FavoritesPage()),
        );

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const PlanEntryCard(height: 72.0),
                  const SizedBox(height: AppSpacing.md),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 5, child: actions),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(flex: 4, child: more),
                      ],
                    )
                  else ...<Widget>[
                    actions,
                    const SizedBox(height: AppSpacing.md),
                    more,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 打开今日推送；词库为空、筛选无候选或今日已完成时给出提示。
  void _openPush(BuildContext context) {
    if (AppData().wordData.words.isEmpty) {
      showSnackBar(context, '词库为空，无法推送！请先导入词库');
      return;
    }
    // 分类筛选在 FSRS 设置中配置；日期种子保证同一天重进得到同一批词。
    final DateTime now = DateTime.now();
    final DailyPushPlan plan = buildDailyPushPlan(
      now: now,
      fsrs: FSRS(),
      wordData: AppData().wordData,
    );
    if (plan.noCandidates) {
      showSnackBar(context, '当前分类筛选下没有可推送的单词，请调整筛选条件');
      return;
    }
    if (plan.words.isEmpty) {
      PushSessionStore.clear();
      showSnackBar(context, '今日的推送已完成');
      return;
    }
    // 读取当天断点并换算为恢复位置；词库规模变化视为断点失效。
    final PushCheckpoint? cp = PushSessionStore.load();
    int initialPhase = 0, initialLearningIndex = 0, initialQuestionIndex = 0;
    if (cp != null &&
        cp.day == pushDayKey(now) &&
        cp.wordCount == AppData().wordData.words.length &&
        (cp.phase == 0 || cp.phase == 1)) {
      int anchor = plan.words.indexWhere((WordItem w) => w.id == cp.wordId);
      if (anchor < 0) anchor = 0;
      initialPhase = cp.phase;
      if (cp.phase == 0) {
        initialLearningIndex = anchor;
      } else {
        initialQuestionIndex = anchor;
      }
    }
    pushPage(
      context,
      FSRSLearningPage(
        fsrs: FSRS(),
        words: plan.words,
        initialPhase: initialPhase,
        initialLearningIndex: initialLearningIndex,
        initialQuestionIndex: initialQuestionIndex,
      ),
    );
  }
}

/// 学习/复习主操作卡：大图标 + 标题 + 一行说明，整卡可点。
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card.filled(
      margin: EdgeInsets.zero,
      color: background,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 156.0),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 40.0, color: foreground),
                const SizedBox(height: AppSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: foreground,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foreground.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「更多」入口：推送、词汇总览、收藏。
class _MoreCard extends StatelessWidget {
  const _MoreCard({
    required this.showPush,
    required this.onPush,
    required this.onOverview,
    required this.onFavorites,
  });

  final bool showPush;
  final VoidCallback onPush;
  final VoidCallback onOverview;
  final VoidCallback onFavorites;

  @override
  Widget build(BuildContext context) {
    final int pushAmount = FSRS().config.pushAmount;
    final List<Widget> tiles = <Widget>[
      if (showPush)
        ListTile(
          leading: const Icon(Icons.push_pin_outlined),
          title: const Text('学习推送单词'),
          subtitle: Text('每日推送 $pushAmount 个'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onPush,
        ),
      ListTile(
        leading: const Icon(Icons.abc),
        title: const Text('词汇总览'),
        subtitle: const Text('浏览全部单词'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onOverview,
      ),
      ListTile(
        leading: const Icon(Icons.star_outline),
        title: const Text('收藏单词'),
        subtitle: const Text('查看已收藏的单词'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onFavorites,
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < tiles.length; i++) ...<Widget>[
            if (i > 0) const Divider(height: 1.0),
            tiles[i],
          ],
        ],
      ),
    );
  }
}

Future<void> shiftToStudy(BuildContext context) async {
  context.read<Global>().uiLogger.info("准备转向学习页面");

  // 有暂存断点时先询问是继续还是重新开始；继续时直接用断点里的词表与配置，
  // 不再走选词流程。
  final LearningSessionCheckpoint? checkpoint = LearningSessionStore.load();
  if (checkpoint != null) {
    final _ResumeChoice? choice = await _askResumeChoice(context, checkpoint);
    if (!context.mounted || choice == null) return;
    if (choice == _ResumeChoice.restart) {
      await LearningSessionStore.clear();
      if (!context.mounted) return;
    } else {
      final List<WordItem>? words = checkpoint.resolveWords(AppData().wordData);
      if (words == null) {
        // 词库被删除/重置后断点失效：清掉断点并按新学习继续。
        await LearningSessionStore.clear();
        if (!context.mounted) return;
        showSnackBar(context, "上次的学习进度已失效，将重新开始");
      } else {
        context.read<Global>().uiLogger.info(
          "恢复暂存学习进度，剩余${checkpoint.remaining}题",
        );
        final bool? finished = await pushPage<bool>(
          context,
          InLearningPage(
            words: words,
            countInReview: checkpoint.countInReview,
            resume: checkpoint,
          ),
        );
        if (!context.mounted) return;
        if (finished ?? false) context.read<Global>().updateLearningStreak();
        return;
      }
    }
  }

  final NavigatorState navigator = Navigator.of(context);
  final ClassSelection classSelection = await popSelectClasses(
    context,
    withCache: false,
    withReviewChoose: true,
    withCategoryFilter: true,
    onImportDict: () => pushPageOn(navigator, const DictManagePage()),
  );
  if (classSelection.selectedClass.isEmpty || !context.mounted) return;
  final List<WordItem> selectedWords = getSelectedWords(
    AppData().wordData,
    classSelection.selectedClass,
    doShuffle: false,
    doDouble: false,
  );
  // 标签筛选（或逻辑）：仅保留含有任一选中标签的单词
  final List<WordItem> words = classSelection.selectedCategories.isEmpty
      ? selectedWords
      : selectedWords
            .where(
              (WordItem word) => wordMatchesAnyCategory(
                word,
                classSelection.selectedCategories,
              ),
            )
            .toList();
  context.read<Global>().uiLogger.info("完成单词挑拣，共${words.length}个");
  if (words.isEmpty) {
    if (classSelection.selectedCategories.isNotEmpty && context.mounted) {
      showSnackBar(context, "当前标签筛选下没有可学习的单词");
    }
    return;
  }
  final bool? finished = await pushPage<bool>(
    context,
    InLearningPage(words: words, countInReview: classSelection.countInReview),
  );
  if (!context.mounted) return;
  context.read<Global>().uiLogger.info("返回完成情况: $finished");
  if (finished ?? false) {
    context.read<Global>().updateLearningStreak();
  }
}

/// 询问用户如何处理上次暂存的常规学习。
Future<_ResumeChoice?> _askResumeChoice(
  BuildContext context,
  LearningSessionCheckpoint checkpoint,
) {
  final String content = checkpoint.remaining <= 0
      ? "上次学习已作答完毕，可继续查看结果。"
      : "检测到未完成的常规学习，还剩 ${checkpoint.remaining} 题。";
  return showDialog<_ResumeChoice>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text("继续上次学习？"),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("取消"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, _ResumeChoice.restart),
          child: const Text("重新开始"),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, _ResumeChoice.resume),
          child: const Text("继续学习"),
        ),
      ],
    ),
  );
}

/// 暂存断点入口的选择：继续上次学习 / 丢弃并重新开始。
enum _ResumeChoice { resume, restart }
