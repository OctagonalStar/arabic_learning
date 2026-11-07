// 模型管理页：集中列出 TTS / ASR 模型目录，支持下载（行内进度）、
// 设为首选、删除与本地模型包（.tar.bz2）导入。
// 逻辑全部在 services/model_manager.dart，本页只做展示与确认交互。

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:arabic_learning/core/statics.dart'
    show AsrModelInfo, StaticsVar, TtsModelInfo;
import 'package:arabic_learning/models/config.dart' show Config;
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/model_manager.dart';
import 'package:arabic_learning/theme/tokens.dart'
    show AppRadius, AppSemanticColors, AppSpacing;
import 'package:arabic_learning/widgets/kit.dart'
    show Button, SettingItem;
import 'package:arabic_learning/widgets/overlays.dart' show alart, showSnackBar;

class ModelManagementPage extends StatefulWidget {
  const ModelManagementPage({super.key});

  @override
  State<ModelManagementPage> createState() => _ModelManagementPageState();
}

class _ModelManagementPageState extends State<ModelManagementPage> {
  /// 正在下载的模型 id；null 表示当前没有下载任务（同时只允许一个）。
  String? _downloadingId;

  /// 正在解压安装的模型 id；下载结束后界面从下载进度切到解压提示。
  String? _installingId;

  /// 是否正在解压导入本地模型包。
  bool _importing = false;
  int _received = 0;
  int _total = 1;

  bool get _busy =>
      _downloadingId != null || _installingId != null || _importing;

  /// 首选模型变更 / 删除首选模型后重建本地 TTS，保证下次播报使用新音色。
  Future<void> _reloadTts() async {
    AppData().resetTTS();
    if (AppData().config.audio.audioSource == 2) {
      await AppData().loadTTS(AppData().config.audio.playRate);
    }
  }

  Future<void> _setPreferred(String id) async {
    final Global global = context.read<Global>();
    global.uiLogger.info("设为首选TTS模型: $id");
    await global.patchConfig(
      (Config config) => config.copyWith(
        audio: config.audio.copyWith(preferredModelId: id),
      ),
    );
    await _reloadTts();
    if (mounted) setState(() {});
  }

  Future<void> _setPreferredAsr(String id) async {
    final Global global = context.read<Global>();
    global.uiLogger.info("设为首选ASR模型: $id");
    await global.patchConfig(
      (Config config) => config.copyWith(
        audio: config.audio.copyWith(preferredAsrModelId: id),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _download(String id) async {
    if (_busy) return;
    final Global global = context.read<Global>();
    setState(() {
      _downloadingId = id;
      _received = 0;
      _total = 1;
    });
    try {
      await ModelManager.install(
        id,
        onProgress: (int received, int total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total;
          });
        },
        // 下载完成后切到解压提示：解压阶段没有字节进度，只能给不确定动画。
        onExtracting: () {
          if (!mounted) return;
          setState(() {
            _downloadingId = null;
            _installingId = id;
          });
        },
      );
      global.uiLogger.info("模型下载完成: $id");
      if (!mounted) return;
      showSnackBar(context, "下载完成");
    } catch (e) {
      global.uiLogger.severe("模型下载失败: $e");
      if (!mounted) return;
      if (e is WebDownloadFailure) {
        _showManualDownload(e.url);
      } else {
        showSnackBar(context, "下载失败：${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingId = null;
          _installingId = null;
        });
      }
    }
  }

  /// Web 端直连被 CORS 拦截时，给出模型包地址让用户自行下载后导入。
  void _showManualDownload(String url) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text("下载被浏览器拦截"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "浏览器不允许网页直接下载 GitHub 上的模型包。"
              "请复制下面的链接自行下载，再回到本页用「导入模型」选择该 .tar.bz2 文件。",
            ),
            const SizedBox(height: AppSpacing.xs),
            SelectableText(
              url,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.of(ctx).pop();
              showSnackBar(context, "链接已复制");
            },
            child: const Text("复制链接"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("关闭"),
          ),
        ],
      ),
    );
  }

  /// 删除确认弹窗；确认后真正执行 [_confirmDelete]。
  void _delete(String id, {required bool isTts, required bool isPreferred}) {
    alart(
      context,
      isPreferred ? "该模型正在使用中，删除后将回退为默认模型。确定删除吗？" : "删除后需重新下载或导入才能继续使用。确定删除吗？",
      destructive: true,
      onConfirmed: () => _confirmDelete(id, isTts: isTts),
    );
  }

  Future<void> _confirmDelete(String id, {required bool isTts}) async {
    final Global global = context.read<Global>();
    try {
      if (isTts) {
        if (AppData().preferredTtsModelId == id) {
          await global.patchConfig(
            (Config config) => config.copyWith(
              audio: config.audio.copyWith(preferredModelId: ""),
            ),
          );
        }
        await _reloadTts();
      } else if (AppData().preferredAsrModelId == id) {
        await global.patchConfig(
          (Config config) => config.copyWith(
            audio: config.audio.copyWith(preferredAsrModelId: ""),
          ),
        );
      }
      await ModelManager.delete(id);
      global.uiLogger.info("模型已删除: $id");
      if (mounted) setState(() {});
    } catch (e) {
      global.uiLogger.severe("模型删除失败: $e");
      if (!mounted) return;
      showSnackBar(context, "删除失败：${e.toString()}");
    }
  }

  Future<void> _importArchive() async {
    if (_busy) return;
    final Global global = context.read<Global>();
    PlatformFile? result;
    try {
      result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['bz2'],
      );
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, "无法打开文件选择器：$e");
      return;
    }
    if (result == null) return;
    if (!mounted) return;
    setState(() => _importing = true);
    try {
      final String id;
      if (kIsWeb) {
        id = await ModelManager.importArchiveBytes(await result.readAsBytes());
      } else {
        final String? path = result.path;
        if (path == null) return;
        id = await ModelManager.importArchive(path);
      }
      global.uiLogger.info("模型包导入成功: $id");
      if (!mounted) return;
      setState(() {});
      showSnackBar(context, "已导入 $id");
    } catch (e) {
      global.uiLogger.severe("模型包导入失败: $e");
      if (!mounted) return;
      showSnackBar(context, e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// 单个模型的展示行：标题 + 状态、描述、大小与许可、操作区。
  Widget _modelRow({
    required String title,
    required String description,
    required String meta,
    required String stateText,
    required Color stateColor,
    required bool downloading,
    required bool installing,
    required String sourceUrl,
    required List<Widget> actions,
  }) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2.0,
                ),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.controlBorder,
                ),
                child: Text(
                  stateText,
                  style: theme.textTheme.labelSmall?.copyWith(color: stateColor),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              meta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (downloading || installing) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: LinearProgressIndicator(
                // 解压阶段拿不到字节进度，用不确定动画表示仍在进行。
                value: downloading
                    ? (_total > 0
                        ? (_received / _total).clamp(0.0, 1.0)
                        : null)
                    : null,
                borderRadius: AppRadius.controlBorder,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                downloading
                    ? "已下载 ${(_received / 1048576).toStringAsFixed(1)} / "
                        "${(_total / 1048576).toStringAsFixed(1)} MB"
                        "${_total > 0 ? "（${(_received * 100) ~/ _total}%）" : ""}"
                    : "正在解压并安装…",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          if (actions.isNotEmpty)
            Row(
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.xxs),
                  actions[i],
                ],
                const Spacer(),
                IconButton(
                  tooltip: "开源地址",
                  icon: const Icon(Icons.open_in_new, size: 18.0),
                  onPressed: () => launchUrl(
                    Uri.parse(sourceUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _ttsRow(TtsModelInfo model) {
    final AppSemanticColors semantic =
        Theme.of(context).extension<AppSemanticColors>()!;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool installed = AppData().isTtsModelInstalled(model.id);
    final bool preferred = AppData().preferredTtsModelId == model.id;
    return _modelRow(
      title: model.title,
      description: model.requiresTashkeel
          ? "${model.description}（需要课文带变音符号）"
          : model.description,
      meta: "${model.sizeMB} MB · ${model.license}",
      stateText: preferred ? "使用中" : (installed ? "已下载" : "未下载"),
      stateColor: preferred
          ? semantic.success
          : installed
              ? scheme.primary
              : semantic.disabled,
      downloading: _downloadingId == model.id,
      installing: _installingId == model.id,
      sourceUrl: model.sourceUrl,
      actions: [
        if (installed && !preferred)
          TextButton(
            onPressed: _busy ? null : () => _setPreferred(model.id),
            child: const Text("设为首选"),
          ),
        if (!installed)
          TextButton(
            onPressed: _busy ? null : () => _download(model.id),
            child: const Text("下载"),
          ),
        if (installed)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: _busy
                ? null
                : () => _delete(
                      model.id,
                      isTts: true,
                      isPreferred: preferred,
                    ),
            child: const Text("删除"),
          ),
      ],
    );
  }

  Widget _asrRow(AsrModelInfo model) {
    final AppSemanticColors semantic =
        Theme.of(context).extension<AppSemanticColors>()!;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool installed = AppData().isAsrModelInstalled(model.id);
    final bool preferred = AppData().preferredAsrModelId == model.id;
    return _modelRow(
      title: model.title,
      description: model.description,
      meta: "${model.sizeMB} MB · ${model.license}",
      stateText: preferred ? "使用中" : (installed ? "已下载" : "未下载"),
      stateColor: preferred
          ? semantic.success
          : installed
              ? scheme.primary
              : semantic.disabled,
      downloading: _downloadingId == model.id,
      installing: _installingId == model.id,
      sourceUrl: model.sourceUrl,
      actions: [
        if (installed && !preferred)
          TextButton(
            onPressed: _busy ? null : () => _setPreferredAsr(model.id),
            child: const Text("设为首选"),
          ),
        if (!installed)
          TextButton(
            onPressed: _busy ? null : () => _download(model.id),
            child: const Text("下载"),
          ),
        if (installed)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: _busy
                ? null
                : () => _delete(
                      model.id,
                      isTts: false,
                      isPreferred: preferred,
                    ),
            child: const Text("删除"),
          ),
      ],
    );
  }

  /// 导入的模型：目录名 + 设为首选 / 删除。
  Widget _importedRow(String id, {required bool isTts}) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool preferred = isTts
        ? AppData().preferredTtsModelId == id
        : AppData().preferredAsrModelId == id;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(id, style: theme.textTheme.titleSmall),
                Text(
                  preferred ? "使用中" : "已导入",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: preferred
                        ? theme.extension<AppSemanticColors>()!.success
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!preferred)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => isTts ? _setPreferred(id) : _setPreferredAsr(id),
              child: const Text("设为首选"),
            ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: _busy
                ? null
                : () => _delete(id, isTts: isTts, isPreferred: preferred),
            child: const Text("删除"),
          ),
        ],
      ),
    );
  }

  Widget _importedSection({required bool isTts}) {
    final List<String> ids =
        isTts ? AppData().importedTtsIds : AppData().importedAsrIds;
    if (ids.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xxs,
          ),
          child: Text("已导入", style: Theme.of(context).textTheme.labelLarge),
        ),
        for (final String id in ids) _importedRow(id, isTts: isTts),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("模型管理")),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            if (kIsWeb)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: AppRadius.cardBorder,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          "模型保存在浏览器的 IndexedDB 中，单个模型通常有几十到上百 MB。"
                          "清除站点数据会一并删除已下载的模型；首次加载与合成都比较慢，"
                          "移动浏览器在内存不足时可能失败。受浏览器 CORS 限制，"
                          "网页内下载可能失败；失败时按提示复制链接自行下载，"
                          "再用「导入模型」选择本地文件。",
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SettingItem(
              title: "文本转语音",
              children: [
                for (final TtsModelInfo model in StaticsVar.ttsModels)
                  _ttsRow(model),
                _importedSection(isTts: true),
              ],
            ),
            SettingItem(
              title: "语音识别",
              children: [
                for (final AsrModelInfo model in StaticsVar.asrModels)
                  _asrRow(model),
                _importedSection(isTts: false),
              ],
            ),
            SettingItem(
              title: "导入",
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "模型包（.tar.bz2）要求",
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        "• 只有一个顶层目录，目录名随意\n"
                        "• TTS VITS：*.onnx + 同名 *.onnx.json + tokens.txt"
                        "（可选 espeak-ng-data/）\n"
                        "• TTS Kokoro：model.onnx 或 model.int8.onnx + "
                        "voices.bin + tokens.txt（可选 espeak-ng-data/）\n"
                        "• ASR Whisper：*encoder*.onnx + *decoder*.onnx + "
                        "*tokens*.txt\n"
                        "• ASR NeMo CTC：model.onnx 或 model.int8.onnx + tokens.txt",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        "导入的模型来自你自己提供的文件，其来源与许可由你自行确认。",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_importing)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const LinearProgressIndicator(),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                "正在解压并导入模型包…",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      Button(
                        onPressed: _busy ? null : _importArchive,
                        child: const Text("导入模型包"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
