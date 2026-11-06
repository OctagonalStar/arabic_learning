

class OfflineTts {
  OfflineTts(OfflineTtsConfig config);

  dynamic generate({required String text, required speed}) {}

  void free() {}
}

void initBindings ({
  int? opt = 0
}) {
  return;
}

class OfflineTtsVitsModelConfig {
  String model;
  String dataDir;
  String tokens;
  double lengthScale;
  OfflineTtsVitsModelConfig(
      {required this.model,
      required this.dataDir,
      required this.tokens,
      required this.lengthScale});
}

class OfflineTtsKokoroModelConfig {
  String model;
  String voices;
  String tokens;
  String dataDir;
  double lengthScale;
  OfflineTtsKokoroModelConfig(
      {required this.model,
      required this.voices,
      required this.tokens,
      required this.dataDir,
      required this.lengthScale});
}

class OfflineTtsModelConfig {
  OfflineTtsVitsModelConfig? vits;
  OfflineTtsKokoroModelConfig? kokoro;
  int numThreads;
  bool debug;
  String provider;
  OfflineTtsModelConfig(
      {this.vits,
      this.kokoro,
      required this.numThreads,
      required this.debug,
      required this.provider});
}

class OfflineTtsConfig {
  OfflineTtsModelConfig model;
  int maxNumSenetences;
  OfflineTtsConfig(
      {required this.model, required this.maxNumSenetences});
}

bool writeWave(
    {required String filename,
    required dynamic samples,
    required int sampleRate}) {
  return false;
}

// 以下为 Web 端的识别桩：只保证调用方编译通过，实际不会被调用。

class OfflineWhisperModelConfig {
  const OfflineWhisperModelConfig({
    this.encoder = '',
    this.decoder = '',
    this.language = '',
    this.task = '',
    this.enableTokenTimestamps = false,
  });

  final String encoder;
  final String decoder;
  final String language;
  final String task;
  final bool enableTokenTimestamps;
}

class OfflineModelConfig {
  const OfflineModelConfig({
    this.whisper = const OfflineWhisperModelConfig(),
    required this.tokens,
    this.numThreads = 1,
    this.debug = false,
    this.provider = 'cpu',
  });

  final OfflineWhisperModelConfig whisper;
  final String tokens;
  final int numThreads;
  final bool debug;
  final String provider;
}

class OfflineRecognizerConfig {
  const OfflineRecognizerConfig({required this.model});

  final OfflineModelConfig model;
}

class OfflineRecognizerResult {
  String text = '';
  List<String> tokens = const <String>[];
  List<double> timestamps = const <double>[];
}

class OfflineStream {
  void acceptWaveform({required dynamic samples, required int sampleRate}) {}
  void free() {}
}

class OfflineRecognizer {
  OfflineRecognizer(OfflineRecognizerConfig config);

  OfflineStream createStream() => OfflineStream();

  void decode(OfflineStream stream) {}

  OfflineRecognizerResult getResult(OfflineStream stream) =>
      OfflineRecognizerResult();

  void free() {}
}