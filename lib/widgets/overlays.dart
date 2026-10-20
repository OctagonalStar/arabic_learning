// 弹窗与提示（原 lib/funcs/ui.dart 拆分）。
// 承载对话框 alart、底部提示 showSnackBar、详解弹窗 viewAnswer
// 与选择题长按用的单词卡片浮层 showWordCardOverlay。
// 说明：与 widgets/kit.dart 之间存在循环 import，在 Dart 中合法。

import 'dart:math' show min;

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/synonyms.dart' show SynonymStore;
import 'package:arabic_learning/theme/tokens.dart' show AppMotion, AppSpacing;
import 'package:arabic_learning/widgets/feedback.dart' show LoadingIndicator;
import 'package:arabic_learning/widgets/flip_word_card.dart' show FlipWordCard;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 弹出窗口
/// 
/// [context] :Widget树上的context
/// 
/// [msg] :需要在窗口中显示的内容（文字）
/// 
/// [onConfirmed] :在被确认后运行的函数
/// 
/// [delayConfirm] :要求等待多久后可以关闭弹窗
/// 
/// 示例(可能在某个按钮中)：
/// 
/// ``` dart
/// onPressed: () {
///   alart(context, "你点击了按钮"，onConfirmed: (){i++}, delayConfirm: Duration(seconds: 1));
/// }
/// ```
void alart(BuildContext context, String msg, {Function? onConfirmed, Duration delayConfirm = const Duration()}) {
  context.read<Global>().uiLogger.info("构建弹出窗口: 携带信息: $msg ;确认参数: ${onConfirmed != null}; 延迟: ${delayConfirm.inMilliseconds}");
  showDialog(
    context: context, 
    requestFocus: true,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("提示"),
        content: Text(msg),
        actions: [
          FutureBuilder(
            future: Future.delayed(delayConfirm, (){return 0;}),
            builder: (context, asyncSnapshot) {
              if(asyncSnapshot.hasData){
                return TextButton(
                  child: Text("确定"),
                  onPressed: () {
                    Navigator.of(context).pop();
                    if(onConfirmed != null) onConfirmed();
                  },
                );
              } else {
                return LoadingIndicator();
              }
            }
          )
        ],
      );
    }
  );
}

void showSnackBar(BuildContext context, String msg, {Duration duration = const Duration(seconds: 3)}){
  context.read<Global>().uiLogger.info("展示底部提示，携带信息: $msg ，持续时长: ${duration.inMilliseconds} 毫秒");
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      duration: duration,
    ),
    snackBarAnimationStyle: AnimationStyle(
      curve: AppMotion.standardCurve,
      reverseCurve: AppMotion.standardCurve
    )
  );
}

/// 弹出详解页面
/// 
/// [chosenWrong] :用户选错的选项，非空且与词条不同时展示同义/不同标记操作区
void viewAnswer(BuildContext context, WordItem wordData, {WordItem? chosenWrong}) async {
  context.read<Global>().uiLogger.info("弹出详解页面");
  MediaQueryData mediaQuery = MediaQuery.of(context);
  showBottomSheet(
    context: context, 
    shape: RoundedSuperellipseBorder(side: BorderSide(width: 1.0, color: Theme.of(context).colorScheme.outlineVariant), borderRadius: StaticsVar.br),
    enableDrag: true,
    builder: (context) {
      return _AnswerSheet(wordData: wordData, chosenWrong: chosenWrong, mediaQuery: mediaQuery);
    },
  );
}

/// 长按选项弹出的单词卡片浮层：居中展示该词条的反面详解卡（[FlipWordCard]
/// `startOnBack`），点击遮罩关闭。
///
/// [word] :该选项对应的词条，卡片直接以反面（全部详情）呈现
Future<void> showWordCardOverlay(BuildContext context, WordItem word) async {
  context.read<Global>().uiLogger.info("弹出单词卡片浮层: ${word.arabic} / ${word.chinese}");
  final MediaQueryData mediaQuery = MediaQuery.of(context);
  // 卡片尺寸：宽度封顶 460、高度封顶 560，且不超过屏幕可用区域的九成/七成，
  // 保证小屏上也不溢出。
  final double cardWidth = min(mediaQuery.size.width * 0.9, 460.0);
  final double cardHeight = min(mediaQuery.size.height * 0.72, 560.0);
  final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: reduceMotion ? Duration.zero : AppMotion.medium,
    transitionBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
      // 减弱动态效果时 transitionDuration 为零，直接呈现终态；正常路径
      // 淡入 + 轻微放大（0.92 → 1.0）。
      final CurvedAnimation curved = CurvedAnimation(parent: animation, curve: AppMotion.standardCurve);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (BuildContext context, Animation<double> progress, Animation<double> secondary) {
      return Center(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FlipWordCard(
              word: word,
              enableFlip: false,
              startOnBack: true,
              width: cardWidth,
              height: cardHeight,
            ),
          ),
        ),
      );
    },
  );
}

/// 详解弹窗内容。
/// 
/// 单独抽出为 [StatefulWidget]：标记同义/不同后需要 setState 即时刷新操作区。
class _AnswerSheet extends StatefulWidget {
  const _AnswerSheet({required this.wordData, required this.mediaQuery, this.chosenWrong});

  final WordItem wordData;
  final WordItem? chosenWrong;
  final MediaQueryData mediaQuery;

  @override
  State<_AnswerSheet> createState() => _AnswerSheetState();
}

class _AnswerSheetState extends State<_AnswerSheet> {
  final SynonymStore _store = SynonymStore();

  /// 撤销当前词条与选错项之间的标记，并刷新操作区。
  void _undoPair() {
    final WordItem chosenWrong = widget.chosenWrong!;
    context.read<Global>().uiLogger.info("撤销同义/不同标记: ${widget.wordData.chinese} / ${chosenWrong.chinese}");
    _store.removePair(widget.wordData.chinese, chosenWrong.chinese);
    setState(() {});
  }

  /// 已标记状态下的一行提示 + 撤销按钮。
  Widget _markedLine(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: _undoPair,
            child: Text("撤销"),
          ),
        ],
      ),
    );
  }

  /// 同义/不同标记操作区，仅在 [widget.chosenWrong] 为有效配对时构建。
  Widget _synonymActionArea(BuildContext context) {
    final WordItem wordData = widget.wordData;
    final WordItem chosenWrong = widget.chosenWrong!;

    if (_store.isDistinctWord(wordData, chosenWrong)) {
      return _markedLine(context, "已标记为不同，不再提示");
    }
    if (_store.isSynonymWord(wordData, chosenWrong)) {
      return _markedLine(context, "已标记为同义，下次不会再同时出现");
    }

    // 未标记：展示配对的两个释义，相近时给出提示，并提供两个标记按钮。
    final bool mayBeSimilar = wordData.chinese.hasSimilarMeaning(chosenWrong.chinese) ||
        (wordData.explanation.trim().isNotEmpty &&
            chosenWrong.explanation.trim().isNotEmpty &&
            wordData.explanation.hasSimilarMeaning(chosenWrong.explanation));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  wordData.chinese,
                  style: Theme.of(context).textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Icon(Icons.sync_alt, size: 16.0, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              Flexible(
                child: Text(
                  chosenWrong.chinese,
                  style: Theme.of(context).textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (mayBeSimilar)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                "这两个选项意思可能相近，是否标记为同义？",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Button(
                    size: Size(widget.mediaQuery.size.width * 0.4, widget.mediaQuery.size.height * 0.06),
                    onPressed: () {
                      context.read<Global>().uiLogger.info("标记为同义: ${wordData.chinese} / ${chosenWrong.chinese}");
                      _store.markSynonym(wordData.chinese, chosenWrong.chinese);
                      setState(() {});
                      showSnackBar(context, "已标记为同义");
                    },
                    child: Text("标记为同义"),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Button(
                    size: Size(widget.mediaQuery.size.width * 0.4, widget.mediaQuery.size.height * 0.06),
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    onPressed: () {
                      context.read<Global>().uiLogger.info("标记为不同: ${wordData.chinese} / ${chosenWrong.chinese}");
                      _store.markDistinct(wordData.chinese, chosenWrong.chinese);
                      setState(() {});
                      showSnackBar(context, "已标记为不同，下次不再提示");
                    },
                    child: Text("它们不同"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WordItem? chosenWrong = widget.chosenWrong;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: StaticsVar.br,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlipWordCard(word: widget.wordData, enableFlip: false, startOnBack: true),
          if (chosenWrong != null && chosenWrong.id != widget.wordData.id) _synonymActionArea(context),
          Button(
            onPressed: () => Navigator.pop(context), 
            size:  Size(widget.mediaQuery.size.width * 0.8, widget.mediaQuery.size.height * 0.1),
            child: Text("我知道了"),
          )
        ],
      ),
    );
  }
}
