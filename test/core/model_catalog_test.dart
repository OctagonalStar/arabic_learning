import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/models/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('模型目录', () {
    test('TTS / ASR 模型 id 全局唯一', () {
      final List<String> ids = <String>[
        ...StaticsVar.ttsModels.map((final TtsModelInfo m) => m.id),
        ...StaticsVar.asrModels.map((final AsrModelInfo m) => m.id),
      ];
      expect(ids.toSet().length, ids.length);
    });

    test('TTS 条目字段完整（kokoro 必须有 voices 文件）', () {
      for (final TtsModelInfo info in StaticsVar.ttsModels) {
        expect(info.modelFile, isNotEmpty, reason: info.id);
        if (info.family == TtsModelFamily.kokoro) {
          expect(info.voicesFile, isNotNull, reason: info.id);
          expect(info.voicesFile, isNotEmpty, reason: info.id);
        }
      }
    });

    test('未知 id 回退到默认模型', () {
      expect(StaticsVar.ttsModel('nope').id, StaticsVar.defaultTtsModelId);
    });

    test('发布包地址为 <releaseBase>/tts-models/<id>.tar.bz2', () {
      expect(
        StaticsVar.ttsArchiveUrl('abc'),
        '${StaticsVar.modelReleaseBase}/tts-models/abc.tar.bz2',
      );
    });
  });

  group('AudioConfig.preferredModelId', () {
    test('toMap / buildFromMap 往返保留', () {
      const AudioConfig config = AudioConfig(preferredModelId: 'nabra-82m-arabic-int8');
      expect(config.toMap()['preferredModelId'], 'nabra-82m-arabic-int8');
      expect(
        AudioConfig.buildFromMap(config.toMap()).preferredModelId,
        'nabra-82m-arabic-int8',
      );
    });

    test('缺少该键的旧配置解析为空串', () {
      final AudioConfig config = AudioConfig.buildFromMap(<String, dynamic>{
        'useBackupSource': 2,
        'playRate': 1.0,
        'autoPlay': false,
      });
      expect(config.preferredModelId, isEmpty);
      expect(config.audioSource, 2);
    });
  });

  group('AudioConfig.preferredAsrModelId', () {
    test('toMap / buildFromMap 往返保留', () {
      const AudioConfig config =
          AudioConfig(preferredAsrModelId: 'my-imported-asr');
      expect(config.toMap()['preferredAsrModelId'], 'my-imported-asr');
      expect(
        AudioConfig.buildFromMap(config.toMap()).preferredAsrModelId,
        'my-imported-asr',
      );
      expect(
        config.copyWith(preferredAsrModelId: '').preferredAsrModelId,
        isEmpty,
      );
    });

    test('缺少该键的旧配置解析为空串', () {
      final AudioConfig config = AudioConfig.buildFromMap(<String, dynamic>{
        'useBackupSource': 2,
        'playRate': 1.0,
        'autoPlay': false,
        'preferredModelId': 'nabra-82m-arabic-int8',
      });
      expect(config.preferredAsrModelId, isEmpty);
      expect(config.preferredModelId, 'nabra-82m-arabic-int8');
    });
  });
}
