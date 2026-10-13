// 单词收藏持久化单例（"favoriteData" 键，位于 usedKeys 白名单，随备份同步）。
//
// 强 id 体系：收藏键为 WordItem.id（wordData.words 的位置下标）。命中判断用
// Set<int> 保证 O(1)，收藏列表按 _order 遍历为 O(k)（k 为收藏数，非全词库 N）。
//
// id 同步约定：
// - AppData.compactUnreferencedWords 重排词条后必须调用 [remap]（丢弃已删 id）；
// - AppData.resetDictsPreservingFsrs 清空词库时调用 [clear]（收藏不按词形恢复）。

import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:arabic_learning/services/app_data.dart';

class FavoriteStore {
  // 作为单例
  static final FavoriteStore _instance = FavoriteStore._internal();
  factory FavoriteStore() => _instance;
  FavoriteStore._internal();

  final Logger logger = Logger("Favorite");

  /// 存储键；新增顶级键必须登记进 `SharedPreferences.usedKeys`，否则备份会丢失。
  static const String storageKey = "favoriteData";

  /// 数据结构版本，便于后续升级。
  static const int dataVersion = 1;

  /// O(1) 命中集合。
  final Set<int> _ids = <int>{};

  /// 收藏顺序（按收藏时间先后），供收藏列表页 O(k) 遍历。
  final List<int> _order = <int>[];

  /// 从存储加载。无 `"favoriteData"` 键时写入默认空数据并返回 false，否则返回 true。
  bool init() {
    final AppData appData = AppData();
    if (!appData.storage.containsKey(storageKey)) {
      logger.info("未发现收藏数据，写入默认值");
      _ids.clear();
      _order.clear();
      save();
      return false;
    }
    _loadFromStorage();
    logger.info("收藏数据加载完成");
    return true;
  }

  /// 从存储重读（备份恢复后调用），不写回。
  void reload() {
    _loadFromStorage();
    logger.info("收藏数据重载完成");
  }

  /// 序列化当前数据。
  Map<String, dynamic> toMap() => <String, dynamic>{
        "version": dataVersion,
        "order": List<int>.of(_order),
      };

  /// 将当前数据写入存储。
  void save() {
    AppData().storage.setString(storageKey, jsonEncode(toMap()));
  }

  /// 是否已收藏（O(1)）。
  bool contains(int id) => _ids.contains(id);

  /// 收藏数量（O(1)）。
  int get count => _ids.length;

  /// 按收藏顺序返回 id 列表（不可变）。
  List<int> get ids => List<int>.unmodifiable(_order);

  /// 切换收藏状态，返回切换后的状态（true=已收藏）。非法 id 直接忽略。
  bool toggle(int id) {
    if (id < 0) return false;
    final bool now;
    if (_ids.contains(id)) {
      _ids.remove(id);
      _order.remove(id);
      now = false;
    } else {
      _ids.add(id);
      _order.add(id);
      now = true;
    }
    save();
    return now;
  }

  /// 移除单个收藏（不存在则忽略）。
  void remove(int id) {
    if (!_ids.remove(id)) return;
    _order.remove(id);
    save();
  }

  /// 批量移除（用于删除词库后清理已移除词条的收藏）。
  void removeAll(Iterable<int> ids) {
    bool changed = false;
    for (final int id in ids) {
      if (_ids.remove(id)) {
        _order.remove(id);
        changed = true;
      }
    }
    if (changed) save();
  }

  /// 清空全部收藏并保存。
  void clear() {
    _ids.clear();
    _order.clear();
    save();
  }

  /// id 重排后同步平移：`oldToNew` 中不存在的 id 视为已删除并丢弃。
  void remap(Map<int, int> oldToNew) {
    final List<int> mapped = <int>[];
    for (final int old in _order) {
      final int? neu = oldToNew[old];
      if (neu != null) mapped.add(neu);
    }
    _order
      ..clear()
      ..addAll(mapped);
    _ids
      ..clear()
      ..addAll(mapped);
    save();
  }

  /// 读取并按需解码存储内容，失败时回退为空数据。
  void _loadFromStorage() {
    _ids.clear();
    _order.clear();
    try {
      final String? raw = AppData().storage.getString(storageKey);
      if (raw == null || raw.isEmpty) return;
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final dynamic order = decoded["order"];
      if (order is! List) return;
      for (final dynamic item in order) {
        if (item is! int || item < 0) continue;
        if (_ids.add(item)) _order.add(item); // 去重并保持顺序
      }
    } catch (e) {
      logger.severe("收藏数据解析失败: $e");
      _ids.clear();
      _order.clear();
    }
  }
}
