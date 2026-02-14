

class OfflineTts {
  OfflineTts(OfflineTtsConfig config);

  dynamic generate({required String text, required speed}) {}
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

class OfflineTtsModelConfig {
  OfflineTtsVitsModelConfig vits;
  int numThreads;
  bool debug;
  String provider;
  OfflineTtsModelConfig(
      {required this.vits,
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