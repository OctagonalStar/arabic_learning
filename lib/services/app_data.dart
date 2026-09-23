// 全局应用数据单例（原 lib/vars/global.dart 拆分）。
// 承载 AppData（存储访问 / 词库导入 / TTS 模型加载）与词库导入结果 DictImportResult。

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:fsrs/fsrs.dart' show Card, ReviewLog;
import 'package:path_provider/path_provider.dart' as path_provider;

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/models/config.dart' show Config;
import 'package:arabic_learning/models/dict.dart' show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/models/reading.dart' show ReadingData;
import 'package:arabic_learning/models/synonym.dart' show SynonymData;
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/memberships.dart';
import 'package:arabic_learning/services/push_session.dart';
import 'package:arabic_learning/services/search.dart';
import 'package:arabic_learning/services/synonyms.dart';
import 'package:arabic_learning/package_replacement/storage.dart';
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/package_replacement/fake_sherpa_onnx.dart' if (dart.library.io) 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

/// 词库导入结果摘要
class DictImportResult {
  /// 成功导入的有效词条数（不含因阿语/中文为空而跳过的词条）
  final int importedCount;

  /// 因阿语或中文为空而跳过的词条数
  final int skippedCount;

  /// 导入的课程（class）数量
  final int classCount;

  /// 实际使用的词库名称（优先元数据 name，回退文件名）
  final String sourceName;

  /// 是否为 JSONL 格式
  final bool isJsonl;

  const DictImportResult({
    required this.importedCount,
    required this.skippedCount,
    required this.classCount,
    required this.sourceName,
    required this.isJsonl,
  });

  String get message =>
      "导入词条: $importedCount\n跳过无效词条: $skippedCount\n课程数: $classCount\n词库名称: $sourceName";
}

class AppData {
  // 作为单例
  static final AppData _instance = AppData._internal();
  factory AppData() => _instance;
  AppData._internal();

  bool inited = false;
  Logger logger = Logger("AppData");

  List<String> internalLogCapture = [];
  Config config = Config();

  late final SharedPreferences storage;
  late final io.Directory basePath;
  late DictData wordData;
  late ReadingData readingData;
  sherpa_onnx.OfflineTts? vitsTTS;

  /// 「重置词库但保留复习进度」流程中暂存的卡片（仅内存，进程内有效）。
  List<({int oldId, String identity, Card card, ReviewLog log})>? _pendingFsrsRestore;
  
  int get wordCount => wordData.words.length;
  bool get isFirstStart => storage.getString("settingData") == null;
  bool get modelTTSDownloaded => io.File("${basePath.path}/${StaticsVar.modelPath}/ar_JO-kareem-medium.onnx").existsSync();

  Future<void> init() async {
    if(inited) return;
    storage = await SharedPreferences.getInstance();
    if(!kIsWeb) {
      basePath = (await path_provider.getApplicationDocumentsDirectory()) as io.Directory;
    }

    if(!isFirstStart) {
      wordData = DictData.buildFromMap(jsonDecode(storage.getString("wordData")!));
      if (normalizeWordGenders()) {
        storage.setString("wordData", jsonEncode(wordData.toMap()));
      }
      readingData = ReadingData.buildFromMap(jsonDecode(storage.getString("readingData") ?? "{\"units\": []}"));
      if(!BKSearch.isReady) BKSearch.init(wordData.words);
      WordMembershipIndex.instance.rebuild(wordData.classes);
      FSRS().init();
    }
    SynonymStore().init();
    inited = true;
  }

  Future<void> initStorageValue() async {
      await storage.setString("wordData", jsonEncode({"Words": [], "Classes": {}}));
      await storage.setString("readingData", jsonEncode({"units": []}));
      await storage.setString("synonymData", jsonEncode(const SynonymData().toMap()));
      wordData = DictData(words: [], classes: []);
      WordMembershipIndex.instance.rebuild(wordData.classes);
      logger.info("配置表初始化完成");
  }

  // load TTS model if any
  Future<void> loadTTS(double playRate) async {
    if(kIsWeb || vitsTTS != null || !modelTTSDownloaded) return;
    logger.info("TTS: 加载本地TTS中");
    sherpa_onnx.initBindings();
    final vits = sherpa_onnx.OfflineTtsVitsModelConfig(
      model: "${basePath.path}/${StaticsVar.modelPath}/ar_JO-kareem-medium.onnx",
      dataDir: "${basePath.path}/${StaticsVar.modelPath}/espeak-ng-data",
      tokens: '${basePath.path}/${StaticsVar.modelPath}/tokens.txt',
      lengthScale: 1 / playRate,
    );
    final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
      vits: vits,
      numThreads: 2,
      debug: false,
      provider: 'cpu',
    );
    final config = sherpa_onnx.OfflineTtsConfig(
      model: modelConfig,
      maxNumSenetences: 1,
    );

    vitsTTS = sherpa_onnx.OfflineTts(config);
    logger.info("TTS: 本地TTS加载完成");
  }

  /// Non-Format Data:
  /// {
  ///    "ClassName": [
  ///       {
  ///        "chinese": {Chinese},
  ///        "arabic": {arabic},
  ///        "explanation": {explanation}
  ///       }, ...
  ///    ]
  /// }
  /// Format Data:
  /// {
  ///    "Words" : [
  ///      {
  ///        "arabic": {arabic},
  ///        "chinese": {Chinese},
  ///        "explanation": {explanation},
  ///        "subClass": {ClassName},
  ///        "learningProgress": {times} //int
  ///       }, ...
  ///   ],
  ///   "Classes": {
  ///        "SourceJsonFileName": {
  ///          "ClassName": [wordINDEX],
  ///        }
  ///    }
  /// }
  /// 将[data]（`{类名: [词条...]}`）格式化为[DictData]。
  ///
  /// 兼容旧版JSON词库与新JSONL词库（解析后结构一致）：
  /// - `explanation` 依次取 `explanation` / `example`；
  /// - `root`、`categories` 及 `properties` 中的词性/复数/阴阳性/现在时/动名词缺省时使用默认值；
  /// - 阿拉伯语或中文为空的词条会被跳过并计入[skipped]；
  /// - 命中的已有词条会用新词库的词形信息补充/覆盖（新库优先）：`root`/`pos`/`plural`/
  ///   `present`/`masdar` 非空即覆盖，`gender` 非 null 即覆盖，`categories` 取并集，
  ///   `explanation` 仅在旧值为空时填入；`arabic`/`chinese`/`className`/`id` 保留旧值。
  ///
  /// [displayName] 为词库展示名（旧版JSON为空）；
  /// 同名`sourceName`再次导入时会替换旧源数据而不是追加课程。
  ({DictData data, int imported, int skipped}) dataFormater(
    Map<String, dynamic> data,
    DictData existData,
    String sourceName, {
    String displayName = "",
  }) {
    logger.info("开始词汇格式化");
    
    // 精确阿语串 -> 词下标（同一串视为同词，保留原有复用行为）
    final Map<String, int> rawWordMap = {};
    // 保守身份键 -> 候选词下标列表；命中后仍需逐个做严格释义比对才合并
    final Map<String, List<int>> identityMap = {};
    final List<String> chineseList = [];
    for(int i = 0; i < existData.words.length; i++) {
      WordItem x = existData.words[i];
      rawWordMap[x.arabic] = i;
      (identityMap[x.arabic.identityKey()] ??= <int>[]).add(i);
      chineseList.add(x.chinese); // Keep list for indexing since it maps 1:1 with word id
    }
    
    int counter = existData.words.length;
    int imported = 0;
    int skipped = 0;

    // 查找已有数据中是否有同名的源数据组；
    // 同名导入时替换旧源（清空旧 subClasses，避免重复课程）。
    int exSourceIndex = existData.classes.indexWhere(
      (SourceItem x) => x.sourceJsonFileName == sourceName,
    );
    if(exSourceIndex == -1){
      existData.classes.add(SourceItem(
        sourceJsonFileName: sourceName,
        displayName: displayName,
        subClasses: [],
      ));
      exSourceIndex = existData.classes.length - 1;
    } else {
      SourceItem oldSource = existData.classes[exSourceIndex];
      existData.classes[exSourceIndex] = SourceItem(
        sourceJsonFileName: sourceName,
        displayName: displayName.isNotEmpty ? displayName : oldSource.displayName,
        subClasses: [],
      );
    }
    SourceItem exSource = existData.classes[exSourceIndex];

    for(var className in data.keys){
      ClassItem exClass = ClassItem(className: className, wordIndexs: []);
      for(var word in data[className]){
        String newRaw = _asString(word["arabic"]);
        String newChinese = _asString(word["chinese"]);
        // 阿语或中文为空的词条视为无效，跳过并计数
        if (newRaw.trim().isEmpty || newChinese.trim().isEmpty) {
          skipped++;
          continue;
        }
        imported++;

        final String newIdentity = newRaw.identityKey();
        int existingIndex = -1;

        if (rawWordMap.containsKey(newRaw)) {
          existingIndex = rawWordMap[newRaw]!;
        } else {
          // 身份键相同（仅发音符号/括号差异）时，还需释义严格相似才视为同一词。
          final List<int>? candidates = identityMap[newIdentity];
          if (candidates != null) {
            for (final int candidate in candidates) {
              if (chineseList[candidate].hasSimilarMeaning(newChinese)) {
                existingIndex = candidate;
                break;
              }
            }
          }
        }

        final Map<dynamic, dynamic> properties =
            word["properties"] is Map ? word["properties"] as Map : const {};
        final String pos = _asString(properties["pos"]);
        bool? gender;
        if (properties["gender"] is bool) gender = properties["gender"] as bool;

        final WordItem incoming = WordItem(
          arabic: newRaw,
          chinese: newChinese,
          explanation: _asString(word["explanation"] ?? word["example"]),
          className: className,
          id: existingIndex != -1 ? existingIndex : counter,
          root: _asString(word["root"]),
          categories: word["categories"] is List
              ? List<String>.from(word["categories"] as List)
              : const [],
          pos: pos,
          plural: _asString(properties["plural"]),
          // 仅名词有阴阳性；非名词在词库中的 gender 为占位值，导入时忽略。
          gender: WordItem.normalizeGender(pos, gender),
          present: _asString(properties["present"]),
          masdar: _asString(properties["masdar"]),
        );

        if (existingIndex != -1) {
          // 命中已有词条：归属到本课程，并补充/覆盖词形信息，不新增词条。
          if(!exClass.wordIndexs.contains(existingIndex)) {
            exClass.wordIndexs.add(existingIndex);
          }
          existData.words[existingIndex] =
              existData.words[existingIndex].supplement(incoming);
          continue;
        }

        exClass.wordIndexs.add(counter);
        existData.words.add(incoming);
        rawWordMap[newRaw] = counter;
        (identityMap[newIdentity] ??= <int>[]).add(counter);
        chineseList.add(newChinese);
        counter ++;
      }
      exSource.subClasses.add(exClass);
    }
    return (data: existData, imported: imported, skipped: skipped);
  }

  /// 数据纠正：仅名词（[WordItem.posNominals]）有阴阳性。过渡版本会为所有非
  /// 名词词条写入占位 gender（恒为 true），此处统一置空；名词及词性未知
  /// （pos 为空）的旧数据保持不变。
  ///
  /// 返回是否有词条被改动（调用方据此决定是否回写存储）。
  bool normalizeWordGenders() {
    bool changed = false;
    // 词表可能来自 const DictData（不可变列表），复制后再改写以保证通用性。
    final List<WordItem> words = List<WordItem>.of(wordData.words);
    for (int i = 0; i < words.length; i++) {
      final WordItem word = words[i];
      final bool? fixed = WordItem.normalizeGender(word.pos, word.gender);
      if (fixed != word.gender) {
        words[i] = word.withGender(fixed);
        changed = true;
      }
    }
    if (changed) {
      wordData = DictData(words: words, classes: wordData.classes);
      logger.info("已纠正非名词词条的阴阳性占位数据");
    }
    return changed;
  }

  /// 删除整个词库来源（**仅解除归属，保留词条本体**）。
  ///
  /// 适用于「删除一个导入的词库」。不删除、不重排 `words`，因此不影响以
  /// 位置为 id 的 FSRS 复习数据与每日推送断点。返回被删除来源的展示名；
  /// 来源不存在时返回 null。
  String? deleteDictSource(String sourceJsonFileName) {
    final int index = wordData.classes.indexWhere(
      (SourceItem source) => source.sourceJsonFileName == sourceJsonFileName,
    );
    if (index == -1) return null;
    final String displayName = wordData.classes[index].name;
    final List<SourceItem> classes = List<SourceItem>.of(wordData.classes)..removeAt(index);
    wordData = DictData(words: wordData.words, classes: classes);
    _persistWordData();
    logger.info("已删除词库来源: $sourceJsonFileName（词条保留）");
    return displayName;
  }

  /// 未被任何课程 [ClassItem.wordIndexs] 引用的词条下标集合。
  Set<int> unreferencedWordIds() {
    final Set<int> referenced = <int>{};
    for (final SourceItem source in wordData.classes) {
      for (final ClassItem course in source.subClasses) {
        referenced.addAll(course.wordIndexs);
      }
    }
    final Set<int> orphans = <int>{};
    for (int i = 0; i < wordData.words.length; i++) {
      if (!referenced.contains(i)) orphans.add(i);
    }
    return orphans;
  }

  /// 彻底删除未被任何课程引用的词条（真正删词）。
  ///
  /// 通过 `old→new` 下标映射同步重写 `words`、所有 `ClassItem.wordIndexs`、
  /// FSRS 卡片与复习日志（丢弃被删词条的卡片），并清空每日推送断点、重建派生索引。
  /// **注意**：会重排词条位置，被删词条上的 FSRS 进度将永久丢失。
  /// 返回 `(removedWords, removedCards)`。
  ({int removedWords, int removedCards}) compactUnreferencedWords() {
    final Set<int> orphans = unreferencedWordIds();
    if (orphans.isEmpty) return (removedWords: 0, removedCards: 0);

    final List<WordItem> newWords = [];
    final Map<int, int> oldToNew = {};
    for (int i = 0; i < wordData.words.length; i++) {
      if (orphans.contains(i)) continue;
      oldToNew[i] = newWords.length;
      newWords.add(wordData.words[i]);
    }

    final List<SourceItem> newClasses = [];
    for (final SourceItem source in wordData.classes) {
      final List<ClassItem> subClasses = [];
      for (final ClassItem course in source.subClasses) {
        final List<int> mapped = [];
        for (final int old in course.wordIndexs) {
          final int? neu = oldToNew[old];
          if (neu != null) mapped.add(neu); // 丢弃越界的脏引用
        }
        subClasses.add(ClassItem(className: course.className, wordIndexs: mapped));
      }
      newClasses.add(SourceItem(
        sourceJsonFileName: source.sourceJsonFileName,
        displayName: source.displayName,
        subClasses: subClasses,
      ));
    }

    final int removedCards = FSRS().remapWordIds(oldToNew);

    wordData = DictData(words: newWords, classes: newClasses);
    _persistWordData();
    PushSessionStore.clear();
    logger.info("清理未归属词条: ${orphans.length} 个，丢弃复习卡片 $removedCards 张");
    return (removedWords: orphans.length, removedCards: removedCards);
  }

  /// 重建全部派生索引（BKSearch / WordMembershipIndex）并回写经阴阳性纠正的数据。
  ///
  /// 只修复**派生**数据；无法恢复已丢失的课程归属（`ClassItem.wordIndexs`
  /// 是归属的唯一权威来源），也无法找回已被删除的词条。返回异常统计文本。
  String repairIndexes() {
    normalizeWordGenders();
    _persistWordData();
    final int orphans = unreferencedWordIds().length;
    final int outOfRangeCards = FSRS().outOfRangeCardCount(wordData.words.length);
    return "已重建词库索引。\n"
        "未归属词条: $orphans\n"
        "越界复习卡片: $outOfRangeCards";
  }

  /// 是否存在「重置词库但保留复习进度」流程中暂存的待恢复卡片。
  bool get hasPendingFsrsRestore => _pendingFsrsRestore != null;

  /// 重置全部词库（清空词库与课程归属），但把复习进度按**词形**暂存到内存，
  /// 供重新导入后调用 [restoreFsrsFromPending] 恢复。
  ///
  /// 清空同时会清空 FSRS 卡片（持久化），避免卡片继续按旧位置 id 指向已不存在的
  /// 词条。暂存的进度**仅存在于本次会话**，中途退出将无法恢复；阅读题与同义词
  /// 标记不受影响。返回暂存的卡片数。
  int resetDictsPreservingFsrs() {
    final FSRS fsrs = FSRS();
    final List<({int oldId, String identity, Card card, ReviewLog log})> pending = [];
    final int wordCount = wordData.words.length;
    for (final ({Card card, ReviewLog log}) entry in fsrs.alignedCards()) {
      final int oldId = entry.card.cardId;
      if (oldId < 0 || oldId >= wordCount) continue; // 越界脏卡直接丢弃
      final String identity = wordData.words[oldId].arabic.identityKey();
      if (identity.isEmpty) continue;
      pending.add((oldId: oldId, identity: identity, card: entry.card, log: entry.log));
    }
    _pendingFsrsRestore = pending;
    fsrs.clearCards();
    // 必须用可增长的列表：重新导入时 dataFormater 会向 classes/words 追加。
    wordData = DictData(words: <WordItem>[], classes: <SourceItem>[]);
    _persistWordData();
    logger.info("已重置词库，内存暂存 ${pending.length} 张复习卡片待恢复");
    return pending.length;
  }

  /// 重新导入完成后，按词形把暂存的复习进度映射到新词条。
  /// 未能匹配到新词条的卡片会被丢弃。返回 `(restored, dropped)`。
  ({int restored, int dropped}) restoreFsrsFromPending() {
    final List<({int oldId, String identity, Card card, ReviewLog log})>? pending =
        _pendingFsrsRestore;
    if (pending == null) return (restored: 0, dropped: 0);

    final Map<String, List<int>> byIdentity = <String, List<int>>{};
    for (int i = 0; i < wordData.words.length; i++) {
      (byIdentity[wordData.words[i].arabic.identityKey()] ??= <int>[]).add(i);
    }

    final List<({Card card, ReviewLog log})> restored = [];
    int dropped = 0;
    for (final ({int oldId, String identity, Card card, ReviewLog log}) entry in pending) {
      final List<int>? candidates = byIdentity[entry.identity];
      if (candidates == null || candidates.isEmpty) {
        dropped++;
        continue;
      }
      final int newId = candidates.removeAt(0);
      restored.add((
        card: entry.card.copyWith(cardId: newId),
        log: ReviewLog(
          cardId: newId,
          rating: entry.log.rating,
          reviewDateTime: entry.log.reviewDateTime,
          reviewDuration: entry.log.reviewDuration,
        ),
      ));
    }
    FSRS().setAlignedCards(restored);
    _pendingFsrsRestore = null;
    logger.info("恢复复习进度: ${restored.length} 张，丢弃 $dropped 张");
    return (restored: restored.length, dropped: dropped);
  }

  /// 放弃暂存的复习进度（清空待恢复快照）。
  void discardPendingFsrsRestore() {
    _pendingFsrsRestore = null;
    logger.info("已放弃待恢复的复习进度");
  }

  /// 持久化当前 `wordData` 并重建检索 / 归属索引。
  void _persistWordData() {
    storage.setString("wordData", jsonEncode(wordData.toMap()));
    BKSearch.rebuild(wordData.words);
    WordMembershipIndex.instance.rebuild(wordData.classes);
  }

  static String _asString(dynamic value) => value == null ? "" : value.toString();

  /// 导入词库原始文本，自动识别旧版JSON对象与新JSONL格式。
  ///
  /// [rawText] 支持：
  /// - 旧版JSON对象文本：`{"课程名": [{"arabic":..,"chinese":..,"explanation":..}]}`
  /// - 新JSONL文本：首行元数据 `{"metadata": true, "name": "..."}`（同时兼容拼写
  ///   `matedata`），其后每行 `{"class": "1", "words": [{"arabic":..,"chinese":..,
  ///   "example":..,"root":..,"categories":[..],"properties":{...}}]}`
  ///
  /// [source] 为词库文件名，作为`sourceJsonFileName`用于去重/替换。
  DictImportResult importDictData(String rawText, String source) {
    logger.info("收到词汇导入请求");
    final String text = rawText.trim();
    bool isJsonl = false;
    String displayName = "";
    Map<String, dynamic> parsed;

    // 优先尝试整体JSON解码：旧版JSON（含多行美化）可成功；
    // JSONL 因多个独立对象相邻而解码失败，从而回退到逐行解析。
    Map<String, dynamic>? wholeObject;
    try {
      final dynamic decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) wholeObject = decoded;
    } catch (_) {
      wholeObject = null;
    }

    if (wholeObject != null &&
        !wholeObject.containsKey("metadata") &&
        !wholeObject.containsKey("matedata") &&
        !wholeObject.containsKey("words")) {
      // 旧版JSON对象
      parsed = wholeObject;
    } else {
      // 新JSONL：逐行解析，忽略空行与无法解析的行
      isJsonl = true;
      parsed = {};
      for (final String rawLine in text.split("\n")) {
        final String line = rawLine.trim();
        if (line.isEmpty) continue;
        dynamic decoded;
        try {
          decoded = jsonDecode(line);
        } catch (_) {
          continue;
        }
        if (decoded is! Map) continue;
        final Map<String, dynamic> obj = Map<String, dynamic>.from(decoded);

        // 元数据行（兼容旧拼写 matedata）
        if (obj.containsKey("metadata") || obj.containsKey("matedata")) {
          final dynamic name = obj["name"];
          if (name is String && name.trim().isNotEmpty) displayName = name.trim();
          continue;
        }

        // 课程单元行
        if (obj.containsKey("words")) {
          final dynamic words = obj["words"];
          if (words is List) {
            parsed[_normalizeClassName(obj["class"])] = words;
          }
        }
      }
    }

    final ({DictData data, int imported, int skipped}) fmt =
        dataFormater(parsed, wordData, source, displayName: displayName);
    wordData = fmt.data;
    normalizeWordGenders();
    storage.setString("wordData", jsonEncode(wordData.toMap()));
    BKSearch.rebuild(wordData.words); // 强制重建搜索索引，保证新词立即可搜
    WordMembershipIndex.instance.rebuild(wordData.classes);
    logger.info("词汇导入完成");

    return DictImportResult(
      importedCount: fmt.imported,
      skippedCount: fmt.skipped,
      classCount: parsed.length,
      sourceName: displayName.isNotEmpty ? displayName : source,
      isJsonl: isJsonl,
    );
  }

  /// 将JSONL中的`class`字段（字符串或数字）统一规范为字符串
  static String _normalizeClassName(dynamic value) {
    if (value == null) return "";
    if (value is String) return value;
    if (value is int) return value.toString();
    if (value is num) {
      return value == value.toInt() ? value.toInt().toString() : value.toString();
    }
    return value.toString();
  }

  void saveReadingData(){
    storage.setString("readingData", jsonEncode(readingData.toMap()));
  }
}
