// 课程选择（原 widgets/kit.dart 拆分）。
// 承载弹出课程选择 [popSelectClasses]、课程列表 [classesSelectionList]
// 与选择页 [ClassSelectPage]。
// 由 widgets/kit.dart 统一 export，调用方仍从 kit.dart 导入。

import 'dart:convert';

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/models/dict.dart' show ClassItem, SourceItem;
import 'package:arabic_learning/models/reading.dart' show ClassSelection;
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/words.dart' show collectAllCategories;
import 'package:arabic_learning/widgets/app_button.dart' show Button;
import 'package:arabic_learning/widgets/category_chips.dart' show CategoryFilter;
import 'package:arabic_learning/widgets/overlays.dart' show showSnackBar;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 弹出课程选择（ClassSelectPage）
/// 
/// [context] :Widget树上的context
/// 
/// [withCache] :是否使用缓存，若启用则会
/// 1.从缓存中加载已选择的课程 
/// 2.将此次课程选择加入持久化的缓存中方便下次直接开始。 
/// 
/// [withCategoryFilter] :是否展示标签筛选区（多选，或逻辑），
/// 仅当词库存在标签时显示；默认关闭以保持既有调用方行为不变。
/// 
/// 返回值: [ClassSelection] 包含所选课程、是否计入复习系统以及所选标签集合
Future<ClassSelection> popSelectClasses(BuildContext context, {bool withCache = false, bool withReviewChoose = true, bool withCategoryFilter = false, List<SourceItem>? forceSelectRange}) async {
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
    isScrollControlled: true,
    enableDrag: true,
    builder: (BuildContext context) {
      return ClassSelectPage(beforeSelectedClasses: beforeSelectedClasses, withReviewChoose: withReviewChoose, withCategoryFilter: withCategoryFilter);
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
        Padding(
          padding: EdgeInsets.all(2),
          child: Material(
            color: isEven ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
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

// Page Widget 可复用的页面Widget

/// 课程选择页面
/// 
/// 若要直接获取选择数据，请使用Route或者push调用，在其返回值中有[[词库键, 课程键]]的列表返回
/// 
/// [beforeSelectedClasses] :已经勾选的课程，可以自定义，但一般搭配缓存使用
/// 
/// [withCategoryFilter] :是否展示标签筛选区（多选，或逻辑）。
/// 仅在 [collectAllCategories] 非空时渲染，筛选结果写入
/// [ClassSelection.selectedCategories] 随返回值一起回传。
/// 
/// 注意：如果你要进行课程选择，请先考虑 [popSelectClasses] 函数，这是一个已经基本成熟的实现
class ClassSelectPage extends StatelessWidget { 
  final List<ClassItem> beforeSelectedClasses;
  final bool withReviewChoose;
  final bool withCategoryFilter;
  final List<SourceItem>? forceSelectRange;
  const ClassSelectPage({super.key, this.beforeSelectedClasses = const [], this.withReviewChoose = false, this.withCategoryFilter = false, this.forceSelectRange});
  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    // 仅在需要筛选时汇总标签，避免无谓遍历；词库无标签时该区不渲染。
    final List<String> availableCategories =
        withCategoryFilter ? collectAllCategories() : const <String>[];
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
          // 标签筛选区：固定在课程列表下方、确认按钮上方，始终可见。
          // 用 ConstrainedBox 限高（非 flex 子项，不与上方 ListView 争抢空间），
          // 标签内容超出时才内部滚动，避免底部弹窗溢出。
          if(withCategoryFilter && availableCategories.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.3),
              child: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setLocalState) {
                    return CategoryFilter(
                      available: availableCategories,
                      selected: classSelection.selectedCategories,
                      title: "标签筛选",
                      description: "仅学习所选标签中任一标签的单词（可多选）",
                      onChanged: (Set<String> value) {
                        setLocalState(() {
                          classSelection.selectedCategories = value;
                        });
                      },
                    );
                  },
                ),
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
