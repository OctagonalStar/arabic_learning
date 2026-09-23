// 词条归属反查缓存：由 DictData.classes/subClasses/wordIndexs 这一单一数据源构建
// 「词条 id -> 所属（词库名, 课程名）」索引，供单词卡片展示全部归属。
// 不参与存储序列化；在数据变更处（启动 / 导入 / 备份恢复）随 BKSearch 一同重建。

import 'package:arabic_learning/models/dict.dart' show ClassItem, SourceItem;
import 'package:flutter/foundation.dart' show immutable;

/// 单个归属条目：词库展示名 + 课程名。
@immutable
class WordMembership {
  /// 词库展示名（[SourceItem.name]：元数据名称优先，回退文件名）。
  final String source;

  /// 课程名（[ClassItem.className]）。
  final String course;

  const WordMembership({required this.source, required this.course});

  /// 展示文案：`词库名 › 课程名`（词库名为空时退化为课程名）。
  String get label => source.isEmpty ? course : '$source › $course';
}

/// 词条归属反查索引（单例，仅内存缓存）。
class WordMembershipIndex {
  WordMembershipIndex._();

  static final WordMembershipIndex instance = WordMembershipIndex._();

  Map<int, List<WordMembership>> _byWord = const <int, List<WordMembership>>{};
  bool _ready = false;

  /// 索引是否已构建（未构建时查询返回空，卡片可回退到旧 `className`）。
  bool get isReady => _ready;

  /// 由词库结构重建索引。O(归属条目总数)，应在导入 / 恢复 / 启动后调用。
  void rebuild(List<SourceItem> classes) {
    final Map<int, List<WordMembership>> map = <int, List<WordMembership>>{};
    for (final SourceItem source in classes) {
      for (final ClassItem course in source.subClasses) {
        for (final int id in course.wordIndexs) {
          (map[id] ??= <WordMembership>[]).add(
            WordMembership(source: source.name, course: course.className),
          );
        }
      }
    }
    _byWord = map;
    _ready = true;
  }

  /// 清空索引（例如重置词库数据时）。
  void clear() {
    _byWord = const <int, List<WordMembership>>{};
    _ready = false;
  }

  /// 取得 [wordId] 的全部归属；无则返回空列表。
  List<WordMembership> of(int wordId) =>
      _byWord[wordId] ?? const <WordMembership>[];
}
