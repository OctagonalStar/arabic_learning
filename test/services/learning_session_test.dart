import 'package:arabic_learning/models/config.dart';
import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/package_replacement/storage.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/learning_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

/// 基础词库：4 个词，id 连续。
const List<WordItem> _words = <WordItem>[
  WordItem(arabic: 'كِتَابٌ', chinese: '书', explanation: '', className: '第一课', id: 0),
  WordItem(arabic: 'قَلَمٌ', chinese: '笔', explanation: '', className: '第一课', id: 1),
  WordItem(arabic: 'بَابٌ', chinese: '门', explanation: '', className: '第一课', id: 2),
  WordItem(arabic: 'مَدْرَسَةٌ', chinese: '学校', explanation: '', className: '第一课', id: 3),
];

DictData _dict(List<WordItem> words) => DictData(words: words, classes: const []);

/// 可读的题型配置：文字题 1、2，关闭全局乱序。
const QuizConfig _quiz = QuizConfig(
  questionSections: <int>[1, 2],
  shuffleGlobally: false,
  shuffleInternaly: true,
  shuffleExternaly: false,
  modifyAllowed: true,
  preferSimilar: true,
);

/// 默认断点：4 个词、4 道题、停在第 2 题。
LearningSessionCheckpoint _checkpoint({
  int seed = 20260923,
  List<String>? wordKeys,
  QuizConfig quiz = _quiz,
  bool countInReview = true,
  List<int>? itemIndices,
  int pageIndex = 1,
  int correctCount = 2,
  int elapsedSeconds = 42,
  int savedAtMillis = 1758000000000,
}) {
  return LearningSessionCheckpoint(
    seed: seed,
    wordKeys: wordKeys ?? _words.map(LearningSessionCheckpoint.wordKey).toList(),
    quiz: quiz,
    countInReview: countInReview,
    itemIndices: itemIndices ?? <int>[0, 5, 2, 9],
    pageIndex: pageIndex,
    correctCount: correctCount,
    elapsedSeconds: elapsedSeconds,
    savedAtMillis: savedAtMillis,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
    await LearningSessionStore.clear();
  });

  group('LearningSessionCheckpoint 序列化', () {
    test('toMap/fromMap 往返保留全部字段与题型开关', () {
      final LearningSessionCheckpoint cp = _checkpoint();
      final Map<String, dynamic> map = cp.toMap();

      expect(map['v'], LearningSessionCheckpoint.currentVersion);
      expect(map['seed'], 20260923);
      expect(map['words'], _words.map(LearningSessionCheckpoint.wordKey).toList());
      expect(map['countInReview'], isTrue);
      expect(map['items'], <int>[0, 5, 2, 9]);
      expect(map['page'], 1);
      expect(map['correct'], 2);
      expect(map['elapsed'], 42);
      expect(map['savedAt'], 1758000000000);

      final LearningSessionCheckpoint? restored = LearningSessionCheckpoint.fromMap(map);
      expect(restored, isNotNull);
      expect(restored!.seed, cp.seed);
      expect(restored.wordKeys, cp.wordKeys);
      expect(restored.countInReview, cp.countInReview);
      expect(restored.itemIndices, cp.itemIndices);
      expect(restored.pageIndex, cp.pageIndex);
      expect(restored.correctCount, cp.correctCount);
      expect(restored.elapsedSeconds, cp.elapsedSeconds);
      expect(restored.savedAtMillis, cp.savedAtMillis);
      expect(restored.quiz.questionSections, <int>[1, 2]);
      expect(restored.quiz.shuffleGlobally, isFalse);
      expect(restored.quiz.shuffleInternaly, isTrue);
      expect(restored.quiz.shuffleExternaly, isFalse);
      expect(restored.quiz.modifyAllowed, isTrue);
      expect(restored.quiz.preferSimilar, isTrue);
    });

    test('remaining 随 pageIndex 递减，结算页为 0', () {
      expect(_checkpoint(pageIndex: 0).remaining, 4);
      expect(_checkpoint(pageIndex: 1).remaining, 3);
      expect(_checkpoint(pageIndex: 4).remaining, 0);

      final LearningSessionCheckpoint settled = _checkpoint(pageIndex: 4);
      final LearningSessionCheckpoint? restored =
          LearningSessionCheckpoint.fromMap(settled.toMap());
      expect(restored, isNotNull);
      expect(restored!.remaining, 0);
    });

    test('wordKey 对相同阿语+中文稳定，不同中文不混淆', () {
      const WordItem a = WordItem(arabic: 'عَيْنٌ', chinese: '眼睛', explanation: '', className: 'x', id: 0);
      const WordItem aAgain = WordItem(arabic: 'عَيْنٌ', chinese: '眼睛', explanation: '', className: 'y', id: 7);
      const WordItem b = WordItem(arabic: 'عَيْنٌ', chinese: '泉眼', explanation: '', className: 'x', id: 1);

      expect(LearningSessionCheckpoint.wordKey(a), LearningSessionCheckpoint.wordKey(aAgain));
      expect(LearningSessionCheckpoint.wordKey(a), isNot(LearningSessionCheckpoint.wordKey(b)));
    });

    test('版本不符返回 null', () {
      final Map<String, dynamic> map = _checkpoint().toMap()..['v'] = 999;
      expect(LearningSessionCheckpoint.fromMap(map), isNull);

      final Map<String, dynamic> noVersion = _checkpoint().toMap()..remove('v');
      expect(LearningSessionCheckpoint.fromMap(noVersion), isNull);
    });

    test('缺少字段返回 null', () {
      for (final String field in <String>[
        'seed',
        'words',
        'quiz',
        'countInReview',
        'items',
        'page',
        'correct',
        'elapsed',
        'savedAt',
      ]) {
        final Map<String, dynamic> map = _checkpoint().toMap()..remove(field);
        expect(LearningSessionCheckpoint.fromMap(map), isNull, reason: '缺少 $field 应返回 null');
      }
    });

    test('字段类型异常返回 null', () {
      final Map<String, dynamic> seed = _checkpoint().toMap()..['seed'] = '20260923';
      expect(LearningSessionCheckpoint.fromMap(seed), isNull);

      final Map<String, dynamic> countInReview = _checkpoint().toMap()..['countInReview'] = 1;
      expect(LearningSessionCheckpoint.fromMap(countInReview), isNull);

      final Map<String, dynamic> page = _checkpoint().toMap()..['page'] = 1.5;
      expect(LearningSessionCheckpoint.fromMap(page), isNull);

      final Map<String, dynamic> words = _checkpoint().toMap()..['words'] = 'a\u0000b';
      expect(LearningSessionCheckpoint.fromMap(words), isNull);

      final Map<String, dynamic> items = _checkpoint().toMap()..['items'] = <dynamic>[0, 'x'];
      expect(LearningSessionCheckpoint.fromMap(items), isNull);

      final Map<String, dynamic> quiz = _checkpoint().toMap()..['quiz'] = 'quiz';
      expect(LearningSessionCheckpoint.fromMap(quiz), isNull);
    });

    test('wordKeys 为空返回 null', () {
      final Map<String, dynamic> empty = _checkpoint().toMap()..['words'] = <String>[];
      expect(LearningSessionCheckpoint.fromMap(empty), isNull);

      final Map<String, dynamic> blank = _checkpoint().toMap()..['words'] = <String>[''];
      expect(LearningSessionCheckpoint.fromMap(blank), isNull);
    });

    test('itemIndices 为空或非法返回 null', () {
      final Map<String, dynamic> empty = _checkpoint().toMap()..['items'] = <int>[];
      expect(LearningSessionCheckpoint.fromMap(empty), isNull);

      final Map<String, dynamic> negative = _checkpoint().toMap()..['items'] = <int>[0, -1];
      expect(LearningSessionCheckpoint.fromMap(negative), isNull);
    });

    test('page 超出题数或为负返回 null', () {
      final Map<String, dynamic> beyond = _checkpoint().toMap()..['page'] = 5;
      expect(LearningSessionCheckpoint.fromMap(beyond), isNull);

      final Map<String, dynamic> negative = _checkpoint().toMap()..['page'] = -1;
      expect(LearningSessionCheckpoint.fromMap(negative), isNull);
    });

    test('quiz 非法返回 null', () {
      final Map<String, dynamic> notMap = _checkpoint().toMap()..['quiz'] = <dynamic>[1, 2];
      expect(LearningSessionCheckpoint.fromMap(notMap), isNull);

      final Map<String, dynamic> missingSections = _checkpoint().toMap()..['quiz'] = <String, dynamic>{};
      expect(LearningSessionCheckpoint.fromMap(missingSections), isNull);

      final Map<String, dynamic> badSections = _checkpoint().toMap()
        ..['quiz'] = <String, dynamic>{
          'questionSections': 1,
          'shuffleGlobally': false,
          'shuffleInternaly': false,
          'shuffleExternaly': false,
          'modifyAllowed': true,
          'preferSimilar': false,
        };
      expect(LearningSessionCheckpoint.fromMap(badSections), isNull);
    });
  });

  group('LearningSessionCheckpoint.resolveWords', () {
    test('按阿语+中文解析，返回顺序与 wordKeys 一致', () {
      final DictData dict = _dict(_words);
      final List<String> keys = <String>[
        LearningSessionCheckpoint.wordKey(_words[2]),
        LearningSessionCheckpoint.wordKey(_words[0]),
        LearningSessionCheckpoint.wordKey(_words[3]),
      ];
      final LearningSessionCheckpoint cp = _checkpoint(wordKeys: keys);

      final List<WordItem>? resolved = cp.resolveWords(dict);
      expect(resolved, isNotNull);
      expect(resolved!.map((WordItem w) => w.chinese).toList(), <String>['门', '书', '学校']);
      expect(resolved.map((WordItem w) => w.id).toList(), <int>[2, 0, 3]);
    });

    test('中文释义被改写时回退到阿语身份键解析', () {
      final LearningSessionCheckpoint cp = _checkpoint(
        wordKeys: <String>[
          LearningSessionCheckpoint.wordKey(_words[0]),
          LearningSessionCheckpoint.wordKey(_words[1]),
        ],
      );

      // 释义改写 + 阿语去掉发音符号，仅身份键仍一致。
      final DictData rewritten = _dict(<WordItem>[
        const WordItem(arabic: 'كتاب', chinese: '书籍', explanation: '', className: '新', id: 0),
        const WordItem(arabic: 'قلم', chinese: '笔（文具）', explanation: '', className: '新', id: 1),
      ]);

      final List<WordItem>? resolved = cp.resolveWords(rewritten);
      expect(resolved, isNotNull);
      expect(resolved!.map((WordItem w) => w.chinese).toList(), <String>['书籍', '笔（文具）']);
    });

    test('同形异义词按中文区分，不会解析到另一条', () {
      final DictData dict = _dict(<WordItem>[
        const WordItem(arabic: 'عَيْنٌ', chinese: '眼睛', explanation: '', className: 'x', id: 0),
        const WordItem(arabic: 'عَيْنٌ', chinese: '泉眼', explanation: '', className: 'x', id: 1),
      ]);
      final LearningSessionCheckpoint cp = _checkpoint(
        wordKeys: <String>[
          LearningSessionCheckpoint.wordKey(dict.words[1]),
        ],
      );

      final List<WordItem>? resolved = cp.resolveWords(dict);
      expect(resolved, isNotNull);
      expect(resolved!.single.chinese, '泉眼');
      expect(resolved.single.id, 1);
    });

    test('任一单词缺失返回 null', () {
      final DictData dict = _dict(_words);

      final LearningSessionCheckpoint missingInDict = _checkpoint(
        wordKeys: <String>[
          LearningSessionCheckpoint.wordKey(_words[0]),
          '不存在\u0000的单词',
        ],
      );
      expect(missingInDict.resolveWords(dict), isNull);

      final LearningSessionCheckpoint missingWholeDict = _checkpoint();
      expect(missingWholeDict.resolveWords(_dict(<WordItem>[_words[0]])), isNull);
      expect(missingWholeDict.resolveWords(const DictData(words: <WordItem>[], classes: <SourceItem>[])), isNull);
    });

    test('词库顺序/id 变化但身份相同仍能解析', () {
      final LearningSessionCheckpoint cp = _checkpoint();

      // 逆序重建词库，id 随位置改变。
      final DictData reordered = _dict(<WordItem>[
        const WordItem(arabic: 'مَدْرَسَةٌ', chinese: '学校', explanation: '', className: 'c', id: 0),
        const WordItem(arabic: 'بَابٌ', chinese: '门', explanation: '', className: 'c', id: 1),
        const WordItem(arabic: 'قَلَمٌ', chinese: '笔', explanation: '', className: 'c', id: 2),
        const WordItem(arabic: 'كِتَابٌ', chinese: '书', explanation: '', className: 'c', id: 3),
      ]);

      final List<WordItem>? resolved = cp.resolveWords(reordered);
      expect(resolved, isNotNull);
      expect(
        resolved!.map((WordItem w) => w.arabic).toList(),
        <String>['كِتَابٌ', 'قَلَمٌ', 'بَابٌ', 'مَدْرَسَةٌ'],
      );
      expect(resolved.map((WordItem w) => w.id).toList(), <int>[3, 2, 1, 0]);
    });
  });

  group('LearningSessionStore', () {
    test('save 后 load 能读回，clear 后返回 null', () async {
      expect(LearningSessionStore.load(), isNull);

      final LearningSessionCheckpoint cp = _checkpoint();
      await LearningSessionStore.save(cp);

      final LearningSessionCheckpoint? loaded = LearningSessionStore.load();
      expect(loaded, isNotNull);
      expect(loaded!.seed, cp.seed);
      expect(loaded.wordKeys, cp.wordKeys);
      expect(loaded.quiz.questionSections, cp.quiz.questionSections);
      expect(loaded.itemIndices, cp.itemIndices);
      expect(loaded.pageIndex, cp.pageIndex);
      expect(loaded.correctCount, cp.correctCount);
      expect(loaded.elapsedSeconds, cp.elapsedSeconds);
      expect(loaded.savedAtMillis, cp.savedAtMillis);
      expect(loaded.countInReview, cp.countInReview);

      await LearningSessionStore.clear();
      expect(LearningSessionStore.load(), isNull);
    });

    test('存储为空或内容非法时返回 null 而不抛异常', () async {
      await AppData().storage.setString(LearningSessionStore.key, '');
      expect(LearningSessionStore.load(), isNull);

      await AppData().storage.setString(LearningSessionStore.key, 'not-json');
      expect(LearningSessionStore.load(), isNull);

      await AppData().storage.setString(LearningSessionStore.key, '[1,2,3]');
      expect(LearningSessionStore.load(), isNull);

      await AppData().storage.setString(LearningSessionStore.key, '{"v":1}');
      expect(LearningSessionStore.load(), isNull);

      await AppData().storage.setString(LearningSessionStore.key, '{"v":999}');
      expect(LearningSessionStore.load(), isNull);

      await AppData().storage.setString(
        LearningSessionStore.key,
        '{"v":1,"seed":"x","words":["a"],"quiz":{},"countInReview":true,'
        '"items":[0],"page":0,"correct":0,"elapsed":0,"savedAt":0}',
      );
      expect(LearningSessionStore.load(), isNull);
    });

    test('learningSessionData 已加入备份白名单', () {
      expect(LearningSessionStore.key, 'learningSessionData');
      expect(SharedPreferences.usedKeys.contains(LearningSessionStore.key), isTrue);
    });
  });
}
