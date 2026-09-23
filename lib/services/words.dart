// 学习用词与布局辅助（原 lib/funcs/utili.dart 拆分）。
// 包含选词、随机/相似词、选择题选项构建、连胜天数、按钮布局计算，
// 以及分类汇总/分类筛选判断（原 lib/funcs/ui.dart 中的纯逻辑函数）。

import 'dart:math';

import 'package:arabic_learning/core/adaptive.dart' show AdaptiveData;
import 'package:arabic_learning/core/date_utils.dart';
import 'package:arabic_learning/core/extensions.dart' show RemoveDuplicatesExtension;
import 'package:arabic_learning/models/config.dart' show LearningConfig;
import 'package:arabic_learning/models/dict.dart' show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/search.dart' show BKSearch;
import 'package:arabic_learning/services/synonyms.dart' show SynonymStore;

List<WordItem> getSelectedWords(DictData wordData , List<ClassItem> selectedClasses, {bool doShuffle = false, bool doDouble = false, int? shuffleSeed}) {
  List<WordItem> ans = [];
  for(ClassItem c in selectedClasses) {
    for (int wordIndex in c.wordIndexs){
      ans.add(wordData.words[wordIndex]); // 保留id方便后面进度保存
    }
  }
  if(doDouble) ans = [...ans, ...ans];
  if(doShuffle) ans.shuffle(Random(shuffleSeed));
  return ans;
}

/// 计算选项按钮的排布模式（0: 1 行, 1: 2 行, 2: 4 行）。
///
/// 布局数据由调用方通过 [layout] 显式传入（原先读取全局
/// `AppData().isWideScreen`，现由 `AdaptiveScope` 提供）。
int calculateButtonBoxLayout(List<String> possible, AdaptiveData layout) {
  // showingMode 0: 1 Row, 1: 2 Rows, 2: 4 Rows
  final bool isWideScreen = layout.isWide;
  final double width = layout.width;
  for(int i = 1; i < 4; i++) {
    if(possible[i].length * 16 > width * (isWideScreen ? 0.21 : 0.8)){
      if (isWideScreen) {
        return 1;
      } else {
        return 2;
      }
    }
  }
  if (isWideScreen) {
    return 0;
  } else {
    return 1;
  }
}

int getStrokeDays(LearningConfig config) {
  return (daysSinceEpoch() - config.lastDate > 1) ? 0 : (config.lastDate - config.startDate + 1);
}

/// 获取[count]个随机的单词
/// 如果指定了[include]则一定包含有其
/// 并且仅有指定了[include]后[useSimilar]和[preferClass]才会生效
/// 如果[useSimilar]为真则使用与[include]相似的单词
/// 如果[preferClass]为真则使用与[include]相同课程的单词
/// 如果[allowRepet]为真则可能随机出现重复项
/// 如果[avoidSynonyms]为真且指定了[include]，则排除与[include]释义完全相同
/// 或被用户标记为同义的词条（仅以[include]为中心判断）
/// 要集中进行随机的时候可以提供[rnd]实例避免重复创建实例
List<WordItem> getRandomWords(int count, DictData dict, {WordItem? include, bool preferClass = true, bool allowRepet = false, bool shuffle = true, bool avoidSynonyms = false, Random? rnd}){
  rnd ??= Random();
  List<WordItem> wordList = [];
  List<WordItem> rndRange = [];
  List<WordItem> backupRndRange = [];

  if(include != null){
    wordList.add(include);
    // 按词条 id 在全部词库/课程中反查归属，兼容一词多课（不依赖单值 className）。
    for(SourceItem source in dict.classes){
      for(ClassItem course in source.subClasses){
        if(!course.wordIndexs.contains(include.id)) continue;
        for(int index in course.wordIndexs){
          if(preferClass){
            rndRange.add(dict.words[index]);
          } else {
            backupRndRange.add(dict.words[index]);
          }
        }
      }
    }

    if(preferClass){
      backupRndRange.addAll(BKSearch.search(include));
    } else {
      rndRange.addAll(BKSearch.search(include));
    }
  }
  
  final bool filterSynonym = avoidSynonyms && include != null;
  bool keepCandidate(WordItem candidate) {
    if (!filterSynonym) return true;
    if (candidate.id == include.id) return false;
    return !SynonymStore().isSynonymWord(include, candidate);
  }

  if (filterSynonym) {
    rndRange = rndRange.where(keepCandidate).toList();
    backupRndRange = backupRndRange.where(keepCandidate).toList();
  }
  if (rndRange.length + backupRndRange.length < count) {
    backupRndRange = filterSynonym ? dict.words.where(keepCandidate).toList() : dict.words;
  }
  // 极端兜底（词库过小/过滤过严）：放弃过滤以避免下方 do/while 死循环
  if (rndRange.length + backupRndRange.length < count) {
    backupRndRange = dict.words;
  }

  do {
    while (wordList.length < count){
      // 30% 的概率在后备的列表里选择
      if((rnd.nextInt(10) > 6 && backupRndRange.isNotEmpty) || rndRange.isEmpty) {
        wordList.add(backupRndRange[rnd.nextInt(backupRndRange.length)]);
      } else {
        wordList.add(rndRange[rnd.nextInt(rndRange.length)]);
      }
    }
    if(!allowRepet) wordList.removeDuplicates();
  } while (wordList.length < count);
  
  if(shuffle) wordList.shuffle();

  return wordList;
}

/// 生成选择题的 4 个选项词（包含 [word] 自身），并排除同义/重复释义的干扰项。
///
/// [preferSimilar] 为真时优先选择与 [word] 相似的单词（内部取反后传给
/// [getRandomWords] 的 `preferClass`）。始终以 [avoidSynonyms] 为真调用，
/// 因此与 [word] 释义完全相同或被标记为同义的词条不会成为干扰项。
List<WordItem> buildChineseChoiceOptionWords(
  WordItem word,
  DictData dict, {
  required bool preferSimilar,
  required Random rnd,
}) {
  return getRandomWords(4, dict, include: word, preferClass: !preferSimilar, rnd: rnd, avoidSynonyms: true);
}

/// 生成选择题的 4 个中文选项（包含 [word] 自身）
///
/// 委托 [buildChineseChoiceOptionWords] 构建选项词后映射为释义字符串，
/// 保持单次 [getRandomWords] 调用与相同的随机数消耗。选项词会排除与
/// [word] 同义或释义完全重复的干扰项。
List<String> buildChineseChoiceOptions(
  WordItem word,
  DictData dict, {
  required bool preferSimilar,
  required Random rnd,
}) {
  return buildChineseChoiceOptionWords(word, dict, preferSimilar: preferSimilar, rnd: rnd)
      .map((WordItem optionWord) => optionWord.chinese)
      .toList(growable: false);
}

/// 汇总当前词库中所有单词的分类标签
/// 
/// 返回顺序稳定：先按 [preferredOrder] 中出现的分级/常用分类排列，
/// 其余分类按首次出现的顺序追加。不硬编码任何分类含义，仅用于筛选器展示排序。
List<String> collectAllCategories() {
  const List<String> preferredOrder = ["二级", "四级", "六级", "八级", "补充", "常用词", "生僻词", "短语"];
  final Set<String> categories = <String>{};
  for(WordItem word in AppData().wordData.words) {
    categories.addAll(word.categories);
  }
  final List<String> ordered = [];
  for(String category in preferredOrder) {
    if(categories.remove(category)) ordered.add(category);
  }
  ordered.addAll(categories);
  return ordered;
}

/// 判断单词是否满足分类筛选
/// 
/// 多选时采用 AND 语义：单词需包含 [selected] 中的全部分类；
/// [selected] 为空表示不进行筛选。
bool wordMatchesCategories(WordItem word, Set<String> selected) {
  if(selected.isEmpty) return true;
  return selected.every((String category) => word.categories.contains(category));
}
