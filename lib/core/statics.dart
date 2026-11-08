// 应用级静态常量与共享实例（原 lib/vars/statics_var.dart 拆分）。
// 仅承载 StaticsVar；AI 提示词已拆分到 core/ai_prompt.dart。

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'package:arabic_learning/theme/tokens.dart' show AppMotion, AppRadius;

/// 本地 TTS 模型的推理架构；决定 [loadTTS] 填哪个 sherpa-onnx 配置。
enum TtsModelFamily { vits, kokoro }

/// 可下载的 TTS 模型。`id` 同时是解压后的目录名与发布包名。
@immutable
class TtsModelInfo {
  final String id;
  final String title;
  final String description;
  final int sizeMB;
  final String license;
  final String sourceUrl;
  final TtsModelFamily family;

  /// 模型目录内的文件名（`tokens.txt` 统一）。
  final String modelFile;
  final String? voicesFile;

  /// Nabra 只接受带变音符号的输入。
  final bool requiresTashkeel;

  const TtsModelInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.sizeMB,
    required this.license,
    required this.sourceUrl,
    required this.family,
    required this.modelFile,
    this.voicesFile,
    this.requiresTashkeel = false,
  });
}

/// ASR 模型家族：决定 sherpa 的模型配置与分词表用法。
enum AsrFamily { whisper, nemoCtc, dolphin, omnilingual }

/// 可下载的语音识别模型（背诵辅助用）。
@immutable
class AsrModelInfo {
  final String id;
  final String title;
  final String description;
  final int sizeMB;
  final String license;
  final String sourceUrl;
  final String language;
  final AsrFamily family;

  const AsrModelInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.sizeMB,
    required this.license,
    required this.sourceUrl,
    required this.language,
    required this.family,
  });
}

/// 线上词库来源：区块标题 + GitHub contents API 地址。
@immutable
class DictRepoInfo {
  final String title;
  final String apiUrl;
  const DictRepoInfo({required this.title, required this.apiUrl});
}

@immutable
class StaticsVar {
  static const String appName = 'Ar学';
  static const int appVersion = 102000;

  /// CI 构建时注入的完整版本（如 `1.2.1-alpha.37`）；本地/正式构建为空串。
  static const String buildVersion = String.fromEnvironment('APP_VERSION');

  static const int termVersion = 6;

  /// 模型发布包统一从该 release 的 `tts-models` / `asr-models` 标签下载，
  /// 资源名即 `<id>.tar.bz2`。
  static const String modelReleaseBase =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download';

  static const String ttsRootDir = 'arabicLearning/tts';
  static const String ttsModelRoot = '$ttsRootDir/model';
  static const String asrModelRoot = 'arabicLearning/asr/model';

  static String ttsModelDir(String id) => '$ttsModelRoot/$id';
  static String asrModelDir(String id) => '$asrModelRoot/$id';
  static String ttsArchiveUrl(String id) => '$modelReleaseBase/tts-models/$id.tar.bz2';
  static String asrArchiveUrl(String id) => '$modelReleaseBase/asr-models/$id.tar.bz2';

  static const String defaultTtsModelId = 'vits-piper-ar_JO-kareem-medium';
  static const String defaultAsrModelId =
      'sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-v2-int8-2026-02-05';

  /// 全部为可再分发许可（MIT / Apache-2.0）。
  /// 注意 `vits-piper-ar_JO-SA_*` 是 CC-BY-NC-ND，不可加入。
  static const List<TtsModelInfo> ttsModels = [
    TtsModelInfo(
      id: 'vits-piper-ar_JO-kareem-medium',
      title: 'Kareem 中等质量',
      description: '标准阿拉伯语男声，原始音色',
      sizeMB: 64,
      license: 'MIT',
      sourceUrl: 'https://huggingface.co/rhasspy/piper-voices',
      family: TtsModelFamily.vits,
      modelFile: 'ar_JO-kareem-medium.onnx',
    ),
    TtsModelInfo(
      id: 'vits-piper-ar_JO-kareem-medium-int8',
      title: 'Kareem 中等质量 · 精简',
      description: '同音色，int8 量化，体积约为原版三分之一',
      sizeMB: 19,
      license: 'MIT',
      sourceUrl: 'https://huggingface.co/rhasspy/piper-voices',
      family: TtsModelFamily.vits,
      modelFile: 'ar_JO-kareem-medium.onnx',
    ),
    TtsModelInfo(
      id: 'nabra-82m-arabic-int8',
      title: 'Nabra 82M',
      description: '更自然的阿拉伯语合成，需要课文自带变音符号',
      sizeMB: 78,
      license: 'Apache-2.0',
      sourceUrl: 'https://huggingface.co/marwanelamami/nabra-82m-sherpa-onnx',
      family: TtsModelFamily.kokoro,
      modelFile: 'model.int8.onnx',
      voicesFile: 'voices.bin',
      requiresTashkeel: true,
    ),
  ];

  static const List<AsrModelInfo> asrModels = [
    AsrModelInfo(
      id: 'sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-v2-int8-2026-02-05',
      title: 'Omnilingual 300M v2',
      description: '阿拉伯语 WER ≈26.7%（FLEURS ar_eg，≤10s 片段）。多语 CTC，字符级较准；体积大、偏慢，输出无标点与变音符号。',
      sizeMB: 366,
      license: 'Apache-2.0',
      sourceUrl: 'https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models',
      language: 'ar',
      family: AsrFamily.omnilingual,
    ),
    AsrModelInfo(
      id: 'sherpa-onnx-dolphin-small-ctc-multi-lang-int8-2025-04-02',
      title: 'Dolphin Small',
      description: '阿拉伯语 WER ≈27.9%（同条件）。速度最快，约为 Whisper tiny 的 3 倍；输出无标点，长段建议先切分。',
      sizeMB: 250,
      license: 'Apache-2.0',
      sourceUrl: 'https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models',
      language: 'ar',
      family: AsrFamily.dolphin,
    ),
  ];

  static const List<DictRepoInfo> dictRepos = [
    DictRepoInfo(
      title: "来自 Github @JYinherit 学长的词库 (在此表示感谢)",
      apiUrl: "https://api.github.com/repos/JYinherit/Arabiclearning/contents/词库",
    ),
    DictRepoInfo(
      title: "来自 Github @OctagonalStar",
      apiUrl:
          "https://api.github.com/repos/OctagonalStar/arabic_chinese_edu_words_dataset/contents/",
    ),
  ];

  static TtsModelInfo ttsModel(String id) => ttsModels.firstWhere(
        (TtsModelInfo m) => m.id == id,
        orElse: () => ttsModels.firstWhere((TtsModelInfo m) => m.id == defaultTtsModelId),
      );

  static AsrModelInfo asrModel(String id) => asrModels.firstWhere(
        (AsrModelInfo m) => m.id == id,
        orElse: () => asrModels.first,
      );

  /// 兼容旧调用点：默认 TTS 模型目录。新代码请用 [ttsModelDir]。
  static String get modelPath => ttsModelDir(defaultTtsModelId);
  static const Map<String, dynamic> tempConfig = {"SelectedClasses": []};
  static const Curve curve = AppMotion.standardCurve;
  static const String onlineDictOwner = 'JYinherit';
  static const String arBackupFont = "Vazirmatn";
  static const String zhBackupFont = "NotoSansSC";
  static const List<String> learningMessage = [
    "⚠️ 警告：您积累的‘知识债’即将逾期。请立即支付5分钟学习时间以避免‘利息’。",
    "友情提示：今日的学习KPI已完成 0%，是时候启动“填鸭”程序了！",
    "你的阴性、阳性、单数、双数、复数... 你都记清楚了吗？",
    "«هل تتذكر ما تعلمته بالأمس؟» ",
    "«إن شاء الله» 你今天会完成学习任务的，对吧？",
    "听说，在沙漠的另一边，有一课书在等你翻开...",
    "..."
  ];
  static const List<MaterialColor> themeList = [
    Colors.pink,
    Colors.blue,
    Colors.green,
    Colors.lime,
    Colors.orange,
    Colors.purple,
    Colors.brown,
    Colors.blueGrey,
    Colors.teal,
    Colors.cyan,
    // 下面的是彩蛋颜色 :)
    MaterialColor(0xFF97FFF6, <int, Color>{
      50: Color(0xFFE0FFFF),
      100: Color(0xFFB3FFFF),
      200: Color(0xFF80FFFF),
      300: Color(0xFF4DFFFF),
      400: Color(0xFF1AFFFF),
      500: Color(0xFF00E6D9),
      600: Color(0xFF00BFB3),
      700: Color(0xFF00998C),
      800: Color(0xFF007366),
      900: Color(0xFF004D40),
    })
  ];
  static final isDesktop = kIsWeb ? false : (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  static final player = AudioPlayer(); // load Player when app start
  static final BorderRadius br = AppRadius.cardBorder;
}
