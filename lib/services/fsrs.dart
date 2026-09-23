import 'dart:convert';

import 'package:arabic_learning/services/app_data.dart';
import 'package:flutter/foundation.dart';
import 'package:fsrs/fsrs.dart';
import 'package:logging/logging.dart';

import 'package:arabic_learning/package_replacement/storage.dart';

class FSRS { 
  // 作为单例
  static final FSRS _instance = FSRS._internal();
  factory FSRS() => _instance;
  FSRS._internal();

  late FSRSConfig config;

  /// [config] 是否已加载。初始化前调用下面基于卡片的方法会安全返回 0。
  bool _inited = false;
  
  final Logger logger = Logger("FSRS");
  // index != cardId; cardId = wordId = the index of word in global.wordData[words]

  bool init() {
    logger.fine("构建FSRS模块");
    AppData appData = AppData();
    if(!appData.storage.containsKey("fsrsData")) {
      logger.info("未发现FSRS配置，加载默认配置");
      config = FSRSConfig();
      _inited = true;
      appData.storage.setString("fsrsData", jsonEncode(config.toMap()));
      return false;
    } else {
      config = FSRSConfig.buildFromMap(jsonDecode(appData.storage.getString("fsrsData")!));
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
        save();
      }
    }
    
    if(config.enabled) return true;
    logger.info("FSRS未启用");
    return false;
  }

  void save() async {
    logger.info("正在保存FSRS配置");
    AppData().storage.setString("fsrsData", jsonEncode(config.toMap()));
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