import 'dart:io';

import 'package:arabic_learning/services/model_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('model_manager_test_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Directory dirWith(String name, List<String> files, {bool espeak = false}) {
    final Directory dir = Directory('${tmp.path}/$name')..createSync();
    for (final String file in files) {
      File('${dir.path}/$file').createSync();
    }
    if (espeak) Directory('${dir.path}/espeak-ng-data').createSync();
    return dir;
  }

  group('resolveTts', () {
    test('VITS：onnx + 同名 onnx.json + tokens', () {
      final Directory dir = dirWith('vits-pack', <String>[
        'ar_JO-kareem-medium.onnx',
        'ar_JO-kareem-medium.onnx.json',
        'tokens.txt',
      ]);

      final TtsModelFiles? files = ModelManager.resolveTts(dir.path);

      expect(files, isNotNull);
      expect(files!.kind, TtsModelKind.vits);
      expect(files.model, 'ar_JO-kareem-medium.onnx');
      expect(files.voices, isNull);
      expect(files.tokens, 'tokens.txt');
      expect(files.hasEspeakData, isFalse);
    });

    test('Kokoro：model.int8.onnx + voices.bin，优先 int8', () {
      final Directory dir = dirWith(
        'kokoro-pack',
        <String>['model.onnx', 'model.int8.onnx', 'voices.bin', 'tokens.txt'],
        espeak: true,
      );

      final TtsModelFiles? files = ModelManager.resolveTts(dir.path);

      expect(files, isNotNull);
      expect(files!.kind, TtsModelKind.kokoro);
      expect(files.model, 'model.int8.onnx');
      expect(files.voices, 'voices.bin');
      expect(files.hasEspeakData, isTrue);
    });

    test('不是 TTS 目录时返回 null', () {
      final Directory dir = dirWith('empty', <String>['tokens.txt']);
      expect(ModelManager.resolveTts(dir.path), isNull);
      expect(ModelManager.resolveTts('${tmp.path}/missing'), isNull);
    });
  });

  group('resolveAsr', () {    test('Whisper：encoder + decoder + tiny-tokens', () {
      final Directory dir = dirWith('whisper-pack', <String>[
        'tiny-encoder.int8.onnx',
        'tiny-decoder.int8.onnx',
        'tiny-tokens.txt',
      ]);

      final AsrModelFiles? files = ModelManager.resolveAsr(dir.path);

      expect(files, isNotNull);
      expect(files!.nemoCtc, isFalse);
      expect(files.encoder, 'tiny-encoder.int8.onnx');
      expect(files.decoder, 'tiny-decoder.int8.onnx');
      expect(files.tokens, 'tiny-tokens.txt');
    });

    test('NeMo CTC：model.onnx + tokens.txt', () {
      final Directory dir = dirWith('nemo-pack', <String>[
        'model.onnx',
        'tokens.txt',
      ]);

      final AsrModelFiles? files = ModelManager.resolveAsr(dir.path);

      expect(files, isNotNull);
      expect(files!.nemoCtc, isTrue);
      expect(files.model, 'model.onnx');
      expect(files.tokens, 'tokens.txt');
    });

    test('不是 ASR 目录时返回 null', () {
      final Directory dir = dirWith('tts-only', <String>['tokens.txt']);
      expect(ModelManager.resolveAsr(dir.path), isNull);
    });
  });

  group('Web 端按顶层文件名解析', () {
    test('resolveTtsNames 识别 VITS / Kokoro 并带上 espeak 标记', () {
      final TtsModelFiles? vits = ModelManager.resolveTtsNames(
        <String>['model.onnx', 'model.onnx.json', 'tokens.txt', 'espeak-ng-data'],
        hasEspeakData: true,
      );
      expect(vits?.kind, TtsModelKind.vits);
      expect(vits?.model, 'model.onnx');
      expect(vits?.hasEspeakData, isTrue);

      final TtsModelFiles? kokoro = ModelManager.resolveTtsNames(
        <String>['model.int8.onnx', 'voices.bin', 'tokens.txt'],
        hasEspeakData: false,
      );
      expect(kokoro?.kind, TtsModelKind.kokoro);
      expect(kokoro?.voices, 'voices.bin');
      expect(kokoro?.hasEspeakData, isFalse);

      expect(
        ModelManager.resolveTtsNames(<String>['tokens.txt'], hasEspeakData: false),
        isNull,
      );
    });

    test('resolveAsrNames 识别 Whisper / NeMo', () {
      final AsrModelFiles? whisper = ModelManager.resolveAsrNames(
        <String>['tiny-encoder.onnx', 'tiny-decoder.onnx', 'tiny-tokens.txt'],
      );
      expect(whisper?.nemoCtc, isFalse);
      expect(whisper?.tokens, 'tiny-tokens.txt');

      final AsrModelFiles? nemo = ModelManager.resolveAsrNames(
        <String>['model.onnx', 'tokens.txt'],
      );
      expect(nemo?.nemoCtc, isTrue);
      expect(ModelManager.resolveAsrNames(<String>['tokens.txt']), isNull);
    });

    test('classifyNames 仍能区分 TTS / ASR', () {
      expect(ModelManager.classifyNames(<String>['voices.bin']), isTrue);
      expect(
        ModelManager.classifyNames(
          <String>['encoder.onnx', 'decoder.onnx'],
        ),
        isFalse,
      );
      expect(ModelManager.classifyNames(<String>['tokens.txt']), isNull);
    });
  });
}
