import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/memberships.dart';
import 'package:arabic_learning/models/dict.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    // AppData 为单例：初始化一次（storage/basePath），随后每次测试重置词库。
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
  });

  setUp(() async {
    await AppData().initStorageValue();
  });

  group('AppData.importDictData', () {
    test('解析旧版 JSON 对象', () {
      final DictImportResult result = AppData().importDictData(
        '{"第一课":[{"arabic":"كتاب","chinese":"书","explanation":"名词"}]}',
        'old.json',
      );

      expect(result.isJsonl, isFalse);
      expect(result.importedCount, 1);
      expect(result.skippedCount, 0);
      expect(result.classCount, 1);
      expect(result.sourceName, 'old.json');

      final DictData data = AppData().wordData;
      expect(data.words.single.arabic, 'كتاب');
      expect(data.words.single.className, '第一课');
      expect(data.classes.single.sourceJsonFileName, 'old.json');
      expect(data.classes.single.subClasses.single.className, '第一课');
    });

    test('解析新 JSONL（metadata + class 规范化为字符串，example 回退）', () {
      final String jsonl = <String>[
        '{"metadata":true,"name":"新词库"}',
        '{"class":1,"words":[{"arabic":"قلم","chinese":"笔","example":"例句",'
            '"root":"ق ل م","categories":["基础"],'
            '"properties":{"pos":"Nominals","gender":false,"plural":"أقلام"}}]}',
      ].join('\n');

      final DictImportResult result = AppData().importDictData(jsonl, 'new.jsonl');

      expect(result.isJsonl, isTrue);
      expect(result.sourceName, '新词库');
      expect(result.importedCount, 1);
      expect(result.classCount, 1);

      final WordItem word = AppData().wordData.words.single;
      expect(word.arabic, 'قلم');
      expect(word.explanation, '例句');
      expect(word.root, 'ق ل م');
      expect(word.categories, ['基础']);
      expect(word.pos, 'Nominals');
      expect(word.gender, isFalse);
      expect(word.plural, 'أقلام');

      final SourceItem source = AppData().wordData.classes.single;
      expect(source.displayName, '新词库');
      expect(source.name, '新词库');
      expect(source.subClasses.single.className, '1');
    });

    test('兼容旧版 matedata 拼写', () {
      final String jsonl = <String>[
        '{"matedata":true,"name":"兼容库"}',
        '{"class":"A","words":[{"arabic":"نور","chinese":"光"}]}',
      ].join('\n');

      final DictImportResult result = AppData().importDictData(jsonl, 'm.jsonl');
      expect(result.sourceName, '兼容库');
      expect(result.isJsonl, isTrue);
      expect(AppData().wordData.classes.single.displayName, '兼容库');
    });

    test('跳过空阿语/空中文，并复用已存在词条', () {
      final DictImportResult result = AppData().importDictData(
        '{"第一课":['
        '{"arabic":"كتاب","chinese":"书"},'
        '{"arabic":"","chinese":"空"},'
        '{"arabic":"قلم","chinese":""},'
        '{"arabic":"كتاب","chinese":"书"}'
        ']}',
        'dup.json',
      );

      // 两条有效（其中一条为重复）、两条被跳过
      expect(result.importedCount, 2);
      expect(result.skippedCount, 2);
      expect(AppData().wordData.words.length, 1);
      expect(
        AppData().wordData.classes.single.subClasses.single.wordIndexs,
        [0],
      );
    });

    test('同名源再次导入会替换旧源课程而不是累加', () {
      AppData().importDictData(
        '{"第一课":[{"arabic":"كتاب","chinese":"书"}]}',
        'same.json',
      );
      expect(AppData().wordData.classes.single.subClasses.length, 1);

      AppData().importDictData(
        '{"第二课":[{"arabic":"قلم","chinese":"笔"}]}',
        'same.json',
      );
      final SourceItem source = AppData().wordData.classes.single;
      expect(source.subClasses.length, 1);
      expect(source.subClasses.single.className, '第二课');
    });

    test('命中已有词条时补充/覆盖词形信息而不新增词条，并建立多词库归属', () {
      AppData().importDictData(
        '{"第一课":[{"arabic":"كتاب","chinese":"书"}]}',
        'base.json',
      );
      expect(AppData().wordData.words.length, 1);
      expect(AppData().wordData.words.single.root, '');

      AppData().importDictData(
        '{"第二课":[{"arabic":"كتاب","chinese":"书","root":"ك ت ب",'
            '"categories":["基础"],"properties":{"pos":"Nominals","gender":false,"plural":"كتب"}}]}',
        'other.json',
      );

      final DictData data = AppData().wordData;
      expect(data.words.length, 1, reason: '同词命中不应新增词条');
      final WordItem word = data.words.single;
      expect(word.root, 'ك ت ب');
      expect(word.categories, ['基础']);
      expect(word.pos, 'Nominals');
      expect(word.gender, isFalse);
      expect(word.plural, 'كتب');
      expect(data.classes.length, 2);
      expect(data.classes[0].subClasses.single.wordIndexs, [0]);
      expect(data.classes[1].subClasses.single.wordIndexs, [0]);
      expect(
        WordMembershipIndex.instance
            .of(0)
            .map((WordMembership m) => m.label)
            .toList(),
        ['base.json › 第一课', 'other.json › 第二课'],
      );
    });

    test('词形字段新库覆盖旧值，explanation 仅补空，categories 取并集', () {
      AppData().importDictData(
        '{"A":[{"arabic":"قلم","chinese":"笔","explanation":"旧的解释",'
            '"root":"ق ل م","categories":["旧"],"properties":{"pos":"Nominals","plural":"أقلام"}}]}',
        'first.json',
      );
      AppData().importDictData(
        '{"B":[{"arabic":"قلم","chinese":"笔","explanation":"新的解释",'
            '"root":"ج د ي د","categories":["新"],"properties":{"pos":"Verbs","plural":"جدد","masdar":"مصدر"}}]}',
        'second.json',
      );

      final WordItem word = AppData().wordData.words.single;
      expect(word.explanation, '旧的解释', reason: '旧解释非空时保持');
      expect(word.root, 'ج د ي د', reason: '词形字段新库覆盖');
      expect(word.pos, 'Verbs');
      expect(word.plural, 'جدد');
      expect(word.masdar, 'مصدر');
      expect(word.categories.toSet(), <String>{'旧', '新'}, reason: '分类取并集');
    });

    test('同一来源的多个课程可共同归属同一词条', () {
      AppData().importDictData(
        '{"A":[{"arabic":"بيت","chinese":"房子"}],'
        '"B":[{"arabic":"بيت","chinese":"房子"}]}',
        'multi.json',
      );
      final DictData data = AppData().wordData;
      expect(data.words.length, 1);
      expect(data.classes.single.subClasses.length, 2);
      expect(data.classes.single.subClasses[0].wordIndexs, [0]);
      expect(data.classes.single.subClasses[1].wordIndexs, [0]);
    });

    test('非名词词条的阴阳性占位值在导入时被忽略，仅名词保留', () {
      final String jsonl = <String>[
        '{"metadata":true,"name":"词性库"}',
        '{"class":"A","words":['
            '{"arabic":"يكتب","chinese":"写","properties":{"pos":"Verbs","gender":true}},'
            '{"arabic":"كتاب","chinese":"书","properties":{"pos":"Nominals","gender":true}},'
            '{"arabic":"هو","chinese":"他","properties":{"pos":"Particles","gender":true}}'
            ']}',
      ].join('\n');

      AppData().importDictData(jsonl, 'pos.jsonl');

      final DictData data = AppData().wordData;
      expect(data.words[0].gender, isNull, reason: '动词无阴阳性');
      expect(data.words[1].gender, isTrue, reason: '名词保留阴阳性');
      expect(data.words[2].gender, isNull, reason: '虚词无阴阳性');
    });

    test('自动纠正存量非名词词条的阴阳性占位数据', () {
      AppData().wordData = const DictData(
        words: <WordItem>[
          WordItem(arabic: 'يكتب', chinese: '写', explanation: '', className: 'A', id: 0, pos: 'Verbs', gender: true),
          WordItem(arabic: 'كتاب', chinese: '书', explanation: '', className: 'A', id: 1, pos: 'Nominals', gender: true),
          WordItem(arabic: 'بيت', chinese: '房子', explanation: '', className: 'A', id: 2, pos: '', gender: false),
        ],
        classes: <SourceItem>[
          SourceItem(sourceJsonFileName: 'x.json', displayName: 'x', subClasses: <ClassItem>[
            ClassItem(className: 'A', wordIndexs: <int>[0, 1, 2]),
          ]),
        ],
      );

      expect(AppData().normalizeWordGenders(), isTrue);
      final DictData data = AppData().wordData;
      expect(data.words[0].gender, isNull, reason: '动词占位值被清除');
      expect(data.words[1].gender, isTrue, reason: '名词保留');
      expect(data.words[2].gender, isFalse, reason: '词性未知的旧数据原样保留');
      expect(AppData().normalizeWordGenders(), isFalse, reason: '再次调用应无改动');
    });
  });
}
