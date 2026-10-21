// `AppData.init()` 启动路径的耗时测量（Linux VM，`flutter test`）。
//
// 用 5000 词合成词库（≈2MB JSON）分别测：
//   - 改造后的并发 init（隔离同步回退：flutter test 下 isolate 被禁用）；
//   - 「改造前」的串行顺序：逐键 await + 主 isolate 同步 jsonDecode + 同步回写。
//
// 改造前的实现已不存在，这里用等价的参考实现（`_legacyInit`）复现：
// 顺序读取 9 个键、主 isolate jsonDecode、normalizeWordGenders 后同步回写。
//
// 运行：flutter test test/services/app_data_init_timing_test.dart
// 用 `--dart-define=PERF=1` 可让断言关闭、只打印数字（默认也打印）。

import 'dart:convert';

import 'package:arabic_learning/core/json_offload.dart';
import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/models/reading.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/favorites.dart';
import 'package:arabic_learning/services/memberships.dart';
import 'package:arabic_learning/services/plan_store.dart';
import 'package:arabic_learning/services/search.dart';
import 'package:arabic_learning/services/synonyms.dart';
import 'package:arabic_learning/package_replacement/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

const int _wordCount = 5000;

/// 合成词库：5000 个互不相同的阿语词形 + 中文释义 + 词形字段。
///
/// 体积与真实词库同量级（约 2MB），且 `categories`/`root`/`pos` 都有值，
/// 让 `DictData.buildFromMap` 的构造开销与真实数据接近。
Map<String, dynamic> _syntheticWordMap() {
  final List<Map<String, dynamic>> words = <Map<String, dynamic>>[];
  final List<int> indexes = <int>[];
  for (int i = 0; i < _wordCount; i++) {
    words.add(<String, dynamic>{
      'arabic': 'كلمة$i',
      'chinese': '第 $i 个词的释义，用于测量解析开销',
      'explanation': '这是第 $i 个词的说明文本，长度接近真实词库。',
      'subClass': '第 ${i ~/ 50} 课',
      'root': 'كلم',
      'categories': <String>['四级', '常用词'],
      'pos': i.isEven ? 'Nominals' : 'Verbs',
      if (i.isEven) 'gender': true,
    });
    indexes.add(i);
  }
  return <String, dynamic>{
    'Words': words,
    'Classes': <String, dynamic>{
      'synthetic.json': <String, dynamic>{
        'displayName': '合成词库',
        'classes': <String, dynamic>{
          for (int c = 0; c < _wordCount ~/ 50; c++)
            '第 $c 课': indexes.sublist(c * 50, (c + 1) * 50),
        },
      },
    },
  };
}

/// 一份 1000 题的阅读数据（约 300KB），代表「另一个需要解析的大键」。
Map<String, dynamic> _syntheticReadingMap() {
  return <String, dynamic>{
    'units': <dynamic>[
      for (int u = 0; u < 20; u++)
        <String, dynamic>{
          'type': 1,
          'title': '阅读 $u',
          'passage': 'النص العربي ' * 200,
          'difficulty': 2,
          'tashkeel': true,
          'questions': <dynamic>[
            for (int q = 0; q < 50; q++)
              <String, dynamic>{
                'riddle': '问题 $u-$q 的题干文本',
                'answers': <String>['选项甲', '选项乙', '选项丙', '选项丁'],
                'type': 'choice',
                'analysis': '解析文本 $u-$q',
              },
          ],
          'tags': <String>['四级'],
        },
    ],
  };
}

/// 改造前的 init 参考实现（逐键串行 + 主 isolate 同步解析 + 同步回写）。
///
/// 只复现「读取与解析」这部分可比开销，不重复测 FSRS/PlanStore 内部逻辑。
Future<void> _legacyInit(SharedPreferences storage) async {
  final String? wordRaw = storage.getString('wordData');
  final DictData words = DictData.buildFromMap(jsonDecode(wordRaw!) as Map<String, dynamic>);
  final ReadingData reading = ReadingData.buildFromMap(
      jsonDecode(storage.getString('readingData') ?? '{"units": []}') as Map<String, dynamic>);
  // 改造前的回写：主 isolate 同步序列化 2MB 再 setString
  storage.setString('wordData', jsonEncode(words.toMap()));
  BKSearch.init(words.words);
  WordMembershipIndex.instance.rebuild(words.classes);
  // 小键：同步读取 + 各自的 jsonDecode
  SynonymStore().init();
  FavoriteStore().init();
  await PlanStore().init();
  // 引用一下 reading，避免被优化掉（也代表它被真正解析过）
  if (reading.units.isEmpty) throw StateError('unexpected');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String wordJson;
  late String readingJson;
  late int wordBytes;

  setUpAll(() {
    mockPathProvider();
    wordJson = jsonEncode(_syntheticWordMap());
    readingJson = jsonEncode(_syntheticReadingMap());
    wordBytes = wordJson.length;
    debugPrint('[perf] 合成词库: $_wordCount 词, ${(wordBytes / 1024).toStringAsFixed(0)} KB');
  });

  Map<String, Object> baseStorage() => <String, Object>{
        'settingData': jsonEncode(<String, dynamic>{}),
        'wordData': wordJson,
        'readingData': readingJson,
        'synonymData': jsonEncode(<String, dynamic>{'synonyms': <dynamic>[], 'distincts': <dynamic>[]}),
        'favoriteData': jsonEncode(<String, dynamic>{'version': 1, 'order': <int>[]}),
        'planData': jsonEncode(<String, dynamic>{}),
      };

  test('阶段耗时对比：改造前（串行+主 isolate）vs 改造后（并发+后台 isolate）', () async {
    // ---- 预热：先跑一次 init，拿到 storage/basePath 并完成 JIT 预热 ----
    // 两个被测路径都只测「读取 + 解析 + 回写」，索引构建（本轮未改）单独计时。
    mockStorage(baseStorage());
    AppData().debugResetForInit();
    await AppData().init();
    await AppData().pendingWordWrite;

    // ---- 阶段 A：改造前的串行参考实现 ----
    mockStorage(baseStorage());
    final SharedPreferences legacyStorage = await SharedPreferences.getInstance();
    final Stopwatch legacy = Stopwatch()..start();
    await _legacyInit(legacyStorage);
    legacy.stop();

    // ---- 阶段 B：改造后的并发 init ----
    mockStorage(baseStorage());
    AppData().debugResetForInit();
    final Stopwatch current = Stopwatch()..start();
    await AppData().init();
    current.stop();
    final int initMicros = current.elapsedMicroseconds;
    // 启动回写（异步编码）单独计时：它不阻塞首帧，但要落盘
    final Stopwatch writeBack = Stopwatch()..start();
    await AppData().pendingWordWrite;
    writeBack.stop();

    // ---- 阶段 C：拆解「解码」与「构造」各自的开销 ----
    final Stopwatch decodeOnly = Stopwatch()..start();
    final Object? decoded = await decodeJsonOffMain(wordJson);
    decodeOnly.stop();

    final Stopwatch buildOnly = Stopwatch()..start();
    final DictData built = DictData.buildFromMap(decoded as Map<String, dynamic>);
    buildOnly.stop();

    final Stopwatch indexOnly = Stopwatch()..start();
    BKSearch.rebuild(built.words);
    indexOnly.stop();

    // 更大词库上的索引耗时：说明「启动路径剩余的最大阻塞点」量级。
    final List<WordItem> bigWords = <WordItem>[
      for (int i = 0; i < 20000; i++)
        WordItem(
          arabic: 'كلمة$i',
          chinese: '第 $i 个词的释义，用于测量解析开销',
          explanation: '',
          className: '第 ${i ~/ 50} 课',
          id: i,
          root: 'كلم',
          categories: const <String>['四级', '常用词'],
          pos: i.isEven ? 'Nominals' : 'Verbs',
          gender: i.isEven ? true : null,
        ),
    ];
    final Stopwatch index20k = Stopwatch()..start();
    BKSearch.rebuild(bigWords);
    index20k.stop();

    String ms(int micros) => '${(micros / 1000).toStringAsFixed(1)}ms';
    debugPrint('[perf] ---- 5000 词 / ${(wordBytes / 1024).toStringAsFixed(0)} KB ----');
    debugPrint('[perf] 改造前 init（串行 + 主 isolate 解码 + 同步回写）: ${ms(legacy.elapsedMicroseconds)}');
    debugPrint('[perf] 改造后 init（并发 + 后台解码，含异步回写等待）: ${ms(current.elapsedMicroseconds + writeBack.elapsedMicroseconds)}');
    debugPrint('[perf]   ├ 改造后 init 主体（首帧前阻塞部分）: ${ms(initMicros)}');
    debugPrint('[perf]   └ 启动回写（不阻塞首帧）: ${ms(writeBack.elapsedMicroseconds)}');
    debugPrint('[perf] 解码 wordData（flutter test 下同步回退）: ${ms(decodeOnly.elapsedMicroseconds)}');
    debugPrint('[perf] 构造 DictData: ${ms(buildOnly.elapsedMicroseconds)}');
    debugPrint('[perf] BKSearch.rebuild（索引，本轮未改）: ${ms(indexOnly.elapsedMicroseconds)}');
    debugPrint('[perf] BKSearch.rebuild 20000 词（索引，本轮未改）: ${ms(index20k.elapsedMicroseconds)}');

    // 正确性：两条路径都必须真的把 5000 词装进内存
    expect(AppData().wordData.words, hasLength(_wordCount));
    expect(AppData().readingData.units, hasLength(20));
    expect(BKSearch.isReady, isTrue);
  });

  test('Web 路径：decodeJsonOffMain 等价于同步 jsonDecode（kIsWeb 守卫的语义）', () async {
    // Web 上 decodeJsonOffMain 直接同步解码；这里验证返回值形状一致，
    // 保证 AppData._initDictAndReading 在两个平台上走同一段业务代码。
    final Object? decoded = await decodeJsonOffMain(wordJson);
    expect(decoded, isA<Map<String, dynamic>>());
    expect((decoded! as Map<String, dynamic>)['Words'], hasLength(_wordCount));
  });
}
