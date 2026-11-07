// 16-bit PCM 单声道 WAV 编码（Web 端 sherpa_onnx.writeWave 不可用）。

import 'dart:typed_data';

/// 把 [-1, 1] 的采样编码成 16-bit PCM WAV；空输入只产出 44 字节头。
Uint8List encodeWav16(Float32List samples, int sampleRate) {
  final int dataLen = samples.length * 2;
  final ByteData header = ByteData(44);
  void ascii(int offset, String text) {
    for (int i = 0; i < text.length; i++) {
      header.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + dataLen, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // fmt 块大小
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // 单声道
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little); // byteRate
  header.setUint16(32, 2, Endian.little); // blockAlign
  header.setUint16(34, 16, Endian.little); // bits
  ascii(36, 'data');
  header.setUint32(40, dataLen, Endian.little);

  final Uint8List out = Uint8List(44 + dataLen);
  out.setRange(0, 44, header.buffer.asUint8List());
  final ByteData data = ByteData.view(out.buffer, 44);
  for (int i = 0; i < samples.length; i++) {
    final double value = samples[i].clamp(-1.0, 1.0);
    data.setInt16(i * 2, (value * 32767).round(), Endian.little);
  }
  return out;
}
