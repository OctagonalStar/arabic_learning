import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:arabic_learning/funcs/fsrs_func.dart';
import 'package:arabic_learning/vars/config_structure.dart' show ClassItem, SourceItem, WordItem, ClassSelection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:arabic_learning/funcs/utili.dart';

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
    shape: RoundedRectangleBorder(side: BorderSide(width: 1.0, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)), borderRadius: StaticsVar.br),
    isDismissible: false,
    isScrollControlled: appData.isWideScreen,
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
          color: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          borderRadius: StaticsVar.br,
        ),
        child: Text(
          source.name,
          style: TextStyle(
            fontSize: 16.0,
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
            color: isEven ? Theme.of(context).colorScheme.primaryContainer.withAlpha(150) : Theme.of(context).colorScheme.secondaryContainer.withAlpha(150),
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
      Center(child: Text('啥啥词库都没导入，你学个啥呢？\n自己去 设置 -> 数据设置 -> 导入词库', style: TextStyle(fontSize: 24.0, color: Colors.redAccent),))
    );
  }
  context.read<Global>().uiLogger.info("课程选择列表构建完成");
  return widgetList;
}

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
                return CircularProgressIndicator();
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
      curve: StaticsVar.curve,
      reverseCurve: StaticsVar.curve
    )
  );
}

/// 弹出详解页面
void viewAnswer(BuildContext context, WordItem wordData) async {
  context.read<Global>().uiLogger.info("弹出详解页面");
  MediaQueryData mediaQuery = MediaQuery.of(context);
  showBottomSheet(
    context: context, 
    shape: RoundedSuperellipseBorder(side: BorderSide(width: 1.0, color: Theme.of(context).colorScheme.onSurface), borderRadius: StaticsVar.br),
    enableDrag: true,
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onPrimary,
          borderRadius: StaticsVar.br,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WordCard(word: wordData, useMask: false),
            Button(
              onPressed: () => Navigator.pop(context), 
              size:  Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.1),
              child: Text("我知道了"),
            )
          ],
        ),
      );
    },
  );
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
    late TextStyle actualStyle;
    if(style == null) {
      actualStyle = TextStyle(
        fontSize: 18.0,
      );
    } else {
      actualStyle = style!;
    }
    return Container(
      width: size?.width,
      height: size?.height,
      margin: EdgeInsets.all(16.0),
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
        borderRadius: StaticsVar.br,
      ),
      child: (animated)
        ? TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: text.length.toDouble()), 
          duration: Durations.long4,
          curve: StaticsVar.curve,
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
            child: Text(
              options[i],
              style: TextStyle(fontSize: 36, fontFamily:options[i].isArabic() ? context.read<Global>().arFont : null),
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
  bool isChoosed = false;

  @override
  Widget build(BuildContext context) {
    color ??= widget.cl ?? Theme.of(context).colorScheme.primaryContainer;
    return AnimatedContainer(
      margin: EdgeInsets.all(8.0),
      duration: widget.isAnimated ? Durations.medium4 : Duration(),
      curve: StaticsVar.curve,
      decoration: BoxDecoration(
        color: color,
        borderRadius: StaticsVar.br,
      ),
      child: Button(
        onPressed: () {
          setState(() {
            if(isChoosed) return;
            isChoosed = true;
            bool? ans = widget.chose(widget.index);
            if(ans != null) {
              if(widget.isAnimated) {
                color = Colors.amber;
                Future.delayed(Durations.medium4, (){
                  setState(() {
                    if(ans) {
                      color = Colors.greenAccent;
                    } else {
                      color = Colors.redAccent;
                    }
                  });
                });
              } else {
                if(ans) {
                  color = Colors.greenAccent;
                } else {
                  color = Colors.redAccent;
                }
              }
            } else {
              setState(() {
                color = Theme.of(context).colorScheme.primaryContainer;
              });
            }
          });
        },
        size: Size(widget.width ?? 200, widget.height ?? 50),
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        child: widget.child,
      ),
    );
  }
}

/// 汇总当前词库中所有单词的分类标签
/// 
/// 返回顺序稳定：先按 [preferredOrder] 中出现的分级/常用分类排列，
/// 其余分类按首次出现的顺序追加。不硬编码任何分类含义，仅用于筛选器展示排序。
List<String> collectAllCategories() {
  const List<String> preferredOrder = ["二级", "四级", "六级", "八级", "补充", "常用词", "生僻词", "短语"];
  final Set<String> categories = <String>{};
  for(WordItem word in AppData().wordData.words) {
    categories.addAll(word.categories);
  }
  final List<String> ordered = [];
  for(String category in preferredOrder) {
    if(categories.remove(category)) ordered.add(category);
  }
  ordered.addAll(categories);
  return ordered;
}

/// 判断单词是否满足分类筛选
/// 
/// 多选时采用 AND 语义：单词需包含 [selected] 中的全部分类；
/// [selected] 为空表示不进行筛选。
bool wordMatchesCategories(WordItem word, Set<String> selected) {
  if(selected.isEmpty) return true;
  return selected.every((String category) => word.categories.contains(category));
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
            color: Theme.of(context).colorScheme.secondaryContainer.withAlpha(180),
            borderRadius: StaticsVar.br,
          ),
          child: Text(
            category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: dense ? 10.0 : 12.0,
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
        color: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
        borderRadius: StaticsVar.br,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_outlined, size: 18.0),
              SizedBox(width: 4.0),
              Text("分类筛选", style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)),
              Spacer(),
              if(selected.isNotEmpty) TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size(0.0, 0.0),
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => onChanged(<String>{}),
                child: Text("清除筛选", style: TextStyle(fontSize: 12.0)),
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
                  style: TextStyle(
                    fontSize: 12.0,
                    color: isSelected ? Theme.of(context).colorScheme.onSecondaryContainer : null,
                  ),
                ),
                selected: isSelected,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                selectedColor: Theme.of(context).colorScheme.secondaryContainer.withAlpha(200),
                backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(120),
                shape: RoundedRectangleBorder(
                  borderRadius: StaticsVar.br,
                  side: BorderSide(
                    color: isSelected
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.outline.withAlpha(120),
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

/// 单词卡片组件
/// 
/// 显示一个阿语单词在上，下有中文解释的卡片
/// 
/// [word] :单词数据 参考Global.wordData中单个单词储存的数据结构
/// 
/// [width] :限定宽度，默认全屏
/// 
/// [height] :限定高度，默认自动
/// 
/// [useMask] :是否显示高斯遮罩
/// 
/// [compact] :紧凑模式，用于词汇总览网格与查找结果等固定尺寸单元。
/// 保持紧凑布局，仅在分类非空时追加一行小标签，绝不溢出；
/// 为false（默认）时展示可滚动的“词形信息”区域，适合详解弹窗与学习页面
class WordCard extends StatelessWidget {
  final WordItem word;
  final double? width;
  final double? height;
  final bool useMask;
  final bool compact;
  const WordCard({super.key, required this.word, this.width, this.height, this.useMask = true, this.compact = false});

  /// 词性的中文展示（未知值原样显示）
  String _posLabel(String pos) {
    switch(pos) {
      case "Nominals": return "名词";
      case "Verbs": return "动词";
      case "Phrases and Clauses": return "短语与从句";
      case "Particles": return "虚词";
      case "Adverbial Expressions": return "状语表达";
      default: return pos;
    }
  }

  /// 卡片内的双栏信息行：左侧标签容器 + 右侧内容，样式与原卡片保持一致
  Widget _infoRow(
    BuildContext context, {
    required String label,
    required String value,
    required double labelWidth,
    required Color labelColor,
    double? height,
    double labelFontSize = 16.0,
    double valueFontSize = 18.0,
    bool isArabicValue = false,
    bool expandValue = false,
    BorderRadius? labelRadius,
  }) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: labelWidth,
            decoration: BoxDecoration(
              color: labelColor,
              borderRadius: labelRadius,
            ),
            alignment: Alignment.center,
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(label, style: TextStyle(fontSize: labelFontSize)),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ClipRect(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: expandValue
                    ? Text(
                        value,
                        style: TextStyle(fontSize: valueFontSize, fontFamily: isArabicValue ? context.read<Global>().arFont : null),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: TextStyle(fontSize: valueFontSize, fontFamily: isArabicValue ? context.read<Global>().arFont : null),
                          textAlign: TextAlign.center,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 紧凑模式内容：固定高度内按比例分配信息行，分类标签行超出时被裁剪，绝不溢出
  Widget _buildCompactBody(BuildContext context, double useWidth, double useHeight) {
    final Color labelOdd = Theme.of(context).colorScheme.onSecondary.withAlpha(150);
    final Color labelEven = Theme.of(context).colorScheme.onPrimary.withAlpha(150);
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _infoRow(context,
            label: "中文", value: word.chinese, labelWidth: useWidth * 0.2,
            labelColor: labelOdd, labelFontSize: 16.0, valueFontSize: 24.0),
        ),
        const Divider(height: 0),
        Expanded(
          flex: 6,
          child: _infoRow(context,
            label: "解释", value: word.explanation, labelWidth: useWidth * 0.2,
            labelColor: labelEven, labelFontSize: 18.0, valueFontSize: 16.0, expandValue: true),
        ),
        const Divider(height: 0),
        if(word.categories.isNotEmpty) ...[
          Expanded(
            flex: 2,
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.0),
                  child: CategoryChips(categories: word.categories, dense: true),
                ),
              ),
            ),
          ),
          const Divider(height: 0),
        ],
        Expanded(
          flex: 3,
          child: _infoRow(context,
            label: "归属课程", value: word.className, labelWidth: useWidth * 0.2,
            labelColor: labelOdd, valueFontSize: 18.0,
            labelRadius: BorderRadius.only(bottomLeft: Radius.circular(25.0))),
        ),
      ],
    );
  }

  /// 详情模式内容：中文、解释、词形信息（可滚动）、归属课程
  Widget _buildDetailedBody(BuildContext context, double useWidth, double useHeight) {
    final Color labelOdd = Theme.of(context).colorScheme.onSecondary.withAlpha(150);
    final Color labelEven = Theme.of(context).colorScheme.onPrimary.withAlpha(150);
    final double labelWidth = useWidth * 0.2;
    final double rowHeight = useHeight * 0.12;
    final List<Widget> morphRows = [];
    void addMorphRow(Widget row) {
      if(morphRows.isNotEmpty) morphRows.add(const Divider(height: 0));
      morphRows.add(row);
    }
    if(word.root.isNotEmpty) {
      addMorphRow(_infoRow(context,
        label: "词根", value: word.root, labelWidth: labelWidth, height: rowHeight,
        labelColor: labelOdd, labelFontSize: 14.0, valueFontSize: 18.0, isArabicValue: true));
    }
    if(word.pos.isNotEmpty) {
      addMorphRow(_infoRow(context,
        label: "词性", value: _posLabel(word.pos), labelWidth: labelWidth, height: rowHeight,
        labelColor: labelEven, labelFontSize: 14.0, valueFontSize: 16.0));
    }
    if(word.plural.isNotEmpty) {
      addMorphRow(_infoRow(context,
        label: "复数", value: word.plural, labelWidth: labelWidth, height: rowHeight,
        labelColor: labelOdd, labelFontSize: 14.0, valueFontSize: 18.0, isArabicValue: true));
    }
    if(word.gender != null) {
      addMorphRow(_infoRow(context,
        label: "阴阳性", value: word.gender! ? "阳性" : "阴性", labelWidth: labelWidth, height: rowHeight,
        labelColor: labelEven, labelFontSize: 14.0, valueFontSize: 16.0));
    }
    if(word.present.isNotEmpty) {
      addMorphRow(_infoRow(context,
        label: "现在式", value: word.present, labelWidth: labelWidth, height: rowHeight,
        labelColor: labelOdd, labelFontSize: 14.0, valueFontSize: 18.0, isArabicValue: true));
    }
    if(word.masdar.isNotEmpty) {
      addMorphRow(_infoRow(context,
        label: "动名词", value: word.masdar, labelWidth: labelWidth, height: rowHeight,
        labelColor: labelEven, labelFontSize: 14.0, valueFontSize: 18.0, isArabicValue: true));
    }
    if(word.categories.isNotEmpty) {
      addMorphRow(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: labelWidth,
                padding: EdgeInsets.symmetric(vertical: 4.0),
                decoration: BoxDecoration(color: labelOdd),
                alignment: Alignment.center,
                child: Text("类别", style: TextStyle(fontSize: 14.0)),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                  child: CategoryChips(categories: word.categories),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        _infoRow(context,
          label: "中文", value: word.chinese, labelWidth: labelWidth, height: useHeight * 0.14,
          labelColor: labelOdd, labelFontSize: 16.0, valueFontSize: 24.0),
        const Divider(height: 0),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _infoRow(context,
                  label: "解释", value: word.explanation, labelWidth: labelWidth, height: useHeight * 0.24,
                  labelColor: labelEven, labelFontSize: 18.0, valueFontSize: 16.0, expandValue: true),
                if(morphRows.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    height: useHeight * 0.1,
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    color: Theme.of(context).colorScheme.secondaryContainer.withAlpha(120),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Icon(Icons.auto_stories_outlined, size: 16.0),
                        SizedBox(width: 4.0),
                        Text("词形信息", style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  ...morphRows,
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 0),
        _infoRow(context,
          label: "归属课程", value: word.className, labelWidth: labelWidth, height: useHeight * 0.14,
          labelColor: labelOdd, labelFontSize: 16.0, valueFontSize: 18.0,
          labelRadius: BorderRadius.only(bottomLeft: Radius.circular(25.0))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    bool hide = useMask;
    double useWidth = width ?? mediaQuery.size.width * 0.9;
    double useHeight = height ?? mediaQuery.size.height * 0.5;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Button(
          size: Size(useWidth, useHeight * 0.3),
          icon: const Icon(Icons.volume_up, size: 24.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(top: Radius.circular(25.0))),
          onPressed: (){
            playTextToSpeech(word.arabic);
          },
          child: Expanded(child: FittedBox(fit: BoxFit.scaleDown ,child: Text(word.arabic, style: TextStyle(fontSize: 64.0, fontFamily: context.read<Global>().arFont)))),
        ),
        Stack(
          children: [
            Container(
              width: useWidth,
              height: useHeight * 0.6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onInverseSurface,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(25.0)),
              ),
              child: compact
                ? _buildCompactBody(context, useWidth, useHeight)
                : _buildDetailedBody(context, useWidth, useHeight)
            ),
            StatefulBuilder(
              builder: (context, setLocalState) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 1.0,
                    end: hide ? 1.0 : 0.0
                  ),
                  duration: Durations.extralong2,
                  curve: StaticsVar.curve,
                  builder: (context, value, child) {
                    return ClipRRect(
                      borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0)),
                      child: value == 0.0 ? null : BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15.0 * value,sigmaY: 15.0 * value),
                        enabled: true,
                        child: Button(
                          size: Size(useWidth, useHeight * 0.6),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0))),
                          onPressed: (){
                            setLocalState(() {
                              hide = false;
                            },);
                          }, 
                          child: hide ? Text("点此查看释义") : SizedBox()
                        ),
                      ),
                    );
                  },
                );
              }
            )
          ],
        )
      ],
    );
  }
}

class Button extends StatelessWidget {
  final Widget? child;
  final void Function()? onPressed;
  final Widget? icon;
  final AxisDirection iconDirection;
  final Size? size;
  final Color? backgroundColor;
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
    this.shape,
    this.size,
    this.shadowColor,
    this.iconDirection = AxisDirection.left,
    this.padding = const EdgeInsetsGeometry.all(16.0),
    this.alignment = MainAxisAlignment.spaceEvenly
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.onPrimary,
        shadowColor: shadowColor,
        fixedSize: size,
        padding: padding,
        shape: shape ?? RoundedRectangleBorder(borderRadius: StaticsVar.br)
      ),
      clipBehavior: Clip.hardEdge,
      onPressed: onPressed,
      child: icon==null 
          ? child
          : [AxisDirection.left, AxisDirection.right].contains(iconDirection)
          ? Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: alignment,
            children: [
              if(iconDirection == AxisDirection.left) Padding(
                padding: const EdgeInsets.all(8.0),
                child: icon!,
              ),
              ?child,
              if(iconDirection == AxisDirection.right) Padding(
                padding: const EdgeInsets.all(8.0),
                child: icon!,
              )
            ],
          )
          : Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: alignment,
            children: [
              if(iconDirection == AxisDirection.up) Padding(
                padding: const EdgeInsets.all(8.0),
                child: icon!,
              ),
              ?child,
              if(iconDirection == AxisDirection.down) Padding(
                padding: const EdgeInsets.all(8.0),
                child: icon!,
              )
            ],
          )
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
      body: Column(
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
      ),
    );
  }
}

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
/// [allowAnitmation] :是否显示动画，即按钮变黄后变红
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
  bool choosed = false;
  bool playing = false;

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建选择题页面: 主单词: ${widget.mainWord};选项: ${widget.choices}");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    int showingMode = widget.bottonLayout;
    // showingMode 0: 1 Row, 1: 2 Rows, 2: 4 Rows
    if(showingMode == -1){
      context.read<Global>().uiLogger.fine("未指定布局，开始计算");
      showingMode = calculateButtonBoxLayout(widget.choices, mediaQuery.size.width);
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
                    child: Expanded(child: FittedBox(fit: BoxFit.contain ,child: Text(widget.mainWord, style: TextStyle(fontSize: 72.0, fontFamily: widget.mainWord.isArabic() ? context.read<Global>().arFont : null)))),
                  );
                }
              ),
            ),
            SizedBox(height: mediaQuery.size.height *0.01),
            ChooseButtons(
              options: widget.choices, 
              settingShowingMode: showingMode,
              onSelected: (value) {
                if(widget.allowMutipleSelect) return widget.onSelected(value);
                if(choosed) {
                  if(widget.onDisAllowMutipleSelect != null) return widget.onDisAllowMutipleSelect!(value);
                  showSnackBar(context, "该页面不允许多次选择");
                  return null;
                } else {
                  choosed = true;
                  return widget.onSelected(value);
                }
              }, 
              isShowAnimation: widget.allowAnitmation
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
          WordCard(word: word),
          Expanded(child: SizedBox()),
          ?bottomWidget,
          SizedBox(height: mediaQuery.size.height * 0.05),
        ],
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
  late Color cl;

  void check(String value) {
    setState(() {
      isChecked = true;
      if(widget.onCheck(value)) {
        cl = Colors.greenAccent;
      } else {
        cl = Colors.redAccent;
      }
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
                begin: Theme.of(context).colorScheme.onPrimaryFixed,
                end: isChecked ? cl.withAlpha(180) : Theme.of(context).colorScheme.onPrimaryFixed
              ),
              duration: Durations.medium2,
              curve: StaticsVar.curve,
              builder: (context, value, child) {
                return TextField(
                  textDirection: TextDirection.rtl,
                  autocorrect: false,
                  controller: controller,
                  expands: false,
                  maxLines: 1,
                  style: TextStyle(fontFamily: context.read<Global>().arFont, fontSize: 28),
                  keyboardType: TextInputType.name,
                  readOnly: isChecked,
                  decoration: InputDecoration(
                    labelText: "阿拉伯语单词",
                    border: OutlineInputBorder(
                      borderRadius: StaticsVar.br,
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
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
      showingMode = calculateButtonBoxLayout(widget.choices, mediaQuery.size.width);
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
              onSelected: (value) {
                if(widget.allowMutipleSelect) return widget.onSelected(value);
                if(choosed) {
                  if(widget.onDisAllowMutipleSelect != null) return widget.onDisAllowMutipleSelect!(value);
                  showSnackBar(context, "该页面不允许多次选择");
                  return null;
                } else {
                  choosed = true;
                  return widget.onSelected(value);
                }
              }, 
              isShowAnimation: widget.allowAnitmation
            ),
            TextButton(
              onPressed: (){
                choosed = true;
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
        backgroundColor: Theme.of(
          context,
        ).colorScheme.onPrimary.withAlpha(150),
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
                style: TextStyle(fontSize: 12.0, color: Colors.grey),
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
          color: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          borderRadius: BorderRadius.vertical(top: Radius.circular(index == 0 ? 25.0 : 5.0), bottom: Radius.circular(index == children.length-1 ? 25.0 : 5.0)),
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
