// 中文释义同义/不同对的数据模型（持久化用）。
// GlossPair 表示一对规范化后的中文释义，SynonymData 为全部标记的集合。

import 'package:flutter/foundation.dart';

/// 规范化中文释义：去除标点与空格，用于同义对匹配。
/// 必须与 core/extensions.dart 的 hasSimilarMeaning 内部 cleanString 的字符集一致：
/// 正则 RegExp(r'[ \(\)\.,/，。、；（）\[\]【】]')，再 trim。
String normalizeGloss(String raw) {
  return raw.replaceAll(RegExp(r'[ \(\)\.,/，。、；（）\[\]【】]'), '').trim();
}

/// 一对规范化后的中文释义。
///
/// 始终保证 [a] 的字典序不大于 [b]（`a.compareTo(b) <= 0`），
/// 因此同一对释义无论输入顺序如何都只对应一个 [GlossPair]。
@immutable
class GlossPair {
  /// 规范化释义，字典序较小者。
  final String a;

  /// 规范化释义，字典序较大者。
  final String b;

  const GlossPair(this.a, this.b);

  /// 规范化 x/y，任一为空或规范化后相等则返回 null；否则按字典序构造。
  static GlossPair? create(String x, String y) {
    final String na = normalizeGloss(x);
    final String nb = normalizeGloss(y);
    if (na.isEmpty || nb.isEmpty || na == nb) return null;
    return na.compareTo(nb) <= 0 ? GlossPair(na, nb) : GlossPair(nb, na);
  }

  /// 是否为有效释义对（两个字段非空且不相等）。
  bool get isValid => a.isNotEmpty && b.isNotEmpty && a != b;

  /// 集合/映射使用的唯一键：`"$a\u0000$b"`。
  String get key => "$a\u0000$b";

  /// 管理页展示文本：`"$a / $b"`。
  String get display => "$a / $b";

  Map<String, dynamic> toMap() {
    return {"a": a, "b": b};
  }

  /// 从映射构建；字段缺失/类型不符/规范化后无效时返回 null。
  static GlossPair? fromMap(Map<String, dynamic> map) {
    final dynamic rawA = map["a"];
    final dynamic rawB = map["b"];
    if (rawA is! String || rawB is! String) return null;
    return create(rawA, rawB);
  }

  @override
  bool operator ==(Object other) {
    return other is GlossPair && other.a == a && other.b == b;
  }

  @override
  int get hashCode => Object.hash(a, b);

  @override
  String toString() => display;
}

/// 全部用户标记的同义对与不同对。
///
/// [distincts] 为负向记忆（用户确认“不同义”，永不再提示）。
@immutable
class SynonymData {
  /// 用户标记为同义的释义对。
  final Set<GlossPair> synonyms;

  /// 用户标记为不同的释义对（负向记忆，永不再提示）。
  final Set<GlossPair> distincts;

  const SynonymData({Set<GlossPair>? synonyms, Set<GlossPair>? distincts})
      : synonyms = synonyms ?? const <GlossPair>{},
        distincts = distincts ?? const <GlossPair>{};

  Map<String, dynamic> toMap() {
    return {
      "version": 1,
      "synonyms": synonyms
          .map((GlossPair pair) => pair.toMap())
          .toList(growable: false),
      "distincts": distincts
          .map((GlossPair pair) => pair.toMap())
          .toList(growable: false),
    };
  }

  /// 从映射构建，容错：缺字段/null/类型不符 → 空集合。
  static SynonymData buildFromMap(Map<String, dynamic> map) {
    Set<GlossPair> parse(dynamic raw) {
      final Set<GlossPair> result = {};
      if (raw is List) {
        for (final dynamic item in raw) {
          if (item is Map) {
            final GlossPair? pair =
                GlossPair.fromMap(Map<String, dynamic>.from(item));
            if (pair != null) result.add(pair);
          }
        }
      }
      return result;
    }

    return SynonymData(
      synonyms: parse(map["synonyms"]),
      distincts: parse(map["distincts"]),
    );
  }
}
