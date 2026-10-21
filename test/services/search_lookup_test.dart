// 词汇检索（BKSearch.lookup）与 identityKey 的语义锁定测试。
//
// 背景：检索热路径从「全表扫描 + 比较器内重复算编辑距离」改为
// 「倒排候选 + 预计算分数排序」；identityKey 从「每次新建 7 个 RegExp」
// 改为「预编译正则 + 小容量缓存」。
//
// 这些改动都**不允许**改变结果语义（identityKey 是跨存储的稳定键，检索顺序
// 是用户可见行为），故此处用「参考实现」（即改造前的原始算法，逐字照抄）
// 对随机语料做逐项比对，锁定：命中集合 + 完整排序顺序。

import 'dart:math';

import 'package:arabic_learning/core/extensions.dart' show StringExtensions;
import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/services/search.dart';
import 'package:flutter_test/flutter_test.dart';

/// 中文测试字符池（均为 CJK，确保不会被 isArabic 误判）。
const List<String> _zhPool = <String>[
  '翻', '译', '书', '写', '笔', '学', '生', '习', '语', '言', '文', '字',
];

/// 生成确定性的合成词库：中文词条足够密集以产生大量并列项。
List<WordItem> _buildFixture(int seed, int count) {
  final Random random = Random(seed);
  final List<WordItem> words = <WordItem>[];
  for (int i = 0; i < count; i++) {
    final int length = 1 + random.nextInt(6);
    final StringBuffer buffer = StringBuffer();
    for (int j = 0; j < length; j++) {
      if (j > 0 && random.nextInt(6) == 0) buffer.write('，');
      buffer.write(_zhPool[random.nextInt(_zhPool.length)]);
    }
    words.add(WordItem(
      arabic: 'w$i',
      chinese: buffer.toString(),
      explanation: '',
      className: 'c',
      id: words.length,
    ));
  }
  // 固定追加几条便于断言的词条（含空释义与超长释义边界）
  const List<List<String>> extras = <List<String>>[
    <String>['ك ت ب', 'كتاب', '书'],
    <String>['ق ل م', 'قلم', '笔'],
    <String>['ج د د', 'جديد', '新的'],
    <String>['ك ت ب', 'كاتب', '作家'],
    <String>['', 'مكتبة', '图书馆，书店'],
    <String>['', 'empty', ''],
    <String>['', 'long', '书书书书书书书书书书书书书书书书书书书书书书书书书'],
  ];
  for (final List<String> extra in extras) {
    words.add(WordItem(
      arabic: extra[1],
      chinese: extra[2],
      explanation: '',
      className: 'c',
      id: words.length,
      root: extra[0],
    ));
  }
  return words;
}

/// 改造前的中文检索算法（逐字照抄），作为参考实现。
///
/// 唯一差异是只返回 id 而非 [WordItem]，排序比较器完全保留原始形态。
List<int> _referenceChineseLookup(List<WordItem> words, String query) {
  final List<String> zh = <String>[for (final WordItem w in words) w.chinese];
  // 分段倒排（原始构建逻辑）
  final Map<String, List<int>> zhTokenExact = <String, List<int>>{};
  for (int i = 0; i < zh.length; i++) {
    for (final String rawToken in zh[i].split(RegExp(r'[，；,;、]'))) {
      final String token = rawToken.trim();
      if (token.isEmpty) continue;
      (zhTokenExact[token] ??= <int>[]).add(i);
    }
  }

  final List<int> result = <int>[];
  final Set<int> added = <int>{};
  for (int i = 0; i < zh.length; i++) {
    final String c = zh[i];
    if (c.contains(query)) {
      if (added.add(i)) result.add(i);
      continue;
    }
    if (query.length >= 3 && getLevenshtein(query, c) < 4) {
      if (query.split('').any((String ch) => c.contains(ch)) &&
          added.add(i)) {
        result.add(i);
      }
    }
  }
  final Set<int> exactTokenIds = <int>{};
  final List<int>? tokenHits = zhTokenExact[query];
  if (tokenHits != null) exactTokenIds.addAll(tokenHits);
  result.sort((int a, int b) {
    final bool eqA = zh[a] == query;
    final bool eqB = zh[b] == query;
    if (eqA != eqB) return eqA ? -1 : 1;
    final bool tokA = exactTokenIds.contains(a);
    final bool tokB = exactTokenIds.contains(b);
    if (tokA != tokB) return tokA ? -1 : 1;
    final bool containA = zh[a].contains(query);
    final bool containB = zh[b].contains(query);
    if (containA != containB) return containA ? -1 : 1;
    return getLevenshtein(query, zh[a]).compareTo(getLevenshtein(query, zh[b]));
  });
  return result;
}

/// 改造前的 identityKey 实现（每次调用都新建 RegExp），作为参考实现。
String _referenceIdentityKey(String input) {
  String res = input;
  res = res.replaceAll(RegExp(r'[\u064B-\u065F\u0640\u0670\u06D6-\u06ED]'), "");
  res = res.replaceAll(RegExp(r'[（(][^）)]*[）)]'), "");
  res = res.replaceAll(RegExp(r'[/／][^]*$'), "");
  res = res.replaceAll(RegExp(r'\s[جم](?=\s|$)[^]*$'), "");
  res = res.replaceAll(RegExp(r'\s-[^]*$'), "");
  res = res.replaceAll(RegExp(r'[،.][^]*$'), "");
  return res.trim();
}

List<int> _ids(List<WordItem> words) => <int>[for (final WordItem w in words) w.id];

void main() {
  group('identityKey 语义与改造前逐字一致', () {
    const List<String> corpus = <String>[
      'كُتُبٌ مَدْرَسِيَّةٌ',
      'قلم (ج: أقلام)',
      'قلم（ج: أقلام）',
      '  قَلَمٌ   ',
      'جديد / جديدة',
      'جديد/جديدة',
      'جَدِيدٌ／جَدِيدَةٌ',
      'كَتَبَ، يَكْتُبُ، كِتَابَةً',
      'متواصل، متواصل',
      'متواصل. متواصل',
      'ميلادي م ميلاد',
      'ميلادي ج ميلاد',
      'كُتُبٌ مَدْرَسِيَّةٌ - ملاحظة',
      '',
      ' ',
      'كتاب',
      'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
      'مَكْتَبٌ (ج: مَكَاتِبُ) / مَكْتَبَةٌ',
    ];

    test('固定语料逐字一致', () {
      for (final String input in corpus) {
        expect(
          input.identityKey(),
          _referenceIdentityKey(input),
          reason: 'identityKey 语义变化：$input',
        );
      }
    });

    test('超长输入（不进入缓存）语义仍一致', () {
      // 超过 identityKey 的缓存长度上限：走直算路径，结果必须一致
      final String long = 'قَلَمٌ (ج: أَقْلَامٌ) ' * 20;
      expect(long.identityKey(), _referenceIdentityKey(long));
      expect(long.identityKey(), long.identityKey());
    });

    test('随机语料逐字一致（含阿拉伯语符号 / 标点 / 括号混合）', () {
      final Random random = Random(77);
      const List<String> pieces = <String>[
        'ك', 'ت', 'ب', 'م', 'ج', 'ة', 'ا', 'ي', ' ', '  ',
        '\u064B', '\u0650', '\u0670', '\u06D6',
        '(', ')', '（', '）', '/', '／', '،', '.', '-', 'قلم', 'ج:',
      ];
      for (int i = 0; i < 500; i++) {
        final int length = random.nextInt(14);
        final StringBuffer buffer = StringBuffer();
        for (int j = 0; j < length; j++) {
          buffer.write(pieces[random.nextInt(pieces.length)]);
        }
        final String input = buffer.toString();
        expect(
          input.identityKey(),
          _referenceIdentityKey(input),
          reason: 'identityKey 语义变化：${input.codeUnits}',
        );
      }
    });

    test('重复调用命中缓存后结果不变', () {
      const String input = 'مَكْتَبٌ (ج: مَكَاتِبُ)';
      final String first = input.identityKey();
      for (int i = 0; i < 5; i++) {
        expect(input.identityKey(), first);
      }
    });
  });

  group('中文检索结果与改造前逐项一致', () {
    for (final int count in <int>[0, 1, 40, 600]) {
      test('词库大小 $count', () {
        final List<WordItem> words = _buildFixture(20251021 + count, count);
        BKSearch.rebuild(words);
        final Random random = Random(count);
        final List<String> queries = <String>[
          // 单字 / 双字 / 三字 / 长串 / 不存在的串 / 全角逗号
          '书', '笔', '翻译', '学习', '语文', '书学生', '图书', '书店', '写',
          '书，', '，', '不存在', '书书书书书书书书书书书书书书书书书书书书书书书书书',
        ];
        for (int i = 0; i < 40; i++) {
          final int length = 1 + random.nextInt(5);
          final StringBuffer buffer = StringBuffer();
          for (int j = 0; j < length; j++) {
            buffer.write(_zhPool[random.nextInt(_zhPool.length)]);
          }
          queries.add(buffer.toString());
        }
        for (final String query in queries) {
          expect(
            _ids(BKSearch.lookup(query)),
            _referenceChineseLookup(words, query),
            reason: '检索结果变化：query="$query"',
          );
        }
      });
    }
  });

  group('中文检索排序优先级', () {
    setUp(() {
      BKSearch.rebuild(<WordItem>[
        WordItem(
          arabic: 'فوري',
          chinese: '即席翻译',
          explanation: '',
          className: 'c',
          id: 0,
        ),
        WordItem(
          arabic: 'ترجمة',
          chinese: '翻译，小传',
          explanation: '',
          className: 'c',
          id: 1,
        ),
        WordItem(
          arabic: 'نقل',
          chinese: '翻译',
          explanation: '',
          className: 'c',
          id: 2,
        ),
      ]);
    });

    test('整串相等 > 分段精确 > 子串包含', () {
      final List<int> ids = _ids(BKSearch.lookup('翻译'));
      expect(ids.first, 2);
      expect(ids.indexOf(1), lessThan(ids.indexOf(0)));
    });
  });

  group('阿语检索排序', () {
    test('精确词根家族优先，其余按编辑距离升序', () {
      BKSearch.rebuild(<WordItem>[
        const WordItem(
          arabic: 'كتاب',
          chinese: '书',
          explanation: '',
          className: 'c',
          id: 0,
          root: 'ك ت ب',
        ),
        const WordItem(
          arabic: 'كاتب',
          chinese: '作家',
          explanation: '',
          className: 'c',
          id: 1,
          root: 'ك ت ب',
        ),
        const WordItem(
          arabic: 'مكتوب',
          chinese: '写好的',
          explanation: '',
          className: 'c',
          id: 2,
          root: 'ك ت ب',
        ),
        const WordItem(
          arabic: 'علم',
          chinese: '知识',
          explanation: '',
          className: 'c',
          id: 3,
          root: 'ع ل م',
        ),
      ]);
      final List<int> ids = _ids(BKSearch.lookup('كتب'));
      // 前三个同根家族（含非子串命中的 كاتب），علم 不被加权进结果
      expect(ids.take(3).toSet(), <int>{0, 1, 2});
      expect(ids.contains(3), isFalse);
      // 同根家族内部：编辑距离升序（كتب 与 كتاب 距离更近）
      expect(ids.indexOf(0), lessThan(ids.indexOf(1)));
    });
  });
}
