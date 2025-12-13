import 'dart:convert';

import 'package:arabic_learning/funcs/utili.dart';
import 'package:fsrs/fsrs.dart';
import 'package:logging/logging.dart';

import 'package:arabic_learning/package_replacement/storage.dart';

class FSRS { 
  List<Card> cards = [];
  List<ReviewLog> reviewLogs = [];
  late Scheduler scheduler;
  late final SharedPreferences prefs;
  late Map<String, dynamic> settingData;
  late final Logger logger;
  // index != cardId; cardId = wordId = the index of word in global.wordData[words]

  bool init({required SharedPreferences outerPrefs}) {
    prefs = outerPrefs;
    logger = Logger('FSRS');
    logger.fine("构建FSRS模块");
    settingData = {
      'enabled': false,
      'scheduler': {},
      'cards': [],
      'reviewLog': [],
      'rater': {
        "desiredRetention": 0.9,
        "easyDuration": 3000,
        "goodDuration": 6000
      },
    };

    if(!prefs.containsKey("fsrsData")) {
      logger.info("未发现FSRS配置，加载默认配置");
      prefs.setString("fsrsData", jsonEncode(settingData));
      return false;
    } else {
      settingData = deepMerge(settingData, jsonDecode(prefs.getString("fsrsData")!));
    }
    
    if(isEnabled()){
      scheduler = Scheduler.fromMap(settingData['scheduler']);
      for(int i = 0; i < settingData['cards'].length; i++) {
        cards.add(Card.fromMap(settingData['cards'][i]));
        reviewLogs.add(ReviewLog.fromMap(settingData['reviewLog'][i]));
      }
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

  void createScheduler({required SharedPreferences prefs}) {
    logger.info("初始化scheduler，选择相关配置 ${settingData["rater"].toString()}");
    scheduler = Scheduler(desiredRetention: settingData["rater"]["desiredRetention"]);
    settingData['enabled'] = true;
    settingData['scheduler'] = scheduler.toMap();
    save();
  }

  int willDueIn(int index) {
    return cards[index].due.toLocal().difference(DateTime.now()).inDays;
  }

  void reviewCard(int wordId, int duration, bool isCorrect) {
    logger.fine("记录复习卡片: Id: $wordId; duration: $duration; isCorrect: $isCorrect");
    int index = cards.indexWhere((Card card) => card.cardId == wordId); // 避免有时候cardId != wordId
    logger.fine("定位复习卡片地址: $index, 目前阶段: ${cards[index].step}, 难度: ${cards[index].difficulty}, 稳定: ${cards[index].stability}, 过期时间(+8): ${cards[index].due.toLocal()}");
    final (:card, :reviewLog) = scheduler.reviewCard(cards[index], calculate(duration, isCorrect), reviewDateTime: DateTime.now().toUtc(), reviewDuration: duration);
    cards[index] = card;
    reviewLogs[index] = reviewLog;
    logger.fine("卡片 $index 复习后: 目前阶段: ${cards[index].step}, 难度: ${cards[index].difficulty}, 稳定: ${cards[index].stability}, 过期时间(+8): ${cards[index].due.toLocal()}");
    save();
  }

  int getWillDueCount() {
    int dueCards = 0;
    for(int i = 0; i < cards.length; i++) {
      if(willDueIn(i) < 1) {
        dueCards++;
      }
    }
    return dueCards;
  }

  int getLeastDueCard() {
    int leastDueIndex = 0;
    for(int i = 1; i < cards.length; i++) {
      if(cards[i].due.toLocal().isBefore(cards[leastDueIndex].due.toLocal()) && cards[i].due.toLocal().difference(DateTime.now()) < Duration(days: 1)) {
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

  Rating calculate(int duration, bool isCorrect) {
    // duration in milliseconds
    if (!isCorrect) {
      logger.fine("计算得分: again");
      return Rating.again;
    }
    if (duration < settingData['rater']['easyDuration']) {
      logger.fine("计算得分: easy");
      return Rating.easy;
    }
    if (duration < settingData['rater']['goodDuration']) {
      logger.fine("计算得分: good");
      return Rating.good;
    }
    logger.fine("计算得分: hard");
    return Rating.hard;
  }
}