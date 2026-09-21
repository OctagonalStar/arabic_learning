// 纯 Dart 扩展方法（原 lib/funcs/utili.dart 拆分）。
// 包含阿语文本判断、中文释义相似度、数字补零、列表去重等无副作用工具。

import 'dart:math';

import 'package:flutter/material.dart';

extension StringExtensions on String {
  bool isArabic() {
    final arabicRegExp = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return arabicRegExp.hasMatch(this);
  }

  /// 文本方向：包含阿拉伯语字符时为 RTL，否则为 LTR
  TextDirection get textDirection => isArabic() ? TextDirection.rtl : TextDirection.ltr;
  String removeAracicExtensionPart(){
    String res = this;
    res = res.replaceAll(RegExp(r'[\u064B-\u065F\u0640\u0670\u06D6-\u06ED]'), ""); 
    res = res.replaceAll(RegExp(r'\(.*\)'), ""); // for "قَلَمٌ (ج: أَقْلَامٌ)"
    res = res.replaceAll(RegExp(r'\ [ج\-/م][^]*$'), ""); // for "ميلادي م ميلاد" "جَدِيدٌ / جَدِيدَةٌ"
    res = res.replaceAll(RegExp(r'[،.][^]*$'), ""); // for "متواصل، متواصل"
    return res;
  }

  /// 简单的中文释义交叉计算（字符 Jaccard 相似度）
  bool hasSimilarMeaning(String other) {
    // 1. 去除中文/英文常见标点符号和空格
    String cleanString(String s) {
      return s.replaceAll(RegExp(r'[ \(\)\.,/，。、；（）\[\]【】]'), '');
    }
    
    String c1 = cleanString(this);
    String c2 = cleanString(other);

    if (c1.isEmpty || c2.isEmpty) return false;
    
    // 如果一个释义完全包含了另一个，直接判定为相似（如：苹果 和 苹果，香蕉）
    if(c1.contains(c2) || c2.contains(c1)) return true;

    // 2. 将字串拆分为单字集合
    Set<String> set1 = c1.split('').toSet();
    Set<String> set2 = c2.split('').toSet();

    // 3. 计算共有字符
    int intersection = set1.intersection(set2).length;
    // int union = set1.union(set2).length;
    
    // 如果短词里包含任何相同的核心字，或共有汉字超过短词的 40% (应对同义替换)
    int minLength = min(set1.length, set2.length);
    
    // 如果它们很短，只要共享一个字就算（例如：走 / 行走）
    if(minLength <= 2 && intersection >= 1) return true;
    
    double similarity = intersection / minLength;
    return similarity >= 0.4;
  }
}

extension ZFillExtension on num {
  String zfill(int width) => _zfillImpl(this, width);
}

String _zfillImpl(num value, int width) {
  if (width <= 0) return value.toString();

  String raw = value.toString();
  bool isNegative = raw.startsWith('-');
  if (isNegative) raw = raw.substring(1);

  int padding = width - raw.length - (isNegative ? 1 : 0);
  if (padding <= 0) return isNegative ? '-$raw' : raw;

  String zeros = '0' * padding;
  return isNegative ? '-$zeros$raw' : '$zeros$raw';
}

extension RemoveDuplicatesExtension<T> on List<T> {
  void removeDuplicates() {
    final Set<T> seen = {};
    final List<T> uniqueItems = [];
    
    for (final item in this) {
      if (!seen.contains(item)) {
        seen.add(item);
        uniqueItems.add(item);
      }
    }
    
    clear();
    addAll(uniqueItems);
  }
}
