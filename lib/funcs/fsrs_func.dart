import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fsrs/fsrs.dart';

class FSRS { 
  List<Card> cards = [];
  List<ReviewLog> reviewLogs = [];
  late Scheduler scheduler;
  late SharedPreferences prefs;
  late Rater rater;
  late Map<String, dynamic> settingData;

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    if(!prefs.containsKey("fsrsData")) {
      settingData = {
        'enabled': false,
        'scheduler': {},
        'cards': [],
        'reviewLog': [],
        'rater': {'scheme': 0},
      };
      prefs.setString("fsrsData", jsonEncode(settingData));
      return;
    }
    settingData = jsonDecode(prefs.getString("fsrsData")!) as Map<String, dynamic>;
    if(isEnabled()){
      scheduler = Scheduler.fromMap(settingData['scheduler']);
      for(int i = 0; i < settingData['cards'].length; i++) {
        cards.add(Card.fromMap(settingData['cards'][i]));
        reviewLogs.add(ReviewLog.fromMap(settingData['reviewLog'][i]));
      }
      rater = Rater(settingData['rater']['scheme']);
    }
  }

  void save() async {
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

  Future<void> createScheduler(int scheme) async {
    await init();
    List<double> desiredRetention = [0.85, 0.9, 0.95, 0.95, 0.99];
    scheduler = Scheduler(desiredRetention: desiredRetention[scheme]);
    settingData['rater']['scheme'] = scheme;
    settingData['enabled'] = true;
    settingData['scheduler'] = scheduler.toMap();
    rater = Rater(scheme);
    save();
  }

  int willDue(int index) {
    return cards[index].due.difference(DateTime.now()).inDays;
  }

  void reviewCard(int index, int duration, bool isCorrect) {
    final (:card, :reviewLog) = scheduler.reviewCard(cards[index], rater.calculate(duration, isCorrect));
    cards[index] = card;
    reviewLogs[index] = reviewLog;
    save();
  }

  List<int> getWillDueCards() {
    List<int> dueCards = [];
    for(int i = 0; i < cards.length; i++) {
      if(willDue(i) == 0) {
        dueCards.add(i);
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
    return leastDueIndex;
  }

  bool isContained(int wordID) {
    for(Card card in cards) {
      if(card.cardId == wordID) return true;
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