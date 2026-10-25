// FSRS 个性化校准：限时看词 → 强制等待 1 分钟 → 中译阿选择题 → 应用个人系数。
//
// 校准只测「首次接触后的初始记忆强度」，因此全程不写 FSRS（不调用
// produceCard）；只有结果页「应用」时才通过 `FSRS().applyPersonalFactor`
// 把系数落盘。结果视图抽成 [FsrsCalibrationResultView]，方便独立测试。
import 'dart:math' show Random;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';

import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS, personalFactorForScore;
import 'package:arabic_learning/theme/tokens.dart' show AppMotion, AppRadius, AppSemanticColors, AppSpacing;
import 'package:arabic_learning/widgets/flip_word_card.dart' show FlipWordCard;
import 'package:arabic_learning/widgets/kit.dart' show Button, TextContainer;
import 'package:arabic_learning/widgets/overlays.dart' show viewAnswer;
import 'package:arabic_learning/widgets/questions.dart' show ChoiceQuestions;
import 'package:arabic_learning/widgets/shared.dart' show RevealableActionBar;

/// 每个词的展示时长。
const Duration _showDuration = Duration(seconds: 5);

/// 展示结束后的强制等待：给短期记忆留出衰减时间。
const Duration _waitDuration = Duration(seconds: 60);

/// 测试词池：未学词与已学词各取这么多个。
const int _poolPerSide = 5;

/// 校准总题数为 10（不足时按比例折算到 10 分制）。
const int _scoreBase = 10;

class FsrsCalibrationPage extends StatefulWidget {
  const FsrsCalibrationPage({super.key});

  @override
  State<FsrsCalibrationPage> createState() => _FsrsCalibrationPageState();
}

enum _Phase { intro, showing, waiting, quiz, result }

class _FsrsCalibrationPageState extends State<FsrsCalibrationPage> {
  final Random _rnd = Random();

  /// 按 id 索引的词条表（`WordItem.id` 是数组下标，但按 Map 查更稳）。
  late final Map<int, WordItem> _wordById;
  late final List<WordItem> _newPool;
  late final List<WordItem> _learnedPool;

  /// 本轮的展示词（也就是出题词）。
  late List<WordItem> _shown;
  late List<_CalibQuestion> _questions;

  _Phase _phase = _Phase.intro;
  int _showIndex = 0;
  int _quizIndex = 0;
  int _correct = 0;

  /// 折算到 0–10 的得分。
  int _scaledScore = 0;
  bool _answered = false;
  int? _chosenIndex;

  /// 词太少、没法凑不出一组 4 选 1。
  bool get _insufficient =>
      _newPool.isEmpty || _newPool.length + _learnedPool.length < 4;

  @override
  void initState() {
    super.initState();
    _wordById = <int, WordItem>{for (final WordItem w in AppData().wordData.words) w.id: w};
    _newPool = AppData().wordData.words
        .where((WordItem w) => !FSRS().isContained(w.id))
        .toList()
      ..shuffle(_rnd);
    _learnedPool = <WordItem>[
      for (final card in FSRS().config.cards) ?_wordById[card.cardId],
    ]..shuffle(_rnd);
    _shown = _sampleWords();
    _questions = _buildQuestions();
  }

  /// 抽 5 个未学 + 5 个已学；重测时重新抽，避免刚看过的词直接抬高分数。
  List<WordItem> _sampleWords() {
    _newPool.shuffle(_rnd);
    _learnedPool.shuffle(_rnd);
    return <WordItem>[
      ..._newPool.take(_poolPerSide),
      ..._learnedPool.take(_poolPerSide),
    ];
  }

  List<_CalibQuestion> _buildQuestions() => <_CalibQuestion>[
        for (final WordItem w in _shown) _CalibQuestion.build(w, _shown, _rnd),
      ]..shuffle(_rnd);

  void _startCalibration() {
    setState(() {
      _shown = _sampleWords();
      _questions = _buildQuestions();
      _phase = _Phase.showing;
      _showIndex = 0;
      _quizIndex = 0;
      _correct = 0;
      _scaledScore = 0;
      _answered = false;
      _chosenIndex = null;
    });
  }

  void _advanceShow() {
    if (!mounted) return;
    if (_showIndex >= _shown.length - 1) {
      setState(() => _phase = _Phase.waiting);
    } else {
      setState(() => _showIndex++);
    }
  }

  void _startQuiz() {
    if (mounted && _phase == _Phase.waiting) setState(() => _phase = _Phase.quiz);
  }

  bool? _onSelect(int value) {
    if (_answered) return null;
    final bool correct = value == _questions[_quizIndex].correctIndex;
    setState(() {
      _answered = true;
      _chosenIndex = value;
      if (correct) _correct++;
    });
    return correct;
  }

  void _advanceQuiz() {
    if (_quizIndex >= _questions.length - 1) {
      setState(() {
        _scaledScore = (_correct / _questions.length * _scoreBase)
            .round()
            .clamp(0, _scoreBase);
        _phase = _Phase.result;
      });
    } else {
      setState(() {
        _quizIndex++;
        _answered = false;
        _chosenIndex = null;
      });
    }
  }

  void _apply() {
    final double factor = personalFactorForScore(_scaledScore);
    FSRS().applyPersonalFactor(factor);
    Navigator.pop(context, factor);
  }

  @override
  Widget build(BuildContext context) {
    final bool canLeave = _phase == _Phase.intro || _phase == _Phase.result;
    return PopScope(
      canPop: canLeave,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text("放弃本次校准？"),
            content: const Text("中途退出会丢失本次结果，个性化系数保持不变。"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("继续测试")),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context);
                },
                child: const Text("退出"),
              ),
            ],
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: SafeArea(top: false, child: _buildBody(context)),
      ),
    );
  }

  String get _title => switch (_phase) {
        _Phase.intro => "个性化校准",
        _Phase.showing => "记住这些词",
        _Phase.waiting => "稍等片刻",
        _Phase.quiz => "回忆测试",
        _Phase.result => "校准结果",
      };

  Widget _buildBody(BuildContext context) {
    if (_insufficient) return _InsufficientView(onBack: () => Navigator.pop(context));
    return switch (_phase) {
      _Phase.intro => _buildIntro(context),
      _Phase.showing => _buildShowing(context),
      _Phase.waiting => _buildWaiting(context),
      _Phase.quiz => _buildQuiz(context),
      _Phase.result => FsrsCalibrationResultView(
          score: _scaledScore,
          questionCount: _questions.length,
          onApply: _apply,
          onRetake: _startCalibration,
        ),
    };
  }

  Widget _buildIntro(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int seconds = _shown.length * _showDuration.inSeconds +
        _waitDuration.inSeconds +
        _questions.length * 8;
    return _CenteredBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.psychology_alt_outlined, size: 44, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: AppSpacing.md),
          Text("先测一测你的记忆起点", style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "FSRS 会按你的记忆强度决定新词的首次复习间隔。\n花两分钟做个小测试，让它更懂你。",
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          _CalibCard(
            child: Column(
              children: [
                _StepRow(index: 1, icon: Icons.visibility_outlined, text: "${_shown.length} 个词，每个限时看 5 秒"),
                const _StepDivider(),
                _StepRow(index: 2, icon: Icons.hourglass_empty, text: "强制等待 1 分钟，让短期记忆自然衰减"),
                const _StepDivider(),
                _StepRow(index: 3, icon: Icons.quiz_outlined, text: "${_questions.length} 道中译阿选择题，按正确数折算系数"),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "预计约 ${(seconds / 60).ceil()} 分钟",
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Button(
            size: Size.fromHeight(64),
            onPressed: _startCalibration,
            icon: const Icon(Icons.play_arrow),
            child: const Text("开始校准"),
          ),
        ],
      ),
    );
  }

  Widget _buildShowing(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final WordItem word = _shown[_showIndex];
    final bool isLast = _showIndex >= _shown.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              Text("${_showIndex + 1} / ${_shown.length}", style: theme.textTheme.titleMedium),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: ClipRRect(
                  borderRadius: AppRadius.controlBorder,
                  child: LinearProgressIndicator(
                    value: (_showIndex + 1) / _shown.length,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text("记住它", style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: AppMotion.medium,
                switchInCurve: AppMotion.standardCurve,
                switchOutCurve: AppMotion.standardCurve,
                transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: Tween<double>(begin: 0.94, end: 1).animate(animation), child: child),
                ),
                // 换 key 让卡片随词切换做淡入缩放，同时重置下方倒计时。
                child: FlipWordCard(
                  key: ValueKey<int>(_showIndex),
                  word: word,
                  masked: false,
                  enableFlip: false,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ShowCountdown(
            key: ValueKey<int>(_showIndex),
            duration: _showDuration,
            onDone: _advanceShow,
          ),
          const SizedBox(height: AppSpacing.sm),
          Button(
            size: Size.fromHeight(56),
            onPressed: _advanceShow,
            child: Text(isLast ? "进入等待" : "下一个"),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiting(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return _CenteredBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("让记忆沉淀一下", style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "这一分钟先别回想刚才的单词。\n短暂遗忘后还能认出的，才是真正记住的。",
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          _WaitCountdown(duration: _waitDuration, onDone: _startQuiz),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_clock, size: 16, color: scheme.outline),
              const SizedBox(width: AppSpacing.xxs),
              Text("等待期间无法跳过", style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuiz(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _CalibQuestion question = _questions[_quizIndex];
    final bool isLast = _quizIndex >= _questions.length - 1;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Row(
            children: [
              Text("${_quizIndex + 1} / ${_questions.length}", style: theme.textTheme.titleMedium),
              const Spacer(),
              Text("答对 $_correct", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
            ],
          ),
        ),
        Expanded(
          // 与复习页一致：题目外壳交给现有题目组件，底栏用 RevealableActionBar。
          child: Material(
            child: ChoiceQuestions(
              key: ValueKey<int>(_quizIndex),
              mainWord: question.word.chinese,
              choices: question.options,
              optionWords: question.optionWords,
              allowAnitmation: true,
              allowMutipleSelect: false,
              hint: "通过中文选择阿拉伯语",
              onSelected: _onSelect,
              bottomWidget: _bottomBar(context, question, isLast),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomBar(BuildContext context, _CalibQuestion question, bool isLast) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double width = mediaQuery.size.width;
    return RevealableActionBar(
      revealed: _answered,
      tipWidth: (double value) => width * 0.9 - width * 0.5 * value,
      tipLabel: (double value) => value == 0.0 ? "忘了？" : "详解",
      onTipClicked: () {
        final WordItem? chosenWrong = (_chosenIndex != null && _chosenIndex != question.correctIndex)
            ? question.optionWords[_chosenIndex!]
            : null;
        viewAnswer(context, question.word, chosenWrong: chosenWrong);
        if (!_answered) setState(() => _answered = true);
      },
      gapWidth: (double value) => width * 0.02 * value,
      gapHeight: clampDouble(mediaQuery.size.height * 0.1, 16.0, 72.0),
      nextThreshold: 0.3,
      nextWidth: (double value) => width * 0.5 * value,
      nextIcon: Icon(isLast ? Icons.done_all : Icons.arrow_downward),
      nextLabel: isLast ? "查看结果" : "下一题",
      onNextClicked: _advanceQuiz,
    );
  }
}

/// 展示阶段：5 秒平滑倒计时（Tween 驱动，逐帧插值）。
class _ShowCountdown extends StatelessWidget {
  final Duration duration;
  final VoidCallback onDone;

  const _ShowCountdown({super.key, required this.duration, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: 0.0),
      duration: duration,
      curve: AppMotion.linearCurve,
      onEnd: onDone,
      builder: (BuildContext context, double value, Widget? child) {
        final int seconds = (value * duration.inSeconds).ceil();
        return Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                "$seconds s",
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.primary),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: ClipRRect(
                borderRadius: AppRadius.controlBorder,
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 等待阶段：圆环 + 大数字，60 秒内匀速走满（强制，无跳过入口）。
class _WaitCountdown extends StatelessWidget {
  final Duration duration;
  final VoidCallback onDone;

  const _WaitCountdown({required this.duration, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: AppMotion.linearCurve,
      onEnd: onDone,
      builder: (BuildContext context, double value, Widget? child) {
        final int remaining = (duration.inSeconds * (1 - value)).ceil();
        return SizedBox(
          width: 184,
          height: 184,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: scheme.primary,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$remaining",
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text("秒", style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 校准结果：得分环、档位、默认系数与个人系数对比、应用 / 重测。
class FsrsCalibrationResultView extends StatelessWidget {
  /// 折算到 0–10 的得分。
  final int score;

  /// 实际题数（不足 10 题时小于 10）。
  final int questionCount;

  final VoidCallback onApply;
  final VoidCallback onRetake;

  const FsrsCalibrationResultView({
    super.key,
    required this.score,
    required this.questionCount,
    required this.onApply,
    required this.onRetake,
  });

  /// 得分档位文案。
  static String tierText(double factor) {
    if (factor <= 0.75) return "记忆较弱";
    if (factor <= 0.9) return "记忆偏弱";
    if (factor <= 1.0) return "记忆正常";
    if (factor <= 1.1) return "记忆较强";
    return "记忆很强";
  }

  /// 系数效果说明。
  static String effectText(double factor) {
    if (factor > 1.0) return "新词的初始复习间隔会相应延长";
    if (factor < 1.0) return "新词的初始复习间隔会相应缩短";
    return "新词的初始复习间隔保持默认";
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors semantic = theme.extension<AppSemanticColors>() ?? AppSemanticColors.of(scheme);
    final double factor = personalFactorForScore(score);
    final Color accent = factor > 1.0
        ? semantic.success
        : factor < 1.0
            ? semantic.warning
            : scheme.primary;

    return _CenteredBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 172,
            height: 172,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: score / _scoreBase),
                  duration: AppMotion.extraLong2,
                  curve: AppMotion.standardCurve,
                  builder: (BuildContext context, double value, Widget? child) => SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 12,
                      strokeCap: StrokeCap.round,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: accent,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "$score",
                      style: theme.textTheme.displayLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      "/ $_scoreBase",
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: AppRadius.controlBorder,
            ),
            child: Text(tierText(factor), style: theme.textTheme.titleMedium?.copyWith(color: accent)),
          ),
          const SizedBox(height: AppSpacing.md),
          _CalibCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _FactorColumn(label: "默认", value: "1.00×", color: scheme.onSurfaceVariant)),
                    Icon(Icons.arrow_forward, color: scheme.outline),
                    Expanded(
                      child: _FactorColumn(
                        label: "你的系数",
                        value: "${factor.toStringAsFixed(2)}×",
                        color: accent,
                        emphasized: true,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Divider(height: 1),
                ),
                Row(
                  children: [
                    Icon(
                      factor > 1.0
                          ? Icons.trending_up
                          : factor < 1.0
                              ? Icons.trending_down
                              : Icons.horizontal_rule,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(effectText(factor), style: theme.textTheme.bodyMedium)),
                  ],
                ),
                if (questionCount != _scoreBase)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      "本次共 $questionCount 题，已按比例折算为 10 分制。",
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Button(
            size: Size.fromHeight(64),
            onPressed: onApply,
            icon: const Icon(Icons.check),
            child: const Text("应用系数"),
          ),
          const SizedBox(height: AppSpacing.xxs),
          TextButton(
            onPressed: onRetake,
            child: const Text("再测一次"),
          ),
        ],
      ),
    );
  }
}

class _FactorColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool emphasized;

  const _FactorColumn({
    required this.label,
    required this.value,
    required this.color,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: (emphasized ? theme.textTheme.headlineSmall : theme.textTheme.titleLarge)?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final IconData icon;
  final String text;

  const _StepRow({required this.index, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
          child: Text("$index", style: theme.textTheme.labelLarge?.copyWith(color: scheme.onPrimaryContainer)),
        ),
        const SizedBox(width: AppSpacing.xs),
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _StepDivider extends StatelessWidget {
  const _StepDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 47),
      child: Divider(height: AppSpacing.sm, color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}

/// 统一的内容容器：圆角 + 低对比底色。
class _CalibCard extends StatelessWidget {
  final Widget child;

  const _CalibCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
}

/// 居中且限宽，手机与桌面都保持可读行宽。
class _CenteredBody extends StatelessWidget {
  final Widget child;

  const _CenteredBody({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: child,
        ),
      ),
    );
  }
}

class _InsufficientView extends StatelessWidget {
  final VoidCallback onBack;

  const _InsufficientView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return _CenteredBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: AppSpacing.sm),
          TextContainer(
            text: "词库里的单词还不足以完成校准：\n至少需要 4 个词，其中要有未学过的新词。\n先去学习一些单词，再来校准吧。",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Button(onPressed: onBack, child: const Text("返回")),
        ],
      ),
    );
  }
}

/// 一道校准选择题：中译阿 4 选 1，干扰项取自同批展示词。
class _CalibQuestion {
  final WordItem word;
  final List<WordItem> optionWords;
  final int correctIndex;

  const _CalibQuestion({required this.word, required this.optionWords, required this.correctIndex});

  List<String> get options => <String>[for (final WordItem w in optionWords) w.arabic];

  factory _CalibQuestion.build(WordItem word, List<WordItem> pool, Random rnd) {
    final List<WordItem> others = pool.where((WordItem x) => x.id != word.id).toList()..shuffle(rnd);
    final List<WordItem> optionWords = <WordItem>[word, ...others.take(3)]..shuffle(rnd);
    return _CalibQuestion(
      word: word,
      optionWords: optionWords,
      correctIndex: optionWords.indexOf(word),
    );
  }
}
