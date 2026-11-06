// 模型管理页：集中列出 TTS / ASR 模型目录，支持下载（行内进度）、
// 设为首选、删除与本地模型包（.tar.bz2）导入。
// 逻辑全部在 services/model_manager.dart，本页只做展示与确认交互。

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
    show Button, SettingItem, TextContainer;
import 'package:arabic_learning/widgets/overlays.dart' show alart, showSnackBar;

class ModelManagementPage extends StatefulWidget {
  const ModelManagementPage({super.key});

  @override
  State<ModelManagementPage> createState() => _ModelManagementPageState();
}

class _ModelManagementPageState extends State<ModelManagementPage> {
  /// 正在下载的模型 id；null 表示当前没有下载任务（同时只允许一个）。
  String? _downloadingId;
  int _received = 0;
  int _total = 1;

  bool get _busy => _downloadingId != null;

  /// 首选模型变更 / 删除首选模型后重建本地 TTS，保证下次播报使用新音色。
  Future<void> _reloadTtsFor(String id) async {
    AppData().resetTTS();
    if (AppData().config.audio.audioSource == 2) {
      await AppData().loadTTS(AppData().config.audio.playRate);
    }
  }

  Future<void> _setPreferred(TtsModelInfo model) async {
    final Global global = context.read<Global>();
    global.uiLogger.info("设为首选TTS模型: ${model.id}");
    await global.patchConfig(
      (Config config) => config.copyWith(
        audio: config.audio.copyWith(preferredModelId: model.id),
      ),
    );
    await _reloadTtsFor(model.id);
    if (mounted) setState(() {});
  }

  Future<void> _download(String id) async {
    if (kIsWeb || _busy) return;
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
      );
      global.uiLogger.info("模型下载完成: $id");
      if (!mounted) return;
      showSnackBar(context, "下载完成");
    } catch (e) {
      global.uiLogger.severe("模型下载失败: $e");
      if (!mounted) return;
      showSnackBar(context, "下载失败：${e.toString()}");
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  /// 删除确认弹窗；确认后真正执行 [_confirmDelete]。
  void _delete(String id, {required bool isPreferred}) {
    alart(
      context,
      isPreferred ? "该模型正在使用中，删除后将回退为默认模型。确定删除吗？" : "删除后需重新下载才能继续使用。确定删除吗？",
      destructive: true,
      onConfirmed: () => _confirmDelete(id),
    );
  }

  Future<void> _confirmDelete(String id) async {
    final Global global = context.read<Global>();
    final bool isTts = StaticsVar.ttsModels.any((TtsModelInfo m) => m.id == id);
    try {
      if (isTts && AppData().preferredTtsModelId == id) {
        await global.patchConfig(
          (Config config) => config.copyWith(
            audio: config.audio.copyWith(preferredModelId: ""),
          ),
        );
      }
      await _reloadTtsFor(id);
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
    if (result == null || result.path == null) return;
    try {
      final String id = await ModelManager.importArchive(result.path!);
      global.uiLogger.info("模型包导入成功: $id");
      if (!mounted) return;
      showSnackBar(context, "已导入 $id");
    } catch (e) {
      global.uiLogger.severe("模型包导入失败: $e");
      if (!mounted) return;
      showSnackBar(context, e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
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
          if (downloading) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: LinearProgressIndicator(
                value: _total > 0 ? _received / _total : null,
                borderRadius: AppRadius.controlBorder,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                "已下载 ${(_received / 1048576).toStringAsFixed(1)} / "
                "${(_total / 1048576).toStringAsFixed(1)} MB"
                "${_total > 0 ? "（${(_received * 100) ~/ _total}%）" : ""}",
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
      sourceUrl: model.sourceUrl,
      actions: [
        if (installed && !preferred)
          TextButton(
            onPressed: _busy ? null : () => _setPreferred(model),
            child: const Text("设为首选"),
          ),
        if (!installed)
          TextButton(
            onPressed: (kIsWeb || _busy) ? null : () => _download(model.id),
            child: const Text("下载"),
          ),
        if (installed)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: (kIsWeb || _busy)
                ? null
                : () => _delete(model.id, isPreferred: preferred),
            child: const Text("删除"),
          ),
      ],
    );
  }

  Widget _asrRow(AsrModelInfo model) {
    final AppSemanticColors semantic =
        Theme.of(context).extension<AppSemanticColors>()!;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool installed = ModelManager.isInstalled(model.id);
    return _modelRow(
      title: model.title,
      description: model.description,
      meta: "${model.sizeMB} MB · ${model.license}",
      stateText: installed ? "已下载" : "未下载",
      stateColor: installed ? scheme.primary : semantic.disabled,
      downloading: _downloadingId == model.id,
      sourceUrl: model.sourceUrl,
      actions: [
        if (!installed)
          TextButton(
            onPressed: (kIsWeb || _busy) ? null : () => _download(model.id),
            child: const Text("下载"),
          ),
        if (installed)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: (kIsWeb || _busy) ? null : () => _delete(model.id, isPreferred: false),
            child: const Text("删除"),
          ),
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
                child: TextContainer(
                  text: "Web 端不支持本地神经网络模型，下载与导入不可用。",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            SettingItem(
              title: "文本转语音",
              children: [
                for (final TtsModelInfo model in StaticsVar.ttsModels)
                  _ttsRow(model),
              ],
            ),
            SettingItem(
              title: "语音识别",
              children: [
                for (final AsrModelInfo model in StaticsVar.asrModels)
                  _asrRow(model),
              ],
            ),
            SettingItem(
              title: "导入",
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Button(
                    onPressed: (kIsWeb || _busy) ? null : _importArchive,
                    child: const Text("导入模型包"),
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
