import 'dart:convert';

import 'package:arabic_learning/models/recitation_text.dart';
import 'package:arabic_learning/services/recitation_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeArabic', () {
    test('去掉 harakat 与 tatweel', () {
      expect(normalizeArabic('مُحَمَّدٌ'), 'محمد');
      expect(normalizeArabic('مـــحمد'), 'محمد');
    });

    test('统一 hamza / ta marbuta / alef maqsura / waw & ya hamza', () {
      expect(normalizeArabic('أَحْمَد'), 'احمد');
      expect(normalizeArabic('إسلام'), 'اسلام');
      expect(normalizeArabic('آمن'), 'امن');
      expect(normalizeArabic('مدرسة'), 'مدرسه');
      expect(normalizeArabic('مصطفى'), 'مصطفي');
      expect(normalizeArabic('مؤمن'), 'مومن');
      expect(normalizeArabic('سائل'), 'سايل');
    });

    test('标点作为词边界，不把两个词粘在一起', () {
      expect(normalizeArabic('بسم، الله'), 'بسم الله');
      expect(normalizeArabic('قال: «لا»'), 'قال لا');
    });

    test('拉丁字母与数字被丢弃', () {
      expect(normalizeArabic('abc ١٢٣'), '');
    });
  });

  group('tokenize', () {
    test('按归一化后的词切分', () {
      expect(tokenize('بِسْمِ اللَّهِ الرَّحْمَٰنِ'), <String>[
        'بسم',
        'الله',
        'الرحمن',
      ]);
    });

    test('空文本得到空列表', () {
      expect(tokenize('  '), isEmpty);
    });
  });

  group('estimateSeconds', () {
    test('长元音与 shadda 增加权重', () {
      expect(estimateSeconds('باب'), greaterThan(estimateSeconds('ببب')));
      expect(estimateSeconds('بّب'), greaterThan(estimateSeconds('بب')));
    });

    test('空文本为 0', () {
      expect(estimateSeconds(''), 0);
    });
  });

  group('lookupStems', () {
    test('原形总在首位', () {
      expect(lookupStems('كتاب').first, 'كتاب');
    });

    test('剥离前附词', () {
      final List<String> forms = lookupStems('والكتاب');
      expect(forms, contains('كتاب'));
      expect(forms, contains('الكتاب'));
      expect(forms, contains('والكتاب'));
    });

    test('剥离后附词与前后组合', () {
      final List<String> forms = lookupStems('وبيتهم');
      expect(forms, contains('بيت'));
      expect(forms, contains('بيتهم'));
    });

    test('归一化后再剥离，且不产生过短词', () {
      final List<String> forms = lookupStems('مدرسةٌ');
      expect(forms.first, 'مدرسه');
      expect(forms, contains('مدرس'));
      expect(forms.every((String f) => f.length >= 2), isTrue);
    });

    test('空输入返回空列表', () {
      expect(lookupStems('  '), isEmpty);
      expect(lookupStems('،'), isEmpty);
    });
  });

  group('RecitationTextUnit 宽松解析', () {
    test('Markdown 围栏包着的 JSON 字符串', () {
      const String raw = '''```json
{"title":"درس","difficulty":120,"source":"课本","tags":"语法",
 "sentences":[{"arabic":"السلام عليكم","translation":"你好","note":"问候语",
 "words":[{"ar":"سلام","zh":"和平"}]}]}
```''';
      final RecitationTextUnit? unit = RecitationTextUnit.buildFromMap(raw);

      expect(unit, isNotNull);
      expect(unit!.title, 'درس');
      expect(unit.difficulty, 100); // 超出 0-100 被夹紧
      expect(unit.tags, <String>['语法']); // 单个字符串也接受
      final RecitationSentence sentence = unit.sentences.single;
      expect(sentence.arabic, 'السلام عليكم');
      expect(sentence.translation, '你好');
      expect(sentence.note, '问候语');
      expect(sentence.words.single.chinese, '和平');
    });

    test('缺 sentences 时用 passage 按行与句末标点切分', () {
      final RecitationTextUnit? unit = RecitationTextUnit.buildFromMap(
        <String, dynamic>{
          'passage': 'الجملة الأولى. الجملة الثانية؟\n\nالثالثة',
        },
      );

      expect(unit, isNotNull);
      expect(
        unit!.sentences.map((RecitationSentence s) => s.arabic).toList(),
        <String>['الجملة الأولى.', 'الجملة الثانية؟', 'الثالثة'],
      );
      expect(
        unit.sentences.every((RecitationSentence s) => s.translation.isEmpty),
        isTrue,
      );
      // 标题回退为参考文本前 20 字
      expect(unit.title, isNotEmpty);
      expect(unit.title.length, lessThanOrEqualTo(20));
      expect(unit.title.contains('\n'), isFalse);
    });

    test('字段别名（大小写不敏感）与纯字符串句子', () {
      final RecitationTextUnit? unit = RecitationTextUnit.buildFromMap(
        <String, dynamic>{
          'title': 't',
          'Lines': <dynamic>[
            <String, dynamic>{
              'Text': 'أنا طالب',
              'zh': '我是学生',
              '注释': '名词句',
              '词汇': <dynamic>[
                <String, dynamic>{'word': 'طالب', '释义': '学生'},
              ],
            },
            'هذا كتاب',
          ],
        },
      );

      expect(unit, isNotNull);
      expect(unit!.sentences.length, 2);
      final RecitationSentence first = unit.sentences.first;
      expect(first.translation, '我是学生');
      expect(first.note, '名词句');
      expect(first.words.single.arabic, 'طالب');
      expect(first.words.single.chinese, '学生');
      expect(unit.sentences.last.translation, '');
    });

    test('无法解析时返回 null，不抛异常', () {
      expect(RecitationTextUnit.buildFromMap('not json'), isNull);
      expect(RecitationTextUnit.buildFromMap('{"title":"x"}'), isNull);
      expect(RecitationTextUnit.buildFromMap(42), isNull);
      expect(RecitationTextUnit.buildFromMap(<String, dynamic>{}), isNull);
    });

    test('strict=false 跳过坏句子，strict=true 整条失败', () {
      final Map<String, dynamic> raw = <String, dynamic>{
        'sentences': <dynamic>[
          <String, dynamic>{'translation': '没有原文'},
          'نص',
        ],
      };

      expect(RecitationTextUnit.buildFromMap(raw), isNull);
      final RecitationTextUnit? lenient = RecitationTextUnit.buildFromMap(
        raw,
        strict: false,
      );
      expect(lenient, isNotNull);
      expect(lenient!.sentences.single.arabic, 'نص');
    });

    test('reference 逐句换行拼接，wordCount 忽略变音符号与标点', () {
      final RecitationTextUnit? unit = RecitationTextUnit.buildFromMap(
        <String, dynamic>{
          'title': 't',
          'sentences': <dynamic>['بِسْمِ اللَّهِ،', 'الرَّحْمَٰنِ'],
        },
      );

      expect(unit!.reference, 'بِسْمِ اللَّهِ،\nالرَّحْمَٰنِ');
      expect(unit.wordCount, 3);
    });

    test('getHash 稳定，标题变化时不同', () {
      RecitationTextUnit make(String title) => RecitationTextUnit(
        title: title,
        sentences: const <RecitationSentence>[
          RecitationSentence(arabic: 'كتاب', translation: '书'),
        ],
      );

      expect(make('a').getHash(), make('a').getHash());
      expect(make('a').getHash(), isNot(make('b').getHash()));
      expect(make('a').getHash(), hasLength(40));
    });
  });

  group('RecitationTextData', () {
    RecitationTextUnit sample() => RecitationTextUnit(
      title: 'درس',
      difficulty: 30,
      source: '课本',
      tags: const <String>['语法'],
      sentences: const <RecitationSentence>[
        RecitationSentence(
          arabic: 'أنا طالب',
          translation: '我是学生',
          note: '名词句',
          words: <RecitationWord>[
            RecitationWord(arabic: 'طالب', chinese: '学生'),
          ],
        ),
      ],
    );

    test('序列化往返', () {
      final RecitationTextData data = RecitationTextData(
        units: <RecitationTextUnit>[sample()],
      );
      final RecitationTextData back = RecitationTextData.buildFromMap(
        jsonDecode(jsonEncode(data.toMap())) as Map<String, dynamic>,
      );

      expect(back.units.length, 1);
      final RecitationTextUnit unit = back.units.single;
      expect(unit.title, 'درس');
      expect(unit.difficulty, 30);
      expect(unit.source, '课本');
      expect(unit.tags, <String>['语法']);
      expect(unit.sentences.single.note, '名词句');
      expect(unit.sentences.single.words.single.chinese, '学生');
      expect(unit.getHash(), data.units.single.getHash());
    });

    test('容错跳过坏数据', () {
      final RecitationTextData data = RecitationTextData.buildFromMap(
        <String, dynamic>{
          'units': <dynamic>[
            null,
            42,
            <String, dynamic>{'title': '无句子'},
            <String, dynamic>{
              'sentences': <dynamic>['نص'],
            },
          ],
        },
      );

      expect(data.units, hasLength(1));
      expect(data.units.single.reference, 'نص');
    });
  });
}
