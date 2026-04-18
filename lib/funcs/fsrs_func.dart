import 'dart:convert';

import 'package:arabic_learning/vars/global.dart';
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
  
  final Logger logger = Logger("FSRS");
  // index != cardId; cardId = wordId = the index of word in global.wordData[words]

  bool init() {
    logger.fine("构建FSRS模块");
    AppData appData = AppData();
    if(!appData.storage.containsKey("fsrsData")) {
      logger.info("未发现FSRS配置，加载默认配置");
      config = FSRSConfig();
      appData.storage.setString("fsrsData", jsonEncode(config.toMap()));
      return false;
    } else {
      config = FSRSConfig.buildFromMap(jsonDecode(appData.storage.getString("fsrsData")!));
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

  int getLeastDueCard() {
    Card? leastDueCard;
    for(Card card in config.cards) {
      if(willDueIn(card) < 1) {
        if(leastDueCard == null || card.due.toLocal().isBefore(leastDueCard.due.toLocal())) {
          leastDueCard = card;
        }
      }
    }
    if (leastDueCard == null) return -1;
    return leastDueCard.cardId;
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
  final List<String> selectedSources;

  const FSRSConfig({
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
    List<String>? selectedSources
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
    selectedSources = selectedSources??const [];
  
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
      "selectedSources": selectedSources
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
    List<String>? selectedSources
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
      selectedSources: selectedSources??this.selectedSources
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
        selectedSources: configData["selectedSources"] == null ? const [] : List<String>.from(configData["selectedSources"])
      );
    }
    return FSRSConfig(enabled: false);
  }
}