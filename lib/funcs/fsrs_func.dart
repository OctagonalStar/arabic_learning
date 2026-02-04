import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fsrs/fsrs.dart';
import 'package:logging/logging.dart';

import 'package:arabic_learning/package_replacement/storage.dart';

class FSRS { 
  late final SharedPreferences prefs;
  late FSRSConfig config;
  late final Logger logger;
  // index != cardId; cardId = wordId = the index of word in global.wordData[words]

  bool init({required SharedPreferences outerPrefs}) {
    prefs = outerPrefs;
    logger = Logger('FSRS');
    logger.fine("构建FSRS模块");

    if(!prefs.containsKey("fsrsData")) {
      logger.info("未发现FSRS配置，加载默认配置");
      config = FSRSConfig();
      prefs.setString("fsrsData", jsonEncode(config.toMap()));
      return false;
    } else {
      config = FSRSConfig.buildFromMap(jsonDecode(prefs.getString("fsrsData")!));
      logger.info("FSRS配置加载完成");
    }
    
    if(config.enabled) return true;
    logger.info("FSRS未启用");
    return false;
  }

  void save() async {
    logger.info("正在保存FSRS配置");
    prefs.setString("fsrsData", jsonEncode(config.toMap()));
  }

  void createScheduler({required SharedPreferences prefs}) {
    logger.info("初始化scheduler，选择相关配置 ${config.toMap().toString()}");
    config = config.copyWith(
      enabled: true,
      scheduler: Scheduler(desiredRetention: config.desiredRetention)
    );
    save();
  }

  int willDueIn(int index) {
    return config.cards[index].due.toLocal().difference(DateTime.now()).inDays;
  }

  void reviewCard(int wordId, int duration, bool isCorrect, {Rating? forceRate}) {
    logger.fine("记录复习卡片: Id: $wordId; duration: $duration; isCorrect: $isCorrect");
    int index = config.cards.indexWhere((Card card) => card.cardId == wordId); // 避免有时候cardId != wordId
    logger.fine("定位复习卡片地址: $index, 目前阶段: ${config.cards[index].step}, 难度: ${config.cards[index].difficulty}, 稳定: ${config.cards[index].stability}, 过期时间(+8): ${config.cards[index].due.toLocal()}");
    final (:card, :reviewLog) = config.scheduler!.reviewCard(config.cards[index], forceRate ?? calculate(duration, isCorrect), reviewDateTime: DateTime.now().toUtc(), reviewDuration: duration);
    config.cards[index] = card;
    config.reviewLogs[index] = reviewLog;
    logger.fine("卡片 $index 复习后: 目前阶段: ${config.cards[index].step}, 难度: ${config.cards[index].difficulty}, 稳定: ${config.cards[index].stability}, 过期时间(+8): ${config.cards[index].due.toLocal()}");
    save();
  }

  int getWillDueCount() {
    int dueCards = 0;
    for(int i = 0; i < config.cards.length; i++) {
      if(willDueIn(i) < 1) {
        dueCards++;
      }
    }
    return dueCards;
  }

  int getLeastDueCard() {
    int leastDueIndex = 0;
    for(int i = 1; i < config.cards.length; i++) {
      if(config.cards[i].due.toLocal().isBefore(config.cards[leastDueIndex].due.toLocal()) && config.cards[i].due.toLocal().difference(DateTime.now()) < Duration(days: 1)) {
        leastDueIndex = i;
      }
    }
    if(config.cards[leastDueIndex].due.difference(DateTime.now()) > Duration(days: 1)) return -1;
    return config.cards[leastDueIndex].cardId;
  }

  bool isContained(int wordId) {
    return config.cards.any((Card card) => card.cardId == wordId);
  }

  void addWordCard(int wordId) {
    logger.fine("添加复习卡片: Id: $wordId");
    // os the wordID == cardID
    config.cards.add(Card(cardId: wordId, state: State.learning));
    config.reviewLogs.add(ReviewLog(cardId: wordId, rating: Rating.good, reviewDateTime: DateTime.now()));
    save();
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

  const FSRSConfig({
    bool? enabled,
    this.scheduler,
    List<Card>? cards,
    List<ReviewLog>? reviewLogs,
    double? desiredRetention,
    int? easyDuration,
    int? goodDuration,
    bool? preferSimilar,
    bool? selfEvaluate
  }) :
    enabled = enabled??false,
    cards = cards??const [],
    reviewLogs = reviewLogs??const [],
    desiredRetention = desiredRetention??0.9,
    easyDuration = easyDuration??3000,
    goodDuration = goodDuration??6000,
    preferSimilar = preferSimilar??false,
    selfEvaluate = selfEvaluate??false;
  
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
      "selfEvaluate": selfEvaluate
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
    bool? selfEvaluate
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
      selfEvaluate: selfEvaluate??this.selfEvaluate
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
        selfEvaluate: configData["selfEvaluate"]
      );
    }
    return FSRSConfig(enabled: false);
  }
}