import 'dart:typed_data';

import 'package:arabic_learning/core/wav.dart';
import 'package:flutter_test/flutter_test.dart';

String _ascii(Uint8List bytes, int offset, int length) =>
    String.fromCharCodes(bytes.sublist(offset, offset + length));

void main() {
  group('encodeWav16', () {
    test('44 字节 RIFF/PCM 头与字段', () {
      final Uint8List wav = encodeWav16(Float32List.fromList(<double>[0]), 16000);

      expect(wav.length, 46);
      expect(_ascii(wav, 0, 4), 'RIFF');
      expect(_ascii(wav, 8, 4), 'WAVE');
      expect(_ascii(wav, 12, 4), 'fmt ');
      expect(_ascii(wav, 36, 4), 'data');

      final ByteData header = ByteData.sublistView(wav, 0, 44);
      expect(header.getUint32(4, Endian.little), 38); // 36 + 2 字节数据
      expect(header.getUint32(16, Endian.little), 16);
      expect(header.getUint16(20, Endian.little), 1); // PCM
      expect(header.getUint16(22, Endian.little), 1); // mono
      expect(header.getUint32(24, Endian.little), 16000);
      expect(header.getUint32(28, Endian.little), 32000); // byteRate
      expect(header.getUint16(32, Endian.little), 2); // blockAlign
      expect(header.getUint16(34, Endian.little), 16); // bits
      expect(header.getUint32(40, Endian.little), 2); // data 长度
    });

    test('采样数换算为两倍字节长度', () {
      final Uint8List wav = encodeWav16(
        Float32List.fromList(<double>[0, 0.5, -0.5, 1, -1]),
        8000,
      );

      expect(wav.length, 44 + 5 * 2);
      expect(ByteData.sublistView(wav).getUint32(40, Endian.little), 10);
      expect(ByteData.sublistView(wav).getUint32(4, Endian.little), 46);
    });

    test('超范围采样被 clamp 到 [-1, 1]', () {
      final Uint8List wav = encodeWav16(
        Float32List.fromList(<double>[2.0, -2.0]),
        16000,
      );
      final ByteData data = ByteData.sublistView(wav);

      expect(data.getInt16(44, Endian.little), 32767);
      expect(data.getInt16(46, Endian.little), -32767);
    });

    test('空输入只产出 44 字节头', () {
      final Uint8List wav = encodeWav16(Float32List(0), 22050);

      expect(wav.length, 44);
      expect(ByteData.sublistView(wav).getUint32(4, Endian.little), 36);
      expect(ByteData.sublistView(wav).getUint32(40, Endian.little), 0);
    });
  });
}
