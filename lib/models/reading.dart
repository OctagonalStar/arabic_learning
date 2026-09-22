// 阅读题数据模型：ReadingData / ClassSelection / ReadingUnit / ReadingQuestion
// （原 lib/vars/config_structure.dart 拆分）。

import 'dart:convert';
import 'dart:typed_data' show Uint8List;

import 'package:arabic_learning/models/dict.dart' show ClassItem;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show immutable;

@immutable
class ReadingData {
  final List<ReadingUnit> units;

  const ReadingData({required this.units});

  Map<String, dynamic> toMap(){
    List<Map<String, dynamic>> units = [];
    for(ReadingUnit x in this.units){
      units.add(x.toMap());
    }
    return {
      "units": units
    };
  }

  static ReadingData buildFromMap(Map<String, dynamic> data){
    List<ReadingUnit> units = [];
    for(Map<String, dynamic> x in data["units"]){
      units.add(ReadingUnit.buildFromMap(x));
    }
    return ReadingData(units: units);
  }
}

class ClassSelection {
  List<ClassItem> selectedClass;
  bool countInReview;

  ClassSelection({
    required this.selectedClass,
    required this.countInReview
  });
}

@immutable
class ReadingUnit {
  /// 1:阅读 2:完形
  final int type;

  final String title;

  final String passage;

  final int difficulty;

  final bool tashkeel;

  final List<ReadingQuestion> questions;

  final List<int> corrects;

  final List<String> tags;

  const ReadingUnit({
    required this.type,
    required this.title,
    required this.passage,
    required this.difficulty,
    required this.tashkeel,
    required this.questions,
    required this.corrects,
    required this.tags
  });

  Map<String, dynamic> toMap({bool export = false}){
    List<Map<String, dynamic>> questionsList = [];
    for(ReadingQuestion x in questions){
      questionsList.add(x.toMap());
    }
    return {
      "type": type,
      "title": title,
      "passage": passage,
      "difficulty": difficulty,
      "tashkeel": tashkeel,
      "questions": questionsList,
      "tags": tags,
      if(!export) "corrects": corrects
    };
  } 

  static ReadingUnit buildFromMap(Map<String, dynamic> unit, {int? type, bool? tashkeel}){
    List<ReadingQuestion> questions = [];
    for(Map<String, dynamic> x in unit["questions"]){
      questions.add(ReadingQuestion.buildFromMap(x));
    }
    if(unit["type"] == null && type == null) throw Exception("Null Question Type");
    if(unit["tashkeel"] == null && tashkeel == null) throw Exception("Null Tashkeel Type");
    return ReadingUnit(
      type: unit["type"] ?? type, 
      title: unit["title"], 
      passage: unit["passage"], 
      difficulty: unit["difficulty"], 
      tashkeel: unit["tashkeel"] ?? tashkeel, 
      questions: questions, 
      tags: List<String>.from(unit["tags"] ?? []),
      corrects: List<int>.from(unit["corrects"] ?? [])
    );
  }

  List<int> getHash() {
    String test = "$type$title;$passage;$difficulty;$tashkeel";
    for(ReadingQuestion x in questions){
      test = "$test;${x.riddle}";
    }
    Uint8List bytes = utf8.encode(test);
    Digest digest = sha1.convert(bytes);

    return digest.bytes;
  }
}

@immutable
class ReadingQuestion {
  final String riddle;
  final List<String> answers;
  final String type;
  final String analysis;

  const ReadingQuestion({
    required this.riddle,
    required this.answers,
    required this.type,
    required this.analysis
  });

  Map<String, dynamic> toMap(){
    return {
      "riddle": riddle,
      "answers": answers,
      "type": type,
      "analysis": analysis
    };
  }

  static ReadingQuestion buildFromMap(Map<String, dynamic> question){
    return ReadingQuestion(
      riddle: question["riddle"], 
      answers: List<String>.from(question["answers"]), 
      type: question["type"], 
      analysis: question["analysis"]
    );
  }
}
