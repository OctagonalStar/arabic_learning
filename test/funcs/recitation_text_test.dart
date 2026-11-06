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
      expect(
        tokenize('بِسْمِ اللَّهِ الرَّحْمَٰنِ'),
        <String>['بسم', 'الله', 'الرحمن'],
      );
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
}
