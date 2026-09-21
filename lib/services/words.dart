// 学习用词与布局辅助（原 lib/funcs/utili.dart 拆分）。
// 包含选词、随机/相似词、选择题选项构建、连胜天数与按钮布局计算。

import 'dart:math';

import 'package:arabic_learning/core/date_utils.dart';
import 'package:arabic_learning/core/extensions.dart' show RemoveDuplicatesExtension;
import 'package:arabic_learning/models/config.dart' show LearningConfig;
import 'package:arabic_learning/models/dict.dart' show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/search.dart' show BKSearch;

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

int calculateButtonBoxLayout(List<String> possible, double width){
  // showingMode 0: 1 Row, 1: 2 Rows, 2: 4 Rows
  bool isWideScreen = AppData().isWideScreen;
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
/// 要集中进行随机的时候可以提供[rnd]实例避免重复创建实例
List<WordItem> getRandomWords(int count, DictData dict, {WordItem? include, bool preferClass = true, bool allowRepet = false, bool shuffle = true, Random? rnd}){
  rnd ??= Random();
  List<WordItem> wordList = [];
  List<WordItem> rndRange = [];
  List<WordItem> backupRndRange = [];

  if(include != null){
    wordList.add(include);
    for(SourceItem source in dict.classes){
      if(source.subClasses.any((ClassItem item) => item.className == include.className)){
        ClassItem course = source.subClasses.singleWhere((ClassItem item) => item.className == include.className);
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
  
  if(rndRange.length + backupRndRange.length < count) backupRndRange = dict.words;

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

/// 生成选择题的 4 个中文选项（包含 [word] 自身）
///
/// [preferSimilar] 为真时优先选择与 [word] 相似的单词（内部取反后传给
/// [getRandomWords] 的 `preferClass`）。参数求值顺序、随机数消耗次数与顺序
/// 均与原先在 fsrs_pages 中直接书写的
/// `getRandomWords(4, dict, include: word, preferClass: !preferSimilar, rnd: rnd)`
/// + `List.generate(4, (index) => optionWords[index].chinese, growable: false)`
/// 完全一致。
List<String> buildChineseChoiceOptions(
  WordItem word,
  DictData dict, {
  required bool preferSimilar,
  required Random rnd,
}) {
  final List<WordItem> optionWords = getRandomWords(4, dict, include: word, preferClass: !preferSimilar, rnd: rnd);
  return List.generate(4, (int index) => optionWords[index].chinese, growable: false);
}
