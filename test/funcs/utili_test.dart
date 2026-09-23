import 'package:arabic_learning/core/adaptive.dart' show AdaptiveData;
import 'package:arabic_learning/core/extensions.dart' show StringExtensions;
import 'package:arabic_learning/services/words.dart';
import 'package:arabic_learning/services/search.dart';
import 'package:arabic_learning/models/config.dart';
import 'package:arabic_learning/models/dict.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getStrokeDays（以 2025/11/1 为基准的天数逻辑）', () {
    // getStrokeDays 内部按 DateTime(2025,11,1) 计算「今天」的序号，
    // 测试侧用同样口径计算，避免跨时区/跨日不稳定。
    final int today = DateTime.now().difference(DateTime(2025, 11, 1)).inDays;

    test('lastDate 为今天 -> 连胜含今天', () {
      expect(
        getStrokeDays(LearningConfig(startDate: today - 4, lastDate: today)),
        5,
      );
    });

    test('lastDate 为昨天 -> 仍延续连胜（边界不归零）', () {
      expect(
        getStrokeDays(LearningConfig(startDate: today - 4, lastDate: today - 1)),
        4,
      );
    });

    test('lastDate 早于昨天 -> 连胜清零', () {
      expect(
        getStrokeDays(LearningConfig(startDate: today - 4, lastDate: today - 2)),
        0,
      );
    });

    test('startDate == lastDate == 今天 -> 1 天', () {
      expect(
        getStrokeDays(LearningConfig(startDate: today, lastDate: today)),
        1,
      );
    });
  });

  group('calculateButtonBoxLayout 分支', () {
    // possible[1..3] 的长度决定是否换行；元素 0 不参与判断。
    // 宽屏阈值 = width * 0.21，窄屏阈值 = width * 0.8。
    List<String> possible(int length) => <String>[
          'x',
          'a' * length,
          'b' * length,
          'c' * length,
        ];

    test('宽屏 + 全部短文本 -> 0', () {
      expect(
        calculateButtonBoxLayout(
          possible(2),
          const AdaptiveData(width: 700, height: 500),
        ),
        0,
      );
    });

    test('宽屏 + 存在长文本 -> 1', () {
      expect(
        calculateButtonBoxLayout(
          possible(10),
          const AdaptiveData(width: 700, height: 500),
        ),
        1,
      );
    });

    test('窄屏 + 全部短文本 -> 1', () {
      expect(
        calculateButtonBoxLayout(
          possible(2),
          const AdaptiveData(width: 400, height: 800),
        ),
        1,
      );
    });

    test('窄屏 + 存在长文本 -> 2', () {
      expect(
        calculateButtonBoxLayout(
          possible(30),
          const AdaptiveData(width: 400, height: 800),
        ),
        2,
      );
    });
  });

  group('BKSearch（纯 Dart 检索索引）', () {
    setUpAll(() {
      BKSearch.rebuild(<WordItem>[
        const WordItem(
          arabic: 'كتاب',
          chinese: '书',
          explanation: '名词',
          className: '第一课',
          id: 0,
          root: 'ك ت ب',
          pos: 'Nominals',
        ),
        const WordItem(
          arabic: 'قلم',
          chinese: '笔',
          explanation: '名词',
          className: '第一课',
          id: 1,
          root: 'ق ل م',
          pos: 'Nominals',
        ),
      ]);
    });

    test('阿语查询命中且排序包含目标词', () {
      final List<WordItem> results = BKSearch.lookup('كتاب');
      expect(results.any((WordItem w) => w.id == 0), isTrue);
    });

    test('中文查询命中', () {
      final List<WordItem> results = BKSearch.lookup('笔');
      expect(results.any((WordItem w) => w.id == 1), isTrue);
    });

    test('空查询返回空列表', () {
      expect(BKSearch.lookup('   '), isEmpty);
    });

    test('初始化后 isReady 为真', () {
      expect(BKSearch.isReady, isTrue);
    });
  });

  group('removeAracicExtensionPart（BK 树键归一化）', () {
    String clean(String s) => s.removeAracicExtensionPart().trim();

    test('移除发音符号', () {
      expect(clean('قَلَمٌ'), 'قلم');
    });

    test('移除半角括号内容', () {
      expect(clean('قلم (ج: أقلام)'), 'قلم');
    });

    test('移除全角括号内容', () {
      expect(clean('قلم（ج: أقلام）'), 'قلم');
    });

    test('移除斜杠及其后内容（含空格）', () {
      expect(clean('جديد / جديدة'), 'جديد');
    });

    test('移除斜杠及其后内容（无空格）', () {
      expect(clean('جديد/جديدة'), 'جديد');
    });

    test('移除阿拉伯语逗号及其后内容', () {
      expect(clean('متواصل، متواصل'), 'متواصل');
    });

    test('组合：发音符号 + 括号 + 斜杠', () {
      expect(clean('مَكْتَبٌ (ج: مَكَاتِبُ) / مَكْتَبَةٌ'), 'مكتب');
    });
  });

  group('wordRoot（词根 BK 树键归一化）', () {
    test('词根中的发音符号 / 括号被移除', () {
      const WordItem w = WordItem(
        arabic: 'مكتب',
        chinese: '书桌',
        explanation: '',
        className: '第一课',
        id: 0,
        root: 'ك ت ب',
      );
      expect(wordRoot(w), 'كتب');
    });

    test('词根缺失时回退到词形提取', () {
      const WordItem w = WordItem(
        arabic: 'كتاب',
        chinese: '书',
        explanation: '',
        className: '第一课',
        id: 1,
      );
      expect(wordRoot(w), isNotEmpty);
    });
  });

  group('BKSearch 建索引时归一化词形', () {
    setUpAll(() {
      BKSearch.rebuild(<WordItem>[
        const WordItem(
          arabic: 'قَلَمٌ (ج: أَقْلَامٌ)',
          chinese: '笔',
          explanation: '名词',
          className: '第一课',
          id: 10,
          root: 'ق ل م',
          pos: 'Nominals',
        ),
        const WordItem(
          arabic: 'جَدِيدٌ/جَدِيدَةٌ',
          chinese: '新的',
          explanation: '形容词',
          className: '第一课',
          id: 11,
          root: 'ج د د',
          pos: 'Nominals',
        ),
      ]);
    });

    test('带括号 / 发音符号的词可用干净词形检索到', () {
      expect(
        BKSearch.lookup('قلم').any((WordItem w) => w.id == 10),
        isTrue,
      );
    });

    test('带斜杠的词可用斜杠前的词形检索到', () {
      expect(
        BKSearch.lookup('جديد').any((WordItem w) => w.id == 11),
        isTrue,
      );
    });
  });

  group('词根精确检索', () {
    setUpAll(() {
      BKSearch.rebuild(<WordItem>[
        const WordItem(
          arabic: 'كتاب',
          chinese: '书',
          explanation: '',
          className: '第一课',
          id: 0,
          root: 'ك ت ب',
        ),
        const WordItem(
          arabic: 'كاتب',
          chinese: '作家',
          explanation: '',
          className: '第一课',
          id: 1,
          root: 'ك ت ب',
        ),
        const WordItem(
          arabic: 'مكتوب',
          chinese: '写好的',
          explanation: '',
          className: '第一课',
          id: 2,
          root: 'ك ت ب',
        ),
        const WordItem(
          arabic: 'علم',
          chinese: '知识',
          explanation: '',
          className: '第二课',
          id: 3,
          root: 'ع ل م',
        ),
      ]);
    });

    test('lookup("كتب") 返回同根家族且包含非子串命中的派生词 كاتب', () {
      final Set<int> ids =
          BKSearch.lookup('كتب').map((WordItem w) => w.id).toSet();
      expect(ids.containsAll(<int>{0, 1, 2}), isTrue);
      // كاتب 与 "كتب" 无子串关系，只能靠精确词根加权召回
      expect(ids.contains(1), isTrue);
      expect('كاتب'.contains('كتب'), isFalse);
    });

    test('带空格词根查询与紧凑查询返回相同 id 集合', () {
      final Set<int> spaced =
          BKSearch.lookup('ك ت ب').map((WordItem w) => w.id).toSet();
      final Set<int> compact =
          BKSearch.lookup('كتب').map((WordItem w) => w.id).toSet();
      expect(spaced, compact);
    });

    test('normalizeRootKey 归一化空格后一致', () {
      expect(normalizeRootKey('ك ت ب'), normalizeRootKey('كتب'));
    });

    test('其他词根对照词未被加权进结果', () {
      final Set<int> ids =
          BKSearch.lookup('كتب').map((WordItem w) => w.id).toSet();
      expect(ids.contains(3), isFalse);
    });
  });
}
