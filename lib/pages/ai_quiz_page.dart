import 'package:arabic_learning/funcs/ai_service.dart';
import 'package:arabic_learning/funcs/quiz_bank.dart';
import 'package:arabic_learning/vars/config_structure.dart' show WordItem;
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AiQuizPage extends StatefulWidget {
  final WordItem word;
  final List<QuizItem>? preloadedItems;
  const AiQuizPage({super.key, required this.word, this.preloadedItems});

  @override
  State<AiQuizPage> createState() => _AiQuizPageState();
}

class _AiQuizPageState extends State<AiQuizPage> with TickerProviderStateMixin {
  // ── 配置状态 ────────────────────────────────────────────────────────────────
  bool _configuring = true;
  QuizType _selectedType = QuizType.fillBlank;
  QuizDifficulty _selectedDiff = QuizDifficulty.medium;

  // ── 题目状态 ────────────────────────────────────────────────────────────────
  List<QuizItem> _items = [];
  int _currentIndex = 0;
  bool _loading = false;
  String? _errorMsg;

  bool _answered = false;
  bool? _correct;
  int? _selectedChoice;          // 选择题
  bool? _tfAnswer;               // 判断题
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late final AnimationController _resultAnim;
  late final Animation<double> _resultScale;

  @override
  void initState() {
    super.initState();
    _resultAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _resultScale = CurvedAnimation(parent: _resultAnim, curve: Curves.elasticOut);
    if (widget.preloadedItems != null && widget.preloadedItems!.isNotEmpty) {
      _items = List.from(widget.preloadedItems!);
      _configuring = false;
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    _resultAnim.dispose();
    AiService().cancel();
    super.dispose();
  }

  // ── 生成题目 ──────────────────────────────────────────────────────────────
  Future<void> _generate() async {
    setState(() { _loading = true; _errorMsg = null; _configuring = false; });
    try {
      final items = await AiService().generateAndSave(
        word: widget.word,
        quizType: _selectedType,
        difficulty: _selectedDiff,
      );
      if (!mounted) return;
      setState(() { _items = items; _currentIndex = 0; _resetAnswer(); _loading = false; });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _errorMsg = e.userMessage; });
    }
  }

  void _resetAnswer() {
    _answered = false; _correct = null; _selectedChoice = null; _tfAnswer = null;
    _resultAnim.reset(); _textCtrl.clear();
  }

  // ── 提交答案 ──────────────────────────────────────────────────────────────
  void _submit({bool? tfAns, int? choiceIdx}) {
    if (_answered) return;
    final QuizItem item = _items[_currentIndex];
    bool ok;

    switch (item.quizType) {
      case QuizType.multipleChoice:
        if (choiceIdx == null) return;
        ok = choiceIdx == item.correctChoiceIndex;
        setState(() { _selectedChoice = choiceIdx; });
        break;
      case QuizType.trueFalse:
        if (tfAns == null) return;
        ok = tfAns == item.isStatementTrue;
        setState(() { _tfAnswer = tfAns; });
        break;
      case QuizType.fillBlank:
      case QuizType.errorCorrection:
        final input = _textCtrl.text.trim();
        if (input.isEmpty) return;
        ok = QuizBank.checkAnswer(input, item);
        _focusNode.unfocus();
        FocusScope.of(context).unfocus();
        break;
    }

    QuizBank().recordFirstResult(item.id, ok);
    setState(() { _answered = true; _correct = ok; });
    _resultAnim.forward(from: 0);
  }

  void _next() {
    if (_currentIndex < _items.length - 1) {
      setState(() { _currentIndex++; _resetAnswer(); });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && (_items[_currentIndex].quizType == QuizType.fillBlank ||
            _items[_currentIndex].quizType == QuizType.errorCorrection)) {
          _focusNode.requestFocus();
        }
      });
    } else {
      _showSummary();
    }
  }

  void _showSummary() {
    final int correct = _items.where((i) => i.firstResult == true).length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('练习完成 🎉'),
        content: Text('本轮共 ${_items.length} 题\n答对 $correct 题，答错 ${_items.length - correct} 题'),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text('返回')),
          TextButton(onPressed: () { Navigator.pop(ctx); setState(() { _configuring = true; _items = []; _currentIndex = 0; _resetAnswer(); }); }, child: const Text('再练一组')),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AI 练习', style: TextStyle(fontSize: 16)),
          Text(widget.word.arabic, style: TextStyle(fontSize: 14, fontFamily: 'Traditional Arabic', color: theme.colorScheme.primary)),
        ]),
        actions: [
          if (!_loading && !_configuring)
            IconButton(icon: const Icon(Icons.tune), tooltip: '重新选择题型', onPressed: () => setState(() { _configuring = true; _items = []; _resetAnswer(); })),
          if (!_loading && !_configuring)
            IconButton(icon: const Icon(Icons.refresh), tooltip: '重新生成', onPressed: _generate),
        ],
      ),
      body: _configuring ? _buildConfig(theme) : _buildBody(theme),
    );
  }

  // ── 配置界面 ──────────────────────────────────────────────────────────────
  Widget _buildConfig(ThemeData theme) {
    final mq = MediaQuery.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('选择题型', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        ...QuizType.values.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChoiceChip(
            label: Row(children: [
              Icon(_typeIcon(t), size: 18),
              const SizedBox(width: 8),
              Text(t.label),
            ]),
            selected: _selectedType == t,
            onSelected: (_) => setState(() => _selectedType = t),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        )),
        const SizedBox(height: 20),
        Text('选择难度', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SegmentedButton<QuizDifficulty>(
          segments: QuizDifficulty.values.map((d) => ButtonSegment(value: d, label: Text(d.label))).toList(),
          selected: {_selectedDiff},
          onSelectionChanged: (s) => setState(() => _selectedDiff = s.first),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            fixedSize: Size(mq.size.width, 56),
            shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
          ),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('开始生成'),
          onPressed: _generate,
        ),
      ]),
    );
  }

  IconData _typeIcon(QuizType t) {
    switch (t) {
      case QuizType.fillBlank:       return Icons.edit_note;
      case QuizType.multipleChoice:  return Icons.checklist;
      case QuizType.trueFalse:       return Icons.rule;
      case QuizType.errorCorrection: return Icons.spellcheck;
    }
  }

  // ── 题目主体 ──────────────────────────────────────────────────────────────
  Widget _buildBody(ThemeData theme) {
    if (_loading) return _buildLoading(theme);
    if (_errorMsg != null) return _buildError(theme);
    if (_items.isEmpty) return const Center(child: Text('暂无题目'));
    return _buildQuiz(theme);
  }

  Widget _buildLoading(ThemeData theme) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 80, height: 80, child: CircularProgressIndicator(strokeWidth: 3, color: theme.colorScheme.primary)),
      const SizedBox(height: 24),
      Text('AI 正在生成 ${_selectedType.label}…', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      Text('难度：${_selectedDiff.label}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      const SizedBox(height: 32),
      OutlinedButton.icon(
        onPressed: () { AiService().cancel(); setState(() { _loading = false; _configuring = true; }); },
        icon: const Icon(Icons.close),
        label: const Text('取消'),
      ),
    ]));
  }

  Widget _buildError(ThemeData theme) {
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
      const SizedBox(height: 16),
      Text(_errorMsg!, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error)),
      const SizedBox(height: 32),
      ElevatedButton.icon(onPressed: _generate, icon: const Icon(Icons.refresh), label: const Text('重试'), style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: StaticsVar.br))),
      const SizedBox(height: 12),
      TextButton(onPressed: () => setState(() { _configuring = true; _errorMsg = null; }), child: const Text('返回选择')),
    ])));
  }

  Widget _buildQuiz(ThemeData theme) {
    final item = _items[_currentIndex];
    final mq = MediaQuery.of(context);
    return Column(children: [
      LinearProgressIndicator(value: (_currentIndex + 1) / _items.length, minHeight: 4, color: theme.colorScheme.primary, backgroundColor: theme.colorScheme.secondaryContainer),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 题号 + 题型标签
        Row(children: [
          Text('第 ${_currentIndex + 1} / ${_items.length} 题', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(width: 8),
          Chip(label: Text(item.quizType.label, style: const TextStyle(fontSize: 11)), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
          const SizedBox(width: 4),
          Chip(label: Text(item.difficulty.label, style: const TextStyle(fontSize: 11)), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
        ]),
        const SizedBox(height: 8),
        // 语法点
        if (item.grammarPoint.isNotEmpty)
          Text('考点：${item.grammarPoint}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 12),
        // 题目卡片
        _buildQuestionCard(theme, item),
        const SizedBox(height: 16),
        // 答题结果
        if (_answered) ...[
          ScaleTransition(scale: _resultScale, child: _buildResultBadge(theme, item)),
          const SizedBox(height: 16),
        ],
        // 操作按钮
        _buildActions(theme, mq, item),
      ]))),
    ]);
  }

  Widget _buildQuestionCard(ThemeData theme, QuizItem item) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: StaticsVar.br),
      child: Column(children: [
        // 句子展示
        Directionality(
          textDirection: TextDirection.rtl,
          child: _buildSentenceWidget(theme, item),
        ),
        // 答题区域：选择/判断题答后仍显示（带着色反馈）；填空/改错题答后隐藏
        if (!_answered ||
            item.quizType == QuizType.multipleChoice ||
            item.quizType == QuizType.trueFalse) ...[
          const SizedBox(height: 16),
          _buildAnswerInput(theme, item),
        ],
        // 解析
        if (_answered && item.explanation.isNotEmpty) ...[
          const Divider(height: 24),
          Text(item.explanation, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withAlpha(180))),
          if ((item.quizType == QuizType.trueFalse || item.quizType == QuizType.errorCorrection) && item.correctSentence.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('正确句：', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            Directionality(textDirection: TextDirection.rtl, child: Text(item.correctSentence, style: const TextStyle(fontFamily: 'Traditional Arabic', fontSize: 18), textAlign: TextAlign.center)),
          ],
        ],
      ]),
    );
  }

  Widget _buildSentenceWidget(ThemeData theme, QuizItem item) {
    const arabicStyle = TextStyle(fontFamily: 'Traditional Arabic', fontSize: 26, height: 2.0);
    // 判断题/改错题：显示完整句子
    if (item.quizType == QuizType.trueFalse || item.quizType == QuizType.errorCorrection) {
      return Text(item.sentence, style: arabicStyle, textAlign: TextAlign.center);
    }
    // 填空/选择：拆分 [____]
    final int blankIdx = item.sentence.indexOf('[____]');
    final String pre = blankIdx >= 0 ? item.sentence.substring(0, blankIdx) : item.sentence;
    final String post = blankIdx >= 0 ? item.sentence.substring(blankIdx + 6) : '';
    if (_answered) {
      return Text.rich(TextSpan(style: arabicStyle, children: [
        TextSpan(text: pre),
        TextSpan(text: item.stdAnswer, style: TextStyle(fontWeight: FontWeight.bold, color: _correct == true ? Colors.green.shade700 : Colors.red.shade700)),
        TextSpan(text: post),
      ]), textAlign: TextAlign.center);
    }
    return Text.rich(TextSpan(style: arabicStyle, children: [
      TextSpan(text: pre),
      TextSpan(text: '（ __ ）', style: TextStyle(color: theme.colorScheme.primary, fontStyle: FontStyle.italic)),
      TextSpan(text: post),
    ]), textAlign: TextAlign.center);
  }

  Widget _buildAnswerInput(ThemeData theme, QuizItem item) {
    switch (item.quizType) {
      case QuizType.multipleChoice:
        if (item.choices.isEmpty) return const SizedBox.shrink();
        return Column(children: List.generate(item.choices.length, (i) {
          final label = String.fromCharCode(65 + i);
          final bool isSelected = _selectedChoice == i;
          final bool isCorrect = i == item.correctChoiceIndex;
          Color borderColor = theme.colorScheme.outline.withAlpha(100);
          if (_answered && isSelected) borderColor = isCorrect ? Colors.green : Colors.red;
          if (_answered && !isSelected && isCorrect) borderColor = Colors.green;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerRight,
                side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
                shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
              ),
              onPressed: _answered ? null : () => _submit(choiceIdx: i),
              child: Row(children: [
                CircleAvatar(radius: 12, backgroundColor: theme.colorScheme.primary, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white))),
                const SizedBox(width: 12),
                Expanded(child: Directionality(textDirection: TextDirection.rtl, child: Text(item.choices[i], style: const TextStyle(fontFamily: 'Traditional Arabic', fontSize: 18)))),
              ]),
            ),
          );
        }));
      case QuizType.trueFalse:
        return Row(children: [
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: (_answered && _tfAnswer == true)
                  ? (_correct == true ? Colors.green.shade700 : Colors.red.shade700)
                  : Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
              fixedSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.check),
            label: const Text('正确 صح'),
            onPressed: _answered ? null : () => _submit(tfAns: true),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: (_answered && _tfAnswer == false)
                  ? (_correct == true ? Colors.green.shade700 : Colors.red.shade700)
                  : Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
              fixedSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.close),
            label: const Text('错误 خطأ'),
            onPressed: _answered ? null : () => _submit(tfAns: false),
          )),
        ]);
      case QuizType.fillBlank:
      case QuizType.errorCorrection:
        return TextField(
          controller: _textCtrl,
          focusNode: _focusNode,
          autofocus: true,
          textDirection: TextDirection.rtl,
          textInputAction: TextInputAction.done,
          style: const TextStyle(fontFamily: 'Traditional Arabic', fontSize: 22),
          decoration: InputDecoration(
            hintText: item.quizType == QuizType.errorCorrection ? 'أكتب الكلمة الصحيحة...' : 'أكتب الإجابة هنا...',
            hintStyle: TextStyle(fontFamily: 'Traditional Arabic', color: theme.colorScheme.outline),
            hintTextDirection: TextDirection.rtl,
            border: OutlineInputBorder(borderRadius: StaticsVar.br),
            suffixIcon: IconButton(icon: const Icon(Icons.send_rounded), onPressed: _submit),
          ),
          onSubmitted: (_) => _submit(),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF\s]'))],
        );
    }
  }

  Widget _buildResultBadge(ThemeData theme, QuizItem item) {
    final ok = _correct == true;
    String correctLabel = '';
    if (!ok) {
      if (item.quizType == QuizType.trueFalse) {
        correctLabel = item.isStatementTrue == true ? '正确答案：正确 (صح)' : '正确答案：错误 (خطأ)';
      } else if (item.quizType == QuizType.multipleChoice && item.correctChoiceIndex >= 0 && item.correctChoiceIndex < item.choices.length) {
        correctLabel = '正确答案：${item.choices[item.correctChoiceIndex]}';
      } else {
        correctLabel = '标准答案：${item.stdAnswer}';
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: ok ? Colors.green.withAlpha(30) : Colors.red.withAlpha(30),
        borderRadius: StaticsVar.br,
        border: Border.all(color: ok ? Colors.green : Colors.red, width: 1.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(ok ? Icons.check_circle : Icons.cancel, color: ok ? Colors.green : Colors.red),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ok ? '正确！' : '错误', style: TextStyle(fontWeight: FontWeight.bold, color: ok ? Colors.green.shade700 : Colors.red.shade700)),
          if (!ok && correctLabel.isNotEmpty) Text(correctLabel, style: const TextStyle(fontFamily: 'Traditional Arabic', fontSize: 16)),
        ]),
      ]),
    );
  }

  Widget _buildActions(ThemeData theme, MediaQueryData mq, QuizItem item) {
    final isLast = _currentIndex == _items.length - 1;
    if (!_answered) {
      // 填空/改错：有提交按钮；选择/判断：直接点按钮
      if (item.quizType == QuizType.fillBlank || item.quizType == QuizType.errorCorrection) {
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(fixedSize: Size(mq.size.width, 56), shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)),
          onPressed: _textCtrl.text.trim().isEmpty ? null : _submit,
          icon: const Icon(Icons.check),
          label: const Text('提交答案'),
        );
      }
      return const SizedBox.shrink(); // 选择/判断题直接在 input 区点击
    }
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(fixedSize: Size(mq.size.width, 56), shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)),
      onPressed: _next,
      icon: Icon(isLast ? Icons.done_all : Icons.navigate_next),
      label: Text(isLast ? '完成' : '下一题'),
    );
  }
}
