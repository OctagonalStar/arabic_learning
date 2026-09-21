// UI 控件库（原 lib/funcs/ui.dart 拆分）。
// 承载基础展示控件（TextContainer/Button/ChooseButtons/CategoryChips 等）、
// 分类标签与筛选（CategoryChips/CategoryFilter）、设置类控件
// （SettingRedirctButton/SettingRow/SettingItem）以及课程选择
// （popSelectClasses/classesSelectionList/ClassSelectPage）。
// 单词卡片相关实现集中在 widgets/flip_word_card.dart。
// 说明：与 widgets/shared.dart、widgets/overlays.dart 之间存在循环 import，
// 在 Dart 中合法。

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
import 'package:flutter/material.dart';
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
/// [isShowAnimation] :是否显示动画，即变黄后变红/绿的动画
/// 若为false则会立即变红/绿
/// 默认为true
/// 
/// [settingShowingMode] :显示选项的模式
/// 为适应不同屏幕选项可以多行显示，
/// 允许值：0：1行；1：2行；2：4行
/// 
/// 该组件在 [ChoiceQuestions] 被调用，若非必要，你不应使用此组件
class ChooseButtons extends StatelessWidget {
  final List<String> options;
  final bool? Function(int) onSelected;
  final bool isShowAnimation;
  final int settingShowingMode; // 0: 1 Row, 1: 2 Rows, 2: 4 Rows

  const ChooseButtons({super.key, 
                      required this.options, 
                      required this.onSelected, 
                      this.isShowAnimation = false, 
                      this.settingShowingMode = -1});
  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    List<Widget> buttonWidgets = [];
    for(int i = 0; i < options.length; i++) {
      buttonWidgets.add(
        ChooseButtonBox(
          index: i,
          chose: onSelected,
          width: settingShowingMode == 0 ? mediaQuery.size.width * 0.2 : settingShowingMode == 1 ? mediaQuery.size.width * 0.45 : mediaQuery.size.width * 0.85,
          height: settingShowingMode == 0 ? mediaQuery.size.height * 0.15 : settingShowingMode == 1 ? mediaQuery.size.height * 0.12 : mediaQuery.size.height * 0.09,
          isAnimated: isShowAnimation,
          child: FittedBox(
            // 选项文字显式只缩不放（FittedBox 默认 contain）：按钮当前以松约束
            // 布局文字，二者观感一致；显式 scaleDown 防止后续布局变化引入放大。
            fit: BoxFit.scaleDown,
            child: Text(
              options[i],
              style: arabicTextStyle(
                context,
                options[i],
                base: withoutColor(Theme.of(context).textTheme.displaySmall!),
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        if(settingShowingMode == 0) Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: buttonWidgets,
        ),
        if(settingShowingMode == 1) Column(
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
        if(settingShowingMode == 2) ...buttonWidgets,
      ],
    );
  }
}

/// 选择题按钮（单个）
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
/// [isAnimated] :是否显示动画，即变黄后变红
class ChooseButtonBox extends StatefulWidget {
  final int index;
  final bool? Function(int) chose;
  final Widget child;
  final Color? cl;
  final double? width;
  final double? height;
  final bool isAnimated;
  const ChooseButtonBox({super.key,
                    required this.index, 
                    required this.chose, 
                    required this.child, 
                    this.cl, 
                    this.width, 
                    this.height,
                    this.isAnimated = true
                  });
  
  @override
  State<ChooseButtonBox> createState() => _ChooseButtonBoxState();
}
class _ChooseButtonBoxState extends State<ChooseButtonBox> {
  Color? color;
  Color? onColor;
  bool isChoosed = false;

  /// 警示色动画结束后待落定的作答结果；`null` 表示没有待处理结果。
  /// 由 [AnimatedContainer.onEnd] 消费且只消费一次，取代原先与动画时长
  /// 并行赛跑的 `Future.delayed`，保证正误色严格在颜色动画完成后切换。
  bool? _pendingResult;

  /// 依据 [ans] 落定按钮的正误颜色（调用方负责包在 `setState` 内）。
  void _applyResult(bool ans, ColorScheme scheme, AppSemanticColors semantic) {
    if(ans) {
      color = semantic.success;
      onColor = semantic.onSuccess;
    } else {
      color = scheme.error;
      onColor = scheme.onError;
    }
  }

  /// 颜色动画结束：落定第一阶段暂存的作答结果，只处理一次。
  void _onColorAnimationEnd() {
    final bool? ans = _pendingResult;
    if(ans == null) return;
    _pendingResult = null;
    setState(() {
      _applyResult(ans, Theme.of(context).colorScheme, context.semanticColors);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppSemanticColors semantic = context.semanticColors;
    color ??= widget.cl ?? scheme.primaryContainer;
    onColor ??= widget.cl == null ? scheme.onPrimaryContainer : scheme.onSurface;
    return AnimatedContainer(
      margin: EdgeInsets.all(8.0),
      duration: widget.isAnimated ? AppMotion.mediumLong : Duration(),
      curve: AppMotion.standardCurve,
      // 关闭动画时不会产生待处理结果，回调内部直接空转。
      onEnd: _onColorAnimationEnd,
      decoration: BoxDecoration(
        color: color,
        borderRadius: StaticsVar.br,
      ),
      child: Button(
        onPressed: () {
          if(isChoosed) return;
          setState(() {
            isChoosed = true;
            bool? ans = widget.chose(widget.index);
            if(ans != null) {
              if(widget.isAnimated) {
                // 先闪警示色，动画结束后由 onEnd 落定正误色。
                color = semantic.warning;
                onColor = semantic.onWarning;
                _pendingResult = ans;
              } else {
                // 关闭动画时保持原语义：立即落定正误色。
                _applyResult(ans, scheme, semantic);
              }
            } else {
              // 未产生正误判定：恢复初始色。
              color = scheme.primaryContainer;
              onColor = scheme.onPrimaryContainer;
            }
          });
        },
        size: Size(widget.width ?? 200, widget.height ?? 50),
        backgroundColor: Colors.transparent,
        foregroundColor: onColor,
        shadowColor: Colors.transparent,
        child: widget.child,
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
class CategoryChips extends StatelessWidget {
  final List<String> categories;
  final bool dense;
  const CategoryChips({super.key, required this.categories, this.dense = false});

  @override
  Widget build(BuildContext context) {
    if(categories.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: dense ? 4.0 : 6.0,
      runSpacing: dense ? 4.0 : 6.0,
      children: List<Widget>.generate(categories.length, (int index) {
        final String category = categories[index];
        return Container(
          padding: EdgeInsets.symmetric(horizontal: dense ? 6.0 : 10.0, vertical: dense ? 1.0 : 4.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: StaticsVar.br,
          ),
          child: Text(
            category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (dense
                    ? Theme.of(context).textTheme.labelSmall
                    : Theme.of(context).textTheme.labelMedium)
                ?.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
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
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
        // 设置项面板为 surfaceContainerHighest，此处用低一层的容器色区分行。
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
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
          Icon(icon),
          Expanded(child: Text(title)),
          Icon(Icons.arrow_forward_ios),
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
    List<Container> decoratedContainers = List.generate(children.length, (int index) {
      return Container(
        width: mediaQuery.size.width * 0.90,
        padding: padding,
        margin: EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
        TextContainer(text: title),
        Center(
          child: Column(
            children: decoratedContainers,
          ),
        ),
      ]
    );
  }
}
