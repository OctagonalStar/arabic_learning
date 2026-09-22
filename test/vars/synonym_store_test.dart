import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/models/synonym.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/synonyms.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    // AppData 为单例：初始化一次（storage/basePath），随后每次测试重置标记。
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
  });

  setUp(() {
    // 单例状态在测试间共享，用 clearAll 重置内存与存储。
    SynonymStore().clearAll();
  });

  WordItem word(String gloss) => WordItem(
        arabic: 'x',
        chinese: gloss,
        explanation: '',
        className: 'c',
        id: 0,
      );

  group('normalizeGloss', () {
    test('去除空格与中英文标点', () {
      expect(normalizeGloss('相会，'), '相会');
      expect(normalizeGloss('相 会'), '相会');
      expect(normalizeGloss('（相会）'), '相会');
      expect(normalizeGloss('相会。'), '相会');
      expect(normalizeGloss(' 相会 '), '相会');
    });
  });

  group('GlossPair', () {
    test('create 按字典序排列', () {
      final GlossPair? pair = GlossPair.create('相见', '相会');
      expect(pair, isNotNull);
      expect(pair!.a, '相会');
      expect(pair.b, '相见');
      expect(pair.key, '相会\u0000相见');
      expect(pair.display, '相会 / 相见');
      expect(pair.isValid, isTrue);
    });

    test('空值/规范化后相等返回 null', () {
      expect(GlossPair.create('', '相会'), isNull);
      expect(GlossPair.create('相会', ''), isNull);
      expect(GlossPair.create('相会，', '相会'), isNull);
      expect(GlossPair.create('   ', '  '), isNull);
    });
  });

  group('SynonymData', () {
    test('toMap/fromMap 往返一致', () {
      final SynonymData data = SynonymData(
        synonyms: {GlossPair.create('相见', '相会')!},
        distincts: {GlossPair.create('书', '笔')!},
      );
      final SynonymData restored = SynonymData.buildFromMap(data.toMap());
      expect(restored.synonyms, data.synonyms);
      expect(restored.distincts, data.distincts);
    });

    test('buildFromMap 容错空字段', () {
      final SynonymData data = SynonymData.buildFromMap(<String, dynamic>{});
      expect(data.synonyms, isEmpty);
      expect(data.distincts, isEmpty);

      final SynonymData nulled = SynonymData.buildFromMap(<String, dynamic>{
        'synonyms': null,
        'distincts': 'bad',
      });
      expect(nulled.synonyms, isEmpty);
      expect(nulled.distincts, isEmpty);
    });
  });

  group('SynonymStore 标记与查询', () {
    test('markSynonym 后 areSynonyms/isSynonymWord 为真', () {
      SynonymStore().markSynonym('相见', '相会');

      expect(SynonymStore().areSynonyms('相见', '相会'), isTrue);
      expect(SynonymStore().areSynonyms('相 见。', '（相会）'), isTrue);
      expect(SynonymStore().isSynonymWord(word('相见'), word('相会')), isTrue);
      expect(SynonymStore().isDistinctWord(word('相见'), word('相会')), isFalse);
    });

    test('规范化后相等视为同义，空串为 false', () {
      expect(SynonymStore().areSynonyms('相会，', '相会'), isTrue);
      expect(SynonymStore().areSynonyms('', '相会'), isFalse);
      expect(SynonymStore().areSynonyms('相会', ''), isFalse);
      expect(SynonymStore().areDistinct('', ''), isFalse);
    });

    test('markDistinct 移除已标记同义并记为不同', () {
      SynonymStore().markSynonym('相见', '相会');
      expect(SynonymStore().areSynonyms('相见', '相会'), isTrue);

      SynonymStore().markDistinct('相见', '相会');
      expect(SynonymStore().areSynonyms('相见', '相会'), isFalse);
      expect(SynonymStore().areDistinct('相见', '相会'), isTrue);

      // 反向：重新标记同义会清除不同标记
      SynonymStore().markSynonym('相见', '相会');
      expect(SynonymStore().areDistinct('相见', '相会'), isFalse);
      expect(SynonymStore().areSynonyms('相见', '相会'), isTrue);
    });

    test('持久化：reload 后仍存在且已写入存储键', () {
      SynonymStore().markSynonym('相见', '相会');

      final String? raw = AppData().storage.getString('synonymData');
      expect(raw, isNotNull);
      expect(raw, contains('相会'));

      // 篡改内存后重载，应从存储恢复
      SynonymStore().data = const SynonymData();
      expect(SynonymStore().areSynonyms('相见', '相会'), isFalse);

      SynonymStore().reload();
      expect(SynonymStore().areSynonyms('相见', '相会'), isTrue);
    });

    test('synonymGroups 传递分组', () {
      SynonymStore().markSynonym('A', 'B');
      SynonymStore().markSynonym('B', 'C');

      final List<List<String>> groups = SynonymStore().synonymGroups();
      expect(groups.length, 1);
      expect(groups.single, ['A', 'B', 'C']);
    });

    test('synonymGroups 无关联对不合并', () {
      SynonymStore().markSynonym('A', 'B');
      SynonymStore().markSynonym('C', 'D');

      final List<List<String>> groups = SynonymStore().synonymGroups();
      expect(groups.length, 2);
      expect(groups[0], ['A', 'B']);
      expect(groups[1], ['C', 'D']);
    });

    test('removePair 与 clearAll', () {
      SynonymStore().markSynonym('相见', '相会');
      SynonymStore().removePair('相见', '相会');
      expect(SynonymStore().areSynonyms('相见', '相会'), isFalse);

      SynonymStore().markSynonym('相见', '相会');
      SynonymStore().markDistinct('书', '笔');
      SynonymStore().clearAll();
      expect(SynonymStore().synonymList, isEmpty);
      expect(SynonymStore().distinctList, isEmpty);
      expect(SynonymStore().areSynonyms('相见', '相会'), isFalse);
      expect(SynonymStore().areDistinct('书', '笔'), isFalse);
    });
  });
}
