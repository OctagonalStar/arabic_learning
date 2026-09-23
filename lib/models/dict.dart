// 词库数据模型：DictData / SourceItem / ClassItem / WordItem
// （原 lib/vars/config_structure.dart 拆分）。

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show immutable;

@immutable
class DictData {
  final List<WordItem> words;
  final List<SourceItem> classes;

  const DictData({
    required this.words,
    required this.classes
  });

  static DictData buildFromMap(Map<String, dynamic> data) {
    List<WordItem> wordsData = [];
    for(Map<String, dynamic> x in data["Words"]) {
      wordsData.add(WordItem.buildFromMap(x, wordsData.length));
    }
    List<SourceItem> classesData = [];
    for(String sourceName in (data["Classes"] as Map<String, dynamic>).keys) {
      classesData.add(SourceItem.buildFromMap(data["Classes"][sourceName], sourceName));
    }
    return DictData(words: wordsData, classes: classesData);
  }
  
  Map<String, dynamic> toMap(){
    List<Map<String, dynamic>> wordList = [];
    for(WordItem word in words){
      wordList.add(word.toMap());
    }
    Map<String, dynamic> classMap = {};
    for(SourceItem source in classes){
      classMap[source.sourceJsonFileName] = source.toMap();
    }
    return {
      "Words": wordList,
      "Classes": classMap
    };
  }
}

@immutable
class SourceItem {
  final String sourceJsonFileName;

  /// 展示名称：新格式词库取自元数据 name；旧数据为空时回退到文件名
  final String displayName;

  final List<ClassItem> subClasses;

  const SourceItem({
    required this.sourceJsonFileName,
    this.displayName = "",
    required this.subClasses
  });

  /// UI 展示用名称（含旧数据回退）
  String get name => displayName.isNotEmpty ? displayName : sourceJsonFileName;

  static SourceItem buildFromMap(Map<String, dynamic> data, String sourceJsonFileName) {
    List<ClassItem> classes = [];
    String displayName = "";
    // 新格式：{"displayName": "...", "classes": {className: [index...]}}
    // 旧格式：直接就是 {className: [index...]}
    if(data["classes"] is Map) {
      displayName = (data["displayName"] as String?) ?? "";
      Map<String, dynamic> classesMap = Map<String, dynamic>.from(data["classes"] as Map);
      for(String className in classesMap.keys) {
        classes.add(ClassItem(className: className, wordIndexs: List<int>.from(classesMap[className])));
      }
    } else {
      for(String className in data.keys) {
        classes.add(ClassItem(className: className, wordIndexs: List<int>.from(data[className])));
      }
    }
    return SourceItem(sourceJsonFileName: sourceJsonFileName, displayName: displayName, subClasses: classes);
  }

  Map<String, dynamic> toMap(){
    Map<String, List<int>> classesMap = {};
    for(ClassItem classItem in subClasses) {
      classesMap[classItem.className] = classItem.wordIndexs;
    }
    return {
      "displayName": displayName,
      "classes": classesMap
    };
  }

  String getHash(List<WordItem> words) {
    return sha256.convert(utf8.encode(sourceJsonFileName)).toString();
  }
}

@immutable
class ClassItem {
  final String className;
  final List<int> wordIndexs;

  const ClassItem({
    required this.className,
    required this.wordIndexs
  });

  @override
  String toString() {
    return className;
  }

  String getHash() {
    return sha256.convert(utf8.encode(toString())).toString();
  }
}

@immutable
class WordItem {
  final String arabic;
  final String chinese;
  final String explanation;
  final String className;
  final int id;

  /// 词根，仅含词根字母、以空格分隔（新大纲词库提供，旧词库为空）
  final String root;

  /// 分类标签，如 ["四级","常用词"] / ["补充","生僻词","短语"]（不硬编码分组）
  final List<String> categories;

  /// 词性标注（Nominals / Verbs / Phrases and Clauses / Particles / Adverbial Expressions）
  final String pos;

  /// 名词复数（仅 Nominals 有意义）
  final String plural;

  /// 名词阴阳性：true 阳性 / false 阴性 / null 未知（旧数据）
  final bool? gender;

  /// 动词现在时第三人称（仅 Verbs 有意义）
  final String present;

  /// 动词动名词（仅 Verbs 有意义）
  final String masdar;

  const WordItem({
    required this.arabic,
    required this.chinese,
    required this.explanation,
    required this.className,
    required this.id,
    this.root = "",
    this.categories = const [],
    this.pos = "",
    this.plural = "",
    this.gender,
    this.present = "",
    this.masdar = ""
  });

  /// 名词词性标识：仅名词具有阴阳性。
  static const String posNominals = "Nominals";

  /// 规范化阴阳性：仅名词（[posNominals]）保留 [gender]；其余已知非名词词性的
  /// `gender` 在词库中仅为占位值（恒为 true），一律置空。`pos` 为空表示词性
  /// 未知（旧数据），无法判定，原样保留。
  static bool? normalizeGender(String pos, bool? gender) {
    if (pos.isEmpty) return gender;
    return pos == posNominals ? gender : null;
  }

  /// 复制并仅替换阴阳性，其余字段不变。
  WordItem withGender(bool? gender) {
    return WordItem(
      arabic: arabic,
      chinese: chinese,
      explanation: explanation,
      className: className,
      id: id,
      root: root,
      categories: categories,
      pos: pos,
      plural: plural,
      gender: gender,
      present: present,
      masdar: masdar,
    );
  }

  /// 用新导入的 [incoming] 补充本词条（一词多词库命中时调用）：
  /// - 词形字段（root/pos/plural/present/masdar）非空即覆盖本地值；gender 非 null 即覆盖；
  /// - categories 取并集；
  /// - explanation 仅当本词条为空时采用 incoming；
  /// - arabic / chinese / className / id 始终保留本地值（释义不合并，归属由反查索引表达）；
  /// - 合并后的词性若非名词（[posNominals]），其 gender 一律规范化为 null。
  WordItem supplement(WordItem incoming) {
    final String mergedPos = incoming.pos.isNotEmpty ? incoming.pos : pos;
    final bool? mergedGender = incoming.gender ?? gender;
    return WordItem(
      arabic: arabic,
      chinese: chinese,
      explanation: explanation.isNotEmpty ? explanation : incoming.explanation,
      className: className,
      id: id,
      root: incoming.root.isNotEmpty ? incoming.root : root,
      categories: <String>{...categories, ...incoming.categories}.toList(growable: false),
      pos: mergedPos,
      plural: incoming.plural.isNotEmpty ? incoming.plural : plural,
      gender: normalizeGender(mergedPos, mergedGender),
      present: incoming.present.isNotEmpty ? incoming.present : present,
      masdar: incoming.masdar.isNotEmpty ? incoming.masdar : masdar,
    );
  }

  Map<String, dynamic> toMap(){
    return {
      "arabic": arabic,
      "chinese": chinese,
      "explanation": explanation,
      "subClass": className,
      // 以下字段仅在有值时写出，保证旧数据序列化结果不变、控制存储体积
      if(root.isNotEmpty) "root": root,
      if(categories.isNotEmpty) "categories": categories,
      if(pos.isNotEmpty) "pos": pos,
      if(plural.isNotEmpty) "plural": plural,
      if(gender != null) "gender": gender,
      if(present.isNotEmpty) "present": present,
      if(masdar.isNotEmpty) "masdar": masdar,
    };
  }

  @override
  String toString() {
    return jsonEncode(toMap());
  }
  
  static WordItem buildFromMap(Map<String, dynamic> word, int id){
    return WordItem(
      arabic: word["arabic"] ?? "", 
      chinese: word["chinese"] ?? "", 
      explanation: word["explanation"] ?? "", 
      className: word["subClass"] ?? "",
      id: id,
      root: word["root"] ?? "",
      categories: word["categories"] == null ? const [] : List<String>.from(word["categories"]),
      pos: word["pos"] ?? "",
      plural: word["plural"] ?? "",
      gender: word["gender"] as bool?,
      present: word["present"] ?? "",
      masdar: word["masdar"] ?? "",
    );
  }
}
