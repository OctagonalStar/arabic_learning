// 背诵录音的 WAV 解码与能量分析。
// 不引入新依赖：录音固定为 16k / 单声道 / PCM16。

import 'dart:math' as math;
import 'dart:typed_data';

/// 录音与分析的固定采样率（`record` 按此配置录音）。
const int recitationSampleRate = 16000;

/// 能量分析的窗口长度。
const int analysisWindowMs = 20;

/// 判定「有声」的下限：峰值窗口 RMS 的 12%，且不低于 0.01。
const double voicedRatioOfPeak = 0.12;
const double voicedRmsFloor = 0.01;

/// 超过该长度的静音算一次卡顿。
const double pauseSeconds = 1.2;

/// 超过该长度的静音把录音切成多段送识别。
const double segmentSilenceSeconds = 0.6;

/// Whisper 单次窗口上限（秒）；更长的段必须硬切。
const double maxSegmentSeconds = 25;

/// 把 16-bit 单声道 PCM 的 WAV 解码成 [-1, 1] 的浮点采样。
///
/// 只接受 RIFF/WAVE + PCM 16-bit + 单声道；其余格式抛出
/// `Exception('无法识别的录音格式')`。
Float32List decodeWav16(Uint8List bytes) {
  if (bytes.length < 44 ||
      _ascii(bytes, 0) != 'RIFF' ||
      _ascii(bytes, 8) != 'WAVE') {
    throw Exception('无法识别的录音格式');
  }

  final ByteData data = ByteData.sublistView(bytes);
  int? audioFormat;
  int? channels;
  int? bits;
  int? dataStart;
  int? dataLength;

  int offset = 12;
  while (offset + 8 <= bytes.length) {
    final String id = _ascii(bytes, offset);
    final int size = data.getUint32(offset + 4, Endian.little);
    final int body = offset + 8;
    if (id == 'fmt ' && body + 16 <= bytes.length) {
      audioFormat = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      dataStart = body;
      dataLength = math.min(size, bytes.length - body);
    }
    offset = body + size + (size & 1); // chunk 按偶数字节对齐
  }

  if (audioFormat != 1 ||
      channels != 1 ||
      bits != 16 ||
      dataStart == null ||
      dataLength == null) {
    throw Exception('无法识别的录音格式');
  }

  final int count = dataLength ~/ 2;
  final Float32List samples = Float32List(count);
  for (int i = 0; i < count; i++) {
    samples[i] = data.getInt16(dataStart + i * 2, Endian.little) / 32768.0;
  }
  return samples;
}

/// 录音的语音占比与内部长停顿。
class SpeechAnalysis {
  /// 有声窗口占全部窗口的比例（0..1）。
  final double speechRatio;

  /// 首尾静音之外的停顿，单位秒。
  final List<({double start, double end})> pauses;

  const SpeechAnalysis({required this.speechRatio, required this.pauses});
}

/// 逐 20ms 窗口做 RMS 分析：语音占比 + 长度 ≥ 1.2s 的停顿。
SpeechAnalysis analysis(Float32List samples, {int sampleRate = recitationSampleRate}) {
  final List<double> rms = _rmsWindows(samples, _windowSamples(sampleRate));
  if (rms.isEmpty) return const SpeechAnalysis(speechRatio: 0, pauses: <({double start, double end})>[]);

  final double threshold = _threshold(rms);
  int voiced = 0;
  for (final double value in rms) {
    if (value >= threshold) voiced++;
  }

  final List<({double start, double end})> pauses = <({double start, double end})>[];
  for (final ({int start, int end}) run in _silentRuns(rms, threshold)) {
    // 开头/结尾的静音是设备延迟或收尾，不是卡壳。
    if (run.start == 0 || run.end == rms.length) continue;
    final double start = run.start * analysisWindowMs / 1000;
    final double end = run.end * analysisWindowMs / 1000;
    if (end - start >= pauseSeconds) pauses.add((start: start, end: end));
  }
  return SpeechAnalysis(speechRatio: voiced / rms.length, pauses: pauses);
}

/// 按 0.6s 以上的停顿切段，并把超过 25s 的段硬切，保证每段都能被 Whisper 完整转写。
List<({Float32List samples, double start})> splitSegments(
  Float32List samples, {
  int sampleRate = recitationSampleRate,
}) {
  final int window = _windowSamples(sampleRate);
  final List<double> rms = _rmsWindows(samples, window);
  final List<int> cuts = <int>[0];
  if (rms.isNotEmpty) {
    final double threshold = _threshold(rms);
    for (final ({int start, int end}) run in _silentRuns(rms, threshold)) {
      if (run.start == 0 || run.end >= rms.length) continue;
      final double start = run.start * analysisWindowMs / 1000;
      final double end = run.end * analysisWindowMs / 1000;
      if (end - start >= segmentSilenceSeconds) {
        cuts.add(((start + end) / 2 * sampleRate).round());
      }
    }
  }
  cuts.add(samples.length);

  final List<({Float32List samples, double start})> result =
      <({Float32List samples, double start})>[];
  for (int i = 0; i + 1 < cuts.length; i++) {
    _appendChunk(result, samples, cuts[i], cuts[i + 1], sampleRate);
  }
  return result;
}

void _appendChunk(
  List<({Float32List samples, double start})> out,
  Float32List samples,
  int from,
  int to,
  int sampleRate,
) {
  final int maxSamples = (maxSegmentSeconds * sampleRate).round();
  final int minSamples = (0.2 * sampleRate).round();
  int start = from;
  while (to - start > maxSamples) {
    out.add((
      samples: samples.sublist(start, start + maxSamples),
      start: start / sampleRate,
    ));
    start += maxSamples;
  }
  if (to - start >= minSamples) {
    out.add((samples: samples.sublist(start, to), start: start / sampleRate));
  }
}

int _windowSamples(int sampleRate) =>
    math.max(1, sampleRate * analysisWindowMs ~/ 1000);

List<double> _rmsWindows(Float32List samples, int window) {
  final int count = samples.length ~/ window;
  final List<double> rms = List<double>.filled(count, 0);
  for (int i = 0; i < count; i++) {
    double sum = 0;
    final int base = i * window;
    for (int j = 0; j < window; j++) {
      final double v = samples[base + j];
      sum += v * v;
    }
    rms[i] = math.sqrt(sum / window);
  }
  return rms;
}

double _threshold(List<double> rms) =>
    math.max(rms.reduce(math.max) * voicedRatioOfPeak, voicedRmsFloor);

/// 连续低于阈值的窗口区间（半开区间，单位：窗口下标）。
List<({int start, int end})> _silentRuns(List<double> rms, double threshold) {
  final List<({int start, int end})> runs = <({int start, int end})>[];
  int? start;
  for (int i = 0; i < rms.length; i++) {
    if (rms[i] < threshold) {
      start ??= i;
    } else if (start != null) {
      runs.add((start: start, end: i));
      start = null;
    }
  }
  if (start != null) runs.add((start: start, end: rms.length));
  return runs;
}

String _ascii(Uint8List bytes, int offset) =>
    String.fromCharCodes(bytes.sublist(offset, offset + 4));
