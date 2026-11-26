// 听抄播放页：先预合成全部音频，再按专业四级听写的四遍流程播放。

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/statics.dart' show StaticsVar;
import 'package:arabic_learning/screens/test/dictation/dictation_shared.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/tts.dart'
    show SpeechClip, TtsFailure, playSpeech, prepareSpeech;
import 'package:arabic_learning/theme/tokens.dart';
import 'package:arabic_learning/theme/typography.dart';
import 'package:arabic_learning/widgets/feedback.dart' show ProgressBar;
import 'package:arabic_learning/widgets/kit.dart' show Button, TextContainer;
import 'package:arabic_learning/widgets/overlays.dart' show alert;
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class DictationPlayPage extends StatefulWidget {
  final DictationArticle article;
  final List<String> sentences;
  final DictationConfig config;

  const DictationPlayPage({
    super.key,
    required this.article,
    required this.sentences,
    required this.config,
  });

  @override
  State<DictationPlayPage> createState() => _DictationPlayPageState();
}

class _DictationPlayPageState extends State<DictationPlayPage> {
  late final List<SpeechClip> _normalClips = List<SpeechClip>.filled(
    widget.sentences.length,
    _placeholderClip,
  );
  late final List<SpeechClip> _slowClips = List<SpeechClip>.filled(
    widget.sentences.length,
    _placeholderClip,
  );

  bool _preparing = true;
  bool _finished = false;
  String? _error;
  String _status = "正在缓存音频...";
  double _progress = 0;
  double _prepProgress = 0;
  int _completedUnits = 0;
  int _passIndex = 0;
  int _sentenceIndex = 0;
  int _secondsLeft = 0;

  int get _totalUnits => widget.sentences.length * dictationPasses.length;

  bool get _cacheAvailable => AppData().config.audio.audioSource == 2;

  bool get _running => !_preparing && !_finished && _error == null;

  static const SpeechClip _placeholderClip = SpeechClip(
    text: "",
    speed: 1.0,
    cached: false,
  );

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _prepare();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    // 页面被返回时立刻停止朗读，避免后台继续播放。
    StaticsVar.player.stop();
    super.dispose();
  }

  Future<void> _prepare() async {
    if (widget.sentences.isEmpty) {
      setState(() {
        _error = "这篇文章没有可播放的句子。";
        _preparing = false;
      });
      return;
    }
    final int total = widget.sentences.length * 2;
    int done = 0;
    try {
      for (int i = 0; i < widget.sentences.length; i++) {
        if (!mounted) return;
        setState(() {
          _status = _cacheAvailable
              ? "正在缓存第 ${i + 1}/${widget.sentences.length} 句"
              : "正在准备第 ${i + 1}/${widget.sentences.length} 句";
          _prepProgress = done / total;
        });
        _normalClips[i] = await prepareSpeech(
          widget.sentences[i],
          speed: widget.config.normalSpeed,
        );
        done++;
        if (!mounted) return;
        setState(() {
          _prepProgress = done / total;
        });
        _slowClips[i] = await prepareSpeech(
          widget.sentences[i],
          speed: widget.config.slowSpeed,
        );
        done++;
      }
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _prepProgress = 1;
        _progress = 0;
      });
      await _run();
    } on TtsFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _error = "准备音频失败：$e";
      });
    }
  }

  Future<void> _run() async {
    if (widget.config.countdown > 0) {
      await _setCountdown(
        "听抄即将开始\n请准备好纸笔，调整设备音量\n听写不设暂停",
        widget.config.countdown,
      );
    }
    for (int pass = 0; pass < dictationPasses.length; pass++) {
      if (!mounted) return;
      final DictationPassKind kind = dictationPasses[pass];
      setState(() {
        _passIndex = pass;
        _sentenceIndex = 0;
        _secondsLeft = 0;
        _status = _passTitle(pass, kind);
      });
      for (int i = 0; i < widget.sentences.length; i++) {
        if (!mounted) return;
        setState(() {
          _sentenceIndex = i;
          _status = "正在播放第 ${i + 1} 句";
        });
        await playSpeech(
          kind == DictationPassKind.normal ? _normalClips[i] : _slowClips[i],
        );
        if (!mounted) return;
        _completedUnits++;
        setState(() {
          _progress = _completedUnits / _totalUnits;
        });
        if (kind == DictationPassKind.slow) {
          await _setCountdown(
            "第 ${pass + 1} 遍 · 第 ${i + 1} 句已读完\n请继续书写",
            widget.config.sentenceInterval,
          );
        }
      }
      if (pass < dictationPasses.length - 1) {
        await _setCountdown(
          "第 ${pass + 1} 遍结束\n准备第 ${pass + 2} 遍",
          widget.config.passInterval,
        );
      }
    }
    if (!mounted) return;
    if (widget.config.finalCheck > 0) {
      await _setCountdown("四遍结束\n请检查拼写、格位与标点", widget.config.finalCheck);
    }
    if (!mounted) return;
    setState(() {
      _finished = true;
      _status = "听抄完成";
      _secondsLeft = 0;
    });
    WakelockPlus.disable();
  }

  Future<void> _setCountdown(String label, int seconds) async {
    for (int i = seconds; i > 0; i--) {
      if (!mounted) return;
      setState(() {
        _status = label;
        _secondsLeft = i;
      });
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() {
      _secondsLeft = 0;
    });
  }

  String _passTitle(int pass, DictationPassKind kind) {
    final String mode = kind == DictationPassKind.normal ? "正常速度" : "慢速逐句";
    return "第 ${pass + 1} 遍 · $mode";
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = !_running;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        alert(
          context,
          "退出后本次听抄进度不会保存。",
          destructive: true,
          confirmLabel: "退出",
          onConfirmed: () {
            if (mounted) Navigator.of(context).pop();
          },
        );
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_finished ? "听抄完成" : "听抄中")),
        body: SafeArea(
          top: false,
          child: _preparing
              ? _buildPreparing(context)
              : _error != null
              ? _buildError(context)
              : _finished
              ? _buildFinished(context)
              : _buildRunning(context),
        ),
      ),
    );
  }

  Widget _buildPreparing(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("正在预缓存音频", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            ProgressBar(value: _prepProgress, minHeight: 12),
            const SizedBox(height: AppSpacing.sm),
            Text(_status, textAlign: TextAlign.center),
            if (!_cacheAvailable) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                "当前音源不支持预缓存，每句开始前仍会现场合成，间隔可能略有偏差。",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: context.semanticColors.warning),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error ?? "未知错误",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Button(
              icon: Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _error = null;
                  _preparing = true;
                  _finished = false;
                  _prepProgress = 0;
                  _completedUnits = 0;
                  _progress = 0;
                  _passIndex = 0;
                  _sentenceIndex = 0;
                  _secondsLeft = 0;
                });
                _prepare();
              },
              child: Text("重试"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunning(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int currentSentence =
        _sentenceIndex.clamp(0, widget.sentences.length - 1) + 1;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: List<Widget>.generate(
                dictationPasses.length,
                (int index) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxs,
                    ),
                    child: _PassMark(
                      label: "第 ${index + 1} 遍",
                      active: index == _passIndex,
                      done: index < _passIndex,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ProgressBar(value: _progress, minHeight: 12),
            const SizedBox(height: AppSpacing.xs),
            Text(
              "已完成 $_completedUnits / $_totalUnits 句次 · "
              "第 $currentSentence/${widget.sentences.length} 句",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _secondsLeft > 0 ? "$_secondsLeft" : "",
              textAlign: TextAlign.center,
              style: theme.textTheme.displayLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              "本次听抄共四遍：正常 → 慢速逐句 → 慢速逐句 → 正常",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!_cacheAvailable) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                "当前音源无法预缓存音频，播放完成时刻可能有偏差。",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.semanticColors.warning,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinished(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      children: [
        TextContainer(text: "听抄完成。下面是可以用于核对的原文：", textAlign: TextAlign.center),
        TextContainer(
          text: widget.article.passage,
          selectable: true,
          style: arabicStyle(context, base: theme.textTheme.headlineSmall),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Button(
            icon: Icon(Icons.check, size: 32.0),
            size: const Size.fromHeight(80.0),
            onPressed: () => Navigator.popUntil(
              context,
              (Route<dynamic> route) => route.isFirst,
            ),
            child: Text(
              "完成",
              style: withoutColor(theme.textTheme.headlineSmall!),
            ),
          ),
        ),
      ],
    );
  }
}

class _PassMark extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;

  const _PassMark({
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background = active
        ? scheme.primary
        : done
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final Color foreground = active
        ? scheme.onPrimary
        : done
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: background, borderRadius: StaticsVar.br),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: foreground),
      ),
    );
  }
}
