import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fsrs/fsrs.dart';

class FSRS { 
  late Scheduler scheduler;
  List<Card> cards = [];
  List<ReviewLog> reviewLogs = [];
  late SharedPreferences prefs;
  late Rater rater;


  void init() async {
    prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> settingData = jsonDecode(prefs.getString("fsrsData")!) as Map<String, dynamic>;
    if(settingData['enabled']){
      scheduler = Scheduler.fromMap(settingData['scheduler']);
      for(int i = 0; i < settingData['cards'].length; i++) {
        cards.add(Card.fromMap(settingData['cards'][i]));
        reviewLogs.add(ReviewLog.fromMap(settingData['reviewLog'][i]));
      }
      rater = Rater(scheme: settingData['rater']['scheme']);
    }
  }

  void save() async {
    Map<String, dynamic> settingData = {
      'enabled': true,
      'scheduler': scheduler.toMap(),
      'cards': cards.map((e) => e.toMap()).toList(),
      'reviewLog': reviewLogs.map((e) => e.toMap()).toList(),
    };
    prefs.setString("fsrsData", jsonEncode(settingData));
  }

  void createScheduler({double desiredRetention = 0.9,}) {
    scheduler = Scheduler(desiredRetention: desiredRetention);
  }

  int willDue(int index) {
    return cards[index].due.difference(DateTime.now()).inDays;
  }

  void reviewCard(int index, Rating rating) {
    final (:card, :reviewLog) = scheduler.reviewCard(cards[index], rating);
    cards[index] = card;
    reviewLogs[index] = reviewLog;
    save();
  }

  List<int> getWillDueCards() {
    List<int> dueCards = [];
    for(int i = 0; i < cards.length; i++) {
      if(willDue(i) <= 1) {
        dueCards.add(i);
      }
    }
    return dueCards;
  }

  void addWordCard(int wordId, Rating initialRating) {
    // os the wordID == cardID
    cards.add(Card(cardId: wordId));
    reviewLogs.add(ReviewLog(cardId: wordId, rating: initialRating, reviewDateTime: DateTime.now()));
    save();
  }
}

class Rater {
  Rating get easy => Rating.easy;
  Rating get good => Rating.good;
  Rating get hard => Rating.hard;
  Rating get forget => Rating.again;

  late int scheme;

  Rater({this.scheme = 3});

  static const List<List<int>> _difficultyScheme = [
    [2000, 8000], // Easy
    [1000, 5000], // Fine
    [800, 3000], // OK~
    [500, 1600], // Emm...
    [300, 1000], // Impossible
  ];

  Rating calculate(double duration, bool isCorrect) {
    // duration in milliseconds
    if (!isCorrect) return Rating.again;
    if (duration < _difficultyScheme[scheme][0]) return Rating.easy;
    if (duration < _difficultyScheme[scheme][1]) return Rating.good;
    return Rating.hard;
  }
}