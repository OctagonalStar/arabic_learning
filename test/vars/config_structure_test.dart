import 'package:arabic_learning/vars/config_structure.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Config 往返一致性', () {
    const Config config = Config(
      user: "tester",
      lastVersion: 999,
      lastTermVersion: 3,
      debug: DebugConfig(enableInternalLog: true, internalLevel: 5),
      regular: RegularConfig(
        theme: 1,
        font: 2,
        darkMode: true,
        hideAppDownloadButton: true,
      ),
      audio: AudioConfig(audioSource: 2, playRate: 1.5, autoPlay: true),
      learning: LearningConfig(
        startDate: 10,
        lastDate: 20,
        overviewForceColumn: 3,
        wordLookupRealtime: false,
      ),
      quiz: QuizConfig(
        questionSections: [3, 4],
        shuffleGlobally: false,
        shuffleInternaly: true,
        shuffleExternaly: true,
        modifyAllowed: false,
        preferSimilar: true,
      ),
      webSync: SyncConfig(
        enabled: true,
        account: SyncAccountConfig(uri: "https://dav", userName: "u", passWord: "p"),
      ),
    );

    test('toMap -> buildFromMap 保留全部字段', () {
      final Config rebuilt = Config.buildFromMap(config.toMap());
      expect(rebuilt.toMap(), config.toMap());
    });

    test('buildFromMap(null) 返回默认 Config', () {
      expect(Config.buildFromMap(null).toMap(), const Config().toMap());
    });

    test('buildFromMap 缺省子配置时使用默认值', () {
      final Config rebuilt = Config.buildFromMap(<String, dynamic>{
        "User": "partial",
        "LastVersion": StaticsVar.appVersion,
        "LastTermVersion": 2,
        "quiz": const QuizConfig().toMap(),
      });
      expect(rebuilt.user, "partial");
      expect(rebuilt.lastVersion, StaticsVar.appVersion);
      expect(rebuilt.lastTermVersion, 2);
      expect(rebuilt.debug.toMap(), const DebugConfig().toMap());
      expect(rebuilt.regular.toMap(), const RegularConfig().toMap());
      expect(rebuilt.audio.toMap(), const AudioConfig().toMap());
      expect(rebuilt.learning.toMap(), const LearningConfig().toMap());
      expect(rebuilt.webSync.toMap(), const SyncConfig().toMap());
    });

    test('copyWith 只覆盖指定字段', () {
      final Config updated = config.copyWith(user: "other", lastVersion: 1000);
      expect(updated.user, "other");
      expect(updated.lastVersion, 1000);
      expect(updated.regular.toMap(), config.regular.toMap());
      expect(updated.quiz.toMap(), config.quiz.toMap());
    });
  });

  group('子配置缺省值', () {
    test('DebugConfig/RegularConfig/AudioConfig/LearningConfig 接受 null', () {
      expect(DebugConfig.buildFromMap(null).toMap(), const DebugConfig().toMap());
      expect(RegularConfig.buildFromMap(null).toMap(), const RegularConfig().toMap());
      expect(AudioConfig.buildFromMap(null).toMap(), const AudioConfig().toMap());
      expect(LearningConfig.buildFromMap(null).toMap(), const LearningConfig().toMap());
    });

    test('SyncConfig/SyncAccountConfig 接受 null', () {
      expect(SyncConfig.buildFromMap(null).toMap(), const SyncConfig().toMap());
      expect(
        SyncAccountConfig.buildFromMap(null).toMap(),
        const SyncAccountConfig().toMap(),
      );
    });

    test('QuizConfig buildFromMap(null) 抛异常（设计如此）', () {
      expect(() => QuizConfig.buildFromMap(null), throwsA(isA<Exception>()));
    });
  });

  group('QuizConfig 旧版兼容与往返', () {
    test('新版格式往返一致', () {
      const QuizConfig quiz = QuizConfig(
        questionSections: [1, 2, 3],
        shuffleGlobally: false,
        shuffleInternaly: true,
        shuffleExternaly: false,
        modifyAllowed: false,
        preferSimilar: true,
      );
      expect(QuizConfig.buildFromMap(quiz.toMap()).toMap(), quiz.toMap());
    });

    test('旧版 zh_ar 嵌套分支被识别', () {
      final Map<String, dynamic> legacy = <String, dynamic>{
        "zh_ar": const QuizConfig(questionSections: [3, 4]).toMap(),
      };
      final QuizConfig rebuilt = QuizConfig.buildFromMap(legacy);
      expect(rebuilt.questionSections, [3, 4]);
      expect(rebuilt.shuffleGlobally, const QuizConfig().shuffleGlobally);
    });

    test('缺失 preferSimilar 时回退默认 false', () {
      final QuizConfig rebuilt = QuizConfig.buildFromMap(<String, dynamic>{
        "questionSections": [1],
        "shuffleGlobally": true,
        "shuffleInternaly": false,
        "shuffleExternaly": false,
        "modifyAllowed": true,
      });
      expect(rebuilt.preferSimilar, isFalse);
    });
  });

  group('DictData / WordItem / SourceItem / ClassItem', () {
    test('DictData 往返一致', () {
      final DictData dict = DictData(
        words: [
          const WordItem(
            arabic: "كتاب",
            chinese: "书",
            explanation: "名词",
            className: "第一课",
            id: 0,
            root: "ك ت ب",
            categories: ["四级", "常用词"],
            pos: "Nominals",
            plural: "كتب",
            gender: true,
          ),
          const WordItem(
            arabic: "كَتَبَ",
            chinese: "写",
            explanation: "动词",
            className: "第一课",
            id: 1,
            pos: "Verbs",
            present: "يكتب",
            masdar: "كتابة",
          ),
        ],
        classes: [
          SourceItem(
            sourceJsonFileName: "src.json",
            displayName: "示例词库",
            subClasses: [
              ClassItem(className: "第一课", wordIndexs: const [0, 1]),
            ],
          ),
        ],
      );
      final DictData rebuilt = DictData.buildFromMap(dict.toMap());
      expect(rebuilt.toMap(), dict.toMap());
    });

    test('WordItem.toMap 空字段省略', () {
      const WordItem empty = WordItem(
        arabic: "ا",
        chinese: "a",
        explanation: "",
        className: "c",
        id: 0,
      );
      expect(
        empty.toMap().keys.toSet(),
        <String>{"arabic", "chinese", "explanation", "subClass"},
      );
    });

    test('WordItem.toMap 有值字段写出，gender=false 也算有值', () {
      const WordItem full = WordItem(
        arabic: "كتاب",
        chinese: "书",
        explanation: "名词",
        className: "第一课",
        id: 0,
        root: "ك ت ب",
        categories: ["四级"],
        pos: "Nominals",
        plural: "كتب",
        gender: false,
        present: "p",
        masdar: "m",
      );
      final Map<String, dynamic> map = full.toMap();
      expect(map["root"], "ك ت ب");
      expect(map["categories"], ["四级"]);
      expect(map["pos"], "Nominals");
      expect(map["plural"], "كتب");
      expect(map["gender"], isFalse);
      expect(map["present"], "p");
      expect(map["masdar"], "m");
    });

    test('WordItem.buildFromMap 缺省字段回退', () {
      final WordItem word = WordItem.buildFromMap(<String, dynamic>{"arabic": "a"}, 7);
      expect(word.id, 7);
      expect(word.chinese, "");
      expect(word.explanation, "");
      expect(word.className, "");
      expect(word.root, "");
      expect(word.categories, isEmpty);
      expect(word.pos, "");
      expect(word.plural, "");
      expect(word.gender, isNull);
      expect(word.present, "");
      expect(word.masdar, "");
    });

    test('SourceItem 新格式解析与往返', () {
      final SourceItem source = SourceItem.buildFromMap(
        <String, dynamic>{
          "displayName": "新词库",
          "classes": <String, dynamic>{
            "A": <int>[0, 1],
          },
        },
        "file.json",
      );
      expect(source.displayName, "新词库");
      expect(source.name, "新词库");
      expect(source.subClasses.single.className, "A");
      expect(source.subClasses.single.wordIndexs, [0, 1]);
      expect(source.toMap(), <String, dynamic>{
        "displayName": "新词库",
        "classes": <String, dynamic>{
          "A": <int>[0, 1],
        },
      });
    });

    test('SourceItem 旧格式回退到文件名', () {
      final SourceItem source = SourceItem.buildFromMap(
        <String, dynamic>{
          "A": <int>[0, 1],
        },
        "file.json",
      );
      expect(source.displayName, "");
      expect(source.name, "file.json");
      expect(source.subClasses.single.className, "A");
      expect(source.subClasses.single.wordIndexs, [0, 1]);
    });

    test('ClassItem toString/hash 稳定', () {
      const ClassItem item = ClassItem(className: "第一课", wordIndexs: [0]);
      expect(item.toString(), "第一课");
      expect(item.getHash(), item.getHash());
      expect(
        item.getHash(),
        isNot(const ClassItem(className: "第二课", wordIndexs: [0]).getHash()),
      );
    });
  });

  group('ReadingUnit 导出行为', () {
    const ReadingUnit unit = ReadingUnit(
      type: 1,
      title: "标题",
      passage: "篇章",
      difficulty: 2,
      tashkeel: true,
      questions: [
        ReadingQuestion(
          riddle: "问题",
          answers: ["A", "B"],
          type: "细节理解",
          analysis: "解析",
        ),
      ],
      corrects: [0],
      tags: ["tag"],
    );

    test('export: true 不含 corrects', () {
      expect(unit.toMap(export: true).containsKey("corrects"), isFalse);
    });

    test('export: false 含 corrects', () {
      expect(unit.toMap()["corrects"], [0]);
    });

    test('ReadingUnit 往返一致', () {
      final ReadingUnit rebuilt = ReadingUnit.buildFromMap(unit.toMap());
      expect(rebuilt.toMap(), unit.toMap());
    });
  });
}
