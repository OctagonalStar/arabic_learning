import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/config_structure.dart';
import 'package:arabic_learning/vars/global.dart';
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
    List<String> possible(int length) => <String>[
          'x',
          'a' * length,
          'b' * length,
          'c' * length,
        ];

    test('宽屏 + 全部短文本 -> 0', () {
      AppData().isWideScreen = true;
      expect(calculateButtonBoxLayout(possible(2), 400), 0);
    });

    test('宽屏 + 存在长文本 -> 1', () {
      AppData().isWideScreen = true;
      expect(calculateButtonBoxLayout(possible(10), 400), 1);
    });

    test('窄屏 + 全部短文本 -> 1', () {
      AppData().isWideScreen = false;
      expect(calculateButtonBoxLayout(possible(2), 400), 1);
    });

    test('窄屏 + 存在长文本 -> 2', () {
      AppData().isWideScreen = false;
      expect(calculateButtonBoxLayout(possible(30), 400), 2);
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
}
