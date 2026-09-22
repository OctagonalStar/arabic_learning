// 中文释义同义/不同对的持久化单例。
// 标记数据存入 "synonymData" 键（usedKeys 白名单内，随备份同步）。

import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/models/synonym.dart';
import 'package:arabic_learning/services/app_data.dart';

class SynonymStore {
  // 作为单例
  static final SynonymStore _instance = SynonymStore._internal();
  factory SynonymStore() => _instance;
  SynonymStore._internal();

  final Logger logger = Logger("Synonym");

  /// 内存中的标记数据，安全初始化为空，可在 [init] 前读取。
  SynonymData data = const SynonymData();

  /// 从存储加载。
  ///
  /// 无 `"synonymData"` 键时写入默认值并返回 false，否则解码返回 true。
  bool init() {
    final AppData appData = AppData();
    if (!appData.storage.containsKey("synonymData")) {
      logger.info("未发现同义对数据，写入默认值");
      data = const SynonymData();
      appData.storage.setString("synonymData", jsonEncode(data.toMap()));
      return false;
    }
    _loadFromStorage();
    logger.info("同义对数据加载完成");
    return true;
  }

  /// 将当前内存数据写入存储。
  void save() {
    AppData().storage.setString("synonymData", jsonEncode(data.toMap()));
  }

  /// 从存储重读（备份恢复后调用），不写回。
  void reload() {
    _loadFromStorage();
    logger.info("同义对数据重载完成");
  }

  /// 读取并按需解码存储内容，失败时回退为空数据。
  void _loadFromStorage() {
    try {
      final String? raw = AppData().storage.getString("synonymData");
      if (raw == null || raw.isEmpty) {
        data = const SynonymData();
        return;
      }
      data = SynonymData.buildFromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      logger.severe("同义对数据解析失败: $e");
      data = const SynonymData();
    }
  }

  /// 两个释义是否同义。空→false；规范化后相等→true；否则查 synonyms。
  bool areSynonyms(String glossA, String glossB) {
    final String a = normalizeGloss(glossA);
    final String b = normalizeGloss(glossB);
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    final GlossPair? pair = GlossPair.create(a, b);
    if (pair == null) return false;
    return data.synonyms.contains(pair);
  }

  /// 两个释义是否被标记为不同（负向记忆）。
  bool areDistinct(String glossA, String glossB) {
    final GlossPair? pair = GlossPair.create(glossA, glossB);
    if (pair == null) return false;
    return data.distincts.contains(pair);
  }

  /// 两个词条的中文释义是否同义。
  bool isSynonymWord(WordItem target, WordItem candidate) {
    return areSynonyms(target.chinese, candidate.chinese);
  }

  /// 两个词条的中文释义是否被标记为不同。
  bool isDistinctWord(WordItem target, WordItem candidate) {
    return areDistinct(target.chinese, candidate.chinese);
  }

  /// 标记两个释义同义：从 distincts 移除并加入 synonyms，然后保存。
  void markSynonym(String glossA, String glossB) {
    final GlossPair? pair = GlossPair.create(glossA, glossB);
    if (pair == null) return;
    final Set<GlossPair> synonyms = Set<GlossPair>.of(data.synonyms)..add(pair);
    final Set<GlossPair> distincts = Set<GlossPair>.of(data.distincts)
      ..remove(pair);
    data = SynonymData(synonyms: synonyms, distincts: distincts);
    save();
  }

  /// 标记两个释义不同：从 synonyms 移除并加入 distincts，然后保存。
  void markDistinct(String glossA, String glossB) {
    final GlossPair? pair = GlossPair.create(glossA, glossB);
    if (pair == null) return;
    final Set<GlossPair> synonyms = Set<GlossPair>.of(data.synonyms)
      ..remove(pair);
    final Set<GlossPair> distincts = Set<GlossPair>.of(data.distincts)
      ..add(pair);
    data = SynonymData(synonyms: synonyms, distincts: distincts);
    save();
  }

  /// 从 synonyms 与 distincts 中移除指定对，然后保存。
  void removePair(String glossA, String glossB) {
    final GlossPair? pair = GlossPair.create(glossA, glossB);
    if (pair == null) return;
    final Set<GlossPair> synonyms = Set<GlossPair>.of(data.synonyms)
      ..remove(pair);
    final Set<GlossPair> distincts = Set<GlossPair>.of(data.distincts)
      ..remove(pair);
    data = SynonymData(synonyms: synonyms, distincts: distincts);
    save();
  }

  /// 清空全部标记并保存。
  void clearAll() {
    data = const SynonymData();
    save();
  }

  /// 同义对列表，按 [GlossPair.display] 排序。
  List<GlossPair> get synonymList {
    final List<GlossPair> list = data.synonyms.toList();
    list.sort((GlossPair x, GlossPair y) => x.display.compareTo(y.display));
    return list;
  }

  /// 不同对列表，按 [GlossPair.display] 排序。
  List<GlossPair> get distinctList {
    final List<GlossPair> list = data.distincts.toList();
    list.sort((GlossPair x, GlossPair y) => x.display.compareTo(y.display));
    return list;
  }

  /// 管理页展示用：对 synonyms 做并查集连通分量，返回 size>=2 的分组（每组按字典序）。
  /// 仅用于展示，不做任何传递闭包式的排除逻辑。
  List<List<String>> synonymGroups() {
    final Map<String, String> parent = {};

    String find(String node) {
      parent.putIfAbsent(node, () => node);
      String root = node;
      while (parent[root] != root) {
        root = parent[root]!;
      }
      // 路径压缩
      String current = node;
      while (parent[current] != root) {
        final String next = parent[current]!;
        parent[current] = root;
        current = next;
      }
      return root;
    }

    for (final GlossPair pair in data.synonyms) {
      final String rootA = find(pair.a);
      final String rootB = find(pair.b);
      if (rootA != rootB) parent[rootA] = rootB;
    }

    final Map<String, List<String>> grouped = {};
    for (final String node in parent.keys.toList()) {
      grouped.putIfAbsent(find(node), () => []).add(node);
    }

    final List<List<String>> result = [];
    for (final List<String> group in grouped.values) {
      if (group.length < 2) continue;
      group.sort();
      result.add(group);
    }
    result.sort((List<String> x, List<String> y) => x.first.compareTo(y.first));
    return result;
  }
}
