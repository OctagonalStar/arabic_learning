import 'package:arabic_learning/funcs/ai_service.dart';
import 'package:arabic_learning/funcs/quiz_bank.dart' show QuizDifficulty, QuizDifficultyLabel;
import 'package:arabic_learning/vars/config_structure.dart' show WordItem;
import 'package:arabic_learning/vars/global.dart' show AppData;
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';

// ── 数据模型 ─────────────────────────────────────────────────────────────────

enum ReadingQuestionType { choice, open }

class ReadingQuestion {
  final ReadingQuestionType type;
  final String q;
  final List<String> choices;   // only for choice
  final int correctIndex;       // only for choice
  final String stdAnswer;
  final String explanation;

  const ReadingQuestion({
    required this.type,
    required this.q,
    this.choices = const [],
    this.correctIndex = 0,
    required this.stdAnswer,
    required this.explanation,
  });

  factory ReadingQuestion.fromMap(Map<String, dynamic> m) {
    final typeStr = m['type'] as String? ?? 'open';
    if (typeStr == 'choice') {
      final raw = (m['choices'] as List?)?.cast<String>() ?? [];
      final idx = (m['correct_index'] as num?)?.toInt() ?? 0;
      return ReadingQuestion(
        type: ReadingQuestionType.choice,
        q: m['q'] as String? ?? '',
        choices: raw,
        correctIndex: idx,
        stdAnswer: raw.isNotEmpty && idx < raw.length ? raw[idx] : (m['std_answer'] as String? ?? ''),
        explanation: m['explanation'] as String? ?? '',
      );
    } else {
      return ReadingQuestion(
        type: ReadingQuestionType.open,
        q: m['q'] as String? ?? '',
        stdAnswer: m['std_answer'] as String? ?? '',
        explanation: m['explanation'] as String? ?? '',
      );
    }
  }
}

class ReadingPassage {
  final String passage;
  final String summary;
  final List<ReadingQuestion> questions;
  const ReadingPassage({required this.passage, required this.summary, required this.questions});

  factory ReadingPassage.fromMap(Map<String, dynamic> m) {
    final qs = ((m['questions'] as List?) ?? [])
        .map((q) => ReadingQuestion.fromMap(q as Map<String, dynamic>))
        .toList();
    return ReadingPassage(
      passage: m['passage'] as String? ?? '',
      summary: m['passage_summary'] as String? ?? '',
      questions: qs,
    );
  }
}

// ── 阅读理解页 ────────────────────────────────────────────────────────────────

class AiReadingPage extends StatefulWidget {
  final List<WordItem> words;
  const AiReadingPage({super.key, required this.words});

  @override
  State<AiReadingPage> createState() => _AiReadingPageState();
}

class _AiReadingPageState extends State<AiReadingPage> {
  // ── config ────────────────────────────────────────────────────────────────
  QuizDifficulty _difficulty = QuizDifficulty.medium;
  bool _configuring = true;

  // ── batch ─────────────────────────────────────────────────────────────────
  late List<List<WordItem>> _batches;
  int _batchIdx = 0;

  // ── passage state ─────────────────────────────────────────────────────────
  bool _loading = false;
  String? _errorMsg;
  ReadingPassage? _passage;

  // ── question state ────────────────────────────────────────────────────────
  int _currentQ = 0;
  int? _selectedChoice;       // for choice questions
  bool _choiceAnswered = false;
  bool _showOpenAnswer = false;
  final TextEditingController _textCtrl = TextEditingController();

  // ── batch size from config ────────────────────────────────────────────────
  int get _batchSize => AppData().config.ai.readingBatchSize.clamp(10, 50);

  @override
  void initState() {
    super.initState();
    _buildBatches();
  }

  void _buildBatches() {
    final size = _batchSize;
    _batches = [];
    for (int i = 0; i < widget.words.length; i += size) {
      _batches.add(widget.words.sublist(i, (i + size).clamp(0, widget.words.length)));
    }
    if (_batches.isEmpty) _batches = [widget.words];
    _batchIdx = 0;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    AiService().cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _errorMsg = null; _configuring = false; });
    try {
      final batchWords = _batches[_batchIdx];
      final raw = await AiService().generateReading(words: batchWords, difficulty: _difficulty);
      if (!mounted) return;
      setState(() {
        _passage = ReadingPassage.fromMap(raw);
        _loading = false;
        _resetQuestion();
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _errorMsg = e.userMessage; });
    }
  }

  void _resetQuestion() {
    _currentQ = 0;
    _selectedChoice = null;
    _choiceAnswered = false;
    _showOpenAnswer = false;
    _textCtrl.clear();
  }

  void _nextBatch() {
    if (_batchIdx < _batches.length - 1) {
      setState(() { _batchIdx++; _passage = null; });
      _generate();
    } else {
      // 全部篇章完成
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('全部完成 🎉'),
        content: Text('已完成 ${_batches.length} 篇阅读练习！'),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text('返回')),
          TextButton(onPressed: () { Navigator.pop(ctx); setState(() { _batchIdx = 0; _passage = null; _configuring = true; }); }, child: const Text('重新开始')),
        ],
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool multipleBatches = _batches.length > 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(multipleBatches
            ? 'AI 阅读理解（第 ${_batchIdx + 1}/${_batches.length} 篇）'
            : 'AI 阅读理解'),
        actions: [
          if (!_loading && !_configuring)
            IconButton(icon: const Icon(Icons.tune), tooltip: '重新选择难度',
                onPressed: () => setState(() { _configuring = true; _passage = null; })),
          if (!_loading && !_configuring)
            IconButton(icon: const Icon(Icons.refresh), tooltip: '重新生成', onPressed: _generate),
        ],
      ),
      body: _configuring ? _buildConfig(theme)
          : _loading ? _buildLoading(theme)
          : _errorMsg != null ? _buildError(theme)
          : _buildReading(theme),
    );
  }

  // ── 配置页 ─────────────────────────────────────────────────────────────────
  Widget _buildConfig(ThemeData theme) {
    final mq = MediaQuery.of(context);
    final int batchCount = _batchSize < widget.words.length
        ? (widget.words.length / _batchSize).ceil() : 1;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest, borderRadius: StaticsVar.br),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('词汇基础（${widget.words.length} 个词）', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                widget.words.take(6).map((w) => w.arabic).join('、') +
                    (widget.words.length > 6 ? ' …' : ''),
                style: const TextStyle(fontFamily: 'Traditional Arabic', fontSize: 18),
              ),
            ),
            if (batchCount > 1) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
                label: Text('将自动分为 $batchCount 篇（每篇约 $_batchSize 词）',
                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 12)),
                backgroundColor: theme.colorScheme.primaryContainer.withAlpha(60),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 24),
        Text('选择难度', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SegmentedButton<QuizDifficulty>(
          segments: QuizDifficulty.values
              .map((d) => ButtonSegment(value: d, label: Text(d.label))).toList(),
          selected: {_difficulty},
          onSelectionChanged: (s) => setState(() => _difficulty = s.first),
        ),
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              fixedSize: Size(mq.size.width, 56),
              shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)),
          icon: const Icon(Icons.menu_book),
          label: Text(batchCount > 1 ? '开始生成（第 1/$batchCount 篇）' : '生成阅读文章'),
          onPressed: _generate,
        ),
      ]),
    );
  }

  // ── 加载中 ─────────────────────────────────────────────────────────────────
  Widget _buildLoading(ThemeData theme) {
    final batchWords = _batches[_batchIdx];
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 80, height: 80,
          child: CircularProgressIndicator(strokeWidth: 3, color: theme.colorScheme.primary)),
      const SizedBox(height: 24),
      Text('AI 正在生成阅读文章…', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(
        '难度：${_difficulty.label}  |  ${batchWords.length} 个词汇  |  目标约 ${batchWords.length * 10} 词',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
      ),
      const SizedBox(height: 32),
      OutlinedButton.icon(
        onPressed: () { AiService().cancel(); setState(() { _loading = false; _configuring = true; }); },
        icon: const Icon(Icons.close), label: const Text('取消')),
    ]));
  }

  // ── 错误页 ─────────────────────────────────────────────────────────────────
  Widget _buildError(ThemeData theme) {
    return Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(_errorMsg!, textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error)),
        const SizedBox(height: 32),
        ElevatedButton.icon(onPressed: _generate, icon: const Icon(Icons.refresh),
            label: const Text('重试'),
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: StaticsVar.br))),
        const SizedBox(height: 12),
        TextButton(onPressed: () => setState(() { _configuring = true; _errorMsg = null; }),
            child: const Text('返回选择')),
      ])));
  }

  // ── 阅读主体 ───────────────────────────────────────────────────────────────
  Widget _buildReading(ThemeData theme) {
    final p = _passage!;
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(tabs: [
          const Tab(text: '📖 阅读文章'),
          Tab(text: '✏️ 理解问答（${p.questions.length}题）'),
        ]),
        Expanded(child: TabBarView(children: [
          _buildPassageTab(theme, p),
          _buildQuestionsTab(theme, p),
        ])),
      ]),
    );
  }

  Widget _buildPassageTab(ThemeData theme, ReadingPassage p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest, borderRadius: StaticsVar.br),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(p.passage,
                style: const TextStyle(fontFamily: 'Traditional Arabic', fontSize: 22, height: 2.2),
                textAlign: TextAlign.justify),
          ),
        ),
        if (p.summary.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(80), borderRadius: StaticsVar.br),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('中文摘要', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 8),
              Text(p.summary, style: theme.textTheme.bodyMedium),
            ]),
          ),
        ],
        if (_batches.length > 1) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.navigate_next),
            label: Text(_batchIdx < _batches.length - 1
                ? '下一篇（第 ${_batchIdx + 2}/${_batches.length} 篇）'
                : '全部完成'),
            onPressed: _nextBatch,
            style: OutlinedButton.styleFrom(
                fixedSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)),
          ),
        ],
      ]),
    );
  }

  // ── 问答区域 ───────────────────────────────────────────────────────────────
  Widget _buildQuestionsTab(ThemeData theme, ReadingPassage p) {
    if (p.questions.isEmpty) return const Center(child: Text('暂无问题'));
    final q = p.questions[_currentQ];
    final mq = MediaQuery.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // 进度
        LinearProgressIndicator(
            value: (_currentQ + 1) / p.questions.length, minHeight: 4,
            color: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.secondaryContainer),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('第 ${_currentQ + 1} / ${p.questions.length} 题',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          Chip(
            label: Text(q.type == ReadingQuestionType.choice ? '选择题' : '问答题',
                style: const TextStyle(fontSize: 11)),
            backgroundColor: q.type == ReadingQuestionType.choice
                ? theme.colorScheme.primaryContainer : theme.colorScheme.tertiaryContainer,
            padding: EdgeInsets.zero,
          ),
        ]),
        const SizedBox(height: 12),

        // 题目
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest, borderRadius: StaticsVar.br),
          child: Text(q.q, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 16),

        // 答题区
        if (q.type == ReadingQuestionType.choice)
          _buildChoiceInput(theme, q)
        else
          _buildOpenInput(theme, q),

        const SizedBox(height: 16),

        // 下一题 / 完成
        if (_choiceAnswered || (q.type == ReadingQuestionType.open && _showOpenAnswer))
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)),
              onPressed: () {
                if (_currentQ < p.questions.length - 1) {
                  setState(() {
                    _currentQ++;
                    _selectedChoice = null;
                    _choiceAnswered = false;
                    _showOpenAnswer = false;
                    _textCtrl.clear();
                  });
                } else {
                  // 这篇做完
                  if (_batches.length > 1) {
                    _nextBatch();
                  } else {
                    showDialog(context: context, builder: (ctx) => AlertDialog(
                      title: const Text('阅读完成 🎉'),
                      content: const Text('已完成所有问题！'),
                      actions: [
                        TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text('返回')),
                        TextButton(onPressed: () { Navigator.pop(ctx); _generate(); }, child: const Text('再生成一篇')),
                      ],
                    ));
                  }
                }
              },
              icon: Icon(_currentQ < p.questions.length - 1 ? Icons.navigate_next : Icons.done_all),
              label: Text(_currentQ < p.questions.length - 1 ? '下一题' : '完成'),
            ),
          ),

        // 选择题结果（答对/错后显示解析）
        if (q.type == ReadingQuestionType.choice && _choiceAnswered) ...[
          const SizedBox(height: 12),
          _buildExplanation(theme, q.explanation),
        ],
        // 问答题 - 查看按钮
        if (q.type == ReadingQuestionType.open && !_showOpenAnswer) ...[
          SizedBox(
            width: double.infinity, height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)),
              onPressed: () => setState(() => _showOpenAnswer = true),
              child: const Text('查看参考答案'),
            ),
          ),
        ],
        if (q.type == ReadingQuestionType.open && _showOpenAnswer) ...[
          const SizedBox(height: 12),
          _buildOpenAnswer(theme, q),
        ],

        SizedBox(height: mq.viewInsets.bottom + 16),
      ]),
    );
  }

  Widget _buildChoiceInput(ThemeData theme, ReadingQuestion q) {
    return Column(children: List.generate(q.choices.length, (i) {
      final label = String.fromCharCode(65 + i);
      Color? bgColor;
      Color borderColor = theme.colorScheme.outline.withAlpha(80);
      if (_choiceAnswered) {
        if (i == q.correctIndex) { bgColor = Colors.green.withAlpha(30); borderColor = Colors.green; }
        else if (i == _selectedChoice) { bgColor = Colors.red.withAlpha(20); borderColor = Colors.red; }
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          borderRadius: StaticsVar.br,
          onTap: _choiceAnswered ? null : () => setState(() {
            _selectedChoice = i;
            _choiceAnswered = true;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: bgColor,
                border: Border.all(color: borderColor, width: _choiceAnswered && (i == q.correctIndex || i == _selectedChoice) ? 2 : 1),
                borderRadius: StaticsVar.br),
            child: Row(children: [
              CircleAvatar(radius: 12,
                  backgroundColor: _choiceAnswered && i == q.correctIndex
                      ? Colors.green : _choiceAnswered && i == _selectedChoice
                      ? Colors.red : theme.colorScheme.primary,
                  child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white))),
              const SizedBox(width: 12),
              Expanded(child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(q.choices[i],
                      style: const TextStyle(fontFamily: 'Traditional Arabic', fontSize: 18)))),
              if (_choiceAnswered && i == q.correctIndex) const Icon(Icons.check_circle, color: Colors.green),
              if (_choiceAnswered && i == _selectedChoice && i != q.correctIndex) const Icon(Icons.cancel, color: Colors.red),
            ]),
          ),
        ),
      );
    }));
  }

  Widget _buildOpenInput(ThemeData theme, ReadingQuestion q) {
    return TextField(
      controller: _textCtrl,
      textDirection: TextDirection.rtl,
      maxLines: 3,
      enabled: !_showOpenAnswer,
      decoration: InputDecoration(
          hintText: '用阿拉伯语写下你的答案…',
          hintTextDirection: TextDirection.rtl,
          border: OutlineInputBorder(borderRadius: StaticsVar.br)),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildOpenAnswer(ThemeData theme, ReadingQuestion q) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.green.withAlpha(25), borderRadius: StaticsVar.br,
          border: Border.all(color: Colors.green, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('参考答案', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        const SizedBox(height: 6),
        Directionality(textDirection: TextDirection.rtl,
            child: Text(q.stdAnswer,
                style: const TextStyle(fontFamily: 'Traditional Arabic', fontSize: 18))),
        if (q.explanation.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(q.explanation, style: TextStyle(color: theme.colorScheme.outline, fontSize: 13)),
        ],
      ]),
    );
  }

  Widget _buildExplanation(ThemeData theme, String explanation) {
    if (explanation.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest, borderRadius: StaticsVar.br),
      child: Row(children: [
        Icon(Icons.lightbulb_outline, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(explanation, style: theme.textTheme.bodySmall)),
      ]),
    );
  }
}
