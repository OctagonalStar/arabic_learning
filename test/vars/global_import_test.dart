import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/config_structure.dart';
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
  });
}
