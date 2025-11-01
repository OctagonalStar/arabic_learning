import 'dart:convert';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<List<List<String>>> popSelectClasses(BuildContext context, {bool withCache = false}) async {
  late final List<List<String>> beforeSelectedClasses;
  if(withCache) {
    final String tpcPrefs = context.read<Global>().prefs.getString("tempConfig") ?? jsonEncode(StaticsVar.tempConfig);
    beforeSelectedClasses = (jsonDecode(tpcPrefs)["SelectedClasses"] as List)
        .cast<List>()
        .map((e) => e.cast<String>().toList())
        .toList();
  } else {
    beforeSelectedClasses = [];
  }
  List<List<String>>? selectedClasses = await showModalBottomSheet<List<List<String>>>(
    context: context,
    // 假装圆角... :)
    shape: RoundedSuperellipseBorder(side: BorderSide(width: 1.0, color: Theme.of(context).colorScheme.onSurface), borderRadius: StaticsVar.br),
    isDismissible: false,
    isScrollControlled: context.read<Global>().isWideScreen,
    enableDrag: true,
    builder: (BuildContext context) {
      return ClassSelector(beforeSelectedClasses: beforeSelectedClasses);
    }
  );
  if(withCache && selectedClasses != null && context.mounted) {
    final String tpcPrefs = context.read<Global>().prefs.getString("tempConfig") ?? jsonEncode(StaticsVar.tempConfig);
    Map<String, dynamic> tpcMap = jsonDecode(tpcPrefs);
    tpcMap["SelectedClasses"] = selectedClasses;
    context.read<Global>().prefs.setString("tempConfig", jsonEncode(tpcMap));
  }
  return selectedClasses ?? [];
}

class ClassSelector extends StatelessWidget { 
  final List<List<String>> beforeSelectedClasses;
  const ClassSelector({super.key, this.beforeSelectedClasses = const []});
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    List<List<String>> selectedClass = beforeSelectedClasses.toList();
    void addClass(List<String> classInfo) {
      selectedClass.add(classInfo);
    }
    void removeClass(List<String> classInfo) {
      selectedClass.removeWhere((e) => e[0] == classInfo[0] && e[1] == classInfo[1]);
    }
    bool isClassSelected(List<String> classInfo) {
      return selectedClass.any((e) => e[0] == classInfo[0] && e[1] == classInfo[1]);
    }
    void onClassChanged(List<String> classInfo) {
      if(isClassSelected(classInfo)) {
        removeClass(classInfo);
      } else {
        addClass(classInfo);
      }
    }
    // 和监听器脱钩...
    // if(!context.watch<ClassSelectModel>().initialized) {
    //   return Scaffold(
    //     body: Center(
    //       child: CircularProgressIndicator(),
    //     ),
    //   );
    // }

    return Scaffold(
      appBar: AppBar(
        title: Text('选择特定课程单词'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: classesSelectionList(context, mediaQuery, onClassChanged, isClassSelected)
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              fixedSize: Size(mediaQuery.size.width, mediaQuery.size.height * 0.05),
              shape: ContinuousRectangleBorder(borderRadius: StaticsVar.br),
            ),
            child: Text('确认'),
            onPressed: () {
              Navigator.pop(context, selectedClass);
            },
          ),
        ],
      ),
    );
  }
}

List<Widget> classesSelectionList(BuildContext context, MediaQueryData mediaQuery, Function (List<String>) onChanged, bool Function (List<String>) isClassSelected) {
  Map<String, dynamic> wordData = context.read<Global>().wordData;
  List<Widget> widgetList = [];
  for (String sourceName in wordData["Classes"].keys) {
    widgetList.add(
      Container(
        margin: EdgeInsets.all(16.0),
        padding: EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onPrimary,
          borderRadius: StaticsVar.br,
        ),
        child: Text(
          sourceName,
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
    bool isEven = true;
    for(String className in wordData["Classes"][sourceName].keys){
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
                title: Text(className),
                value: isClassSelected([sourceName, className]),
                onChanged: (value) {
                  setLocalState(() {
                    onChanged([sourceName, className]);
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
    widgetList.add(
      Center(child: Text('啥啥词库都没导入，你学个啥呢？\n自己去 设置 -> 数据设置 -> 导入词库', style: TextStyle(fontSize: 24.0, color: Colors.redAccent),))
    );
  }
  return widgetList;
}


void alart(context, String e, {Function? onConfirmed}) {
  showDialog(
    context: context, 
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("提示"),
        content: Text(e),
        actions: [
          TextButton(
            child: Text("确定"),
            onPressed: () {
              Navigator.of(context).pop();
              if(onConfirmed != null) onConfirmed();
            },
          )
        ],
      );
    }
  );
}


class TextContainer extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool? selectable;
  final Size? size;
  final TextAlign? textAlign;
  const TextContainer({super.key, 
                      required this.text, 
                      this.style,
                      this.size,
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
          color: Theme.of(context).colorScheme.onPrimary,
          borderRadius: StaticsVar.br,
        ),
        child: (selectable??false) 
                ? SelectableText(text,style: actualStyle, textAlign: textAlign,) 
                : Text(text,style: actualStyle, textAlign: textAlign),
    );
  }
}

class InDevelopingPage extends StatelessWidget {
  const InDevelopingPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("开发中"),
      ),
      body: Center(
        child: FittedBox(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.build,
                size: 100.0,
              ),
              Text(
                "该页面还在开发中...",
                style: TextStyle(
                  fontSize: 40.0,
                ),
              ),
              Text(
                "日子要一天一天过，单词要一个一个背...\n高数要一课一课学，阿语要一句一句记...\n牙膏要一点一点挤，代码要一行一行敲...",
                style: TextStyle(
                  fontSize: 18.0,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class ChooseButtons extends StatelessWidget {
  final List<String> options;
  final bool? Function(int) onSelected;
  final Widget? belowTip;
  final bool isShowAnimation;
  final int settingShowingMode; // 0: Auto, 1: 1 Row, 2: 2 Rows, 3: 4 Rows

  const ChooseButtons({super.key, required this.options, required this.onSelected, this.belowTip, this.isShowAnimation = false, this.settingShowingMode = 0});
  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    int showingMode = settingShowingMode;
    // showingMode 0: 1 Row, 1: 2 Rows, 2: 4 Rows
    if(showingMode == 0) {
      bool overFlowPossible = false;
      for(int i = 1; i < 4; i++) {
        if(options[i].length * 16 > mediaQuery.size.width * (context.read<Global>().isWideScreen ? 0.21 : 0.8)){
          overFlowPossible = true;
          break;
        }
      }
      if (context.read<Global>().isWideScreen) {
        if(overFlowPossible){
          showingMode = 1;
        } else {
          showingMode = 0;
        }
      } else {
        if(overFlowPossible){
          showingMode = 2;
        } else {
          showingMode = 1;
        }
      }
    }
    List<Widget> buttonWidgets = [];
    for(int i = 0; i < options.length; i++) {
      buttonWidgets.add(
        ChooseButtonBox(
          index: i,
          chose: onSelected,
          width: showingMode == 0 ? mediaQuery.size.width * 0.2 : showingMode == 1 ? mediaQuery.size.width * 0.45 : mediaQuery.size.width * 0.85,
          height: mediaQuery.size.height * 0.15,
          isAnimated: isShowAnimation,
          child: FittedBox(
            child: Text(
              options[i],
              style: TextStyle(fontSize: 36),
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        if(showingMode == 0) Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: buttonWidgets,
        ),
        if(showingMode == 1) Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: buttonWidgets.sublist(0, 2),
            ),
            SizedBox(height: mediaQuery.size.height * 0.02),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: buttonWidgets.sublist(2),
            ),
          ],
        ),
        if(showingMode == 2) ...buttonWidgets,
        SizedBox(height: mediaQuery.size.height * 0.02),
        if(belowTip != null) belowTip!,
      ],
    );
  }
}

class ChooseButtonBox extends StatefulWidget {
    final int index;
  final bool? Function(int) chose;
  final Widget child;
  final Color? cl;
  final double? width;
  final double? height;
  final bool? isAnimated;
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
  @override
  Widget build(BuildContext context) {
    color ??= widget.cl ?? Theme.of(context).colorScheme.primaryContainer;
    return AnimatedContainer(
      margin: EdgeInsets.all(8.0),
      duration: Duration(milliseconds: widget.isAnimated == true ? 500 : 0),
      curve: StaticsVar.curve,
      decoration: BoxDecoration(
        color: color,
        borderRadius: StaticsVar.br,
      ),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            bool? ans = widget.chose(widget.index);
            if(ans != null) {
              if(ans) {
                color = Colors.greenAccent;
              } else {
                color = Colors.redAccent;
              }
            }
          });
        },
        style: ElevatedButton.styleFrom(
          fixedSize: Size(widget.width?? 200, widget.height?? 50),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: StaticsVar.br,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}