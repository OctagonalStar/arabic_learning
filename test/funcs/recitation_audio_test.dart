import 'dart:typed_data';

import 'package:arabic_learning/services/recitation_audio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造 16-bit 单声道 PCM 的 WAV。
Uint8List _wav(List<int> samples, {int sampleRate = 16000}) {
  final int dataSize = samples.length * 2;
  final ByteData data = ByteData(44 + dataSize);

  void ascii(int offset, String text) {
    for (int i = 0; i < text.length; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, dataSize, Endian.little);
  for (int i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

/// 16k 下的常量振幅「有声」样本。
List<double> _tone(int samples) => List<double>.filled(samples, 0.3);

void main() {
  group('decodeWav16', () {
    test('解码长度与浮点数值', () {
      final Float32List samples =
          decodeWav16(_wav(<int>[0, 16384, -16384, 32767]));
      expect(samples.length, 4);
      expect(samples[0], 0);
      expect(samples[1], closeTo(0.5, 0.001));
      expect(samples[2], closeTo(-0.5, 0.001));
    });

    test('非 PCM 16-bit 时抛异常', () {
      final Uint8List wav = _wav(<int>[0, 0]);
      wav[20] = 3; // WAVE_FORMAT_IEEE_FLOAT
      expect(() => decodeWav16(wav), throwsException);
    });

    test('不是 WAV 时抛异常', () {
      expect(() => decodeWav16(Uint8List(64)), throwsException);
    });
  });

  group('analysis', () {
    test('中间的静音段被识别为停顿', () {
      final Float32List samples = Float32List.fromList(<double>[
        ..._tone(8000), // 0.5s 有声
        ...List<double>.filled(24000, 0), // 1.5s 静音
        ..._tone(8000), // 0.5s 有声
      ]);
      final SpeechAnalysis result = analysis(samples);
      expect(result.speechRatio, closeTo(0.4, 0.02));
      expect(result.pauses, hasLength(1));
      expect(result.pauses.single.start, closeTo(0.5, 0.05));
      expect(result.pauses.single.end, closeTo(2.0, 0.05));
    });

    test('首尾静音不算停顿', () {
      final Float32List samples = Float32List.fromList(<double>[
        ...List<double>.filled(16000, 0),
        ..._tone(16000),
        ...List<double>.filled(16000, 0),
      ]);
      expect(analysis(samples).pauses, isEmpty);
    });
  });

  group('splitSegments', () {
    test('0.6s 以上的静音把录音切成两段', () {
      final Float32List samples = Float32List.fromList(<double>[
        ..._tone(4800), // 0.3s
        ...List<double>.filled(12800, 0), // 0.8s
        ..._tone(4800), // 0.3s
      ]);
      final List<({Float32List samples, double start})> segments =
          splitSegments(samples);
      expect(segments, hasLength(2));
      expect(segments.first.start, 0);
      expect(segments.last.start, closeTo(0.7, 0.05));
    });
  });
}
