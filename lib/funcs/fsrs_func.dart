import 'dart:convert';

import 'package:arabic_learning/vars/global.dart';
import 'package:flutter/material.dart' show BuildContext;
import 'package:fsrs/fsrs.dart';
import 'package:logging/logging.dart';

import 'package:arabic_learning/package_replacement/storage.dart';
import 'package:provider/provider.dart';

class FSRS { 
  List<Card> cards = [];
  List<ReviewLog> reviewLogs = [];
  late Scheduler scheduler;
  late SharedPreferences prefs;
  late Rater rater;
  late Map<String, dynamic> settingData;
  late final Logger logger;
  // index != cardId; cardId = wordId = the index of word in global.wordData[words]

  Future<bool> init({BuildContext? context}) async {
    logger = Logger('FSRS');
    logger.fine("构建FSRS模块");
    prefs = context==null ? await SharedPreferences.getInstance() : context.read<Global>().prefs;
    if(!prefs.containsKey("fsrsData")) {
      logger.info("未发现FSRS配置，加载默认配置");
      settingData = {
        'enabled': false,
        'scheduler': {},
        'cards': [],
        'reviewLog': [],
        'rater': {'scheme': 0},
      };
      prefs.setString("fsrsData", jsonEncode(settingData));
      return false;
    }
    settingData = jsonDecode(prefs.getString("fsrsData")!) as Map<String, dynamic>;
    if(isEnabled()){
      scheduler = Scheduler.fromMap(settingData['scheduler']);
      for(int i = 0; i < settingData['cards'].length; i++) {
        cards.add(Card.fromMap(settingData['cards'][i]));
        reviewLogs.add(ReviewLog.fromMap(settingData['reviewLog'][i]));
      }
      rater = Rater(settingData['rater']['scheme']);
      logger.info("FSRS配置加载完成");
      return true;
    }
    logger.info("FSRS未启用");
    return false;
  }

  void save() async {
    logger.info("正在保存FSRS配置");
    settingData['scheduler'] = scheduler.toMap();
    List cardsCache = [];
    List logCache = [];
    for(int i = 0; i < cards.length; i++) {
      cardsCache.add(cards[i].toMap());
      logCache.add(reviewLogs[i].toMap());
    }
    settingData['cards'] = cardsCache;
    settingData['reviewLog'] = logCache;
    prefs.setString("fsrsData", jsonEncode(settingData));
  }

  bool isEnabled() {
    return settingData['enabled'];
  }

  Future<void> createScheduler(int scheme, {BuildContext? context}) async {
    await init(context: context);
    logger.info("初始化scheduler，选择方案 $scheme");
    List<double> desiredRetention = [0.85, 0.9, 0.95, 0.95, 0.99];
    scheduler = Scheduler(desiredRetention: desiredRetention[scheme]);
    settingData['rater']['scheme'] = scheme;
    settingData['enabled'] = true;
    settingData['scheduler'] = scheduler.toMap();
    rater = Rater(scheme);
    save();
  }

  int willDueIn(int index) {
    return cards[index].due.difference(DateTime.now()).inDays;
  }

  void reviewCard(int wordId, int duration, bool isCorrect) {
    logger.fine("记录复习卡片: Id: $wordId; duration: $duration; isCorrect: $isCorrect");
    int index = cards.indexWhere((Card card) => card.cardId == wordId); // 避免有时候cardId != wordId
    logger.fine("定位复习卡片地址: $index, 目前阶段: ${cards[index].step}, 难度: ${cards[index].difficulty}, 稳定: ${cards[index].stability}, 过期时间(+8): ${cards[index].due.toLocal()}");
    final (:card, :reviewLog) = scheduler.reviewCard(cards[index], rater.calculate(duration, isCorrect), reviewDateTime: DateTime.now().toUtc(), reviewDuration: duration);
    logger.fine("卡片 $index 复习后: 目前阶段: ${cards[index].step}, 难度: ${cards[index].difficulty}, 稳定: ${cards[index].stability}, 过期时间(+8): ${cards[index].due.toLocal()}");
    cards[index] = card;
    reviewLogs[index] = reviewLog;
    save();
  }

  int getWillDueCount() {
    int dueCards = 0;
    for(int i = 0; i < cards.length; i++) {
      if(willDueIn(i) == 0) {
        dueCards++;
      }
    }
    return dueCards;
  }

  int getLeastDueCard() {
    int leastDueIndex = 0;
    for(int i = 1; i < cards.length; i++) {
      if(cards[i].due.isBefore(cards[leastDueIndex].due) && cards[i].due.difference(DateTime.now()) < Duration(days: 1)) {
        leastDueIndex = i;
      }
    }
    if(cards[leastDueIndex].due.difference(DateTime.now()) > Duration(days: 1)) return -1;
    return cards[leastDueIndex].cardId;
  }

  bool isContained(int wordId) {
    for(Card card in cards) {
      if(card.cardId == wordId) return true;
    }
    return false;
  }

  void addWordCard(int wordId) {
    // os the wordID == cardID
    cards.add(Card(cardId: wordId, state: State.learning));
    reviewLogs.add(ReviewLog(cardId: wordId, rating: Rating.good, reviewDateTime: DateTime.now()));
    save();
  }
}

class Rater {
  Rating get easy => Rating.easy;
  Rating get good => Rating.good;
  Rating get hard => Rating.hard;
  Rating get forget => Rating.again;

  late int scheme;

  Rater(this.scheme);

  static const List<List<int>> _difficultyScheme = [
    [3000, 8000], // Easy
    [2000, 6000], // Fine
    [1500, 4000], // OK~
    [1000, 2000], // Emm...
    [1000, 1500], // Impossible
  ];

  Rating calculate(int duration, bool isCorrect) {
    // duration in milliseconds
    if (!isCorrect) return Rating.again;
    if (duration < _difficultyScheme[scheme][0]) return Rating.easy;
    if (duration < _difficultyScheme[scheme][1]) return Rating.good;
    return Rating.hard;
  }
}