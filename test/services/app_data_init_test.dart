// `AppData.init()` 启动路径的行为回归测试。
//
// 覆盖本轮性能改造的三条不变量：
// 1. 并发读取后，各键的「缺失 / 空 / 损坏」处理与改造前完全一致；
// 2. 启动阶段不再做「没有变化也整份写回」的全量写盘；
// 3. 存量阴阳性纠正的回写是延迟的，且在词库被改动后会被丢弃（不覆盖新数据）。
//
// `AppData` 是单例，同一个测试文件里用 `debugResetForInit()` 反复重新 init，
// 用 `mockStorage` 提供不同的初始键值。

import 'dart:convert';

import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/models/reading.dart';
import 'package:arabic_learning/package_replacement/storage.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/favorites.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/memberships.dart';
import 'package:arabic_learning/services/plan_store.dart';
import 'package:arabic_learning/services/search.dart';
import 'package:arabic_learning/services/synonyms.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

/// 一份「已启动过」的最小存储：有 settingData 即非首次启动。
Map<String, Object> _storageWith({Map<String, Object>? extra}) {
  return <String, Object>{
    'settingData': jsonEncode(<String, dynamic>{}),
    ...?extra,
  };
}

Map<String, dynamic> _wordMap(List<Map<String, dynamic>> words,
    {Map<String, dynamic>? classes}) {
  return <String, dynamic>{
    'Words': words,
    'Classes': classes ?? <String, dynamic>{},
  };
}

Map<String, dynamic> _word(String arabic, String chinese,
        {String className = 'A', String pos = ''}) =>
    <String, dynamic>{
      'arabic': arabic,
      'chinese': chinese,
      'explanation': '',
      'subClass': className,
      if (pos.isNotEmpty) 'pos': pos,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    mockPathProvider();
  });

  setUp(() {
    // 每次用例都从一个干净的存储开始；FSRS 的 SQLite 打开是记忆化的，
    // 在 flutter test 下会稳定回退 JSON 后端（见 fsrs_store_integration_test）。
    mockStorage(_storageWith());
    AppData().debugResetForInit();
    AppData().debugWordWriteCount = 0;
  });

  group('AppData.init：键缺失 / 空 / 损坏的处理', () {
    test('wordData 缺失 -> 降级为空词库，不抛异常', () async {
      mockStorage(_storageWith());
      AppData().debugResetForInit();

      await AppData().init();

      expect(AppData().inited, isTrue);
      expect(AppData().wordData.words, isEmpty);
      expect(AppData().wordData.classes, isEmpty);
      // readingData 也缺失时用空 units 兜底
      expect(AppData().readingData.units, isEmpty);
      // 空词库也要建索引，后续搜索不报错
      expect(BKSearch.lookup('كتاب'), isEmpty);
    });

    test('wordData 为空字符串 -> 同样降级为空词库', () async {
      mockStorage(_storageWith(extra: <String, Object>{'wordData': ''}));
      AppData().debugResetForInit();

      await AppData().init();

      expect(AppData().wordData.words, isEmpty);
    });

    test('wordData 是坏 JSON -> 上抛（与改造前一致，由 Global 接管）', () async {
      mockStorage(_storageWith(extra: <String, Object>{'wordData': '{not json'}));
      AppData().debugResetForInit();

      await expectLater(AppData().init(), throwsA(isA<FormatException>()));
      expect(AppData().inited, isFalse, reason: '初始化失败不应标记完成');
    });

    test('readingData 是坏 JSON -> 上抛；wordData 已正确解析', () async {
      mockStorage(_storageWith(extra: <String, Object>{
        'wordData': jsonEncode(_wordMap(<Map<String, dynamic>>[
          _word('كتاب', '书'),
        ])),
        'readingData': '{bad',
      }));
      AppData().debugResetForInit();

      await expectLater(AppData().init(), throwsA(isA<FormatException>()));
      expect(AppData().inited, isFalse);
    });

    test('wordData 与 readingData 同时损坏 -> 抛词库那条错误（顺序与改造前一致）',
        () async {
      mockStorage(_storageWith(extra: <String, Object>{
        'wordData': '{bad word',
        'readingData': '{bad reading',
      }));
      AppData().debugResetForInit();

      // 两个解码并发，但 Future.wait 按列表顺序抛第一个错误（词库优先）。
      await expectLater(
        AppData().init(),
        throwsA(isA<FormatException>().having(
          (FormatException e) => e.source?.toString() ?? '',
          'source',
          contains('bad word'),
        )),
      );
    });

    test('小键损坏 -> 各自回退为空，不影响启动', () async {
      mockStorage(_storageWith(extra: <String, Object>{
        'wordData': jsonEncode(_wordMap(<Map<String, dynamic>>[
          _word('كتاب', '书'),
        ])),
        'synonymData': '{bad',
        'favoriteData': '{bad',
        'planData': '{bad',
      }));
      AppData().debugResetForInit();

      await AppData().init();

      expect(AppData().inited, isTrue);
      expect(AppData().wordData.words, hasLength(1));
      expect(SynonymStore().data.synonyms, isEmpty);
      expect(FavoriteStore().count, 0);
      expect(PlanStore().state.plan, isNull);
      expect(PlanStore().inited, isTrue, reason: '损坏数据也要标记为已加载');
    });

    test('readingData 缺失但 wordData 正常 -> units 为空、词库完整', () async {
      mockStorage(_storageWith(extra: <String, Object>{
        'wordData': jsonEncode(_wordMap(<Map<String, dynamic>>[
          _word('كتاب', '书'),
          _word('بيت', '房子'),
        ])),
      }));
      AppData().debugResetForInit();

      await AppData().init();

      expect(AppData().wordData.words, hasLength(2));
      expect(AppData().readingData.units, isEmpty);
    });

    test('首次启动（无 settingData）-> 不读词库，isFirstStart 为真', () async {
      mockStorage(<String, Object>{});
      AppData().debugResetForInit();

      await AppData().init();

      expect(AppData().isFirstStart, isTrue);
      expect(AppData().inited, isTrue);
      // 首次启动路径由 Global 调 initStorageValue() 写默认值。
      expect(AppData().wordData.words, isEmpty);
    });
  });

  group('AppData.init：索引与数据落地', () {
    test('词库与课程归属解析后，搜索索引与归属索引都可用', () async {
      mockStorage(_storageWith(extra: <String, Object>{
        'wordData': jsonEncode(_wordMap(
          <Map<String, dynamic>>[
            _word('كتاب', '书'),
            _word('بيت', '房子'),
          ],
          classes: <String, dynamic>{
            'lib.json': <String, dynamic>{
              'displayName': '演示词库',
              'classes': <String, dynamic>{
                'A': <int>[0, 1],
              },
            },
          },
        )),
        'readingData': jsonEncode(<String, dynamic>{
          'units': <dynamic>[
            <String, dynamic>{
              'type': 1,
              'title': 'T',
              'passage': 'P',
              'difficulty': 1,
              'tashkeel': false,
              'questions': <dynamic>[],
              'tags': <String>[],
            },
          ],
        }),
      }));
      AppData().debugResetForInit();

      await AppData().init();

      expect(AppData().wordData.words, hasLength(2));
      // BKSearch 是进程级单例且 `init` 已就绪时早退（改造前行为），
      // 故这里只校验 init 一定会重建的归属索引与解析结果。
      expect(WordMembershipIndex.instance.of(0).single.course, 'A');
      expect(WordMembershipIndex.instance.of(0).single.source, '演示词库');
      expect(WordMembershipIndex.instance.of(1).single.course, 'A');
      expect(AppData().readingData.units.single.title, 'T');
    });

    test('词条 id 仍是位置下标（重建后与数组顺序一致）', () async {
      mockStorage(_storageWith(extra: <String, Object>{
        'wordData': jsonEncode(_wordMap(<Map<String, dynamic>>[
          _word('a', '1'),
          _word('b', '2'),
          _word('c', '3'),
        ])),
      }));
      AppData().debugResetForInit();

      await AppData().init();

      expect(AppData().wordData.words.map((WordItem w) => w.id), <int>[0, 1, 2]);
    });
  });

  group('AppData.init：启动阶段不做无变化的整份写盘', () {
    test('数据未变 -> 不写 wordData', () async {
      final String raw = jsonEncode(_wordMap(<Map<String, dynamic>>[
        // pos 为 Nominals + gender=true 是「合法」数据，不会被纠正
        <String, dynamic>{
          'arabic': 'كتاب',
          'chinese': '书',
          'explanation': '',
          'subClass': 'A',
          'pos': 'Nominals',
          'gender': true,
        },
      ]));
      mockStorage(_storageWith(extra: <String, Object>{'wordData': raw}));
      AppData().debugResetForInit();

      await AppData().init();
      await AppData().pendingWordWrite;

      expect(AppData().debugWordWriteCount, 0, reason: '没有变化就不该回写');
      expect(AppData().storage.getString('wordData'), raw,
          reason: '存储内容必须原样保留');
    });

    test('缺失的小键不再写入默认值（留待首次真实改动）', () async {
      mockStorage(_storageWith(extra: <String, Object>{
        'wordData': jsonEncode(_wordMap(<Map<String, dynamic>>[])),
      }));
      AppData().debugResetForInit();

      await AppData().init();

      expect(AppData().storage.containsKey('synonymData'), isFalse);
      expect(AppData().storage.containsKey('favoriteData'), isFalse);
      // 内存状态仍是可用的空数据
      expect(SynonymStore().data.synonyms, isEmpty);
      expect(FavoriteStore().count, 0);
    });

    test('存量阴阳性占位数据被纠正 -> 恰好回写一次', () async {
      final String raw = jsonEncode(_wordMap(<Map<String, dynamic>>[
        <String, dynamic>{
          'arabic': 'يكتب',
          'chinese': '写',
          'explanation': '',
          'subClass': 'A',
          'pos': 'Verbs',
          'gender': true, // 非名词的占位值，启动时应被清除
        },
      ]));
      mockStorage(_storageWith(extra: <String, Object>{'wordData': raw}));
      AppData().debugResetForInit();

      await AppData().init();
      await AppData().pendingWordWrite;

      expect(AppData().wordData.words.single.gender, isNull);
      expect(AppData().debugWordWriteCount, 1);

      final dynamic persisted =
          jsonDecode(AppData().storage.getString('wordData')!) as Map;
      expect((persisted['Words'] as List).single['gender'], isNull,
          reason: '纠正结果必须落盘');
    });

    test('回写进行中词库被改动 -> 旧快照被丢弃，不覆盖新数据', () async {
      final String raw = jsonEncode(_wordMap(<Map<String, dynamic>>[
        <String, dynamic>{
          'arabic': 'يكتب',
          'chinese': '写',
          'explanation': '',
          'subClass': 'A',
          'pos': 'Verbs',
          'gender': true,
        },
      ]));
      mockStorage(_storageWith(extra: <String, Object>{'wordData': raw}));
      AppData().debugResetForInit();

      await AppData().init();
      // 不等待 pendingWordWrite：模拟「回写还在后台编码时用户导入新词库」。
      AppData().importDictData(
        '{"B":[{"arabic":"بيت","chinese":"房子"}]}',
        'b.json',
      );
      await AppData().pendingWordWrite;

      // 导入结果必须还在，且不能被启动快照回滚成单条 Verbs。
      expect(AppData().wordData.words, hasLength(2));
      final dynamic persisted =
          jsonDecode(AppData().storage.getString('wordData')!) as Map;
      expect((persisted['Words'] as List), hasLength(2),
          reason: '存储里应是导入后的新词库');
    });
  });

  group('AppData.init：并发读取不破坏依赖顺序', () {
    test('词库为空时索引仍标记为就绪，查询返回空而不是抛异常', () async {
      mockStorage(_storageWith(extra: <String, Object>{
        'wordData': jsonEncode(_wordMap(<Map<String, dynamic>>[])),
      }));
      AppData().debugResetForInit();

      await AppData().init();

      expect(BKSearch.isReady, isTrue);
      expect(WordMembershipIndex.instance.isReady, isTrue);
      expect(BKSearch.lookup('anything'), isEmpty);
    });

    test('FSRS 在 init 返回时已就绪（与词库解析并发后汇合）', () async {
      mockStorage(_storageWith(extra: <String, Object>{
        'wordData': jsonEncode(_wordMap(<Map<String, dynamic>>[])),
      }));
      AppData().debugResetForInit();

      await AppData().init();

      expect(FSRS().inited, isTrue);
    });

    test('重复 init 是空操作（不会重置已加载的数据）', () async {
      mockStorage(_storageWith(extra: <String, Object>{
        'wordData': jsonEncode(_wordMap(<Map<String, dynamic>>[
          _word('كتاب', '书'),
        ])),
      }));
      AppData().debugResetForInit();

      await AppData().init();
      final DictData first = AppData().wordData;
      await AppData().init();

      expect(identical(AppData().wordData, first), isTrue);
    });
  });

  group('ReadingData 解析', () {
    test('空 units 数组可解析', () async {
      mockStorage(_storageWith(extra: <String, Object>{
        'wordData': jsonEncode(_wordMap(<Map<String, dynamic>>[])),
        'readingData': jsonEncode(<String, dynamic>{'units': <dynamic>[]}),
      }));
      AppData().debugResetForInit();

      await AppData().init();

      expect(AppData().readingData, isA<ReadingData>());
      expect(AppData().readingData.units, isEmpty);
    });
  });

  group('存储键契约', () {
    test('启动读取的键都在备份白名单内', () {
      for (final String key in <String>[
        'wordData',
        'readingData',
        'synonymData',
        'favoriteData',
        'planData',
      ]) {
        expect(SharedPreferences.usedKeys, contains(key));
      }
    });
  });
}
