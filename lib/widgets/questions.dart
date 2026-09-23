// 题目控件（原 lib/funcs/ui.dart 拆分）。
// 承载选择题 ChoiceQuestions、单词卡片题 WordCardQuestion、自我评级题
// SelfRatingQuestion、拼写题 SpellQuestion 与听力题 ListeningQuestion。

import 'dart:math' show Random;

import 'package:arabic_learning/core/adaptive.dart' show AdaptiveScope;
import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/models/dict.dart' show DictData, WordItem;
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/tts.dart';
import 'package:arabic_learning/services/words.dart' show calculateButtonBoxLayout, getRandomWords;
import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:arabic_learning/theme/typography.dart';
import 'package:arabic_learning/widgets/flip_word_card.dart' show FlipWordCard;
import 'package:arabic_learning/widgets/kit.dart' show Button, ChooseButtons, TextContainer;
import 'package:arabic_learning/widgets/overlays.dart' show alart, showSnackBar;
import 'package:arabic_learning/widgets/shared.dart' show ButtonLabel, appInputDecoration;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 选择题页面
/// 
/// 构建一个选择题
/// 
/// [mainWord] :做为题目的文本
/// 
/// [choices] :作为选项的文本（不会进行二次洗牌）
/// 
/// [onSelected] :在选择后触发的回调，会传入所选择选项的索引号，需要再返回一个bool值。
/// 该组件不知道正确答案，请在回调中进行判断，正确则返回true，否则返回false
/// 
/// [hint] :在题目上方用于提示的文本
/// 
/// [bottomWidget] :题目下方的组件，可用于翻页之类的其他功能，自行设置
/// 
/// [onDisAllowMutipleSelect] :在不允许多次选择的题目中尝试多选时触发，默认会触发底部通知"该题目不允许多次选择"
/// 
/// [allowAudio] :是否允许播放音频（通常 [mainWord] 为中文时设置为不允许(false)）
/// 
/// [bottonLayout] :控制选项按钮的排布
/// 允许值：-1：自动；0：1行；1：2行；2：4行，默认自动
/// 
/// [allowAnitmation] :是否显示动画，即预判微光 -> 徽章 -> 正误差异化
/// 关闭时立即落色
class ChoiceQuestions extends StatefulWidget {
  final String mainWord;
  final List<String> choices;
  final bool? Function(int) onSelected;
  final String? hint;
  final Widget? midWidget;
  final Widget? bottomWidget;
  final Function? onDisAllowMutipleSelect;
  final bool allowMutipleSelect;
  final bool allowAudio;
  final int bottonLayout;
  final bool allowAnitmation;
  const ChoiceQuestions({super.key, 
                        required this.mainWord, 
                        required this.choices, 
                        required this.allowAudio, 
                        required this.onSelected,
                        this.hint, 
                        this.midWidget,
                        this.bottomWidget, 
                        this.onDisAllowMutipleSelect,
                        this.bottonLayout = -1,
                        this.allowMutipleSelect = true,
                        this.allowAnitmation = true});

  @override
  State<StatefulWidget> createState() => _ChoiceQuestions();
}
class _ChoiceQuestions extends State<ChoiceQuestions> {
  bool playing = false;

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建选择题页面: 主单词: ${widget.mainWord};选项: ${widget.choices}");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    int showingMode = widget.bottonLayout;
    // showingMode 0: 1 Row, 1: 2 Rows, 2: 4 Rows
    if(showingMode == -1){
      context.read<Global>().uiLogger.fine("未指定布局，开始计算");
      showingMode = calculateButtonBoxLayout(widget.choices, AdaptiveScope.of(context));
      context.read<Global>().uiLogger.info("最终采用布局方案: $showingMode");
    }
    return Material(
      child: Center(
        child: Column(
          children: [
            if(widget.hint!=null) TextContainer(text: widget.hint!, animated: true),
            Expanded(
              child: widget.midWidget ?? StatefulBuilder(
                builder: (context, setLocalState) {
                  return Button(
                    icon: Icon(widget.allowAudio ? (playing ? Icons.multitrack_audio : Icons.volume_up) : Icons.short_text, size: 24.0),
                    size: Size.fromWidth(mediaQuery.size.width * 0.8),
                    onPressed: () async {
                      if (playing || !widget.allowAudio) {
                        context.read<Global>().uiLogger.warning("${playing ? "正在播放" : "不准许音频"}，中断TTS");
                        return;
                      }
                      setLocalState(() {
                        playing = true;
                      });
                      try {
                        await playTextToSpeech(widget.mainWord);
                      } catch (e) {
                        if(context.mounted) alart(context, e.toString());
                      }
                      
                      setLocalState(() {
                        playing = false;
                      });
                    },
                    // displayLarge(57) 为封顶字号：长词由 scaleDown 缩小，
                    // 短词保持封顶而不会被 contain 放大填满按钮。
                    child: ButtonLabel(child: Text(widget.mainWord, style: arabicTextStyle(context, widget.mainWord, base: withoutColor(Theme.of(context).textTheme.displayLarge!)))),
                  );
                }
              ),
            ),
            SizedBox(height: mediaQuery.size.height *0.01),
            ChooseButtons(
              options: widget.choices,
              settingShowingMode: showingMode,
              onSelected: widget.onSelected,
              isShowAnimation: widget.allowAnitmation,
              // 单选时判定后聚焦选中项并淡化其余选项；多选保持原样。
              isSingleSelect: !widget.allowMutipleSelect,
              // 单选作答后锁定全部选项（统一由 ChooseButtons 处理）。
              lockAfterSelect: !widget.allowMutipleSelect,
              onLockedTap: (int value) {
                if(widget.onDisAllowMutipleSelect != null) {
                  widget.onDisAllowMutipleSelect!(value);
                  return;
                }
                showSnackBar(context, "该页面不允许多次选择");
              },
            ),
            SizedBox(height: mediaQuery.size.height *0.01),
            if(widget.bottomWidget != null) widget.bottomWidget!,
            SizedBox(height: mediaQuery.size.height *0.03),
          ],
        ),
      ),
    );
  }
}

/// 卡片题目页面
/// 
/// [word] :单词数据
/// 
/// [bottomWidget] :题目下方的组件，可用于翻页之类的其他功能，自行设置
class WordCardQuestion extends StatelessWidget {
  final WordItem word;
  final String? hint;
  final Widget? bottomWidget;
  const WordCardQuestion({super.key, required this.word, this.hint, this.bottomWidget});

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建单词卡片页面，主单词: ${word.arabic}");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Material(
      child: Column(
        children: [
          if(hint != null) TextContainer(text: hint!, animated: true),
          SizedBox(height: mediaQuery.size.height * 0.01),
          Expanded(child: FlipWordCard(word: word, masked: true)),
          SizedBox(height: mediaQuery.size.height *0.01),
          ?bottomWidget,
          SizedBox(height: mediaQuery.size.height * 0.05),
        ],
      ),
    );
  }
}

/// 自我评级题目：单词卡片 + 评级选项。
///
/// 用于复习页的自我评级模式（或复习随机到单词卡片题型）：上方展示单词卡片
/// （[masked] 控制是否遮挡释义，评级/揭示后由调用方置 false），下方为复用
/// [ChooseButtons] 的评级选项（单选、评一次后锁定）。
///
/// 与 [ChoiceQuestions] / [WordCardQuestion] 同属 *Question 组件；[ChooseButtons]
/// 仅供 *Question 组件复用，业务代码不应直接调用。
class SelfRatingQuestion extends StatelessWidget {
  /// 单词数据
  final WordItem word;

  /// 评级选项文案（由调用方决定，通常为 4 档 FSRS 评分）
  final List<String> choices;

  /// 选择后回调，传入选项索引；返回非 null 视为已判定
  final bool? Function(int) onSelected;

  /// 题目上方提示文本
  final String? hint;

  /// 选项下方组件（如翻页条）
  final Widget? bottomWidget;

  /// 是否遮挡释义（外部按“是否已评级/已揭示”控制）
  final bool masked;

  /// 卡片是否允许点击翻卡查看详情
  final bool enableFlip;

  /// 卡片宽度 / 高度（可选；缺省由 [FlipWordCard] 自适应）
  final double? cardWidth;
  final double? cardHeight;

  const SelfRatingQuestion({
    super.key,
    required this.word,
    required this.choices,
    required this.onSelected,
    this.hint,
    this.bottomWidget,
    this.masked = true,
    this.enableFlip = true,
    this.cardWidth,
    this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建自我评级题目，主单词: ${word.arabic}");
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final int showingMode = calculateButtonBoxLayout(choices, AdaptiveScope.of(context));
    return Material(
      child: Center(
        child: Column(
          children: [
            if(hint != null) TextContainer(text: hint!, animated: true),
            Expanded(
              child: FlipWordCard(
                word: word,
                width: cardWidth,
                height: cardHeight,
                enableFlip: enableFlip,
                masked: masked,
              ),
            ),
            SizedBox(height: mediaQuery.size.height * 0.01),
            ChooseButtons(
              options: choices,
              settingShowingMode: showingMode,
              onSelected: onSelected,
              isShowAnimation: false,
              isSingleSelect: true,
              lockAfterSelect: true,
              onLockedTap: (int value) {
                showSnackBar(context, "该页面不允许多次选择");
              },
            ),
            SizedBox(height: mediaQuery.size.height * 0.01),
            ?bottomWidget,
            SizedBox(height: mediaQuery.size.height * 0.03),
          ],
        ),
      ),
    );
  }
}

/// 拼写题目页面
class SpellQuestion extends StatefulWidget {
  final WordItem word;
  final bool Function(String text) onCheck;
  final String? hint;
  final Widget? bottomWidget;
  const SpellQuestion({super.key, required this.word, required this.onCheck, this.hint, this.bottomWidget});

  @override
  State<StatefulWidget> createState() => _SpellQuestion();
}
class _SpellQuestion extends State<SpellQuestion> {
  TextEditingController controller = TextEditingController();
  bool isChecked = false;
  bool? isCorrect;

  void check(String value) {
    setState(() {
      isChecked = true;
      isCorrect = widget.onCheck(value);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建拼写题页面，主单词: ${widget.word.arabic}");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Material(
      child: Column(
        children: [
          if(widget.hint != null) TextContainer(text: widget.hint!, animated: true),
          TextContainer(
            text: widget.word.chinese,
            size: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.2),
            style: Theme.of(context).textTheme.displayLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: mediaQuery.size.height * 0.02),
          SizedBox(
            width: mediaQuery.size.width * 0.6,
            child: TweenAnimationBuilder(
              tween: ColorTween(
                // 默认填 surfaceContainerHighest；作答后叠加低透明度语义色，
                // 文字沿用 onSurface，深/浅两态均保持可读。
                begin: Theme.of(context).colorScheme.surfaceContainerHighest,
                end: isChecked
                  ? ((isCorrect ?? false)
                      ? context.semanticColors.success
                      : context.semanticColors.error).withAlpha(64)
                  : Theme.of(context).colorScheme.surfaceContainerHighest
              ),
              duration: AppMotion.medium,
              curve: AppMotion.standardCurve,
              builder: (context, value, child) {
                return TextField(
                  textDirection: TextDirection.rtl,
                  autocorrect: false,
                  controller: controller,
                  expands: false,
                  maxLines: 1,
                  style: arabicStyle(context, base: Theme.of(context).textTheme.headlineMedium),
                  keyboardType: TextInputType.name,
                  readOnly: isChecked,
                  decoration: appInputDecoration(
                    context,
                    labelText: "阿拉伯语单词",
                    filled: true,
                    fillColor: value
                  ),
                  onSubmitted: (text) {
                    check(text);
                  },
                );
              }
            ),
          ),
          SizedBox(height: mediaQuery.size.height * 0.05),
          Button(
            onPressed: () {
              context.read<Global>().uiLogger.info("提交单词检查: [${controller.text}]");
              check(controller.text);
            }, 
            size: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.1),
            child: Text("提交"),
          ),
          Expanded(child: SizedBox()),
          if(widget.bottomWidget != null) widget.bottomWidget!,
          SizedBox(height: mediaQuery.size.height * 0.05)
        ],
      ),
    );
  }
}

/// 听力题目页面
class ListeningQuestion extends StatefulWidget {
  final String mainWord;
  final List<String> choices;
  final bool? Function(int) onSelected;
  final String? hint;
  final Widget? bottom;
  final Function? onDisAllowMutipleSelect;
  final bool allowMutipleSelect;
  final int bottonLayout;
  final bool allowAnitmation;
  const ListeningQuestion({super.key, 
                        required this.mainWord, 
                        required this.choices, 
                        required this.onSelected,
                        this.hint, 
                        this.bottom, 
                        this.onDisAllowMutipleSelect,
                        this.bottonLayout = -1,
                        this.allowMutipleSelect = true,
                        this.allowAnitmation = true});

  @override
  State<StatefulWidget> createState() => _ListeningQuestion();
}

class _ListeningQuestion extends State<ListeningQuestion> {
  bool choosed = false;
  bool playing = false;

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建听力题页面: 主单词: ${widget.mainWord};选项: ${widget.choices}");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    int showingMode = widget.bottonLayout;
    if(showingMode == -1){
      context.read<Global>().uiLogger.fine("未指定布局，开始计算");
      showingMode = calculateButtonBoxLayout(widget.choices, AdaptiveScope.of(context));
      context.read<Global>().uiLogger.info("最终采用布局方案: $showingMode");
    }
    return Material(
      child: Center(
        child: Column(
          children: [
            if(widget.hint!=null) TextContainer(text: widget.hint!, animated: true),
            Expanded(
              child: StatefulBuilder(
                builder: (context, setLocalState) {
                  return Button(
                    size: Size.fromWidth(mediaQuery.size.width * 0.8),
                    onPressed: () async {
                      if (playing) {
                        context.read<Global>().uiLogger.warning("正在播放，中断TTS");
                        return;
                      }
                      setLocalState(() {
                        playing = true;
                      });
                      try {
                        await playTextToSpeech(widget.mainWord);
                      } catch (e) {
                        if(context.mounted) alart(context, e.toString());
                      }
                      
                      setLocalState(() {
                        playing = false;
                      });
                    },
                    child: Icon(playing ? Icons.multitrack_audio : Icons.volume_up, size: 60,),
                  );
                }
              ),
            ),
            SizedBox(height: mediaQuery.size.height *0.01),
            ChooseButtons(
              options: widget.choices,
              settingShowingMode: showingMode,
              onSelected: widget.onSelected,
              isShowAnimation: widget.allowAnitmation,
              // 单选时判定后聚焦选中项并淡化其余选项；多选保持原样。
              isSingleSelect: !widget.allowMutipleSelect,
              // 单选作答后锁定全部选项；「跳过」后由 locked 统一锁定。
              lockAfterSelect: !widget.allowMutipleSelect,
              locked: choosed,
              onLockedTap: (int value) {
                if(widget.onDisAllowMutipleSelect != null) {
                  widget.onDisAllowMutipleSelect!(value);
                  return;
                }
                showSnackBar(context, "该页面不允许多次选择");
              },
            ),
            TextButton(
              onPressed: (){
                setState(() {
                  choosed = true;
                });
                widget.onSelected(-1);
              },
              child: Text("跳过听力题目")
            ),
            SizedBox(height: mediaQuery.size.height *0.01),
            if(widget.bottom != null) widget.bottom!,
            SizedBox(height: mediaQuery.size.height *0.05),
          ],
        ),
      ),
    );
  }
}

/// 单个待测单词及其题型、选项数据。
///
/// 学习页面与复习/推送页面共用，保证同一配置下题目构建方式一致。
@immutable
class TestItem {
  /// 测试单词
  final WordItem testWord;

  /// 测试类型
  /// 0: 单词卡片
  /// 1: 中译阿 选择题
  /// 2: 阿译中 选择题
  /// 3: 拼写题
  /// 4: 听力题
  final int testType;

  /// 选择题和听力题的选项
  final List<String>? options;

  /// 选择题和听力题的选项词（与 [options] 一一对应，用于取回选错的词条）
  final List<WordItem>? optionWords;

  /// 选择题和听力题的正确血选项索引号
  final int? correctIndex;

  const TestItem({
    required this.testWord,
    required this.testType,
    this.options,
    this.optionWords,
    this.correctIndex
  });

  static TestItem buildTestItem(WordItem word, int testType, DictData wordData,bool preferSimilar,Random rnd){
    if(testType == 0 || testType == 3){
      return TestItem(testWord: word, testType: testType);
    } else {
      final List<WordItem> optionWords = getRandomWords(4, wordData, include: word, preferClass: !preferSimilar, rnd: rnd, avoidSynonyms: true);
      return TestItem(
        testWord: word, 
        testType: testType,
        options: List.generate(4, (int index) => ((testType == 2 || (testType == 4 && rnd.nextBool())) ? optionWords[index].chinese : optionWords[index].arabic), growable: false),
        optionWords: optionWords,
        correctIndex: optionWords.indexOf(word)
      );
    }
  }

  /// 从 [sections] 中随机挑选一个题型；单元素时直接返回且不消耗随机数
  /// （保持既有确定性测试的随机序列不变）。
  static int pickType(List<int> sections, Random rnd) =>
      sections.length == 1 ? sections.first : sections[rnd.nextInt(sections.length)];
}
