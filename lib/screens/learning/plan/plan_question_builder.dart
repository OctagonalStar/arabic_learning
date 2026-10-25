// 「计划学习」单组答题会话的纯辅助逻辑：题目构建与「本组新增已学词」统计。
//
// 这里不依赖任何 UI / 全局单例，便于单元测试；页面只负责把
// `AppData().wordData` / `FSRS().isContained` 等运行时数据传进来。

import 'dart:math' show Random;

import 'package:arabic_learning/models/dict.dart' show DictData, WordItem;
import 'package:arabic_learning/models/plan.dart' show PlanChain;
import 'package:arabic_learning/widgets/questions.dart' show TestItem;

/// 按链条构建本组题目（section-major）：
/// 外层遍历 [PlanChain.sections]，内层遍历 [words]。
///
/// [PlanChain.shuffleWithinSection] 为真时，仅打乱**每个 section 内**的词序，
/// 不做题型乱序或全局乱序，保证「同一题型成组出现」的学习节奏。
/// 越界题型会被跳过（正常配置已由 [PlanChain] 清洗）。
List<TestItem> buildPlanTestItems({
  required List<WordItem> words,
  required PlanChain chain,
  required DictData wordData,
  required bool preferSimilar,
  required Random rnd,
}) {
  final List<TestItem> items = <TestItem>[];
  for (final int type in chain.sections) {
    if (type < 0 || type > 3) continue; // 题型 4（听力题）已删除
    final List<WordItem> sectionWords = List<WordItem>.of(words);
    if (chain.shuffleWithinSection) sectionWords.shuffle(rnd);
    for (final WordItem word in sectionWords) {
      items.add(
        TestItem.buildTestItem(word, type, wordData, preferSimilar, rnd),
      );
    }
  }
  return items;
}

/// 统计本组「新增已学词」数量。
///
/// 定义：作答前不在 FSRS（不在 [beforeIds]）、作答后已进入 FSRS
/// （[isLearned] 返回 true）的词数。已经学过的词不计入，避免同一词在
/// 多组间被重复统计。
int countNewLearnedWords({
  required Iterable<WordItem> words,
  required Set<int> beforeIds,
  required bool Function(int wordId) isLearned,
}) {
  return words
      .where(
        (WordItem word) => !beforeIds.contains(word.id) && isLearned(word.id),
      )
      .length;
}
