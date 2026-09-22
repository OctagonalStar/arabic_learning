import 'dart:math';

import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/search.dart';
import 'package:arabic_learning/services/synonyms.dart';
import 'package:arabic_learning/services/words.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

/// 构造一个单课程词库：
/// - id 0 为固定目标词「相会」；
/// - id 1 为「特殊对」候选，释义由 [specialGloss] 决定（可为重复释义或近义词）；
/// - id 2..9 为 8 个释义互不相同的普通干扰词。
///
/// 共 10 词，过滤后池仍远大于 4，保证不会触发极端兜底（放弃过滤），
/// 从而让「排除」断言稳定。
DictData buildTestDict(String specialGloss) {
  final List<WordItem> words = <WordItem>[
    const WordItem(
      arabic: 'لقاء',
      chinese: '相会',
      explanation: '见面',
      className: '第一课',
      id: 0,
      root: 'ل ق ي',
      pos: 'Nominals',
    ),
    WordItem(
      arabic: 'التقاء',
      chinese: specialGloss,
      explanation: '会面',
      className: '第一课',
      id: 1,
      root: 'ل ق ي',
      pos: 'Nominals',
    ),
    const WordItem(
      arabic: 'كتاب',
      chinese: '书',
      explanation: '书籍',
      className: '第一课',
      id: 2,
      root: 'ك ت ب',
      pos: 'Nominals',
    ),
    const WordItem(
      arabic: 'قلم',
      chinese: '笔',
      explanation: '书写工具',
      className: '第一课',
      id: 3,
      root: 'ق ل م',
      pos: 'Nominals',
    ),
    const WordItem(
      arabic: 'مدرسة',
      chinese: '学校',
      explanation: '教育机构',
      className: '第一课',
      id: 4,
      root: 'د ر س',
      pos: 'Nominals',
    ),
    const WordItem(
      arabic: 'طالب',
      chinese: '学生',
      explanation: '学习者',
      className: '第一课',
      id: 5,
      root: 'ط ل ب',
      pos: 'Nominals',
    ),
    const WordItem(
      arabic: 'بيت',
      chinese: '房子',
      explanation: '住所',
      className: '第一课',
      id: 6,
      root: 'ب ي ت',
      pos: 'Nominals',
    ),
    const WordItem(
      arabic: 'سيارة',
      chinese: '汽车',
      explanation: '交通工具',
      className: '第一课',
      id: 7,
      root: 'س ي ر',
      pos: 'Nominals',
    ),
    const WordItem(
      arabic: 'مدينة',
      chinese: '城市',
      explanation: '聚居地',
      className: '第一课',
      id: 8,
      root: 'م د ن',
      pos: 'Nominals',
    ),
    const WordItem(
      arabic: 'ماء',
      chinese: '水',
      explanation: '液体',
      className: '第一课',
      id: 9,
      root: 'م و ه',
      pos: 'Nominals',
    ),
  ];

  return DictData(
    words: words,
    classes: const <SourceItem>[
      SourceItem(
        sourceJsonFileName: 'test.json',
        displayName: '测试词库',
        subClasses: <ClassItem>[
          ClassItem(
            className: '第一课',
            wordIndexs: <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
          ),
        ],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictData dict;
  late WordItem target;

  /// 用指定释义构建特殊对并重建检索索引。
  void useSpecialPair(String specialGloss) {
    dict = buildTestDict(specialGloss);
    target = dict.words[0];
    BKSearch.rebuild(dict.words);
  }

  setUpAll(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    // getRandomWords 会调用 BKSearch.search，标记操作需要 AppData.storage。
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
  });

  setUp(() {
    // 单例状态在测试间共享，先清空标记再准备默认词库。
    SynonymStore().clearAll();
    useSpecialPair('相会');
  });

  group('getRandomWords 的 avoidSynonyms 过滤', () {
    test('精确重复释义（同词条释义相同）在 avoidSynonyms 为真时被排除', () {
      // id 1 的释义与目标 id 0 完全相同（规范化后相等）。
      expect(
        SynonymStore().isSynonymWord(target, dict.words[1]),
        isTrue,
      );

      for (int seed = 0; seed < 60; seed++) {
        final List<WordItem> result = getRandomWords(
          4,
          dict,
          include: target,
          rnd: Random(seed),
          avoidSynonyms: true,
        );
        expect(result.length, 4, reason: 'seed=$seed');
        expect(
          result.any((WordItem w) => w.id == target.id),
          isTrue,
          reason: 'seed=$seed 目标词必须出现',
        );
        expect(
          result.any((WordItem w) => w.id == 1),
          isFalse,
          reason: 'seed=$seed 释义完全重复的干扰项必须被排除',
        );
      }
    });

    test('用户标记为同义的词在 avoidSynonyms 为真时被排除', () {
      useSpecialPair('相见');
      SynonymStore().markSynonym('相会', '相见');
      expect(
        SynonymStore().isSynonymWord(target, dict.words[1]),
        isTrue,
      );

      for (int seed = 0; seed < 60; seed++) {
        final List<WordItem> result = getRandomWords(
          4,
          dict,
          include: target,
          rnd: Random(seed),
          avoidSynonyms: true,
        );
        expect(result.length, 4, reason: 'seed=$seed');
        expect(
          result.any((WordItem w) => w.id == 1),
          isFalse,
          reason: 'seed=$seed 已标记同义的干扰项必须被排除',
        );
      }
    });

    test('标记为不同（负向记忆）后不再视为同义，也不被排除', () {
      useSpecialPair('相见');
      SynonymStore().markDistinct('相会', '相见');

      expect(SynonymStore().areSynonyms('相会', '相见'), isFalse);
      expect(
        SynonymStore().isSynonymWord(target, dict.words[1]),
        isFalse,
      );

      for (int seed = 0; seed < 20; seed++) {
        final List<WordItem> result = getRandomWords(
          4,
          dict,
          include: target,
          rnd: Random(seed),
          avoidSynonyms: true,
        );
        expect(result.length, 4, reason: 'seed=$seed');
      }
    });

    test('avoidSynonyms 为假时保持原有行为（返回 count 项）', () {
      for (int seed = 0; seed < 60; seed++) {
        final List<WordItem> result = getRandomWords(
          4,
          dict,
          include: target,
          rnd: Random(seed),
        );
        expect(result.length, 4, reason: 'seed=$seed');
      }
    });
  });

  group('buildChineseChoiceOptionWords', () {
    test('返回 4 个选项词，包含目标且排除已标记同义的干扰项', () {
      useSpecialPair('相见');
      SynonymStore().markSynonym('相会', '相见');

      for (int seed = 0; seed < 60; seed++) {
        final List<WordItem> optionWords = buildChineseChoiceOptionWords(
          target,
          dict,
          preferSimilar: false,
          rnd: Random(seed),
        );
        expect(optionWords.length, 4, reason: 'seed=$seed');
        expect(
          optionWords.any((WordItem w) => w.id == target.id),
          isTrue,
          reason: 'seed=$seed 必须包含目标词',
        );
        expect(
          optionWords.any((WordItem w) => w.id == 1),
          isFalse,
          reason: 'seed=$seed 同义干扰项必须被排除',
        );
      }
    });

    test('buildChineseChoiceOptions 委托后仍返回 4 个释义字符串', () {
      for (int seed = 0; seed < 30; seed++) {
        final List<String> options = buildChineseChoiceOptions(
          target,
          dict,
          preferSimilar: false,
          rnd: Random(seed),
        );
        expect(options.length, 4, reason: 'seed=$seed');
        expect(options, contains('相会'));
      }
    });
  });
}
