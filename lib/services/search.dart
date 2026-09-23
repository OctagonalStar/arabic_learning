// 词汇检索与词干分析服务（原 lib/funcs/utili.dart 拆分）。
// 包含 BK-Tree、阿拉伯语词干提取、易混词分级与 BKSearch 索引。

import 'dart:math';

import 'package:arabic_learning/core/extensions.dart' show StringExtensions;
import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:flutter/foundation.dart' show immutable;
import 'package:logging/logging.dart';

/// 内部极简 BK-Tree 节点。
class _BKNode {
  final String key;
  final Map<int, _BKNode> children = {};
  _BKNode(this.key);
}

/// 内部极简 BK-Tree 实现。
///
/// 替代第三方 `bk_tree` 包：该包在每次插入时以 INFO 级**无条件**打印
/// `constructTree`（不受其 `verbose` 控制），且初始化时会全局设置
/// `Logger.root.level = ALL` 并挂上 `print` 监听器；万级词库下会打印数万行
/// 日志并拖慢构建。这里仅实现所需的「构建 + 容差搜索」，无任何日志副作用。
class _SimpleBKTree {
  final int Function(String, String) _distance;
  final List<_BKNode> _nodes = [];

  _SimpleBKTree(Iterable<String> keys, this._distance) {
    // 打乱插入顺序可显著平衡 BK-Tree（搜索结果为精确集合，与树形无关）
    final List<String> ordered = keys.toList()..shuffle(Random(0));
    for(final String key in ordered) {
      _add(key);
    }
  }

  void _add(String key) {
    final _BKNode node = _BKNode(key);
    _nodes.add(node);
    if(_nodes.length == 1) return;
    _BKNode current = _nodes.first;
    while(true) {
      final int d = _distance(current.key, key);
      final _BKNode? child = current.children[d];
      if(child == null) {
        current.children[d] = node;
        return;
      }
      current = child;
    }
  }

  /// 返回与 [query] 编辑距离不超过 [tolerance] 的所有已存 key
  List<String> search(String query, int tolerance) {
    if(_nodes.isEmpty) return const <String>[];
    final List<String> out = <String>[];
    final List<_BKNode> stack = <_BKNode>[_nodes.first];
    while(stack.isNotEmpty) {
      final _BKNode node = stack.removeLast();
      final int d = _distance(node.key, query);
      if(d <= tolerance) out.add(node.key);
      final int lo = d - tolerance < 0 ? 0 : d - tolerance;
      final int hi = d + tolerance;
      for(int i = lo; i <= hi; i++) {
        final _BKNode? child = node.children[i];
        if(child != null) stack.add(child);
      }
    }
    return out;
  }
}

/// 简单的词性枚举，用于区分词汇类别
enum ArabicPOS {
  verb,   // 动词
  noun,   // 名词（包括形容词、分词、动名词）
  unknown // 无法判断（如太短或未匹配到模式）
}

class AnalysisResult {
  /// 提取出的三字母词根。
  final String root;
  /// 匹配到的构词法模式名称。
  final String patternName;
  /// 词性标记
  final ArabicPOS pos;

  AnalysisResult(this.root, this.patternName, this.pos);
}

/// 内部辅助类，用于定义一个构词法模式。
class _RootPattern {
  /// 模式的名称，如 "Form X (Past)"。
  final String name; 
  /// 用于匹配的正则表达式。
  final RegExp regex;
  /// 捕获组索引，定义了词根字母 (R1, R2, R3) 在正则匹配中的位置。
  final List<int> groups; 
  /// 该模式对应的词性
  final ArabicPOS pos;

  // ignore: unused_element_parameter
  _RootPattern(this.name, String pattern, this.pos, {this.groups = const [1, 2, 3]})
      : regex = RegExp(pattern);
}

/// 一个基于构词法模式的阿拉伯语词根提取器 (Stemmer)。
///
/// 该类通过一个预定义的模式库来识别单词的构词形式，并从中提取出标准的三字母词根。
/// 这对于判断不同派生词之间的相似性至关重要。
class ArabicStemmer {
  // 2. 定义模式库 (优先级：长/特异性 -> 短/通用性)
  static final List<_RootPattern> _patterns = [
    // --- Form X (استفعل) ---
    _RootPattern("Form X (Past)", r'^است(.)(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form X (Present)", r'^يست(.)(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form X (Participle)", r'^مست(.)(.)(.)$', ArabicPOS.noun),
    
    // --- [新增] Instrumental (Mif'aal - مفعال) ---
    // e.g., Miftah (مفتاح) -> F-T-H
    // 正则：Meem + R1 + R2 + Alef + R3
    _RootPattern("Instrumental (Mif'aal)", r'^م(.)(.)ا(.)$', ArabicPOS.noun),

    // --- Form I Passive (مفعول) ---
    // e.g., Maktub (مكتوب)
    // 正则：Meem + R1 + R2 + Waw + R3
    _RootPattern("Form I (Passive)", r'^م(.)(.)و(.)$', ArabicPOS.noun), 

    // --- Form VII (انفعل) ---
    _RootPattern("Form VII (Past)", r'^ان(.)(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form VII (Present)", r'^ين(.)(.)(.)$', ArabicPOS.verb),
    _RootPattern("Form VII (Participle)", r'^من(.)(.)(.)$', ArabicPOS.noun), 

    // --- Form VIII (افتعل) ---
    _RootPattern("Form VIII (Past)", r'^ا(.)ت(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form VIII (Present)", r'^ي(.)ت(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form VIII (Participle)", r'^م(.)ت(.)(.)$', ArabicPOS.noun), 

    // --- Form VI (تفاعل) ---
    _RootPattern("Form VI (Past)", r'^ت(.)ا(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form VI (Present)", r'^يت(.)ا(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form VI (Participle)", r'^مت(.)ا(.)(.)$', ArabicPOS.noun), 

    // --- Form III (فاعل) ---
    _RootPattern("Form III/I-Active", r'^(.)ا(.)(.)$', ArabicPOS.noun), // 这里的 Active Participle 往往作名词用，但也可能是动词过去式，暂定名词
    _RootPattern("Form III (Present)", r'^ي(.)ا(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form III (Participle)", r'^م(.)ا(.)(.)$', ArabicPOS.noun), 

    // --- Form V (تفعّل) ---
    _RootPattern("Form V (Past)", r'^ت(.)(.)(.)$', ArabicPOS.verb), 
    _RootPattern("Form V (Present)", r'^يت(.)(.)(.)$', ArabicPOS.verb),
    _RootPattern("Form V (Participle)", r'^مت(.)(.)(.)$', ArabicPOS.noun),

    // --- Masdar Form II/V (Taf'aal) ---
    _RootPattern("Masdar (Taf'aal)", r'^ت(.)(.)ا(.)$', ArabicPOS.noun), 

    // --- [新增] Elative/Comparative (Af'al - أفعل) ---
    // e.g., Akbar (أكبر) -> K-B-R
    // 归一化后为: Alef + R1 + R2 + R3
    // 注意：这也涵盖了 Form IV Past (Af'ala - أكرم)
    _RootPattern("Comparative (Af'al)", r'^ا(.)(.)(.)$', ArabicPOS.noun), 

    // --- [新增] Elative Fem (Fu'la - فعلى) ---
    // e.g., Kubra (كبرى) -> K-B-R
    // 归一化后：R1 + R2 + R3 + Alef (from Yaa/Alif Maqsura)
    // 必须是4个字母，以Alef结尾
    _RootPattern("Comparative Fem (Fu'la)", r'^(.)(.)(.)ا$', ArabicPOS.noun),

    // --- Form IV (Participle) ---
    _RootPattern("Form IV (Participle)", r'^م(.)(.)(.)$', ArabicPOS.noun), 
    
    // --- Default Form I Present (Yaf'alu) ---
    _RootPattern("Form I (Present)", r'^ي(.)(.)(.)$', ArabicPOS.verb),
  ];

  /// 对输入的阿拉伯语单词进行预处理和规范化。
  String normalize(String text) {
    if (text.isEmpty) return "";
    // 移除额外部分
    String res = text.removeAracicExtensionPart();
    // 统一不同形式的 Alef
    res = res.replaceAll(RegExp(r'[أإآ]'), 'ا');
    // 将 Alef Maqsura 统一为 Alef
    res = res.replaceAll('ى', 'ا');
    
    // 忽略所有 "ة" (Ta Marbuta)，直接删除
    // 之前是替换为 'ه'，现在按照需求删除，以便处理如 'مكتبة' -> 'مكتب'
    res = res.replaceAll('ة', '');
    
    return res.trim();
  }

  /// 分析单词，返回其词根和匹配的模式。
  AnalysisResult analyze(String word) {
    String stem = normalize(word);

    if (stem.length <= 2) return AnalysisResult(stem, "Too Short", ArabicPOS.unknown);

    // 遍历模式库，找到第一个匹配的模式
    for (final pattern in _patterns) {
      final match = pattern.regex.firstMatch(stem);
      if (match != null) {
        String r1 = match.group(pattern.groups[0])!;
        String r2 = match.group(pattern.groups[1])!;
        String r3 = match.group(pattern.groups[2])!;
        return AnalysisResult(r1 + r2 + r3, pattern.name, pattern.pos);
      }
    }
    
    // 如果没有模式匹配成功，则使用后备的词缀剥离方法
    String fallbackRoot = _fallbackStripping(stem);
    return AnalysisResult(fallbackRoot, "Fallback/Form I", ArabicPOS.unknown);
  }

  /// 提取单词的词根（仅返回词根字符串）。
  String extractRoot(String word) {
    return analyze(word).root;
  }

  /// 后备方案：通过剥离常见的前后缀来简化单词。
  String _fallbackStripping(String stem) {
    String s = stem;
    
    if (s.startsWith('وال') || s.startsWith('فال')) s = s.substring(1);
    if (s.startsWith('لل') || s.startsWith('ال')) s = s.substring(2);
    if (s.length > 3 && (s.startsWith('و') || s.startsWith('ف'))) s = s.substring(1);

    if (s.length > 4) {
      if (s.endsWith('ات') || s.endsWith('ون') || s.endsWith('ين')) {
        s = s.substring(0, s.length - 2);
      } else if (s.endsWith('ي')) {
        s = s.substring(0, s.length - 1);
      }
       // 注意：这里去掉了对 'ه' (Ha) 的移除，因为我们不再把 'ة' 转为 'ه'
       // 如果 'ه' 是原生字母或代词后缀，仍需小心
    }

    return s;
  }
}

/// 计算两个字符串之间的 Levenshtein 编辑距离。
///
/// 编辑距离指从一个字符串转换成另一个所需的最少单字符编辑（插入、删除或替换）次数。
int getLevenshtein(String s, String t) {
  if (s == t) return 0;
  if (s.isEmpty) return t.length;
  if (t.isEmpty) return s.length;

  List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
  List<int> v1 = List<int>.generate(t.length + 1, (index) => 0);

  for (int i = 0; i < s.length; i++) {
    v1[0] = i + 1;
    for (int j = 0; j < t.length; j++) {
      int cost = (s[i] == t[j]) ? 0 : 1;
      v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
    }
    for (int j = 0; j < t.length + 1; j++) {
      v0[j] = v1[j];
    }
  }
  return v1[t.length];
}

final _arabicStemmer = ArabicStemmer();

/// 获取单词用于相似度计算的词根。
///
/// 优先使用词库提供的 [WordItem.root]（去掉发音符号 / 括号 / 斜杠后缀等扩展
/// 部分并去除分隔空格）；为空时回退到 [ArabicStemmer] 从词形提取。
///
/// 词库文本里的 `root` 偶尔夹带发音符号或 `(…)`、`/…` 说明，若直接作为
/// BK 树键会污染相似度计算，故此处统一走 [StringExtensions.removeAracicExtensionPart]。
String wordRoot(WordItem word) {
  final String provided =
      _arabicStemmer.normalize(word.root).replaceAll(RegExp(r'\s+'), '');
  if (provided.isNotEmpty) return provided;
  return _arabicStemmer.extractRoot(word.arabic);
}

/// 将用户输入归一化为词根键，用于精确词根匹配（去除发音符号/空白，统一阿列夫等）。
String normalizeRootKey(String input) => wordRoot(WordItem(
  arabic: input.replaceAll(RegExp(r'\s+'), ''),
  chinese: input,
  explanation: "",
  id: -1,
  className: "",
));

/// 将词库提供的词性字符串映射为[ArabicPOS]。
///
/// `Verbs` -> 动词，`Nominals` -> 名词，其余（含未提供）-> 未知。
ArabicPOS wordPos(WordItem word) {
  switch (word.pos) {
    case "Verbs":
      return ArabicPOS.verb;
    case "Nominals":
      return ArabicPOS.noun;
    default:
      return ArabicPOS.unknown;
  }
}

/// 混淆项的优先级等级
/// 1: 同根 + 同词性 (最高质量，考义项辨析)
/// 2: 近根 + 同词性 (考拼写辨析)
/// 3: 同根 + 异词性 (考词性辨析，难度较低)
/// 4: 近根 + 异/未知词性 (视觉干扰)
int _calculateTier(AnalysisResult target, AnalysisResult candidate) {
  int rootDist = getLevenshtein(target.root, candidate.root);

  // 1. 同根词 (Root Distance = 0)
  if (rootDist == 0) {
    if (target.pos == candidate.pos && target.pos != ArabicPOS.unknown) {
      return 1; // Tier 1: 同根同性
    }
    return 3; // Tier 3: 同根异性
  }

  // 2. 近根词 (Root Distance = 1)
  if (rootDist == 1) {
    if (target.pos == candidate.pos && target.pos != ArabicPOS.unknown) {
      return 2; // Tier 2: 近根同性
    }
    return 4; // Tier 4: 近根异性/未知
  }

  return 0; // 不相关
}

//基于BK-tree实现快速相似词搜索

class VocabularyOptimizer {
  _SimpleBKTree? _bkTree;
  final Map<String, Set<WordItem>> _rootToWordsMap = {}; 

  /// 初始化并构建优化器
  void build(List<WordItem> words) {
    _rootToWordsMap.clear();
    for (final word in words) {
      _addWordToMap(word);
    }
    if(_rootToWordsMap.isNotEmpty) {
      _bkTree = _SimpleBKTree(_rootToWordsMap.keys, getLevenshtein);
    }
  }

  void _addWordToMap(WordItem word) {
    final root = wordRoot(word);
    if (root.isEmpty) return;

    if (_rootToWordsMap.containsKey(root)) {
      _rootToWordsMap[root]!.add(word);
    } else {
      _rootToWordsMap[root] = {word};
    }
  }

  /// 查找与给定单词相似的所有单词
  List<WordItem> findSimilarWords(WordItem word, {int maxDistance = 1}) {
    if (_bkTree == null) return [];
    final queryRoot = wordRoot(word);
    if (queryRoot.isEmpty) return [];

    final results = _bkTree!.search(queryRoot, maxDistance);

    final resultWords = <WordItem>[];
    for (final String root in results) {
      final Set<WordItem>? words = _rootToWordsMap[root];
      if (words != null) resultWords.addAll(words);
    }
    return resultWords;
  }

  /// 返回词根恰好等于 [root] 的所有单词（未命中返回空列表）。
  List<WordItem> wordsForRoot(String root) {
    final Set<WordItem>? words = _rootToWordsMap[root];
    if (words == null || words.isEmpty) return const <WordItem>[];
    return List<WordItem>.unmodifiable(words);
  }
}

/// 词汇检索索引（用于「查找单词」）。
///
/// 原实现每次输入都对全表（万级）重新做正则归一化、子串判断与编辑距离，
/// 实时搜索下每次按键约 80-100ms，低端设备会明显卡顿。此索引：
/// 1. 归一化结果只预计算一次；
/// 2. 子串匹配走字符倒排索引（候选集为超集，再精确校验）；
/// 3. 模糊匹配走整词 BK-Tree；
/// 4. 词根近似沿用 [VocabularyOptimizer] 以保留原有易混词召回。
/// 最终只对少量候选做编辑距离校验与排序。
class VocabularyLookupIndex {
  final List<WordItem> _words;
  final VocabularyOptimizer _optimizer;
  final List<String> _arNorm;
  final List<String> _zh;
  final Map<String, List<int>> _arExact;
  final Map<String, List<int>> _arChars;
  final _SimpleBKTree? _arTree;

  VocabularyLookupIndex._(
    this._words,
    this._optimizer,
    this._arNorm,
    this._zh,
    this._arExact,
    this._arChars,
    this._arTree,
  );

  factory VocabularyLookupIndex.build(List<WordItem> words, VocabularyOptimizer optimizer) {
    final List<String> arNorm = List<String>.generate(
      words.length, (int i) => words[i].arabic.removeAracicExtensionPart().trim());
    final List<String> zh = List<String>.generate(words.length, (int i) => words[i].chinese);

    final Map<String, List<int>> arExact = {};
    final Map<String, List<int>> arChars = {};

    for(int i = 0; i < words.length; i++) {
      final String a = arNorm[i];
      if(a.isNotEmpty) {
        (arExact[a] ??= <int>[]).add(i);
        for(final String ch in a.split('').toSet()) {
          (arChars[ch] ??= <int>[]).add(i);
        }
      }
    }

    return VocabularyLookupIndex._(
      words,
      optimizer,
      arNorm,
      zh,
      arExact,
      arChars,
      arExact.isEmpty
          ? null
          : _SimpleBKTree(
              arExact.keys.where((String s) => s.length <= _maxFuzzyKeyLength),
              getLevenshtein,
            ),
    );
  }

  /// 参与模糊检索的最长归一化词长：更长的多为短语，改用子串匹配，
  /// 避免长字符串的编辑距离拖慢 BK-Tree 构建。
  static const int _maxFuzzyKeyLength = 12;

  /// 原扫描使用的编辑距离阈值（严格小于该值才算命中）
  static int _editLimit(String q) => 6 ~/ (q.length * 0.5 + 1);

  /// 主入口：按输入自动判断阿语/中文
  List<WordItem> lookup(String rawQuery) {
    final String query = rawQuery.trim();
    if(query.isEmpty) return <WordItem>[];
    return query.isArabic() ? _lookupArabic(query) : _lookupChinese(query);
  }

  List<WordItem> _lookupArabic(String query) {
    final String q = query.removeAracicExtensionPart().trim();
    if(q.isEmpty) return <WordItem>[];

    final List<int> result = <int>[];
    final Set<int> added = <int>{};

    // 1) 词根近似：与原实现一致，保留原有召回（不做二次校验）
    final int rootTolerance = 4 ~/ (q.length * 0.5 + 1);
    for(final WordItem w in _optimizer.findSimilarWords(
        WordItem(arabic: query, chinese: query, explanation: "", id: -1, className: ""),
        maxDistance: rootTolerance)) {
      if(w.id >= 0 && w.id < _words.length && added.add(w.id)) result.add(w.id);
    }

    // 2) 整词模糊 + 3) 子串（字符倒排返回超集）
    final Set<int> candidates = <int>{};
    candidates.addAll(_fuzzyCandidates(q, _arTree, _arExact, max(0, _editLimit(q) - 1)));
    candidates.addAll(_charCandidates(q, _arChars));

    final int limit = _editLimit(q);
    for(final int i in candidates) {
      if(added.contains(i)) continue;
      final String a = _arNorm[i];
      final bool hit = a.contains(q) ||
          (q.length >= 3 && (q.length - a.length).abs() <= limit && getLevenshtein(q, a) < limit);
      if(hit) {
        added.add(i);
        result.add(i);
      }
    }

    // 精确词根加权：命中已知词根时，其家族优先展示
    final Set<int> exactRootIds = <int>{};
    final String qKey = normalizeRootKey(query);
    if (qKey.isNotEmpty) {
      for (final WordItem w in _optimizer.wordsForRoot(qKey)) {
        if (w.id >= 0 && w.id < _words.length) {
          exactRootIds.add(w.id);
          if (added.add(w.id)) result.add(w.id);
        }
      }
    }

    result.sort((int a, int b) {
      final bool ea = exactRootIds.contains(a);
      final bool eb = exactRootIds.contains(b);
      if (ea != eb) return ea ? -1 : 1;
      return getLevenshtein(q, _arNorm[a]).compareTo(getLevenshtein(q, _arNorm[b]));
    });
    return [for(final int i in result) _words[i]];
  }

  /// 中文检索：沿用原「子串 + 有界编辑距离」扫描。
  /// 中文串可能很长，构建整词 BK-Tree 的代价远大于收益，故不建树。
  List<WordItem> _lookupChinese(String query) {
    final List<int> result = <int>[];
    final Set<int> added = <int>{};
    for(int i = 0; i < _zh.length; i++) {
      final String c = _zh[i];
      if(c.contains(query)) {
        if(added.add(i)) result.add(i);
        continue;
      }
      if(query.length >= 3 && getLevenshtein(query, c) < 4) {
        if(query.split('').any((String ch) => c.contains(ch)) && added.add(i)) result.add(i);
      }
    }
    result.sort((int a, int b) {
      final bool containA = _zh[a].contains(query);
      final bool containB = _zh[b].contains(query);
      if(containA != containB) return containA ? -1 : 1;
      return getLevenshtein(query, _zh[a]).compareTo(getLevenshtein(query, _zh[b]));
    });
    return [for(final int i in result) _words[i]];
  }

  Set<int> _fuzzyCandidates(String q, _SimpleBKTree? tree, Map<String, List<int>> exact, int tolerance) {
    final Set<int> out = <int>{};
    if(tree == null || q.isEmpty || tolerance <= 0) return out;
    for(final String key in tree.search(q, tolerance)) {
      final List<int>? idxs = exact[key];
      if(idxs != null) out.addAll(idxs);
    }
    return out;
  }

  /// 字符倒排交集：返回「包含 [text] 全部字符」的候选（子串匹配的超集）
  List<int> _charCandidates(String text, Map<String, List<int>> index) {
    if(text.isEmpty) return const <int>[];
    final List<String> chars = text.split('').toSet().toList();
    List<int>? smallest;
    String? smallestChar;
    for(final String ch in chars) {
      final List<int>? posting = index[ch];
      if(posting == null || posting.isEmpty) return const <int>[];
      if(smallest == null || posting.length < smallest.length) {
        smallest = posting;
        smallestChar = ch;
      }
    }
    if(smallest == null || smallest.isEmpty) return const <int>[];
    final List<List<int>> others = [
      for(final String ch in chars) if(ch != smallestChar) index[ch]!,
    ];
    if(others.isEmpty) return smallest;
    final List<int> out = <int>[];
    for(final int candidate in smallest) {
      bool ok = true;
      for(final List<int> list in others) {
        if(!_sortedContains(list, candidate)) {
          ok = false;
          break;
        }
      }
      if(ok) out.add(candidate);
    }
    return out;
  }

  /// 在升序列表中二分查找（倒排表按索引升序构建）
  bool _sortedContains(List<int> sorted, int value) {
    int lo = 0;
    int hi = sorted.length - 1;
    while(lo <= hi) {
      final int mid = (lo + hi) >> 1;
      final int v = sorted[mid];
      if(v == value) return true;
      if(v < value) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return false;
  }
}

/// 1. 初始化: BKSearch.init(['ktb', 'maktaba', ...]);
/// 2. 搜索: var results = BKSearch.search('kitab');
@immutable
class BKSearch {
  // 私有构造函数，防止外部实例化
  const BKSearch._();
  
  // 单例实例
  static final VocabularyOptimizer _optimizer = VocabularyOptimizer();
  static VocabularyLookupIndex? _lookupIndex;
  static bool _isInitialized = false;

  static final Logger logger = Logger("BKT");

  /// [必须调用] 初始化搜索引擎
  /// 通常在 App 启动或加载词库时调用
  static void init(List<WordItem> allWords) {
    if (_isInitialized) return; // 避免重复初始化
    rebuild(allWords);
  }

  /// [强制重建] 无论是否已初始化都重建索引。
  /// 导入新词库或恢复备份数据后调用，保证新词立即可搜。
  static void rebuild(List<WordItem> allWords) {
    logger.info("正在构建搜索索引，词库大小: ${allWords.length}...");
    _optimizer.build(allWords);
    _lookupIndex = VocabularyLookupIndex.build(allWords, _optimizer);
    _isInitialized = true;
    logger.info("搜索索引构建完成");
  }

  /// 词汇检索（「查找单词」）：阿语/中文的子串与模糊匹配，结果按编辑距离排序。
  static List<WordItem> lookup(String query) {
    if (!_isInitialized || _lookupIndex == null) {
      logger.warning("警告: BKSearch 尚未初始化，无法执行词汇检索");
      return <WordItem>[];
    }
    return _lookupIndex!.lookup(query);
  }

  /// 普通搜索: 返回所有相似词列表
  /// [query] : 用户输入的单词
  /// [threshold] : 容错阈值，默认 1 (允许 1 个字符的编辑距离差异)
  static List<WordItem> search(WordItem query, {int threshold = 1}) {
    if (!_isInitialized) {
      logger.warning("警告: BKSearch 尚未初始化，请先调用 init()");
      return [];
    }
    return _optimizer.findSimilarWords(query, maxDistance: threshold);
  }

  /// [核心功能] 分级搜索混淆词
  /// 返回一个 Map，key 为优先级 (1-4)，value 为符合该优先级的单词列表。
  /// 
  /// Tier 1: 同根 + 同词性 (最高质量)
  /// Tier 2: 近根(dist=1) + 同词性
  /// Tier 3: 同根 + 异词性
  /// Tier 4: 近根(dist=1) + 异/未知词性
  static Map<int, List<WordItem>> searchWithTiers(WordItem targetWord) {
    if (!_isInitialized) {
      logger.warning("警告: BKSearch 尚未初始化，无法执行分级搜索");
      return {1: [], 2: [], 3: [], 4: []};
    }

    // 1. 分析目标词（优先使用词库提供的词根/词性，缺省时由 wordRoot 回退到词干提取）
    final targetAnalysis = AnalysisResult(wordRoot(targetWord), "Provided", wordPos(targetWord));
    
    // 2. 使用 BK-Tree 快速获取候选词 (词根距离 <= 1)
    // 这一步利用了索引，极大减少了计算量
    final candidates = _optimizer.findSimilarWords(targetWord, maxDistance: 1);

    final Map<int, List<WordItem>> result = {
      1: [],
      2: [],
      3: [],
      4: [],
    };

    // 3. 遍历候选词，进行精细分类
    for (WordItem candidateStr in candidates) {
      if (candidateStr == targetWord) continue; // 跳过自己

      final candidateAnalysis = AnalysisResult(wordRoot(candidateStr), "Provided", wordPos(candidateStr));
      
      int tier = _calculateTier(targetAnalysis, candidateAnalysis);
      if (tier > 0) {
        result[tier]!.add(candidateStr);
      }
    }

    return result;
  }

  /// 检查是否已经准备好
  static bool get isReady => _isInitialized;
}
