import 'package:arabic_learning/funcs/ai_service.dart';
import 'package:arabic_learning/funcs/quiz_bank.dart';
import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/pages/ai_quiz_page.dart';
import 'package:arabic_learning/vars/config_structure.dart' show WordItem;
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';

/// AI 练习入口设置页：在测试页独立访问，允许自选单词范围 + 题目类型进行 AI 练习
class AiTestSetupPage extends StatefulWidget {
  const AiTestSetupPage({super.key});

  @override
  State<AiTestSetupPage> createState() => _AiTestSetupPageState();
}

class _AiTestSetupPageState extends State<AiTestSetupPage> {
  // ── 单词选择 ──────────────────────────────────────────────────────────────
  List<WordItem> _selectedWords = [];

  // ── 题目配置 ──────────────────────────────────────────────────────────────
  QuizType _quizType = QuizType.fillBlank;
  QuizDifficulty _difficulty = QuizDifficulty.medium;

  // ── 批量设置 ──────────────────────────────────────────────────────────────
  /// 每次练习随机抽取几个单词
  int _wordBatchSize = 1;

  // ── 状态 ─────────────────────────────────────────────────────────────────
  bool _launching = false;
  String? _errorMsg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final bool hasWords = _selectedWords.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 练习'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 步骤 1：选择单词范围 ────────────────────────────────────────
            _SectionHeader(step: '1', title: '选择单词范围'),
            const SizedBox(height: 12),
            _WordRangeCard(
              theme: theme,
              mq: mq,
              selectedWords: _selectedWords,
              onTap: _pickWords,
            ),
            const SizedBox(height: 24),

            // ── 步骤 2：题目配置（需先选单词才激活） ────────────────────────
            AnimatedOpacity(
              opacity: hasWords ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !hasWords,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionHeader(step: '2', title: '选择题型'),
                    const SizedBox(height: 12),
                    _QuizTypeSelector(
                      selected: _quizType,
                      onChanged: (t) => setState(() => _quizType = t),
                    ),
                    const SizedBox(height: 24),

                    _SectionHeader(step: '3', title: '选择难度'),
                    const SizedBox(height: 12),
                    SegmentedButton<QuizDifficulty>(
                      segments: QuizDifficulty.values
                          .map((d) => ButtonSegment(
                                value: d,
                                label: Text(d.label),
                                icon: Icon(_diffIcon(d), size: 16),
                              ))
                          .toList(),
                      selected: {_difficulty},
                      onSelectionChanged: (s) =>
                          setState(() => _difficulty = s.first),
                    ),
                    const SizedBox(height: 24),

                    // ── 步骤 4：批量大小 ──────────────────────────────────
                    _SectionHeader(step: '4', title: '每次练习抽取单词数'),
                    const SizedBox(height: 8),
                    _BatchSizeRow(
                      value: _wordBatchSize,
                      max: _selectedWords.length.clamp(1, 10),
                      onChanged: (v) => setState(() => _wordBatchSize = v),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '将从 ${_selectedWords.length} 个单词中随机抽取 $_wordBatchSize 个进行练习',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── 错误提示 ──────────────────────────────────────────────────
            if (_errorMsg != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: StaticsVar.br,
                ),
                child: Row(children: [
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: TextStyle(
                          color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── 启动按钮 ──────────────────────────────────────────────────
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                fixedSize: Size(mq.size.width, 60),
                shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
                backgroundColor: hasWords
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                foregroundColor: hasWords
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.outline,
              ),
              icon: _launching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_launching ? '准备中…' : '开始 AI 练习'),
              onPressed: hasWords && !_launching ? _launch : null,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── 选词 ──────────────────────────────────────────────────────────────────
  Future<void> _pickWords() async {
    setState(() => _errorMsg = null);
    final selection = await popSelectClasses(
      context,
      withCache: false,
      withReviewChoose: false,
    );
    if (selection.selectedClass.isEmpty) return;
    final words =
        getSelectedWords(AppData().wordData, selection.selectedClass);
    setState(() {
      _selectedWords = words;
      _wordBatchSize = _wordBatchSize.clamp(1, words.length);
    });
  }

  // ── 启动练习 ──────────────────────────────────────────────────────────────
  Future<void> _launch() async {
    if (_selectedWords.isEmpty) return;
    setState(() {
      _launching = true;
      _errorMsg = null;
    });

    try {
      // 随机抽取单词
      final shuffled = List<WordItem>.from(_selectedWords)..shuffle();
      final batch = shuffled.take(_wordBatchSize).toList();

      if (batch.isEmpty) {
        setState(() {
          _errorMsg = '所选范围内没有单词，请重新选择';
          _launching = false;
        });
        return;
      }

      if (!mounted) return;

      // 逐词进入 AiQuizPage
      // 多词时：弹出进度对话框，逐词生成并跳转
      if (batch.length == 1) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AiQuizPage(word: batch.first),
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _MultiWordAiSession(
              words: batch,
              quizType: _quizType,
              difficulty: _difficulty,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = e.toString());
      }
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  IconData _diffIcon(QuizDifficulty d) {
    switch (d) {
      case QuizDifficulty.easy:
        return Icons.sentiment_satisfied;
      case QuizDifficulty.medium:
        return Icons.sentiment_neutral;
      case QuizDifficulty.hard:
        return Icons.sentiment_dissatisfied;
    }
  }
}

// ── 多词批量练习页 ──────────────────────────────────────────────────────────────
/// 逐词生成题目并依次展示，提供词间导航
class _MultiWordAiSession extends StatefulWidget {
  final List<WordItem> words;
  final QuizType quizType;
  final QuizDifficulty difficulty;

  const _MultiWordAiSession({
    required this.words,
    required this.quizType,
    required this.difficulty,
  });

  @override
  State<_MultiWordAiSession> createState() => _MultiWordAiSessionState();
}

class _MultiWordAiSessionState extends State<_MultiWordAiSession> {
  int _currentWordIndex = 0;
  bool _loading = false;
  String? _errorMsg;
  List<QuizItem>? _preloadedItems;

  @override
  void initState() {
    super.initState();
    _loadCurrentWord();
  }

  Future<void> _loadCurrentWord() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
      _preloadedItems = null;
    });
    try {
      final items = await AiService().generateAndSave(
        word: widget.words[_currentWordIndex],
        quizType: widget.quizType,
        difficulty: widget.difficulty,
      );
      if (!mounted) return;
      setState(() {
        _preloadedItems = items;
        _loading = false;
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.userMessage;
        _loading = false;
      });
    }
  }

  void _goToWord(int index) {
    setState(() => _currentWordIndex = index);
    _loadCurrentWord();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = widget.words[_currentWordIndex];
    final total = widget.words.length;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
              'AI 练习 (${_currentWordIndex + 1}/$total)'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 20),
              Text(
                'AI 正在生成题目…',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                word.arabic,
                style: TextStyle(
                  fontFamily: 'Traditional Arabic',
                  fontSize: 28,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(word.chinese,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () {
                  AiService().cancel();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close),
                label: const Text('取消'),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMsg != null) {
      return Scaffold(
        appBar: AppBar(
            title: Text('AI 练习 (${_currentWordIndex + 1}/$total)')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(_errorMsg!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: theme.colorScheme.error)),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _loadCurrentWord,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 跳转到 AiQuizPage（已预加载题目）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _preloadedItems == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => _MultiWordQuizWrapper(
            word: word,
            preloadedItems: _preloadedItems!,
            currentIndex: _currentWordIndex,
            total: total,
            onNext: _currentWordIndex < total - 1
                ? () => _goToWord(_currentWordIndex + 1)
                : null,
          ),
        ),
      ).then((_) {
        // 如果用户 pop 回来但仍未完成，重置 preloadedItems 让 addPostFrameCallback 不重复跳转
        if (mounted) setState(() => _preloadedItems = null);
      });
    });

    // 占位 loading（实际会被 addPostFrameCallback 跳走）
    return Scaffold(
      appBar:
          AppBar(title: Text('AI 练习 (${_currentWordIndex + 1}/$total)')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

// ── 带"下一个单词"入口的 AiQuizPage 包装 ────────────────────────────────────────
class _MultiWordQuizWrapper extends StatelessWidget {
  final WordItem word;
  final List<QuizItem> preloadedItems;
  final int currentIndex;
  final int total;
  final VoidCallback? onNext;

  const _MultiWordQuizWrapper({
    required this.word,
    required this.preloadedItems,
    required this.currentIndex,
    required this.total,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AiQuizPage(word: word, preloadedItems: preloadedItems),
        // 右上角当前进度 + 下一词按钮
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  if (onNext != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withAlpha(200),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.skip_next, size: 18),
                      label: Text('${currentIndex + 1}/$total 下一词'),
                      onPressed: () {
                        Navigator.pop(context);
                        onNext!();
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 子组件 ─────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String step;
  final String title;
  const _SectionHeader({required this.step, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      CircleAvatar(
        radius: 12,
        backgroundColor: theme.colorScheme.primary,
        child: Text(step,
            style: const TextStyle(fontSize: 12, color: Colors.white)),
      ),
      const SizedBox(width: 10),
      Text(title, style: theme.textTheme.titleMedium),
    ]);
  }
}

class _WordRangeCard extends StatelessWidget {
  final ThemeData theme;
  final MediaQueryData mq;
  final List<WordItem> selectedWords;
  final VoidCallback onTap;

  const _WordRangeCard({
    required this.theme,
    required this.mq,
    required this.selectedWords,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasWords = selectedWords.isNotEmpty;
    return Material(
      color: hasWords
          ? theme.colorScheme.primaryContainer.withAlpha(100)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: StaticsVar.br,
      child: InkWell(
        borderRadius: StaticsVar.br,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(children: [
            Icon(
              hasWords ? Icons.library_books : Icons.library_books_outlined,
              color: hasWords
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasWords ? '已选 ${selectedWords.length} 个单词' : '点击选择单词范围',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: hasWords
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ),
                  if (hasWords) ...[
                    const SizedBox(height: 4),
                    Text(
                      _previewWords(selectedWords),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontFamily: 'Traditional Arabic',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: theme.colorScheme.outline),
          ]),
        ),
      ),
    );
  }

  String _previewWords(List<WordItem> words) {
    final sample = words.take(5).map((w) => w.arabic).join('、');
    return words.length > 5 ? '$sample …' : sample;
  }
}

class _QuizTypeSelector extends StatelessWidget {
  final QuizType selected;
  final ValueChanged<QuizType> onChanged;
  const _QuizTypeSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: QuizType.values.map((t) {
        final bool isSelected = selected == t;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChoiceChip(
            avatar: Icon(_typeIcon(t), size: 18),
            label: Row(children: [
              Expanded(child: Text(t.label)),
              Text(
                _typeDesc(t),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ]),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onChanged(t),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        );
      }).toList(),
    );
  }

  IconData _typeIcon(QuizType t) {
    switch (t) {
      case QuizType.fillBlank:
        return Icons.edit_note;
      case QuizType.multipleChoice:
        return Icons.checklist;
      case QuizType.trueFalse:
        return Icons.rule;
      case QuizType.errorCorrection:
        return Icons.spellcheck;
    }
  }

  String _typeDesc(QuizType t) {
    switch (t) {
      case QuizType.fillBlank:
        return '在句中填入目标词';
      case QuizType.multipleChoice:
        return '四选一，选出正确答案';
      case QuizType.trueFalse:
        return '判断句子是否有错';
      case QuizType.errorCorrection:
        return '找出并改正错误词';
    }
  }
}

class _BatchSizeRow extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  const _BatchSizeRow(
      {required this.value, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton(
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: value > 1 ? () => onChanged(value - 1) : null,
      ),
      Expanded(
        child: Slider(
          value: value.toDouble(),
          min: 1,
          max: max.toDouble(),
          divisions: (max - 1).clamp(1, 100),
          label: value.toString(),
          onChanged: (v) => onChanged(v.round()),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.add_circle_outline),
        onPressed: value < max ? () => onChanged(value + 1) : null,
      ),
      SizedBox(
        width: 36,
        child: Text(
          value.toString(),
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ),
    ]);
  }
}
