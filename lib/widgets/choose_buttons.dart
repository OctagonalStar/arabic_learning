// 选择题选项按钮（原 widgets/kit.dart 拆分）。
// 承载选项按钮组 [ChooseButtons] 与单个选项 [ChooseButtonBox]（含判定动画、
// 释义行揭示与长按回调）。供各 *Question 组件复用，业务代码不应直接调用。
// 由 widgets/kit.dart 统一 export，调用方仍从 kit.dart 导入。

import 'dart:async';

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/theme/tokens.dart' show AppMotion, AppSemanticColors;
import 'package:arabic_learning/theme/typography.dart';
import 'package:arabic_learning/widgets/app_button.dart' show Button;
import 'package:arabic_learning/widgets/motion.dart' show FadeSlideIn;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

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

  /// 与 [options] 一一对应的选项词条；非空时启用两项能力：
  /// 1. 答案锁定（单选首次作答）或选对（多选）后，每个选项按钮内平滑揭示
  ///    对应词条的释义行（阿拉伯语选项显示中文释义，中文选项显示阿语原文）；
  /// 2. [onOptionLongPress] 非空时长按选项回调对应词条。
  /// 为 null（如本地 PK）时两项功能均禁用，保持旧行为。
  final List<WordItem>? optionWords;

  /// 长按选项时回调，传入该选项对应的词条；仅 [optionWords] 非空时生效。
  final void Function(WordItem word)? onOptionLongPress;

  const ChooseButtons({super.key, 
                      required this.options, 
                      required this.onSelected, 
                      this.isShowAnimation = false, 
                      this.settingShowingMode = -1,
                      this.isSingleSelect = false,
                      this.lockAfterSelect = false,
                      this.locked = false,
                      this.onLockedTap,
                      this.optionWords,
                      this.onOptionLongPress});
  @override
  State<ChooseButtons> createState() => _ChooseButtonsState();
}

class _ChooseButtonsState extends State<ChooseButtons> {
  /// 已有判定结果的选项索引（单选聚焦的锚点）；`null` 表示尚无判定。
  int? _judgedIndex;

  /// 内部锁定：`lockAfterSelect` 为真且已产生首次选择后置位。
  bool _locked = false;

  /// 是否已揭示各选项释义行：单选首次作答（锁定）或任一选项选对后置位；
  /// 仅在 [ChooseButtons.optionWords] 非空时生效。
  bool _revealed = false;

  bool get _isLocked => widget.locked || _locked;

  /// 选项 `i` 的释义行文本：阿拉伯语选项显示中文释义，中文选项显示阿语原文；
  /// 未到揭示时机或缺少词条数据时返回 null（不渲染该行）。
  String? _subtitleFor(int index) {
    final List<WordItem>? words = widget.optionWords;
    if(words == null || !_revealed || index >= words.length) return null;
    final WordItem word = words[index];
    return widget.options[index].isArabic() ? word.chinese : word.arabic;
  }

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
        !listEquals(oldWidget.options, widget.options) ||
        !listEquals(oldWidget.optionWords, widget.optionWords)) {
      _judgedIndex = null;
      _locked = false;
      _revealed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    // 选中聚焦（E）：仅单选 + 开启动画 + 已产生判定结果时淡化其余选项。
    final bool focusJudged = widget.isShowAnimation && widget.isSingleSelect && _judgedIndex != null;
    List<Widget> buttonWidgets = [];
    for(int i = 0; i < widget.options.length; i++) {
      final String? subtitle = _subtitleFor(i);
      buttonWidgets.add(
        ChooseButtonBox(
          index: i,
          chose: (int index) {
            if(_isLocked) {
              widget.onLockedTap?.call(index);
              return null;
            }
            if(widget.lockAfterSelect) _locked = true;
            final bool? result = widget.onSelected(index);
            // 答案锁定（单选首次作答）或选对（多选）后揭示全部释义行；
            // 答错且未锁定的多选保持隐藏，允许继续作答。
            if((widget.lockAfterSelect || result == true) && !_revealed) {
              setState(() {
                _revealed = true;
              });
            }
            return result;
          },
          width: widget.settingShowingMode == 0 ? mediaQuery.size.width * 0.2 : widget.settingShowingMode == 1 ? mediaQuery.size.width * 0.45 : mediaQuery.size.width * 0.85,
          height: widget.settingShowingMode == 0 ? mediaQuery.size.height * 0.15 : widget.settingShowingMode == 1 ? mediaQuery.size.height * 0.12 : mediaQuery.size.height * 0.09,
          isAnimated: widget.isShowAnimation,
          // 揭示释义期间不淡化聚焦，保证释义行始终可读；
          // 未提供词条数据时保持旧的聚焦淡化行为（0.4）。
          isDimmed: focusJudged && i != _judgedIndex && widget.optionWords == null,
          onJudged: _onJudged,
          onLongPress: (widget.optionWords != null && widget.onOptionLongPress != null && i < widget.optionWords!.length)
              ? () => widget.onOptionLongPress!(widget.optionWords![i])
              : null,
          definition: subtitle,
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
///
/// [onLongPress] :长按整个选项区域时触发（如弹出单词卡片浮层）；为 null 时不响应
/// 长按，也不影响正常点击
///
/// [definition] :释义行文本；非空时在按钮下方平滑展开一行次要释义
/// （高度动画，减弱动态效果时直接呈现），null 时不渲染该行
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
  final VoidCallback? onLongPress;
  final String? definition;
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
                    this.onLongPress,
                    this.definition,
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
    // 长按（onLongPress）包在外层且用 translucent 命中：正常点击仍交给
    // 内部 Button，未提供回调时整层不参与长按手势。
    final Widget surface = AnimatedBuilder(
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

            // 释义行：AnimatedSize 常驻（作答前高度为 0），揭示时仅替换其
            // 子节点，高度才会从 0 平滑增长；内容再经 FadeSlideIn 淡入上滑。
            // 若在揭示瞬间才插入 AnimatedSize，它首帧即按终态尺寸布局，
            // 表现为“突然撑开”，因此这里必须保持同一实例。
            // 减弱动态效果时不包 AnimatedSize（零时长会在布局期间同步触发
            // 监听，引发“布局中变更”断言），直接呈现终态。
            final Widget? definitionInner = widget.definition == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 2.0, bottom: 8.0),
                    child: FadeSlideIn(
                      duration: reduceMotion ? Duration.zero : AppMotion.medium,
                      // 逐项轻微错峰，四个选项的释义依次浮现。
                      delay: reduceMotion ? Duration.zero : Duration(milliseconds: 100 * widget.index),
                      slideOffset: const Offset(0.0, 6.0),
                      child: Text(
                        widget.definition!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        // 阿语副行按文本方向渲染并套用配置的阿语字体，
                        // 汉字释义保持原有排版。
                        textDirection: widget.definition!.textDirection,
                        style: arabicTextStyle(
                          context,
                          widget.definition!,
                          base: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
            final Widget definitionContent = definitionInner == null
                ? SizedBox(width: widget.width ?? 200, height: 0.0)
                : SizedBox(width: widget.width ?? 200, child: definitionInner);
            final Widget definitionLine = reduceMotion
                ? definitionContent
                : AnimatedSize(
                    duration: AppMotion.long2,
                    curve: AppMotion.standardCurve,
                    alignment: Alignment.topCenter,
                    child: definitionContent,
                  );

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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
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
                      definitionLine,
                    ],
                  ),
                ),
              ),
            );
          },
        );

    final Widget dimmed = AnimatedOpacity(
      duration: reduceMotion ? Duration.zero : AppMotion.medium,
      curve: AppMotion.standardCurve,
      opacity: widget.isDimmed ? 0.4 : 1.0,
      child: AnimatedScale(
        duration: reduceMotion ? Duration.zero : AppMotion.medium,
        curve: AppMotion.standardCurve,
        scale: widget.isDimmed ? 0.975 : 1.0,
        child: surface,
      ),
    );

    if(widget.onLongPress == null) return dimmed;
    // 长按位于聚焦/判定层之外，命中范围覆盖整个选项区域（含释义行），
    // 且不与 Button 的点击手势冲突。
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: widget.onLongPress,
      child: dimmed,
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
