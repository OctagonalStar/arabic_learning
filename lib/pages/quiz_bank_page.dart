import 'package:arabic_learning/funcs/quiz_bank.dart';
import 'package:arabic_learning/pages/ai_quiz_page.dart';
import 'package:arabic_learning/vars/global.dart' show AppData;
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';

/// 题库浏览页：按单词分组展示所有已生成题目
class QuizBankPage extends StatefulWidget {
  const QuizBankPage({super.key});

  @override
  State<QuizBankPage> createState() => _QuizBankPageState();
}

class _QuizBankPageState extends State<QuizBankPage> {
  List<QuizItem> _allItems = [];
  bool _loading = true;

  /// 按 wordId 分组
  Map<int, List<QuizItem>> get _grouped {
    final Map<int, List<QuizItem>> m = {};
    for (final item in _allItems) {
      m.putIfAbsent(item.wordId, () => []).add(item);
    }
    return m;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await QuizBank().getAllItems();
    if (!mounted) return;
    setState(() {
      _allItems = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 题库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _allItems.isEmpty
              ? _buildEmpty(theme)
              : _buildList(theme),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz_outlined, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            '题库为空',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 8),
          Text(
            '在单词详情页点击「AI 生成练习」\n生成的题目会自动存入题库',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    final grouped = _grouped;
    final wordIds = grouped.keys.toList();

    // 统计数据
    final int totalItems = _allItems.length;
    final int answeredItems = _allItems.where((i) => i.firstResult != null).length;
    final int correctItems = _allItems.where((i) => i.firstResult == true).length;

    return Column(
      children: [
        // ── 统计栏 ────────────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withAlpha(100),
            borderRadius: StaticsVar.br,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statChip(theme, '总题数', totalItems, Icons.library_books),
              _statChip(theme, '已作答', answeredItems, Icons.check_box),
              _statChip(theme, '答对', correctItems, Icons.emoji_events,
                  accent: Colors.green),
            ],
          ),
        ),

        // ── 按词分组列表 ───────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: wordIds.length,
            itemBuilder: (ctx, i) {
              final int wid = wordIds[i];
              final List<QuizItem> items = grouped[wid]!;
              return _WordGroup(
                wordId: wid,
                items: items,
                onReview: () => _openReview(wid, items),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statChip(ThemeData theme, String label, int value, IconData icon,
      {Color? accent}) {
    return Column(
      children: [
        Icon(icon, size: 20, color: accent ?? theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text('$value',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: accent ?? theme.colorScheme.primary)),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  void _openReview(int wordId, List<QuizItem> items) {
    final words = AppData().wordData.words;
    if (wordId >= words.length) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiQuizPage(
          word: words[wordId],
          preloadedItems: items,
        ),
      ),
    );
  }
}

// ── 单词分组折叠卡片 ──────────────────────────────────────────────────────────

class _WordGroup extends StatefulWidget {
  final int wordId;
  final List<QuizItem> items;
  final VoidCallback onReview;

  const _WordGroup({
    required this.wordId,
    required this.items,
    required this.onReview,
  });

  @override
  State<_WordGroup> createState() => _WordGroupState();
}

class _WordGroupState extends State<_WordGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = AppData().wordData.words;
    final String arabic = widget.wordId < words.length
        ? words[widget.wordId].arabic
        : '#${widget.wordId}';
    final String chinese = widget.wordId < words.length
        ? words[widget.wordId].chinese
        : '';

    final int correct = widget.items.where((i) => i.firstResult == true).length;
    final int answered = widget.items.where((i) => i.firstResult != null).length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
      child: Column(
        children: [
          // ── 卡片头部 ────────────────────────────────────────────────────────
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                arabic,
                style: const TextStyle(
                  fontFamily: 'Traditional Arabic',
                  fontSize: 16,
                ),
                textDirection: TextDirection.rtl,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            title: Text(arabic,
                style: const TextStyle(
                    fontFamily: 'Traditional Arabic', fontSize: 18),
                textDirection: TextDirection.rtl),
            subtitle: Text(chinese),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 答题进度
                Text(
                  '$answered/${widget.items.length}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),

          // ── 题目列表 ────────────────────────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                ...widget.items.asMap().entries.map((e) {
                  final int idx = e.key;
                  final QuizItem item = e.value;
                  return _QuizItemTile(
                      index: idx, item: item, wordId: widget.wordId);
                }),
                // 复习按钮
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: StaticsVar.br),
                    ),
                    onPressed: widget.onReview,
                    icon: const Icon(Icons.play_arrow),
                    label: Text('复习这 ${widget.items.length} 道题'),
                  ),
                ),
              ],
            ),
          ),

          // ── 正确率指示条 ─────────────────────────────────────────────────────
          if (answered > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: correct / answered,
                  minHeight: 4,
                  backgroundColor: Colors.red.withAlpha(50),
                  color: Colors.green,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 单道题预览 ─────────────────────────────────────────────────────────────────

class _QuizItemTile extends StatelessWidget {
  final int index;
  final QuizItem item;
  final int wordId;

  const _QuizItemTile({
    required this.index,
    required this.item,
    required this.wordId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool? result = item.firstResult;

    Color? resultColor;
    IconData resultIcon = Icons.radio_button_unchecked;
    if (result == true) {
      resultColor = Colors.green;
      resultIcon = Icons.check_circle;
    } else if (result == false) {
      resultColor = Colors.red;
      resultIcon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 结果图标
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(resultIcon, size: 18, color: resultColor ?? theme.colorScheme.outline),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 例句（RTL）
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    item.sentence,
                    style: const TextStyle(
                      fontFamily: 'Traditional Arabic',
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.grammarPoint,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '答案：${item.stdAnswer}',
                      style: TextStyle(
                        fontFamily: 'Traditional Arabic',
                        fontSize: 14,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
