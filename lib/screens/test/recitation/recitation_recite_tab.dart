// 背诵 tab（按 [RecitationReciteMode] 分「逐句 / 整篇」两个独立页面，各自持有录音与滚动状态）。
// 逐句：一句一张竖向卡片，卡片内单独录音评分（分数只留本会话，不写存储），出分后停在原句。
// 整篇：整段 reference 录音评分 + RecitationResultView + RecitationStore 历史。
// 状态机：ready → recording → analyzing →（逐句回 ready / 整篇进 result）。
// 原文与译文各自模糊/显隐；出分后原文按词着色（漏读红 / 错读黄），逐句卡片下方显示识别文本。
// 录音与评分逻辑都在 services/recitation_*.dart，本页只做流程与展示。

import 'dart:async' show Timer;
import 'dart:ui' show ImageFilter;

import 'package:arabic_learning/core/adaptive.dart' show AdaptiveScope;
import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/models/recitation_text.dart';
import 'package:arabic_learning/package_replacement/fake_dart_io.dart'
    if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/screens/setting/model_management_page.dart'
    show ModelManagementPage;
import 'package:arabic_learning/screens/test/recitation/recitation_progress_bar.dart'
    show RecitationProgressBar;
import 'package:arabic_learning/screens/test/recitation/recitation_shared.dart'
    show RecitationCard, RecitationChip, RecitationTranslation;
import 'package:arabic_learning/screens/test/recitation/recitation_result.dart'
    show RecitationResultView;
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/recitation_recorder.dart';
import 'package:arabic_learning/services/recitation_scorer.dart';
import 'package:arabic_learning/services/recitation_service.dart';
import 'package:arabic_learning/services/recitation_store.dart';
import 'package:arabic_learning/core/recitation_text.dart'
    show tokenize, tokenSpanOf;
import 'package:arabic_learning/theme/tokens.dart'
    show AppBreakpoints, AppMotion, AppRadius, AppSpacing;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/motion.dart' show CrossFadeSwitcher;
import 'package:arabic_learning/widgets/overlays.dart' show showSnackBar;
import 'package:arabic_learning/core/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 背诵页的两种形态；每个 tab 只承担一种。
enum RecitationReciteMode { sentence, whole }

enum _Stage { ready, recording, analyzing, result }

class RecitationReciteTab extends StatefulWidget {
  final RecitationTextUnit unit;
  final RecitationReciteMode mode;
  // 传入时与「学习」tab 共用当前句位置；整篇模式不传，用自己的内部状态。
  final ValueNotifier<int>? position;
  const RecitationReciteTab({
    super.key,
    required this.unit,
    required this.mode,
    this.position,
  });

  @override
  State<RecitationReciteTab> createState() => _RecitationReciteTabState();
}

class _RecitationReciteTabState extends State<RecitationReciteTab>
    with AutomaticKeepAliveClientMixin {
  final RecitationRecorder _recorder = RecitationRecorder();
  late final PageController _pager;
  final ScrollController _wholeScroll = ScrollController();
  // 本页唯一的「当前句」（从 1 开始），只驱动底部进度条重建。
  final ValueNotifier<int> _ownCurrent = ValueNotifier<int>(1);
  // 供给了共用位置就直接用它，否则退回本页自有 notifier。
  ValueNotifier<int> get _current => widget.position ?? _ownCurrent;
  final Set<int> _revealed = <int>{};
  // 译文显隐独立于原文；_showAllTranslations 为页内开关，仅本次会话有效。
  final Set<int> _revealedZh = <int>{};
  bool _showAllTranslations = false;
  // 逐句成绩只保存在本会话内存里，按句索引映射，不落盘。
  final Map<int, RecitationOutcome> _sentenceOutcomes =
      <int, RecitationOutcome>{};
  final GlobalKey _resultKey = GlobalKey();

  _Stage _stage = _Stage.ready;
  bool _permissionDenied = false;
  // 整篇的「显示原文」开关；逐句卡片各自有显隐按钮。
  bool _showOriginal = false;
  int _seconds = 0;
  // 正在录音 / 分析的句子；整篇模式为 -1。
  int _activeIndex = -1;
  // 权限被拒后「重试」要重录的句子。
  int _retryIndex = 0;
  String _status = '';
  RecitationOutcome? _outcome;
  Timer? _timer;
  // 开始录音的墙钟时间：读秒按它算，不靠 tick 累加。
  DateTime? _startedAt;
  // 启动流程是异步的，用同步标志挡住连点。
  bool _starting = false;

  bool get _whole => widget.mode == RecitationReciteMode.whole;

  /// 切 tab 后保留本页的页码 / 成绩 / 结果。
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 从共用位置恢复页码，切 tab 回来直接停在同一句。
    final int max = widget.unit.sentences.isEmpty
        ? 0
        : widget.unit.sentences.length - 1;
    _pager = PageController(
      initialPage: ((widget.position?.value ?? 1) - 1).clamp(0, max),
    );
    // 只有共用位置时才监听；整篇模式保持独立。
    widget.position?.addListener(_syncFromPosition);
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.position?.removeListener(_syncFromPosition);
    _wholeScroll.dispose();
    _pager.dispose();
    _ownCurrent.dispose();
    _recorder.dispose();
    super.dispose();
  }

  /// 共用位置变了（来自「学习」tab 或进度条）才翻页；自身翻页已同步过，不重复动画。
  void _syncFromPosition() {
    final ValueNotifier<int>? shared = widget.position;
    if (shared == null || !mounted || !_pager.hasClients) return;
    final int target = shared.value - 1;
    if ((_pager.page ?? 0).round() == target) return;
    _pager.animateToPage(
      target,
      duration: AppMotion.quick,
      curve: AppMotion.standardCurve,
    );
  }

  /// 录音失败/评分失败时清理临时 WAV。
  void _deleteWav(String path) {
    try {
      final io.File file = io.File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  String _clock(int seconds) =>
      "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}";

  /// 检查麦克风权限；被拒时置位 [<_permissionDenied>]，由顶部提示给出重试入口。
  Future<bool> _ensurePermission() async {
    final Global global = context.read<Global>();
    bool permitted;
    try {
      permitted = await _recorder.ensurePermission();
    } catch (e) {
      global.uiLogger.severe("录音权限检查失败: $e");
      if (mounted) showSnackBar(context, "无法访问麦克风：$e");
      return false;
    }
    if (!mounted) return false;
    if (!permitted) {
      setState(() => _permissionDenied = true);
      return false;
    }
    if (_permissionDenied) setState(() => _permissionDenied = false);
    return true;
  }

  /// 开始录音。[index] 为句子索引，整篇模式传 -1。
  Future<void> _startRecording(int index) async {
    // 启动是异步的，用同步标志挡住连点：重复 start 会各起一个计时器，读秒翻倍。
    if (_stage != _Stage.ready || _starting) return;
    _starting = true;
    try {
      final Global global = context.read<Global>();
      _retryIndex = index;
      if (!await _ensurePermission()) return;
      if (!mounted) return;
      try {
        await _recorder.start();
      } catch (e) {
        global.uiLogger.severe("录音启动失败: $e");
        if (mounted) showSnackBar(context, "录音启动失败：$e");
        return;
      }
      if (!mounted) return;
      global.uiLogger.info(
          "录音开始: ${index >= 0 ? "第 ${index + 1} 句" : "整篇"} (${widget.unit.title})");
      setState(() {
        _stage = _Stage.recording;
        _activeIndex = index;
        _seconds = 0;
      });
      _startedAt = DateTime.now();
      _timer?.cancel();
      // 读秒按开始时间算而不是 tick 累加：回调抖动或重复都不会跳秒。
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final DateTime? started = _startedAt;
        if (!mounted || started == null) return;
        final int elapsed = DateTime.now().difference(started).inSeconds;
        if (elapsed != _seconds) setState(() => _seconds = elapsed);
      });
    } finally {
      _starting = false;
    }
  }

  /// 停止录音并评分。[index] 为句子索引，整篇模式传 -1。
  Future<void> _stopAndScore(int index) async {
    final Global global = context.read<Global>();
    _timer?.cancel();
    final String wavPath;
    try {
      wavPath = await _recorder.stop();
    } catch (e) {
      global.uiLogger.severe("录音停止失败: $e");
      if (!mounted) return;
      showSnackBar(context, "录音停止失败：$e");
      setState(() => _stage = _Stage.ready);
      return;
    }
    setState(() {
      _stage = _Stage.analyzing;
      _status = '';
      // 录完就先露出原文：评分出分后直接看到逐词标色，不再回模糊。
      if (index >= 0) {
        _revealed.add(index);
      } else {
        _showOriginal = true;
      }
    });
    final String reference = index >= 0
        ? widget.unit.sentences[index].arabic
        : widget.unit.reference;
    try {
      final RecitationOutcome outcome = await RecitationService().analyze(
        reference: reference,
        wavPath: wavPath,
        onStatus: (String status) {
          if (mounted) setState(() => _status = status);
        },
      );
      if (!mounted) return;
      global.uiLogger.info(
          "评分完成: ${index >= 0 ? "第 ${index + 1} 句" : "整篇"}, "
          "scoreable=${outcome.scoreable}, score=${outcome.score}, "
          "coverage=${outcome.coverage.toStringAsFixed(3)}");
      if (index >= 0) {
        setState(() {
          _sentenceOutcomes[index] = outcome;
          _stage = _Stage.ready;
        });
      } else {
        setState(() {
          _outcome = outcome;
          _stage = _Stage.result;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final BuildContext? target = _resultKey.currentContext;
          if (target == null) return;
          Scrollable.ensureVisible(
            target,
            duration: AppMotion.medium,
            curve: AppMotion.decelerateCurve,
            alignment: 0.0,
          );
        });
      }
    } catch (e) {
      _deleteWav(wavPath);
      global.uiLogger.severe("背诵评分失败: $e");
      if (!mounted) return;
      showSnackBar(context, "评分失败：${e.toString()}");
      setState(() => _stage = _Stage.ready);
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
      _stage = _Stage.ready;
      _activeIndex = -1;
      _seconds = 0;
    });
  }

  void _retry() {
    setState(() {
      _stage = _Stage.ready;
      _outcome = null;
    });
  }

  void _retryRecording() => _startRecording(_whole ? -1 : _retryIndex);

  // 定位 / 进度同步

  void _locatePage(int index) {
    if (!_pager.hasClients) return;
    _pager.animateToPage(
      index - 1,
      duration: AppMotion.quick,
      curve: AppMotion.standardCurve,
    );
  }

  /// 「统一显示中文」页内开关：选中即全部译文可见，仅本次会话有效。
  /// 标签压到两个字并靠 tooltip 说全，放进进度条 / 标题行都不会挤爆窄屏。
  Widget _translationToggle() {
    return Tooltip(
      message: "统一显示中文",
      child: FilterChip(
        label: const Text("中文"),
        selected: _showAllTranslations,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onSelected: (bool value) =>
            setState(() => _showAllTranslations = value),
      ),
    );
  }

  Color _gradeColor(RecitationOutcome outcome) {
    final ThemeData theme = Theme.of(context);
    if (!outcome.scoreable) return theme.colorScheme.error;
    final int score = outcome.score ?? 0;
    if (score >= 85) return context.semanticColors.success;
    if (score >= 70) return theme.colorScheme.primary;
    if (score >= 55) return context.semanticColors.warning;
    return theme.colorScheme.error;
  }

  /// 权限 / 模型未下载提示：错误色淡底 + 边框，与卡片区分开但同属一个色系。
  Widget _gate(ThemeData theme, {required String text, required Widget action}) {
    final ColorScheme scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            scheme.error.withValues(alpha: 0.08),
            scheme.surfaceContainerLow,
          ),
          borderRadius: AppRadius.controlBorder,
          border: Border.all(color: scheme.error.withValues(alpha: 0.38)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.error_outline, size: 20.0, color: scheme.error),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: action,
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, double width, bool modelReady) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Center(
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_whole)
                Row(
                  children: <Widget>[
                    Text("原文", style: theme.textTheme.titleLarge),
                    const Spacer(),
                    _translationToggle(),
                    const SizedBox(width: AppSpacing.xs),
                    TextButton(
                      onPressed: () => setState(() {
                        _showOriginal = !_showOriginal;
                        _revealed.clear();
                      }),
                      child: Text(_showOriginal ? "模糊原文" : "显示原文"),
                    ),
                  ],
                ),
              if (!modelReady)
                _gate(
                  theme,
                  text: "语音识别模型未下载，无法进行背诵评分。请先在「模型管理」中下载。",
                  action: Button(
                    onPressed: () async {
                      await pushPage(
                        context,
                        ModelManagementPage(),
                      );
                      if (mounted) setState(() {});
                    },
                    child: const Text("前往模型管理"),
                  ),
                )
              else if (_permissionDenied)
                _gate(
                  theme,
                  text: "无法访问麦克风：请在系统设置中允许「Ar学」使用麦克风后重试。",
                  action: Button(onPressed: _retryRecording, child: const Text("重试")),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 点原文 / 眼睛按钮都只切换本句原文的显隐。
  void _toggleArabic(int index) => setState(() {
        if (!_revealed.remove(index)) _revealed.add(index);
      });

  /// 译文显隐；「统一显示中文」打开时不再有单句遮挡，点击无效。
  void _toggleTranslation(int index) {
    if (_showAllTranslations) return;
    setState(() {
      if (!_revealedZh.remove(index)) _revealedZh.add(index);
    });
  }

  /// 只模糊需要遮掩的那一部分，两块各自成像，布局不受影响。
  Widget _blurUnless(bool visible, Widget child) => visible
      ? child
      : ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Opacity(opacity: 0.9, child: child),
        );

  /// 本句的逐词标记。逐句结果本身就对应本句 token；整篇结果按句 token 数切片。
  /// 分词数与结果对不上（门禁命中、文本被改过）时返回 null，退回纯文本。
  List<RecitationTokenMark>? _marksFor(int index, RecitationOutcome? outcome) {
    if (outcome == null || outcome.marks.isEmpty) return null;
    final List<RecitationSentence> sentences = widget.unit.sentences;
    if (!_whole) {
      final int count = tokenize(sentences[index].arabic).length;
      return count == outcome.marks.length ? outcome.marks : null;
    }
    if (tokenize(widget.unit.reference).length != outcome.marks.length) {
      return null;
    }
    int start = 0;
    for (int i = 0; i < index; i++) {
      start += tokenize(sentences[i].arabic).length;
    }
    final int count = tokenize(sentences[index].arabic).length;
    if (count == 0 || start + count > outcome.marks.length) return null;
    return outcome.marks.sublist(start, start + count);
  }

  /// 原文按词着色：漏读红、错读黄，词间空格与标点保持普通样式。
  Widget _arabicText(
    ThemeData theme,
    String text,
    TextStyle style,
    List<RecitationTokenMark>? marks,
  ) {
    final List<({int start, int end})> spans = tokenSpanOf(text);
    if (marks == null || marks.length != spans.length) {
      return Text(
        text,
        textDirection: TextDirection.rtl,
        style: style.copyWith(height: 1.7),
      );
    }
    final Color warning = context.semanticColors.warning;
    final List<InlineSpan> parts = <InlineSpan>[];
    int cursor = 0;
    for (int i = 0; i < spans.length; i++) {
      final ({int start, int end}) span = spans[i];
      if (span.start > cursor) {
        parts.add(TextSpan(text: text.substring(cursor, span.start)));
      }
      final Color? markColor = switch (marks[i]) {
        RecitationTokenMark.missing => theme.colorScheme.error,
        RecitationTokenMark.misread => warning,
        RecitationTokenMark.matched => null,
      };
      parts.add(TextSpan(
        text: text.substring(span.start, span.end),
        style: markColor == null
            ? null
            : TextStyle(
                color: markColor,
                backgroundColor: markColor.withValues(alpha: 0.15),
              ),
      ));
      cursor = span.end;
    }
    if (cursor < text.length) {
      parts.add(TextSpan(text: text.substring(cursor)));
    }
    return Text.rich(
      TextSpan(children: parts),
      textDirection: TextDirection.rtl,
      style: style.copyWith(height: 1.7),
    );
  }

  Widget _sentenceBody(
    int index,
    ThemeData theme,
    bool wide,
    RecitationOutcome? outcome,
  ) {
    final RecitationSentence sentence = widget.unit.sentences[index];
    final TextStyle arabicStyle =
        (wide ? theme.textTheme.headlineMedium : theme.textTheme.headlineSmall)!;
    final bool arabicVisible = _showOriginal || _revealed.contains(index);
    final bool translationVisible =
        _showAllTranslations || _revealedZh.contains(index);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggleArabic(index),
          child: _blurUnless(
            arabicVisible,
            _arabicText(
              theme,
              sentence.arabic,
              arabicStyle,
              _marksFor(index, _whole ? _outcome : outcome),
            ),
          ),
        ),
        if (sentence.translation.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleTranslation(index),
              child: _blurUnless(
                translationVisible,
                RecitationTranslation(text: sentence.translation),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sentenceCard(int index, ThemeData theme, bool wide) {
    final ColorScheme scheme = theme.colorScheme;
    final RecitationSentence sentence = widget.unit.sentences[index];
    final bool arabicVisible = _showOriginal || _revealed.contains(index);
    final bool translationVisible =
        _showAllTranslations || _revealedZh.contains(index);
    final RecitationOutcome? outcome = _sentenceOutcomes[index];
    return RecitationCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                RecitationChip(
                  text: "第 ${index + 1} 句",
                  background: scheme.surfaceContainerHighest,
                  foreground: scheme.onSurfaceVariant,
                ),
                if (outcome != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.xs),
                  RecitationChip(
                    text: outcome.scoreable
                        ? "${outcome.score} 分 · ${outcome.grade}"
                        : "未评分",
                    background:
                        _gradeColor(outcome).withValues(alpha: 0.15),
                    foreground: _gradeColor(outcome),
                  ),
                ],
                const Spacer(),
                IconButton(
                  tooltip: arabicVisible ? "模糊原文" : "显示原文",
                  onPressed: () => _toggleArabic(index),
                  icon: Icon(
                    arabicVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                if (sentence.translation.isNotEmpty && !_showAllTranslations)
                  IconButton(
                    tooltip: translationVisible ? "模糊译文" : "显示译文",
                    onPressed: () => _toggleTranslation(index),
                    icon: Icon(
                      translationVisible
                          ? Icons.subtitles_off_outlined
                          : Icons.subtitles_outlined,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            _sentenceBody(index, theme, wide, outcome),
            if (!_whole) _sentenceControls(index, theme, outcome),
          ],
        ),
      ),
    );
  }

  /// 逐句卡片底部：录音按钮 / 录音中 / 分析中 / 本句成绩。
  Widget _sentenceControls(int index, ThemeData theme, RecitationOutcome? outcome) {
    final ColorScheme scheme = theme.colorScheme;
    final bool active = _activeIndex == index;
    final bool modelReady = AppData().asrModelDownloaded;
    final List<Widget> content;
    if (active && _stage == _Stage.recording) {
      content = <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.mic, color: scheme.error),
            const SizedBox(width: AppSpacing.xs),
            Text("录音中 ${_clock(_seconds)}",
                style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            Expanded(
              child: Button(
                onPressed: () => _stopAndScore(index),
                child: const Text("停止并评分"),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Button(
                onPressed: _cancelRecording,
                backgroundColor: scheme.secondaryContainer,
                child: const Text("取消"),
              ),
            ),
          ],
        ),
      ];
    } else if (active && _stage == _Stage.analyzing) {
      content = <Widget>[
        Row(
          children: <Widget>[
            const SizedBox(
              width: 18.0,
              height: 18.0,
              child: CircularProgressIndicator(strokeWidth: 2.0),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                _status.isEmpty ? "正在分析录音…" : _status,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ];
    } else {
      content = <Widget>[
        if (outcome != null) _outcomeDetail(theme, outcome),
        if (outcome != null && outcome.transcript.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "识别文本",
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  outcome.transcript,
                  textDirection: TextDirection.rtl,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: Button(
            icon: const Icon(Icons.mic_none),
            onPressed:
                modelReady && _stage == _Stage.ready ? () => _startRecording(index) : null,
            child: Text(outcome == null ? "录这一句" : "重录这句"),
          ),
        ),
      ];
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        // 控制区用最深一档容器色，和译文区 / 卡片本身分开。
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: AppRadius.controlBorder,
          border: Border.all(color: scheme.outlineVariant),
        ),
        // 不同阶段给不同 key，CrossFadeSwitcher 才会切换而不是原地重建。
        child: CrossFadeSwitcher(
          duration: AppMotion.quick,
          child: Column(
            key: ValueKey<String>('${_stage.name}-${outcome != null}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: content,
          ),
        ),
      ),
    );
  }

  /// 本句成绩摘要：覆盖/顺序/多读；门禁命中时只给结论。
  /// 漏读不再单列文字，原文里已经逐词标红。
  Widget _outcomeDetail(ThemeData theme, RecitationOutcome outcome) {
    final ColorScheme scheme = theme.colorScheme;
    if (!outcome.scoreable) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(
          outcome.summary,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.error,
            height: 1.5,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        "覆盖 ${(outcome.coverage * 100).round()}% · "
        "顺序 ${(outcome.orderRate * 100).round()}% · "
        "多读 ${(outcome.insertionRate * 100).round()}%",
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _sentencePager(ThemeData theme, bool wide, double width) {
    final List<RecitationSentence> sentences = widget.unit.sentences;
    return PageView.builder(
      controller: _pager,
      scrollDirection: Axis.vertical,
      itemCount: sentences.length,
      onPageChanged: (int index) => _current.value = index + 1,
      itemBuilder: (BuildContext context, int index) => Center(
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            // shortcut: 卡片自身可滚时内层会吃掉竖向滑动，翻句改用底部进度条 /
            // 上下箭头；课文长到一屏放不下时再换成能透传手势的分页实现。
            child: _sentenceCard(index, theme, wide),
          ),
        ),
      ),
    );
  }

  Widget _wholeList(ThemeData theme, bool wide, double width) {
    final List<RecitationSentence> sentences = widget.unit.sentences;
    return SingleChildScrollView(
      controller: _wholeScroll,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: SizedBox(
          width: width,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < sentences.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: _sentenceCard(i, theme, wide),
                ),
              if (_stage == _Stage.result && _outcome != null)
                Padding(
                  key: _resultKey,
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: _panel(
                    theme,
                    child: RecitationResultView(
                      outcome: _outcome!,
                      onRetry: _retry,
                      onNewText: null,
                    ),
                  ),
                ),
              _historySection(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(ThemeData theme, {required Widget child}) {
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _wholeControls(ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    final bool modelReady = AppData().asrModelDownloaded;
    if (_stage == _Stage.analyzing) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(
              width: 18.0,
              height: 18.0,
              child: CircularProgressIndicator(strokeWidth: 2.0),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                _status.isEmpty ? "正在分析录音…" : _status,
                style: theme.textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    if (_stage == _Stage.recording) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.mic, color: scheme.error),
                const SizedBox(width: AppSpacing.xs),
                Text("录音中 ${_clock(_seconds)}",
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                Expanded(
                  child: Button(
                    onPressed: () => _stopAndScore(-1),
                    child: const Text("停止并评分"),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Button(
                    onPressed: _cancelRecording,
                    backgroundColor: scheme.secondaryContainer,
                    child: const Text("取消"),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Button(
          icon: const Icon(Icons.mic_none),
          onPressed: modelReady ? () => _startRecording(-1) : null,
          child: Text(_outcome == null ? "开始背诵" : "再背一遍"),
        ),
      ),
    );
  }

  Widget _historySection(ThemeData theme) {
    final List<RecitationRecord> records =
        RecitationStore().recordsFor(RecitationService.textHash(widget.unit.reference));
    if (records.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
          child: Text("历史成绩", style: theme.textTheme.titleLarge),
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
              children: <Widget>[
                Expanded(
                  child: Text(
                    "${DateTime.fromMillisecondsSinceEpoch(record.timestamp).month}"
                    "-${DateTime.fromMillisecondsSinceEpoch(record.timestamp).day.toString().padLeft(2, '0')}"
                    " ${DateTime.fromMillisecondsSinceEpoch(record.timestamp).hour.toString().padLeft(2, '0')}"
                    ":${DateTime.fromMillisecondsSinceEpoch(record.timestamp).minute.toString().padLeft(2, '0')}",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text("${record.score} 分",
                    style: theme.textTheme.titleMedium),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  "覆盖 ${(record.coverage * 100).round()}%",
                  style: theme.textTheme.bodyMedium?.copyWith(
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
    super.build(context);
    final ThemeData theme = Theme.of(context);
    final bool wide = AdaptiveScope.of(context).isWide;
    final double width = AppBreakpoints.contentWidth(context);
    final int count = widget.unit.sentences.length;
    final bool modelReady = AppData().asrModelDownloaded;
    // KeepAlive 挂起期间监听可能因 pager 无 clients 而跳过，回到前台的第一帧补齐位置。
    if (!_whole) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromPosition());
    }
    return SafeArea(
      top: false,
      // 底部安全区交给进度条自己的 SafeArea，条底色才能铺到手势区。
      bottom: false,
      child: Column(
        children: <Widget>[
          _header(theme, width, modelReady),
          Expanded(
            child: _whole
                ? _wholeList(theme, wide, width)
                : _sentencePager(theme, wide, width),
          ),
          if (_whole && _stage != _Stage.result)
            CrossFadeSwitcher(
              duration: AppMotion.quick,
              child: KeyedSubtree(
                key: ValueKey<String>(_stage.name),
                child: _wholeControls(theme),
              ),
            ),
          // 整篇没有翻句需求，不显示进度条；「统一显示中文」放在逐句的进度条里。
          if (!_whole)
            ValueListenableBuilder<int>(
              valueListenable: _current,
              builder: (BuildContext context, int value, Widget? child) =>
                  RecitationProgressBar(
                    current: value,
                    count: count,
                    onLocate: _locatePage,
                    trailing: _translationToggle(),
                  ),
            ),
        ],
      ),
    );
  }
}
