// 纯 Dart 扩展方法（原 lib/funcs/utili.dart 拆分）。
// 包含阿语文本判断、中文释义相似度、数字补零、列表去重等无副作用工具。

import 'package:arabic_learning/theme/tokens.dart' show AppSemanticColors;
import 'package:flutter/material.dart';

/// 语义色（成功 / 警告 / 错误 / 禁用）便捷访问。
///
/// 主题由 `buildTheme` 挂载 [AppSemanticColors]；此处额外提供按当前
/// `ColorScheme` 现算的回退，保证未挂载自定义主题的局部测试 / 预览也能取值。
extension SemanticColorsContext on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ??
      AppSemanticColors.of(Theme.of(this).colorScheme);
}

// 预编译正则：下列方法处于检索索引构建、去重与收藏匹配的热路径上，
// 单次调用可达数万次；若每次调用都新建 RegExp，仅编译开销就会成为瓶颈，
// 故统一提为文件级常量复用（语义与内联 `RegExp(...)` 完全一致）。
final RegExp _arabicCharRegExp =
    RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
final RegExp _arabicDiacriticsRegExp =
    RegExp(r'[\u064B-\u065F\u0640\u0670\u06D6-\u06ED]');
final RegExp _parentheticalRegExp = RegExp(r'[（(][^）)]*[）)]');
final RegExp _slashTailRegExp = RegExp(r'[/／][^]*$');
final RegExp _standaloneMarkerTailRegExp = RegExp(r'\s[جم](?=\s|$)[^]*$');
final RegExp _hyphenTailRegExp = RegExp(r'\s-[^]*$');
final RegExp _arabicCommaTailRegExp = RegExp(r'[،.][^]*$');
final RegExp _meaningPunctuationRegExp = RegExp(r'[ \(\)\.,/，。、；（）\[\]【】]');

/// [StringExtensions.identityKey] 的容量上限。
const int _identityKeyCacheLimit = 4096;

/// [StringExtensions.identityKey] 的最近结果缓存。
///
/// 身份键在 FSRS 去重、收藏反查、计划去重里会对**同一批**词条反复求值，
/// 缓存可跳过重复的 7 次正则替换。超过上限时整体清空（简单实现即可保证
/// 内存不会无限增长），命中与否都不改变返回值语义。
final Map<String, String> _identityKeyCache = <String, String>{};

extension StringExtensions on String {
  bool isArabic() => _arabicCharRegExp.hasMatch(this);

  /// 文本方向：包含阿拉伯语字符时为 RTL，否则为 LTR
  TextDirection get textDirection => isArabic() ? TextDirection.rtl : TextDirection.ltr;
  /// 去掉单词的扩展部分，得到用于 BK 树索引 / 检索的“干净”词形。
  ///
  /// 依次移除：发音符号（harakat/tashkeel）、括号内内容（半角 `()` 与全角
  /// `（）`）、斜杠及其后内容（半角 `/` 与全角 `／`，不要求斜杠前有空格）、
  /// **独立**的 `ج` / `-` / `م` 标记及其后内容、阿拉伯语逗号 / 句点及其后内容。
  ///
  /// 注意：`ج` / `م` 只有在作为独立标记（其后为空白或结尾）时才会截断，
  /// 避免把 `كُتُبٌ مَدْرَسِيَّةٌ` 这类「第二词以 م 开头」的短语误截成首个词。
  String removeAracicExtensionPart(){
    String res = this;
    res = res.replaceAll(_arabicDiacriticsRegExp, ""); 
    res = res.replaceAll(_parentheticalRegExp, ""); // for "قَلَمٌ (ج: أَقْلَامٌ)" / "（…）"
    res = res.replaceAll(_slashTailRegExp, ""); // for "جَدِيدٌ/جَدِيدَةٌ"（不要求空格）
    res = res.replaceAll(_standaloneMarkerTailRegExp, ""); // 仅独立标记: "ميلادي م ميلاد"
    res = res.replaceAll(_hyphenTailRegExp, ""); // 独立连字符标记
    res = res.replaceAll(_arabicCommaTailRegExp, ""); // for "متواصل، متواصل"
    return res;
  }

  /// 用于「去重 / 合并」的保守身份键。
  ///
  /// 只做**词形级**清理（发音符号、括号内容、斜杠/逗号变体、独立标记），并保留
  /// 多词短语的完整词形；**不做**检索层的阿列夫 / `ة` 折叠（那属于更激进的检索
  /// 归一化，在 `ArabicStemmer.normalize` 中完成）。与 [removeAracicExtensionPart]
  /// 职责分离：检索侧的归一化调整不会改变这里的去重语义。
  ///
  /// 实现细节：正则已预编译；结果按原始字符串缓存在 [_identityKeyCache] 中，
  /// 因为该键在搜索、FSRS 去重与收藏反查循环里会对同一批词条反复求值。
  /// 返回值与逐个正则内联替换逐字一致（跨存储的稳定键，不可改变语义）。
  String identityKey(){
    final String? cached = _identityKeyCache[this];
    if(cached != null) return cached;
    String res = this;
    res = res.replaceAll(_arabicDiacriticsRegExp, "");
    res = res.replaceAll(_parentheticalRegExp, "");
    res = res.replaceAll(_slashTailRegExp, "");
    res = res.replaceAll(_standaloneMarkerTailRegExp, "");
    res = res.replaceAll(_hyphenTailRegExp, "");
    res = res.replaceAll(_arabicCommaTailRegExp, "");
    res = res.trim();
    // 只缓存短词形（真实词条），避免异常长的输入把内存顶满
    if(length <= 128) {
      if(_identityKeyCache.length >= _identityKeyCacheLimit) {
        _identityKeyCache.clear();
      }
      _identityKeyCache[this] = res;
    }
    return res;
  }

  /// 中文释义是否可判定为「同一含义」。
  ///
  /// 严格判定：去除标点/空格后必须**完全相等**或**互为子串**。
  /// 不再使用「短释义共用一个字」或「字符占比 ≥40%」的宽松规则，避免
  /// `写, 书写` 与 `教科书`（仅共用「书」）、`质子` 与 `中子`（仅共用「子」）
  /// 等不同含义被误合并。
  bool hasSimilarMeaning(String other) {
    String clean(String s) => s.replaceAll(_meaningPunctuationRegExp, '');
    final String c1 = clean(this);
    final String c2 = clean(other);
    if (c1.isEmpty || c2.isEmpty) return false;
    return c1 == c2 || c1.contains(c2) || c2.contains(c1);
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
