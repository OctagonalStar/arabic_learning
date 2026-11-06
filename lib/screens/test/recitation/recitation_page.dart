// 课文背诵页：输入课文 → 录音 → 识别评分 → 结果与历史。
// 状态机：input → recording → analyzing → result（各分支可回 input）。
// 逻辑全部在 services/recitation_*.dart，本页只做流程与展示；Web 端无入口。

import 'dart:async' show Timer;

import 'package:arabic_learning/package_replacement/fake_dart_io.dart'
    if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/recitation_recorder.dart';
import 'package:arabic_learning/services/recitation_scorer.dart';
import 'package:arabic_learning/services/recitation_service.dart';
import 'package:arabic_learning/services/recitation_store.dart';
import 'package:arabic_learning/screens/setting/model_management_page.dart'
    show ModelManagementPage;
import 'package:arabic_learning/screens/test/recitation/recitation_result.dart'
    show RecitationResultView;
import 'package:arabic_learning/theme/tokens.dart' show AppRadius, AppSpacing;
import 'package:arabic_learning/widgets/kit.dart' show Button, TextContainer;
import 'package:arabic_learning/widgets/overlays.dart' show showSnackBar;
import 'package:arabic_learning/widgets/shared.dart' show appInputDecoration;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _Stage { input, recording, analyzing, result }

class RecitationPage extends StatefulWidget {
  const RecitationPage({super.key});

  @override
  State<RecitationPage> createState() => _RecitationPageState();
}

class _RecitationPageState extends State<RecitationPage> {
  final RecitationRecorder _recorder = RecitationRecorder();
  final TextEditingController _controller = TextEditingController();

  _Stage _stage = _Stage.input;
  bool _permissionDenied = false;
  int _seconds = 0;
  Timer? _timer;
  String _status = '';
  RecitationOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _recorder.dispose();
    super.dispose();
  }

  String get _text => _controller.text.trim();

  /// 录音失败/评分失败时清理临时 WAV。
  void _deleteWav(String path) {
    try {
      final io.File file = io.File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  Future<void> _startRecitation() async {
    if (_text.isEmpty || !AppData().asrModelDownloaded) return;
    final Global global = context.read<Global>();
    bool permitted;
    try {
      permitted = await _recorder.ensurePermission();
    } catch (e) {
      global.uiLogger.severe("录音权限检查失败: $e");
      if (!mounted) return;
      showSnackBar(context, "无法访问麦克风：$e");
      return;
    }
    if (!mounted) return;
    if (!permitted) {
      setState(() => _permissionDenied = true);
      return;
    }
    setState(() => _permissionDenied = false);
    try {
      await _recorder.start();
    } catch (e) {
      global.uiLogger.severe("录音启动失败: $e");
      if (!mounted) return;
      showSnackBar(context, "录音启动失败：$e");
      return;
    }
    if (!mounted) return;
    setState(() {
      _stage = _Stage.recording;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  Future<void> _stopAndScore() async {
    final Global global = context.read<Global>();
    _timer?.cancel();
    final String wavPath;
    try {
      wavPath = await _recorder.stop();
    } catch (e) {
      global.uiLogger.severe("录音停止失败: $e");
      if (!mounted) return;
      showSnackBar(context, "录音停止失败：$e");
      setState(() => _stage = _Stage.input);
      return;
    }
    final String reference = _text;
    setState(() {
      _stage = _Stage.analyzing;
      _status = '';
    });
    try {
      final RecitationOutcome outcome = await RecitationService().analyze(
        reference: reference,
        wavPath: wavPath,
        onStatus: (String status) {
          if (mounted) setState(() => _status = status);
        },
      );
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _stage = _Stage.result;
      });
    } catch (e) {
      _deleteWav(wavPath);
      global.uiLogger.severe("背诵评分失败: $e");
      if (!mounted) return;
      showSnackBar(context, "评分失败：${e.toString()}");
      setState(() => _stage = _Stage.input);
    }
  }

  /// 取消录音：`record` 的 cancel 会丢弃已录文件。
  Future<void> _cancelRecording() async {
    _timer?.cancel();
    try {
      await _recorder.cancel();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _stage = _Stage.input;
      _seconds = 0;
    });
  }

  void _retry() {
    setState(() {
      _stage = _Stage.input;
      _outcome = null;
    });
  }

  void _newText() {
    _controller.clear();
    setState(() {
      _stage = _Stage.input;
      _outcome = null;
    });
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  Widget _historySection() {
    if (_text.isEmpty) return const SizedBox.shrink();
    final List<RecitationRecord> records =
        RecitationStore().recordsFor(RecitationService.textHash(_text));
    if (records.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
          child: Text("历史成绩", style: theme.textTheme.titleMedium),
        ),
        for (final RecitationRecord record in records.take(5))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: AppRadius.controlBorder,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "${DateTime.fromMillisecondsSinceEpoch(record.timestamp).month}"
                    "-${_twoDigits(DateTime.fromMillisecondsSinceEpoch(record.timestamp).day)}"
                    " ${_twoDigits(DateTime.fromMillisecondsSinceEpoch(record.timestamp).hour)}"
                    ":${_twoDigits(DateTime.fromMillisecondsSinceEpoch(record.timestamp).minute)}",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text("${record.score} 分"),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  "覆盖 ${(record.coverage * 100).round()}%",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double width = MediaQuery.sizeOf(context).width * 0.9;
    return Scaffold(
      appBar: AppBar(title: const Text("课文背诵")),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            Center(
              child: SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_stage != _Stage.result) ...[
                      TextField(
                        controller: _controller,
                        textDirection: TextDirection.rtl,
                        keyboardType: TextInputType.multiline,
                        minLines: 4,
                        maxLines: 8,
                        enabled: _stage == _Stage.input,
                        decoration: appInputDecoration(
                          context,
                          hintText: "粘贴或输入要背诵的课文",
                          suffix: _text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: _newText,
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          _text.isEmpty
                              ? "支持任意阿拉伯语课文"
                              : "${_text.split(RegExp(r'\s+')).length} 词 · "
                                  "${_text.replaceAll(RegExp(r'\s'), '').length} 字母",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                      if (!AppData().asrModelDownloaded) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: TextContainer(
                            text: "语音识别模型未下载，无法进行背诵评分。请先在「模型管理」中下载。",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                        Button(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ModelManagementPage(),
                              ),
                            );
                            if (mounted) setState(() {});
                          },
                          child: const Text("前往模型管理"),
                        ),
                      ] else if (_permissionDenied) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: TextContainer(
                            text: "无法访问麦克风：请在系统设置中允许「Ar学」使用麦克风后重试。",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                        Button(
                          onPressed: _startRecitation,
                          child: const Text("重试"),
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Button(
                            onPressed: _text.isEmpty ? null : _startRecitation,
                            child: const Text("开始背诵"),
                          ),
                        ),
                    ],
                    if (_stage == _Stage.recording) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.mic, color: Colors.red),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                "录音中 ${_twoDigits(_seconds ~/ 60)}:${_twoDigits(_seconds % 60)}",
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: Button(
                                onPressed: _stopAndScore,
                                child: const Text("停止并评分"),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Button(
                                onPressed: _cancelRecording,
                                backgroundColor: theme.colorScheme.secondaryContainer,
                                child: const Text("取消"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_stage == _Stage.analyzing)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Center(
                          child: Column(
                            children: [
                              const CircularProgressIndicator(),
                              Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.sm),
                                child: Text(
                                  _status.isEmpty ? "正在分析录音…" : _status,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_stage == _Stage.result && _outcome != null)
                      RecitationResultView(
                        outcome: _outcome!,
                        onRetry: _retry,
                        onNewText: _newText,
                      ),
                    if (_stage != _Stage.recording && _stage != _Stage.analyzing)
                      _historySection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
