import 'dart:async';
import 'dart:convert';

import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/db/fsrs_store.dart';
import 'package:arabic_learning/services/db/fsrs_store_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:fsrs/fsrs.dart';
import 'package:logging/logging.dart';

import 'package:arabic_learning/package_replacement/storage.dart';

/// 与 `PushSessionStore.key` 保持一致。
///
/// 这里用常量而不是 import，避免 `services/` 内部多一条循环依赖
/// （`push_session.dart` 已经 import 了本文件）。
const String _pushSessionStorageKey = "pushSessionData";

class FSRS { 
  // 作为单例
  static final FSRS _instance = FSRS._internal();
  factory FSRS() => _instance;
  FSRS._internal();

  late FSRSConfig config;

  /// [config] 是否已加载。初始化前调用下面基于卡片的方法会安全返回 0。
  bool _inited = false;

  /// [config] 是否已加载（未加载时读取 [config] 会抛异常，调用方需先判断）。
  bool get inited => _inited;
  
  final Logger logger = Logger("FSRS");
  // index != cardId; cardId = wordId = the index of word in global.wordData[words]

  /// 卡片数据后端。默认 JSON（旧 `fsrsData`），原生平台由 [initAsync] 换成 SQLite。
  FsrsStore _store = JsonFsrsStore();

  /// 当前使用的存储后端（测试可注入）。
  FsrsStore get store => _store;

  /// 注入存储后端（仅测试用）。
  ///
  /// 生产代码由 [initAsync] 自行决定后端；测试用它直接接上 drift 后端，
  /// 从而在不打开真实数据库文件的前提下验证导出/恢复链路。
  @visibleForTesting
  void debugUseStore(FsrsStore store) {
    _store = store;
  }

  /// 是否使用 SQLite 后端（Web / 测试 / 打开失败时为 false）。
  bool get usingSqlite => _store.usesSqlite;

  /// [initAsync] 的打开任务记忆化，避免重复建库。
  Future<void>? _opening;

  /// 本次前台会话内是否已写过「降级安全快照」。
  bool _legacySnapshotWritten = false;

  /// 写入防抖计时器：答题时只重置计时，避免每次都序列化整张卡片表。
  Timer? _saveTimer;

  /// 生命周期落盘守卫（退后台/隐藏/销毁前立即写盘），只注册一次。
  AppLifecycleListener? _lifecycleListener;

  /// 同步初始化（JSON 后端）。Web、测试与 SQLite 打开失败时的兜底路径。
  ///
  /// 返回 FSRS 是否启用。原生平台请使用 [initAsync]（会优先尝试 SQLite）。
  bool init() {
    logger.fine("构建FSRS模块");
    _ensureHooks();
    if (_store is! JsonFsrsStore) {
      // 已切到 SQLite：同步接口读不了库，交由 initAsync(reload: true) 刷新。
      logger.fine("当前为 SQLite 后端，跳过同步初始化");
      return _inited && config.enabled;
    }
    final FSRSConfig? loaded = (_store as JsonFsrsStore).loadSync();
    if (loaded == null) {
      logger.info("未发现FSRS配置，加载默认配置");
      _applyLoaded(null);
      return false;
    }
    return _applyLoaded(loaded);
  }

  /// 异步初始化：原生平台优先打开 SQLite，失败则自动回退 JSON 后端。
  ///
  /// [reload] 为 true 时从**当前后端**重新读取（备份恢复 / 降级快照回灌后使用），
  /// 不会再尝试打开新的数据库。
  ///
  /// 无论走哪条路径，返回时 [config] 一定已就绪（`produceCard` 不会静默无效）。
  Future<void> initAsync({bool reload = false}) async {
    _ensureHooks();
    if (reload) {
      if (_store is! JsonFsrsStore) {
        _saveTimer?.cancel();
        _saveTimer = null;
        await _store.flush();
        _applyLoaded(await _store.load());
        _writeLegacySnapshot(markSession: false);
        return;
      }
      init();
      return;
    }
    if (_opening != null) return _opening!;
    _opening = _openAndLoad();
    return _opening!;
  }

  Future<void> _openAndLoad() async {
    final SharedPreferences prefs = AppData().storage;
    final String? legacyJson = prefs.getString("fsrsData");
    final Map<String, String> legacyHotKv = <String, String>{
      _pushSessionStorageKey: prefs.getString(_pushSessionStorageKey) ?? "",
    };

    FsrsStore? opened;
    try {
      opened = await openDriftStore(
        legacyJson: legacyJson,
        legacyHotKv: legacyHotKv,
      );
      if (opened == null) {
        logger.info("使用 JSON 存储后端（fsrsData）");
        init();
        return;
      }
      final FSRSConfig? loaded = await opened.load();
      _store = opened;
      _applyLoaded(loaded);
      // 这里**不**写降级快照：偏好文件里已有一份可用的 fsrsData
      // （迁移自旧版或上次退后台写入），启动时再整份重写（其中含 wordData）
      // 没有必要。数据的新鲜度由退后台/隐藏时的 flushAsync 保证。
    } catch (e, stack) {
      logger.severe("SQLite 存储初始化失败，回退 JSON 存储: $e", e, stack);
      try {
        await opened?.close();
      } catch (_) {
        // 关闭失败无需处理：本次会话已回退 JSON 后端。
      }
      _store = JsonFsrsStore();
      init();
    }
  }

  /// 应用已加载的配置（null 表示无数据 → 默认配置并落盘）。
  /// 返回 FSRS 是否启用。
  bool _applyLoaded(FSRSConfig? loaded) {
    if (loaded == null) {
      config = FSRSConfig();
      _inited = true;
      _store.save(config);
      return false;
    }

    config = loaded;
    _inited = true;
    logger.info("FSRS配置加载完成");

    // 清洗潜在的重复脏数据 (Deduplication)
    final Set<int> seenIds = {};
    final List<Card> uniqueCards = [];
    final List<ReviewLog> uniqueLogs = [];

    for(int i = 0; i < config.cards.length; i++) {
      final currentCardId = config.cards[i].cardId;
      if(!seenIds.contains(currentCardId)) {
        seenIds.add(currentCardId);
        uniqueCards.add(config.cards[i]);
        if(i < config.reviewLogs.length) {
          uniqueLogs.add(config.reviewLogs[i]);
        }
      }
    }

    if(uniqueCards.length < config.cards.length) {
      logger.warning("发现并清理了 ${config.cards.length - uniqueCards.length} 条重复复习记录");
      config = config.copyWith(cards: uniqueCards, reviewLogs: uniqueLogs);
      _flush();
    }

    if(config.enabled) return true;
    logger.info("FSRS未启用");
    return false;
  }

  /// 保存 FSRS 配置。
  ///
  /// 默认按 400ms 防抖合并写入（答题时每答一题都会调用，逐题整表序列化开销过大）；
  /// [immediate] 为 true 时取消待执行的防抖任务并立即写盘。
  void save({bool immediate = false}) {
    if(immediate) {
      _flush();
      return;
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _flush);
  }

  /// 立即把当前配置写入存储（跳过防抖），供页面/测试/生命周期节点调用。
  ///
  /// SQLite 后端下**不会**触碰 `shared_preferences`（那才是真正的开销来源）；
  /// 降级快照只在生命周期节点（[flushAsync]）与导出/恢复时写。
  void flush() {
    _flush();
  }

  /// 可等待版本：等待写入真正落盘，并补写一次「降级安全快照」。
  ///
  /// 用于退后台/隐藏/分离：除 [FsrsStore.flush] 外，额外把当前配置完整写成
  /// 一次旧版 `fsrsData` blob（每次前台会话最多一次），这样用户降级旧版本
  /// 最多只丢当前会话的复习记录。
  Future<void> flushAsync() async {
    _flush();
    _writeLegacySnapshot();
    await _store.flush();
  }

  void _flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    logger.info("正在保存FSRS配置");
    // 异步入队：SQLite 后端只保留最新快照，调用方无需等待。
    _store.save(config);
  }

  /// 把当前配置完整写成旧版 `fsrsData` blob（降级旧版本时最多只丢当前会话）。
  ///
  /// 仅在 SQLite 后端下生效。生命周期路径每次前台会话最多写一次
  /// （[markSession]），避免每次答题都重写包含 `wordData` 的整个偏好文件；
  /// 启动 / 恢复等显式节点用 `markSession: false`，不占用这次额度。
  void _writeLegacySnapshot({bool markSession = true}) {
    if (!_store.usesSqlite || !_inited) return;
    if (markSession && _legacySnapshotWritten) return;
    if (markSession) _legacySnapshotWritten = true;
    logger.fine("写入旧版 fsrsData 快照（降级安全）");
    final String json = jsonEncode(config.toMap());
    // 记下这次写的内容：下次启动若发现偏好文件里的 fsrsData 与它不同，
    // 说明是外部（旧版本/备份/手工）写的，需要重新导入而不是丢弃。
    // 顺序上先写偏好文件、成功后再记摘要，避免「摘要已记但文件没写成」把
    // 一次会话的进度误判成外部写入。
    if (AppData().storage.getString("fsrsData") == json) {
      // 内容没变就不重写：偏好文件里还包含 wordData，整份重写没有意义。
      unawaited(_store.noteLegacySnapshot(json));
      return;
    }
    unawaited(AppData()
        .storage
        .setString("fsrsData", json)
        .then((_) => _store.noteLegacySnapshot(json)));
  }

  /// 注册存储层钩子：导出前落盘、导出时用内存副本覆盖、备份恢复后重灌。
  void _ensureHooks() {
    _ensureLifecycleListener();
    // 备份/导出快照前强制落盘，避免 400ms 防抖窗口内的答题记录丢失。
    // SQLite 后端不需要写旧版 blob（导出钩子会直接给出内存副本），
    // 否则每次导出又会整份重写偏好文件。
    SharedPreferences.flushPendingWrites = _flushForExport;
    SharedPreferences.exportOverrides = _exportOverrides;
    SharedPreferences.afterRecovery = _onStorageRecovered;
  }

  void _flushForExport() {
    if (_store.usesSqlite) {
      _flush();
      return;
    }
    flush();
  }

  /// 导出时用内存中的权威副本覆盖 `fsrsData` / `pushSessionData`。
  ///
  /// 备份格式与旧版完全一致（`FSRSConfig.toMap()`），旧版本可直接导入。
  /// 非 SQLite 后端返回 null（此时 `shared_preferences` 里的值就是权威副本）。
  Map<String, String>? _exportOverrides() {
    if (!_store.usesSqlite || !_inited) return null;
    return <String, String>{
      "fsrsData": jsonEncode(config.toMap()),
      _pushSessionStorageKey: _store.hotKv(_pushSessionStorageKey) ?? "",
    };
  }

  /// 备份恢复后：把恢复出来的旧 `fsrsData` 幂等全量灌回 SQLite。
  Future<void> _onStorageRecovered() async {
    if (_store is JsonFsrsStore) return; // JSON 后端：重新 init 即可
    _saveTimer?.cancel();
    _saveTimer = null;
    // 高频键同理：备份里的 pushSessionData 必须覆盖库里的旧断点
    // （备份中没有该键时保持现状，与旧版「跳过缺失键」的行为一致）。
    final String? pushRaw = AppData().storage.getString(_pushSessionStorageKey);
    if (pushRaw != null && pushRaw.isNotEmpty) {
      await _store.setHotKv(_pushSessionStorageKey, pushRaw);
    }

    final String? raw = AppData().storage.getString("fsrsData");
    if (raw == null || raw.isEmpty) return;
    try {
      await _store.importLegacy(raw);
      _applyLoaded(await _store.load());
      _writeLegacySnapshot(markSession: false);
      logger.info("备份数据已灌回 SQLite 存储");
    } catch (e, stack) {
      logger.severe("备份数据灌回 SQLite 失败: $e", e, stack);
    }
  }

  /// 注册生命周期落盘守卫：应用暂停/隐藏/分离前立即写盘，避免防抖窗口内丢数据。
  /// 纯 Dart 测试环境没有初始化 WidgetsBinding，此时直接跳过（不抛异常）。
  void _ensureLifecycleListener() {
    if(_lifecycleListener != null) return;
    try {
      // 未初始化绑定时 AppLifecycleListener 的构造会抛错，纯 Dart 环境据此跳过。
      _lifecycleListener = AppLifecycleListener(
        onPause: () => unawaited(flushAsync()),
        onHide: () => unawaited(flushAsync()),
        onDetach: () => unawaited(flushAsync()),
        onResume: _onForeground,
      );
    } catch (e) {
      logger.fine("非 Flutter 环境，跳过生命周期落盘守卫: $e");
    }
  }

  /// 回到前台：允许下一次退后台再写一次降级快照。
  void _onForeground() {
    _legacySnapshotWritten = false;
  }

  void createScheduler({required SharedPreferences prefs}) {
    logger.info("初始化scheduler，选择相关配置 ${config.toMap().toString()}");
    config = config.copyWith(
      enabled: true,
      scheduler: Scheduler(desiredRetention: config.desiredRetention)
    );
    save();
  }

  int willDueIn(Card card) {
    return card.due.toLocal().difference(DateTime.now()).inDays;
  }

  void produceCard(int wordId, {int? duration, bool? isCorrect, Rating? forceRate}) {
    logger.fine("记录复习卡片: Id: $wordId; duration: $duration; isCorrect: $isCorrect; forceRate: $forceRate");
    final int index = config.cards.indexWhere((Card card) => card.cardId == wordId);
    if(index == -1) {
      // 卡片不存在 进行添加
      logger.fine("添加复习卡片: Id: $wordId");
      if(config.cards.isEmpty) {
        config = config.copyWith(
          cards: [],
          reviewLogs: []
        );
      }
      config.cards.add(Card(cardId: wordId, state: State.learning));
      config.reviewLogs.add(ReviewLog(cardId: wordId, rating: Rating.good, reviewDateTime: DateTime.now()));
    } else {
      // 卡片存在 进行复习
      if((duration == null || isCorrect == null) && forceRate == null) {
        logger.shout("传入信息缺失: wordId: $wordId; duration: $duration; isCorrect: $isCorrect; forceRate: $forceRate");
        return; // 避免错误信息导入
      }
      logger.fine("定位复习卡片地址: $index, 目前阶段: ${config.cards[index].step}, 难度: ${config.cards[index].difficulty}, 稳定: ${config.cards[index].stability}, 过期时间(+8): ${config.cards[index].due.toLocal()}");
      final (:card, :reviewLog) = config.scheduler!.reviewCard(config.cards[index], forceRate ?? calculate(duration!, isCorrect!), reviewDateTime: DateTime.now().toUtc(), reviewDuration: duration);
      config.cards[index] = card;
      config.reviewLogs[index] = reviewLog;
      logger.fine("卡片 $index 复习后: 目前阶段: ${config.cards[index].step}, 难度: ${config.cards[index].difficulty}, 稳定: ${config.cards[index].stability}, 过期时间(+8): ${config.cards[index].due.toLocal()}");
    }
    save();
  }

  int getWillDueCount() {
    int dueCards = 0;
    for(Card card in config.cards) {
      if(willDueIn(card) < 1) {
        dueCards++;
      }
    }
    return dueCards;
  }

  bool isContained(int wordId) {
    return config.cards.any((Card card) => card.cardId == wordId);
  }

  Rating calculate(int duration, bool isCorrect) {
    // duration in milliseconds
    if (!isCorrect) {
      logger.fine("计算得分: again");
      return Rating.again;
    }
    if (duration < config.easyDuration) {
      logger.fine("计算得分: easy");
      return Rating.easy;
    }
    if (duration < config.goodDuration) {
      logger.fine("计算得分: good");
      return Rating.good;
    }
    logger.fine("计算得分: hard");
    return Rating.hard;
  }

  DateTime? getCardBirthday(int wordId) {
    try {
      return config.reviewLogs.firstWhere((ReviewLog rvl) => rvl.cardId == wordId).reviewDateTime;
    } catch (e) {
      logger.severe("wordID: $wordId card not found or has more than one");
      return null;
    }
  }

  /// 统计这些词 id 上已有的复习卡片数量（用于删词前的影响提示）。
  int countCardsFor(Set<int> wordIds) {
    if (!_inited) return 0;
    return config.cards.where((Card card) => wordIds.contains(card.cardId)).length;
  }

  /// 统计越界的复习卡片数量（`cardId` 不在 `[0, wordCount)` 内）。
  int outOfRangeCardCount(int wordCount) {
    if (!_inited) return 0;
    return config.cards
        .where((Card card) => card.cardId < 0 || card.cardId >= wordCount)
        .length;
  }

  /// 返回与 `reviewLogs` 对齐的卡片列表（缺失日志以默认值补齐）。
  List<({Card card, ReviewLog log})> alignedCards() {
    if (!_inited) return const <({Card card, ReviewLog log})>[];
    final List<({Card card, ReviewLog log})> out = [];
    for (final Card card in config.cards) {
      ReviewLog? log;
      for (final ReviewLog candidate in config.reviewLogs) {
        if (candidate.cardId == card.cardId) {
          log = candidate;
          break;
        }
      }
      out.add((
        card: card,
        log: ReviewLog(
          cardId: card.cardId,
          rating: log?.rating ?? Rating.good,
          reviewDateTime: log?.reviewDateTime ?? DateTime.now(),
          reviewDuration: log?.reviewDuration,
        ),
      ));
    }
    return out;
  }

  /// 用给定的对齐卡片列表替换全部卡片并持久化。
  void setAlignedCards(List<({Card card, ReviewLog log})> entries) {
    if (!_inited) return;
    config = config.copyWith(
      cards: entries.map((e) => e.card).toList(growable: false),
      reviewLogs: entries.map((e) => e.log).toList(growable: false),
    );
    save();
  }

  /// 清空全部卡片与复习日志并持久化，返回被清空的数量。
  int clearCards() {
    if (!_inited) return 0;
    final int count = config.cards.length;
    config = config.copyWith(cards: const <Card>[], reviewLogs: const <ReviewLog>[]);
    save();
    return count;
  }

  /// 按 `old→new` 下标映射重建卡片与复习日志：丢弃不存在于映射中的词条卡片、
  /// 重写 `cardId`，并保持 `cards[i]` 与 `reviewLogs[i]` 一一对齐。
  /// 返回被丢弃的卡片数。
  int remapWordIds(Map<int, int> oldToNew) {
    if (!_inited || config.cards.isEmpty) return 0;
    final List<({Card card, ReviewLog log})> remapped = [];
    int dropped = 0;
    for (final ({Card card, ReviewLog log}) entry in alignedCards()) {
      final int? neu = oldToNew[entry.card.cardId];
      if (neu == null) {
        dropped++;
        continue;
      }
      remapped.add((
        card: entry.card.copyWith(cardId: neu),
        log: ReviewLog(
          cardId: neu,
          rating: entry.log.rating,
          reviewDateTime: entry.log.reviewDateTime,
          reviewDuration: entry.log.reviewDuration,
        ),
      ));
    }
    setAlignedCards(remapped);
    logger.info("FSRS 重新映射词 id: 保留 ${remapped.length} 张，丢弃 $dropped 张");
    return dropped;
  }
}

@immutable
class FSRSConfig {
  final bool enabled;
  final Scheduler? scheduler;
  final List<Card> cards;
  final List<ReviewLog> reviewLogs;
  final double desiredRetention;
  final int easyDuration;
  final int goodDuration;
  final bool preferSimilar;
  final bool selfEvaluate;
  final int pushAmount;
  final bool reinforceMemory;

  /// 每日推送单词的分类筛选（AND 语义，空列表=不筛选）
  final List<String> pushCategories;

  /// 复习与每日推送随机使用的题型集合（每词随机取其一）。
  /// 0: 单词卡片；1: 中译阿 选择题；2: 阿译中 选择题；
  /// 3: 中译阿 拼写题；4: 听力题。
  /// 与学习页面的 `QuizConfig.questionSections` 相互独立。
  final List<int> reviewQuestionSections;

  FSRSConfig({
    bool? enabled,
    this.scheduler,
    List<Card>? cards,
    List<ReviewLog>? reviewLogs,
    double? desiredRetention,
    int? easyDuration,
    int? goodDuration,
    bool? preferSimilar,
    bool? selfEvaluate,
    int? pushAmount,
    bool? reinforceMemory,
    List<String>? pushCategories,
    List<int>? reviewQuestionSections
  }) :
    enabled = enabled??false,
    cards = cards??const [],
    reviewLogs = reviewLogs??const [],
    desiredRetention = desiredRetention??0.9,
    easyDuration = easyDuration??3000,
    goodDuration = goodDuration??6000,
    preferSimilar = preferSimilar??false,
    selfEvaluate = selfEvaluate??false,
    pushAmount = pushAmount??0,
    reinforceMemory = reinforceMemory??false,
    pushCategories = pushCategories??const [],
    reviewQuestionSections = _normalizeSections(reviewQuestionSections);

  /// 清洗题型集合：null/空/全部越界时回退到 `[2]`（保持旧行为），
  /// 否则仅保留 0-4 的合法题型。
  static List<int> _normalizeSections(List<int>? value) {
    if(value == null || value.isEmpty) return const [2];
    final List<int> filtered = value.where((int type) => type >= 0 && type <= 4).toList(growable: false);
    return filtered.isEmpty ? const [2] : filtered;
  }
  
  Map<String, dynamic> toMap(){
    return {
      'enabled': enabled,
      'scheduler': scheduler?.toMap() ?? {},
      'cards': List<Map>.generate(cards.length, (index) => cards[index].toMap(), growable: false),
      'reviewLog': List<Map>.generate(reviewLogs.length, (index) => reviewLogs[index].toMap(), growable: false),
      "desiredRetention": desiredRetention,
      "easyDuration": easyDuration,
      "goodDuration": goodDuration,
      "preferSimilar": preferSimilar,
      "selfEvaluate": selfEvaluate,
      "pushAmount": pushAmount,
      "reinforceMemory": reinforceMemory,
      "pushCategories": pushCategories,
      "reviewQuestionSections": reviewQuestionSections
    };
  }

  FSRSConfig copyWith({
    bool? enabled,
    Scheduler? scheduler,
    List<Card>? cards,
    List<ReviewLog>? reviewLogs,
    double? desiredRetention,
    int? easyDuration,
    int? goodDuration,
    bool? preferSimilar,
    bool? selfEvaluate,
    int? pushAmount,
    bool? reinforceMemory,
    List<String>? pushCategories,
    List<int>? reviewQuestionSections
  }) {
    return FSRSConfig(
      enabled: enabled??this.enabled,
      scheduler: scheduler??this.scheduler,
      cards: cards??this.cards,
      reviewLogs: reviewLogs??this.reviewLogs,
      desiredRetention: desiredRetention??this.desiredRetention,
      easyDuration: easyDuration??this.easyDuration,
      goodDuration: goodDuration??this.goodDuration,
      preferSimilar: preferSimilar??this.preferSimilar,
      selfEvaluate: selfEvaluate??this.selfEvaluate,
      pushAmount: pushAmount??this.pushAmount,
      reinforceMemory: reinforceMemory??this.reinforceMemory,
      pushCategories: pushCategories??this.pushCategories,
      reviewQuestionSections: reviewQuestionSections??this.reviewQuestionSections
    );
  }

  static FSRSConfig buildFromMap(Map<String, dynamic> configData){
    if(configData["enabled"]??false) {
      return FSRSConfig(
        enabled: configData["enabled"],
        scheduler: Scheduler.fromMap(configData["scheduler"]),
        cards: List<Card>.generate(configData["cards"].length,(index) => Card.fromMap(configData["cards"][index]), growable: true),
        reviewLogs: List<ReviewLog>.generate(configData["reviewLog"].length,(index) => ReviewLog.fromMap(configData["reviewLog"][index]), growable: true),
        desiredRetention: configData["desiredRetention"],
        easyDuration: configData["easyDuration"],
        goodDuration: configData["goodDuration"],
        preferSimilar: configData["preferSimilar"],
        selfEvaluate: configData["selfEvaluate"],
        pushAmount: configData["pushAmount"],
        reinforceMemory: configData["reinforceMemory"],
        pushCategories: configData["pushCategories"] == null
            ? const []
            : List<String>.from(configData["pushCategories"]),
        reviewQuestionSections: configData["reviewQuestionSections"] == null
            ? const [2]
            : _normalizeSections(List<int>.from(configData["reviewQuestionSections"]))
      );
    }
    return FSRSConfig(enabled: false);
  }
}