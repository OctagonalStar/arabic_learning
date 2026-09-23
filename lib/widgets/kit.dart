// UI 控件库（原 lib/funcs/ui.dart 拆分）。
// 承载基础展示控件（TextContainer/Button/ChooseButtons/CategoryChips 等）、
// 分类标签与筛选（CategoryChips/CategoryFilter）、设置类控件
// （SettingRedirctButton/SettingRow/SettingItem）以及课程选择
// （popSelectClasses/classesSelectionList/ClassSelectPage）。
// 单词卡片相关实现集中在 widgets/flip_word_card.dart。
// 说明：与 widgets/shared.dart、widgets/overlays.dart 之间存在循环 import，
// 在 Dart 中合法。

import 'dart:async';
import 'dart:convert';

import 'package:arabic_learning/core/adaptive.dart' show AdaptiveScope;
import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion, AppRadius, AppSemanticColors;
import 'package:arabic_learning/theme/typography.dart';
import 'package:arabic_learning/models/dict.dart' show ClassItem, SourceItem;
import 'package:arabic_learning/models/reading.dart' show ClassSelection;
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/widgets/overlays.dart' show showSnackBar;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';

// 该文件主要包含了对于UI有关的函数及多次在不同地方使用的Widget类或者函数

// UI Functions UI相关的函数调用

/// 弹出课程选择（ClassSelectPage）
/// 
/// [context] :Widget树上的context
/// 
/// [withCache] :是否使用缓存，若启用则会
/// 1.从缓存中加载已选择的课程 
/// 2.将此次课程选择加入持久化的缓存中方便下次直接开始。 
/// 
/// 返回值: [[词库键, 课程键]] 对应了[Global.wordData]中的数据结构
/// 
/// 可以通过以下方式使用返回值，得到该课单词的ID
/// 
/// ``` dart
/// List<List<String>> value = await popSelectClasses(context);
/// List<int> wordsId = context.read<Global>().wordData["Classes"][value[0]][value[1]]
/// ```
/// 
/// 但是以上方案不常用，常用的方案是通过utili中的getSelectedWords直接获取单词数据(Map)
/// 
/// ``` dart
/// List<List<String>> value = await popSelectClasses(context);
/// List<Map<String, dynamic>> words = getSelectedWords(context , forceSelectClasses: value);
/// ```
Future<ClassSelection> popSelectClasses(BuildContext context, {bool withCache = false, bool withReviewChoose = true, List<SourceItem>? forceSelectRange}) async {
  context.read<Global>().uiLogger.info("弹出课程选择（ClassSelectPage），withCache: $withCache");
  final List<ClassItem> beforeSelectedClasses = [];
  AppData appData = AppData();
  if(withCache) {
    if(forceSelectRange != null) throw Exception("popSelectClasses不允许forceSelectRange时使用withCache");
    final String tpcPrefs = appData.storage.getString("tempConfig") ?? jsonEncode(StaticsVar.tempConfig);
    final List<List<String>> cacheList = (jsonDecode(tpcPrefs)["SelectedClasses"] as List)
        .cast<List>()
        .map((e) => e.cast<String>().toList())
        .toList();
    for(List<String> cachedClass in cacheList) {
      for(SourceItem sourceItem in appData.wordData.classes){
        if(sourceItem.sourceJsonFileName != cachedClass[0]){
          continue;
        }
        if(sourceItem.subClasses.any((ClassItem classItem) => classItem.className == cachedClass[1])){
          beforeSelectedClasses.add(
            sourceItem.subClasses.firstWhere((ClassItem classItem) => classItem.className == cachedClass[1])
          );
        }
      }
    }
    context.read<Global>().uiLogger.fine("已缓存课程选择: $beforeSelectedClasses");
  }

  ClassSelection? selectedClasses = await showModalBottomSheet<ClassSelection>(
    context: context,
    shape: RoundedRectangleBorder(side: BorderSide(width: 1.0, color: Theme.of(context).colorScheme.outlineVariant), borderRadius: StaticsVar.br),
    isDismissible: false,
    isScrollControlled: AdaptiveScope.of(context).isWide,
    enableDrag: true,
    builder: (BuildContext context) {
      return ClassSelectPage(beforeSelectedClasses: beforeSelectedClasses, withReviewChoose: withReviewChoose);
    }
  );

  if(withCache && selectedClasses != null && context.mounted) {
    final String tpcPrefs = appData.storage.getString("tempConfig") ?? jsonEncode(StaticsVar.tempConfig);
    Map<String, dynamic> tpcMap = jsonDecode(tpcPrefs);
    tpcMap["SelectedClasses"] = selectedClasses;
    appData.storage.setString("tempConfig", jsonEncode(tpcMap));
    context.read<Global>().uiLogger.info("课程选择缓存完成");
  }
  if(context.mounted) context.read<Global>().uiLogger.fine("选择的课程: $selectedClasses");
  return selectedClasses??ClassSelection(selectedClass: [], countInReview: false);
}


/// 获取课程组件列表
/// 
/// [context] :Widget树上的context
/// 
/// [mediaQuery] :`MediaQuery.of(context)` 用于自适应组件大小
/// 
/// [onChanged] :当一个课程选项被勾选或取消时触发的操作，会传入一个[词库键, 课程键]的参数
/// 
/// [isClassSelected] :需要一个函数判断该课程是否被选中
/// 
/// 一般情况下该函数只会在 [ClassSelectPage] 中被使用，若非必要你不应该使用此函数
List<Widget> classesSelectionList(BuildContext context, Function (ClassItem) onChanged, bool Function (ClassItem) isClassSelected, List<SourceItem>? forceSelectRange) {
  context.read<Global>().uiLogger.fine("构建课程选择列表");
  late List<SourceItem> sourcesList;
  if(forceSelectRange != null) {
    sourcesList = forceSelectRange;
  } else {
    sourcesList = AppData().wordData.classes;
  }
  List<Widget> widgetList = [];
  for (SourceItem source in sourcesList) {
    widgetList.add(
      Container(
        margin: EdgeInsets.all(16.0),
        padding: EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: StaticsVar.br,
        ),
        child: Text(
          source.name,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
    bool isEven = true;
    for(ClassItem classItem in source.subClasses){
      widgetList.add(
        Container(
          margin: EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isEven ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: StatefulBuilder(
            builder: (context, setLocalState) {
              return CheckboxListTile(
                title: Text(classItem.className),
                value: isClassSelected(classItem),
                onChanged: (value) {
                  setLocalState(() {
                    onChanged(classItem);
                  });
                },
              );
            }
          ),
        ),
      );
      isEven = !isEven;
    }
  }
  if(widgetList.isEmpty) {
    context.read<Global>().uiLogger.warning("用户未导入可用词库");
    widgetList.add(
      Center(child: Text('啥啥词库都没导入，你学个啥呢？\n自己去 设置 -> 数据设置 -> 导入词库', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: context.semanticColors.error),))
    );
  }
  context.read<Global>().uiLogger.info("课程选择列表构建完成");
  return widgetList;
}

// Base Widgets 较为基础的Widget

/// 文本框容器
/// 
/// 显示一个带文本的容器，有背景色
/// 
/// [text] :显示的文本 必须
/// 
/// [style] :自定义文本的属性TextStyle 默认为null
/// 
/// [selectable] :控制文本能否被选中（复制等操作需要） 默认为false
/// 
/// [size] :文本容器的大小 默认为null（自适应）
/// 
/// [textAlign] :控制文本排布方向 默认为null（自适应）
class TextContainer extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool selectable;
  final Size? size;
  final TextAlign? textAlign;
  final bool animated;
  const TextContainer({super.key, 
                      required this.text, 
                      this.style,
                      this.size,
                      this.animated = false,
                      this.selectable = false,
                      this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    // 默认 18 号正文：由主题 `textTheme.titleMedium`（已按历史尺寸微调）提供。
    final TextStyle actualStyle =
        style ?? Theme.of(context).textTheme.titleMedium!;
    return Container(
      width: size?.width,
      height: size?.height,
      margin: EdgeInsets.all(16.0),
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: StaticsVar.br,
      ),
      child: (animated)
        ? TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: text.length.toDouble()), 
          duration: AppMotion.long2,
          curve: AppMotion.standardCurve,
          builder: (context, value, child) {
            if(value == text.length.toDouble()) return child!;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text.substring(0, value.floor()), style: actualStyle, textAlign: textAlign, maxLines: 1),
                Text(text[value.floor()], style: actualStyle.copyWith(color: actualStyle.color?.withAlpha((255 * value.remainder(1)).round()) ?? Theme.of(context).textTheme.bodyLarge!.color!.withAlpha((255 * value.remainder(1)).round())), maxLines: 1)
              ],
            );
          },
          child: (selectable) 
            ? SelectableText(text,style: actualStyle, textAlign: textAlign, maxLines: 1)
            : Text(text,style: actualStyle, textAlign: textAlign, maxLines: 1)
        ) : (selectable) 
            ? SelectableText(text,style: actualStyle, textAlign: textAlign)
            : Text(text,style: actualStyle, textAlign: textAlign)
    );
  }
}

/// 选择题按钮组
/// 
/// 为选择题生成4个按钮
/// 
/// [options] :选项文本 列表，长度必须为4
/// 
/// [onSelected] :某个选项被选中时的回调，会传入一个int类型数据指示被选择的按钮的索引号[0~3]
/// 
/// [isShowAnimation] :是否显示判定动画（预判微光 -> 低饱和落色 -> 徽章 -> 正误差异化）
/// 若为false则会立即变红/绿，且不出现徽章、抖动与淡化
/// 默认为true
/// 
/// [settingShowingMode] :显示选项的模式
/// 为适应不同屏幕选项可以多行显示，
/// 允许值：0：1行；1：2行；2：4行
/// 
/// [isSingleSelect] :是否单选模式。为 true 且 [isShowAnimation] 为 true 时，
/// 某选项产生判定结果后其余选项会淡化并轻微缩小（选中聚焦）。
/// 多选（`ChoiceQuestions.allowMutipleSelect`）应保持 false，以免干扰继续选择。
/// 默认为false
///
/// 该组件供各 *Question 组件（ChoiceQuestions / ListeningQuestion /
/// SelfRatingQuestion）复用；业务代码不应直接调用。
class ChooseButtons extends StatefulWidget {
  final List<String> options;
  final bool? Function(int) onSelected;
  final bool isShowAnimation;
  final int settingShowingMode; // 0: 1 Row, 1: 2 Rows, 2: 4 Rows
  final bool isSingleSelect;

  /// 是否在首次选择后锁定全部选项（单选作答后禁止再次选择）。
  final bool lockAfterSelect;

  /// 外部强制锁定（如听力题「跳过」后禁止再作答）；true 时忽略所有选项点击。
  final bool locked;

  /// 锁定时再次点击任意选项的回调，传入被点击的选项索引。
  final void Function(int index)? onLockedTap;

  const ChooseButtons({super.key, 
                      required this.options, 
                      required this.onSelected, 
                      this.isShowAnimation = false, 
                      this.settingShowingMode = -1,
                      this.isSingleSelect = false,
                      this.lockAfterSelect = false,
                      this.locked = false,
                      this.onLockedTap});
  @override
  State<ChooseButtons> createState() => _ChooseButtonsState();
}

class _ChooseButtonsState extends State<ChooseButtons> {
  /// 已有判定结果的选项索引（单选聚焦的锚点）；`null` 表示尚无判定。
  int? _judgedIndex;

  /// 内部锁定：`lockAfterSelect` 为真且已产生首次选择后置位。
  bool _locked = false;

  bool get _isLocked => widget.locked || _locked;

  /// 子按钮产生判定结果（`chose` 返回非 null）时记录，用于选中聚焦。
  void _onJudged(int index) {
    if(_judgedIndex == index) return;
    setState(() {
      _judgedIndex = index;
    });
  }

  @override
  void didUpdateWidget(ChooseButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 选项 / 模式变化（PageView 可能复用 element）时重置聚焦与锁定，避免残留旧状态。
    if(oldWidget.isShowAnimation != widget.isShowAnimation ||
        oldWidget.isSingleSelect != widget.isSingleSelect ||
        oldWidget.lockAfterSelect != widget.lockAfterSelect ||
        !listEquals(oldWidget.options, widget.options)) {
      _judgedIndex = null;
      _locked = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    // 选中聚焦（E）：仅单选 + 开启动画 + 已产生判定结果时淡化其余选项。
    final bool focusJudged = widget.isShowAnimation && widget.isSingleSelect && _judgedIndex != null;
    List<Widget> buttonWidgets = [];
    for(int i = 0; i < widget.options.length; i++) {
      buttonWidgets.add(
        ChooseButtonBox(
          index: i,
          chose: (int index) {
            if(_isLocked) {
              widget.onLockedTap?.call(index);
              return null;
            }
            if(widget.lockAfterSelect) _locked = true;
            return widget.onSelected(index);
          },
          width: widget.settingShowingMode == 0 ? mediaQuery.size.width * 0.2 : widget.settingShowingMode == 1 ? mediaQuery.size.width * 0.45 : mediaQuery.size.width * 0.85,
          height: widget.settingShowingMode == 0 ? mediaQuery.size.height * 0.15 : widget.settingShowingMode == 1 ? mediaQuery.size.height * 0.12 : mediaQuery.size.height * 0.09,
          isAnimated: widget.isShowAnimation,
          isDimmed: focusJudged && i != _judgedIndex,
          onJudged: _onJudged,
          child: FittedBox(
            // 选项文字显式只缩不放（FittedBox 默认 contain）：按钮当前以松约束
            // 布局文字，二者观感一致；显式 scaleDown 防止后续布局变化引入放大。
            fit: BoxFit.scaleDown,
            child: Text(
              widget.options[i],
              style: arabicTextStyle(
                context,
                widget.options[i],
                base: withoutColor(Theme.of(context).textTheme.displaySmall!),
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        if(widget.settingShowingMode == 0) Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: buttonWidgets,
        ),
        if(widget.settingShowingMode == 1) Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: buttonWidgets.sublist(0, 2),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: buttonWidgets.sublist(2),
            ),
          ],
        ),
        if(widget.settingShowingMode == 2) ...buttonWidgets,
      ],
    );
  }
}

/// 选择题按钮（单个）
/// 
/// 判定反馈由单个 [AnimationController] 驱动，分阶段且有限（总时长
/// [AppMotion.extraLong1]，可 `pumpAndSettle`）：
/// 1. 预判（~176ms）：琥珀描边 + 微光脉冲，不整块高饱和变色；
/// 2. 揭示：底色过渡为低饱和语义容器色，文字保持可读；
/// 3. 徽章：✓ / ✗ 圆形徽章以 `easeOutBack` 弹性缩放入场（~272ms）并淡入；
/// 4. 差异化：正确轻微脉冲（1→1.045→1），错误水平抖动（0→+6→-6→+4→0），
///    均伴随柔和外发光；位移 / 缩放均不参与布局。
/// 同时触发触觉反馈（正确 [HapticFeedback.lightImpact]、错误
/// [HapticFeedback.mediumImpact]），平台失败时静默容错。
///
/// [index] :这个按钮的索引号
/// 
/// [chose] :回调参数，被选择时触发，会传入该按钮索引号
/// 
/// [child] :按钮的子组件（内容）
/// 
/// [cl] :该按钮的颜色（初始颜色）
/// 
/// [width] :宽
/// 
/// [height] :高
/// 
/// [isAnimated] :是否显示判定动画；false 时保持旧语义立即落定正误色，
/// 无徽章 / 抖动 / 淡化
///
/// [isDimmed] :是否淡化（单选聚焦时由父组件传入）；true 时降低不透明度并轻微缩小
///
/// [onJudged] :产生判定结果（[chose] 返回非 null）时通知父组件，用于选中聚焦协调
class ChooseButtonBox extends StatefulWidget {
  final int index;
  final bool? Function(int) chose;
  final Widget child;
  final Color? cl;
  final double? width;
  final double? height;
  final bool isAnimated;
  final bool isDimmed;
  final ValueChanged<int>? onJudged;
  const ChooseButtonBox({super.key,
                    required this.index, 
                    required this.chose, 
                    required this.child, 
                    this.cl, 
                    this.width, 
                    this.height,
                    this.isAnimated = true,
                    this.isDimmed = false,
                    this.onJudged,
                  });
  
  @override
  State<ChooseButtonBox> createState() => _ChooseButtonBoxState();
}

class _ChooseButtonBoxState extends State<ChooseButtonBox> with SingleTickerProviderStateMixin {
  /// 判定动画总时长（800ms），各阶段以 [Interval] 划分，见类文档。
  static const Duration _judgeDuration = AppMotion.extraLong1;

  /// 徽章直径与错误抖动幅度（像素级位移，不影响布局）。
  static const double _badgeSize = 26.0;
  static const double _shakeAmplitude = 6.0;

  /// 唯一的判定动画控制器：预判 / 揭示 / 徽章 / 脉冲 / 抖动 / 发光均由它驱动。
  late final AnimationController _controller;

  /// 预判微光：0 → 1 → 0（琥珀描边 / 微光脉冲）。
  late final Animation<double> _warning;

  /// 揭示进度：初始色 → 低饱和语义容器色。
  late final Animation<double> _reveal;

  /// 柔和外发光：随差异化阶段渐显并静态保持。
  late final Animation<double> _glow;

  /// 徽章弹性缩放（`easeOutBack`）与淡入。
  late final Animation<double> _badgeScale;
  late final Animation<double> _badgeOpacity;

  /// 正确脉冲（1 → 1.045 → 1）与错误水平抖动（0 → +6 → -6 → +4 → 0）。
  late final Animation<double> _pulse;
  late final Animation<double> _shake;

  bool isChoosed = false;

  /// 作答判定结果；`null` 表示尚未判定或未产生判定（多选 / 不判定）。
  bool? _result;

  /// 是否执行了完整判定动画（开启动画且未要求减弱动态效果）。
  bool _animated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _judgeDuration);
    _warning = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 1.0),
      TweenSequenceItem<double>(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 1.0),
    ]).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.22, curve: Curves.easeInOut)));
    _reveal = CurvedAnimation(parent: _controller, curve: const Interval(0.14, 0.46, curve: AppMotion.standardCurve));
    _glow = CurvedAnimation(parent: _controller, curve: const Interval(0.46, 0.86, curve: Curves.easeOutCubic));
    _badgeScale = CurvedAnimation(parent: _controller, curve: const Interval(0.40, 0.74, curve: Curves.easeOutBack));
    _badgeOpacity = CurvedAnimation(parent: _controller, curve: const Interval(0.40, 0.58, curve: Curves.easeOut));
    _pulse = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(tween: Tween<double>(begin: 1.0, end: 1.045), weight: 1.0),
      TweenSequenceItem<double>(tween: Tween<double>(begin: 1.045, end: 1.0), weight: 1.0),
    ]).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.52, 1.0, curve: Curves.easeInOut)));
    _shake = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(tween: Tween<double>(begin: 0.0, end: _shakeAmplitude), weight: 1.0),
      TweenSequenceItem<double>(tween: Tween<double>(begin: _shakeAmplitude, end: -_shakeAmplitude), weight: 2.0),
      TweenSequenceItem<double>(tween: Tween<double>(begin: -_shakeAmplitude, end: _shakeAmplitude * 2 / 3), weight: 1.0),
      TweenSequenceItem<double>(tween: Tween<double>(begin: _shakeAmplitude * 2 / 3, end: 0.0), weight: 1.0),
    ]).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.52, 1.0, curve: Curves.easeInOut)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 触觉反馈：Web / 测试 / 平台不支持时静默失败，不中断判定流程。
  void _fireHaptic(bool correct) {
    final Future<void> feedback =
        correct ? HapticFeedback.lightImpact() : HapticFeedback.mediumImpact();
    unawaited(feedback.catchError((Object _) {}));
  }

  /// 点击选项：同步调用 [ChooseButtonBox.chose] 获取判定结果并驱动动画。
  /// `chose()` 的调用时机与次数保持不变（点击时同步调用一次，仍在 `setState` 内）。
  void _handleTap() {
    if(isChoosed) return;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    setState(() {
      isChoosed = true;
      final bool? ans = widget.chose(widget.index);
      _result = ans;
      _animated = ans != null && widget.isAnimated && !reduceMotion;
      if(_animated) {
        _controller.forward(from: 0.0);
      } else {
        // 立即落色（未开动画 / 减弱动态效果）或恢复初始色（未判定）：不启动动画。
        _controller.value = 0.0;
      }
    });
    final bool? ans = _result;
    if(ans != null) {
      widget.onJudged?.call(widget.index);
      // 触觉反馈属于判定语义，PK 等关闭判定的场景不引入。
      if(widget.isAnimated) _fireHaptic(ans);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppSemanticColors semantic = context.semanticColors;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final bool judged = _result != null;
    final bool correct = _result == true;
    // 旧语义：isAnimated=false（如 PK）保持立即落定高饱和正误色。
    final bool legacyInstant = judged && !widget.isAnimated;
    // 新语义动画路径；减弱动态效果时只落定静态结果色（staticReveal）。
    final bool animated = judged && _animated;
    final bool staticReveal = judged && !legacyInstant && !animated;

    final Color accent = correct ? semantic.success : semantic.error;
    // 落定色：低饱和语义容器色（语义色低透明度叠 surface 容器），文字保持可读。
    final Color judgedColor = legacyInstant
        ? accent
        : Color.alphaBlend(accent.withValues(alpha: 0.20), scheme.surfaceContainerHighest);
    final Color judgedOnColor = legacyInstant
        ? (correct ? semantic.onSuccess : scheme.onError)
        : scheme.onSurface;

    // 未判定时恢复初始色（自定义 cl 时按其明暗语义取前景）。
    final Color idleColor = widget.cl ?? scheme.primaryContainer;
    final Color idleOnColor = widget.cl == null ? scheme.onPrimaryContainer : scheme.onSurface;

    // 逐帧动画（颜色揭示 / 预判描边 / 发光 / 脉冲 / 抖动）统一由控制器驱动：
    // build 本身不会逐帧执行，必须经 AnimatedBuilder 监听控制器。
    // 选中聚焦（E）：仅由父组件在单选判定后置位；减弱动态效果时不做过渡。
    return AnimatedOpacity(
      duration: reduceMotion ? Duration.zero : AppMotion.medium,
      curve: AppMotion.standardCurve,
      opacity: widget.isDimmed ? 0.4 : 1.0,
      child: AnimatedScale(
        duration: reduceMotion ? Duration.zero : AppMotion.medium,
        curve: AppMotion.standardCurve,
        scale: widget.isDimmed ? 0.975 : 1.0,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) {
            // 揭示进度：非动画路径直接 1.0（立即落色）。
            final double reveal = animated ? _reveal.value : (judged ? 1.0 : 0.0);
            final Color background = judged ? Color.lerp(idleColor, judgedColor, reveal)! : idleColor;
            final Color foreground = judged ? Color.lerp(idleOnColor, judgedOnColor, reveal)! : idleOnColor;

            // 预判描边 / 微光与判定外发光（结束后发光静态保持；旧语义不引入）。
            final double warning = animated ? _warning.value : 0.0;
            final double glow = animated ? _glow.value : 0.0;
            final Border? border;
            if(legacyInstant) {
              border = null;
            } else if(animated) {
              // 预判琥珀描边 -> 揭示正误强调描边，随 reveal 交叉过渡。
              border = Border.all(
                color: Color.lerp(
                  semantic.warning.withValues(alpha: 0.34 + 0.51 * warning),
                  accent.withValues(alpha: 0.45),
                  reveal,
                )!,
                width: 1.5,
              );
            } else if(staticReveal) {
              border = Border.all(color: accent.withValues(alpha: 0.45), width: 1.5);
            } else {
              border = null;
            }
            final List<BoxShadow>? shadows;
            if(legacyInstant || staticReveal) {
              shadows = null;
            } else if(judged) {
              shadows = glow > 0.0
                  ? <BoxShadow>[BoxShadow(color: accent.withValues(alpha: 0.30 * glow), blurRadius: 16.0, spreadRadius: 1.0)]
                  : null;
            } else if(warning > 0.0) {
              shadows = <BoxShadow>[BoxShadow(color: semantic.warning.withValues(alpha: 0.20 * warning), blurRadius: 14.0)];
            } else {
              shadows = null;
            }

            // 差异化（D）：正确脉冲 / 错误抖动，均不参与布局。
            final double pulseScale = (animated && correct) ? _pulse.value : 1.0;
            final double shakeDx = (animated && !correct) ? _shake.value : 0.0;

            return Transform.translate(
              offset: Offset(shakeDx, 0.0),
              child: Transform.scale(
                scale: pulseScale,
                child: Container(
                  // 供测试定位容器装饰；index 在单个按钮组内唯一。
                  key: ValueKey<String>('chooseButtonBoxSurface-${widget.index}'),
                  margin: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: StaticsVar.br,
                    boxShadow: shadows,
                  ),
                  // 描边以前景装饰绘制，避免 Container 依据 border 追加内边距导致布局跳动。
                  foregroundDecoration: border == null
                      ? null
                      : BoxDecoration(border: border, borderRadius: StaticsVar.br),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Button(
                        onPressed: _handleTap,
                        size: Size(widget.width ?? 200, widget.height ?? 50),
                        backgroundColor: Colors.transparent,
                        foregroundColor: foreground,
                        shadowColor: Colors.transparent,
                        child: widget.child,
                      ),
                      if(animated) Positioned(
                        top: 4.0,
                        right: 4.0,
                        // 徽章仅作视觉评章，不拦截点击。
                        child: IgnorePointer(
                          child: FadeTransition(
                            opacity: _badgeOpacity,
                            child: ScaleTransition(
                              scale: _badgeScale,
                              child: _buildBadge(scheme, semantic),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 判定徽章：✓（成功）/ ✗（错误）圆形评章，置于按钮内容层。
  Widget _buildBadge(ColorScheme scheme, AppSemanticColors semantic) {
    final bool correct = _result == true;
    final Color accent = correct ? semantic.success : semantic.error;
    return Container(
      width: _badgeSize,
      height: _badgeSize,
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.surface.withValues(alpha: 0.9), width: 1.5),
        boxShadow: <BoxShadow>[BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 8.0)],
      ),
      alignment: Alignment.center,
      child: Icon(
        correct ? Icons.check_rounded : Icons.close_rounded,
        size: 15.0,
        color: correct ? semantic.onSuccess : scheme.onError,
      ),
    );
  }
}

/// 分类标签组件
/// 
/// 将 [categories] 中的字符串原样渲染为标签，不做任何分组或含义解释
/// 
/// [categories] :分类字符串列表，为空时不渲染任何内容
/// 
/// [dense] :紧凑模式，使用更小的字号与内边距，适用于空间受限的卡片
/// 
/// [scale] :在 [dense] 基准尺寸上的额外缩放（默认 1.0 保持既有外观），
/// 供大卡片等空间充裕的场景放大字号 / 内边距 / 圆角与间距；不覆盖
/// `MediaQuery.textScaler`，系统无障碍文字缩放仍会叠加生效
class CategoryChips extends StatelessWidget {
  final List<String> categories;
  final bool dense;
  final double scale;
  const CategoryChips({super.key, required this.categories, this.dense = false, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    if(categories.isEmpty) return const SizedBox.shrink();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle baseStyle =
        (dense ? Theme.of(context).textTheme.labelSmall : Theme.of(context).textTheme.labelMedium) ??
            const TextStyle();
    // 显式放大的字号让系统 textScaler 在其之上继续叠加（不替换系统值）。
    final TextStyle labelStyle = baseStyle.copyWith(
      color: scheme.onSecondaryContainer,
      fontSize: (baseStyle.fontSize ?? 12.0) * scale,
    );
    return Wrap(
      spacing: (dense ? 4.0 : 6.0) * scale,
      runSpacing: (dense ? 4.0 : 6.0) * scale,
      children: List<Widget>.generate(categories.length, (int index) {
        final String category = categories[index];
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: (dense ? 6.0 : 10.0) * scale,
            vertical: (dense ? 1.0 : 4.0) * scale,
          ),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.card * scale),
          ),
          child: Text(
            category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        );
      }),
    );
  }
}

/// 分类筛选组件
/// 
/// [available] :可供选择的分类列表（展示顺序由调用方决定，组件不硬编码顺序）
/// 
/// [selected] :当前已选择的分类集合
/// 
/// [onChanged] :选择变化时的回调，传出新的完整集合（调用方负责持有状态）
/// 
/// 多选时使用 AND 语义筛选单词，空集合表示不筛选；
/// 非空时会出现“清除筛选”按钮。
class CategoryFilter extends StatelessWidget {
  final List<String> available;
  final Set<String> selected;
  final void Function(Set<String>) onChanged;
  const CategoryFilter({super.key, required this.available, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if(available.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.all(8.0),
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: StaticsVar.br,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_outlined, size: 18.0),
              SizedBox(width: 4.0),
              Text("分类筛选", style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
              Spacer(),
              if(selected.isNotEmpty) TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size(0.0, 0.0),
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => onChanged(<String>{}),
                child: Text("清除筛选", style: Theme.of(context).textTheme.labelMedium),
              )
            ],
          ),
          Wrap(
            spacing: 6.0,
            runSpacing: 6.0,
            children: List<Widget>.generate(available.length, (int index) {
              final String category = available[index];
              final bool isSelected = selected.contains(category);
              return FilterChip(
                label: Text(
                  category,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    // 未选中时与 chipTheme.labelStyle 的 onSurfaceVariant 保持一致
                    color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                selected: isSelected,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                selectedColor: Theme.of(context).colorScheme.secondaryContainer,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: StaticsVar.br,
                  side: BorderSide(
                    color: isSelected
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                onSelected: (bool value) {
                  final Set<String> next = Set<String>.of(selected);
                  if(value) {
                    next.add(category);
                  } else {
                    next.remove(category);
                  }
                  onChanged(next);
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class Button extends StatefulWidget {
  final Widget? child;
  final void Function()? onPressed;
  final Widget? icon;
  final AxisDirection iconDirection;
  final Size? size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? shadowColor;
  final EdgeInsetsGeometry padding;
  final OutlinedBorder? shape;
  final MainAxisAlignment alignment;

  const Button({
    super.key,
    this.child,
    this.icon,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.shape,
    this.size,
    this.shadowColor,
    this.iconDirection = AxisDirection.left,
    this.padding = const EdgeInsetsGeometry.all(16.0),
    this.alignment = MainAxisAlignment.spaceEvenly
  });

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  /// 指针按压中：仅做视觉缩放反馈，不改变布局尺寸与命中区域。
  bool _pressed = false;

  void _setPressed(bool value) {
    if(_pressed == value) return;
    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // 默认采用 M3 填充色调按钮配色（primaryContainer / onPrimaryContainer）；
    // 显式指定容器背景色时自动匹配对应的 onXxx 前景色，未知背景回退 onSurface，
    // 需要更精确对比度的调用方仍可传入 [foregroundColor] 覆盖。
    final Color background = widget.backgroundColor ?? scheme.primaryContainer;
    final Color foreground = widget.foregroundColor ??
        (background == scheme.primaryContainer
            ? scheme.onPrimaryContainer
            : background == scheme.secondaryContainer
                ? scheme.onSecondaryContainer
                : background == scheme.errorContainer
                    ? scheme.onErrorContainer
                    : scheme.onSurface);
    // 透明背景按钮（如 WordCardArabicButton 发音、ChooseButtonBox 选项）没有容器色，
    // 以前景色作为 state layer 底色；前景也透明时回退 onSurface，保证亮暗模式可读。
    final Color overlayBase = foreground.a == 0 ? scheme.onSurface : foreground;
    final Widget button = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        shadowColor: widget.shadowColor,
        fixedSize: widget.size,
        padding: widget.padding,
        shape: widget.shape ?? RoundedRectangleBorder(borderRadius: StaticsVar.br),
        // 按压 / 悬停的 Material state layer（即时视觉反馈）。
        overlayColor: overlayBase.withValues(alpha: 0.10),
        animationDuration: AppMotion.quick,
      ),
      clipBehavior: Clip.hardEdge,
      onPressed: widget.onPressed,
      child: widget.icon==null 
          ? widget.child
          : [AxisDirection.left, AxisDirection.right].contains(widget.iconDirection)
          ? Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: widget.alignment,
            children: [
              if(widget.iconDirection == AxisDirection.left) Padding(
                padding: const EdgeInsets.all(8.0),
                child: widget.icon!,
              ),
              ?widget.child,
              if(widget.iconDirection == AxisDirection.right) Padding(
                padding: const EdgeInsets.all(8.0),
                child: widget.icon!,
              )
            ],
          )
          : Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: widget.alignment,
            children: [
              if(widget.iconDirection == AxisDirection.up) Padding(
                padding: const EdgeInsets.all(8.0),
                child: widget.icon!,
              ),
              ?widget.child,
              if(widget.iconDirection == AxisDirection.down) Padding(
                padding: const EdgeInsets.all(8.0),
                child: widget.icon!,
              )
            ],
          )
    );
    // 禁用态与“减弱动态效果”下保持纯 ElevatedButton，不引入额外包装。
    if(widget.onPressed == null ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      return button;
    }
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: AppMotion.quick,
        curve: AppMotion.standardCurve,
        child: button,
      ),
    );
  }
}

// Page Widget 可复用的页面Widget

/// 课程选择页面
/// 
/// 若要直接获取选择数据，请使用Route或者push调用，在其返回值中有[[词库键, 课程键]]的列表返回
/// 
/// [beforeSelectedClasses] :已经勾选的课程，可以自定义，但一般搭配缓存使用
/// 
/// 注意：如果你要进行课程选择，请先考虑 [popSelectClasses] 函数，这是一个已经基本成熟的实现
class ClassSelectPage extends StatelessWidget { 
  final List<ClassItem> beforeSelectedClasses;
  final bool withReviewChoose;
  final List<SourceItem>? forceSelectRange;
  const ClassSelectPage({super.key, this.beforeSelectedClasses = const [], this.withReviewChoose = false, this.forceSelectRange});
  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    ClassSelection classSelection = ClassSelection(
      selectedClass: beforeSelectedClasses.toList(), 
      countInReview: FSRS().config.enabled
    );
    void addClass(ClassItem classInfo) {
      classSelection.selectedClass.add(classInfo);
    }
    void removeClass(ClassItem classInfo) {
      classSelection.selectedClass.remove(classInfo);
    }
    bool isClassSelected(ClassItem classInfo) {
      return classSelection.selectedClass.any((e) => e==classInfo);
    }
    void onClassChanged(ClassItem classInfo) {
      if(isClassSelected(classInfo)) {
        removeClass(classInfo);
      } else {
        addClass(classInfo);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('选择特定课程单词'),
      ),
      body: SafeArea(top: false, child: Column(
        children: [
          Expanded(
            child: ListView(
              children: classesSelectionList(context, onClassChanged, isClassSelected, forceSelectRange)
            ),
          ),
          if(withReviewChoose) StatefulBuilder(
            builder: (context, setLocalState) {
              return Row(
                children: [
                  Expanded(child: Text("本次学习${classSelection.countInReview?"将":"不会"}计入复习系统")),
                  Switch(
                    value: classSelection.countInReview, 
                    onChanged: (value){
                      if(value == true && !FSRS().config.enabled) {
                        showSnackBar(context, "请先启用复习系统");
                        return ;
                      }
                      setLocalState(() {
                        classSelection.countInReview = value;
                      });
                    }
                  )
                ],
              );
            }
          ),
          Button(
            size: Size(mediaQuery.size.width, mediaQuery.size.height * 0.08),
            child: Text('确认'),
            onPressed: () {
              Navigator.pop(context, classSelection);
            },
          ),
        ],
      )),
    );
  }
}

// 有关设置的Widget
class SettingRedirctButton extends StatelessWidget {
  const SettingRedirctButton({
    super.key,
    required this.title,
    required this.target,
    this.icon = Icons.settings
  });

  final String title;
  final IconData icon;
  final Widget target;

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
        // 与 SettingItem 卡片形成同一容器的“更亮一层”，整块设置项观感统一；
        // 前置图标用主题主色、尾部箭头用次级前景，稳定传达“可跳转”。
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurface,
        shape: BeveledRectangleBorder(),
      ),
      onPressed: () {
        context.read<Global>().uiLogger.info(
          "跳转: SettingPage => ${target.toString()}",
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => target,
          ),
        );
      },
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          Expanded(child: Text(title)),
          Icon(Icons.arrow_forward_ios, size: 16.0, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.leading,
    required this.end,
    this.icon = Icons.settings,
    this.note,
  });

  final String leading;
  final String? note;
  final IconData icon;
  final Widget end;

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Row(
      children: [
        SizedBox(width: mediaQuery.size.width * 0.02),
        Icon(icon, size: 24.0),
        SizedBox(width: mediaQuery.size.width * 0.01),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(leading),
              if(note != null) Text(
                note!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        end,
        SizedBox(width: mediaQuery.size.width * 0.02)
      ],
    );
  }
}

class SettingItem extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry? padding;
  final List<Widget> children;
  const SettingItem({super.key, required this.title, required this.children, this.padding});

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 SettingItem: $title");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    List<Container> decoratedContainers = List.generate(children.length, (int index) {
      return Container(
        width: mediaQuery.size.width * 0.90,
        padding: padding,
        margin: EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          // 统一用 surfaceContainerLow 作为分区卡片底色；分区内各设置项
          // （SettingRow / SettingRedirctButton）再用更高一层的容器色区分。
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.vertical(top: Radius.circular(index == 0 ? AppRadius.card : 5.0), bottom: Radius.circular(index == children.length-1 ? AppRadius.card : 5.0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: children[index],
      );
    });

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分区标题：主题主色 + 加粗，避免再叠一层灰色容器造成色彩杂乱。
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Center(
          child: Column(
            children: decoratedContainers,
          ),
        ),
      ]
    );
  }
}
