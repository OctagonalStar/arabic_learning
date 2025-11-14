import 'dart:convert';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'utili.dart';

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
    shape: RoundedSuperellipseBorder(side: BorderSide(width: 1.0, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)), borderRadius: StaticsVar.br),
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
              fixedSize: Size(mediaQuery.size.width, mediaQuery.size.height * 0.08),
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
          color: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
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
            color: isEven ? Theme.of(context).colorScheme.primaryContainer.withAlpha(150) : Theme.of(context).colorScheme.secondaryContainer.withAlpha(150),
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

void alart(context, String e, {Function? onConfirmed, Duration delayConfirm = const Duration(milliseconds: 0)}) {
  showDialog(
    context: context, 
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("提示"),
        content: Text(e),
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
          color: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
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
  final bool isShowAnimation;
  final bool allowMutipleSelect;
  final int settingShowingMode; // -1: Auto, 0: 1 Row, 1: 2 Rows, 2: 4 Rows

  const ChooseButtons({super.key, 
                      required this.options, 
                      required this.onSelected, 
                      this.allowMutipleSelect = false,
                      this.isShowAnimation = false, 
                      this.settingShowingMode = -1});
  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    int showingMode = settingShowingMode;
    // showingMode 0: 1 Row, 1: 2 Rows, 2: 4 Rows
    if(showingMode == -1) {
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
          height: showingMode == 0 ? mediaQuery.size.height * 0.15 : showingMode == 1 ? mediaQuery.size.height * 0.12 : mediaQuery.size.height * 0.11,
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
            // SizedBox(height: mediaQuery.size.height * 0.01),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: buttonWidgets.sublist(2),
            ),
          ],
        ),
        if(showingMode == 2) ...buttonWidgets,
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
  @override
  Widget build(BuildContext context) {
    color ??= widget.cl ?? Theme.of(context).colorScheme.primaryContainer.withAlpha(150);
    return AnimatedContainer(
      margin: EdgeInsets.all(8.0),
      duration: Duration(milliseconds: widget.isAnimated ? 500 : 0),
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
              color = Colors.amber;
              Future.delayed(Duration(milliseconds: widget.isAnimated ? 500 : 0), (){
                setState(() {
                  if(ans) {
                    color = Colors.greenAccent;
                  } else {
                    color = Colors.redAccent;
                  }
                });
              });
            } else {
              color = Theme.of(context).colorScheme.onPrimary.withAlpha(150);
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

class ChoiceQuestions extends StatefulWidget {
  final String mainWord;
  final List<String> choices;
  final bool? Function(int) onSelected;
  final String? hint;
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
                        this.bottomWidget, 
                        this.onDisAllowMutipleSelect,
                        this.bottonLayout = 0,
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
    MediaQueryData mediaQuery = MediaQuery.of(context);
    late final bool overFlowPossible;
    int showingMode = widget.bottonLayout;
    // showingMode 0: 1 Row, 1: 2 Rows, 2: 4 Rows
    if(showingMode == -1){
      for(int i = 1; i < 5; i++) {
        if(widget.choices[i].length * 16 > mediaQuery.size.width * (context.read<Global>().isWideScreen ? 0.21 : 0.8)){
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
    return Material(
      child: Center(
        child: Column(
          children: [
            if(widget.hint!=null) TextContainer(text: widget.hint!),
            Expanded(
              child: StatefulBuilder(
                builder: (context, setLocalState) {
                  return ElevatedButton.icon(
                    icon: Icon(widget.allowAudio ? (playing ? Icons.multitrack_audio : Icons.volume_up) : Icons.short_text, size: 24.0),
                    label: FittedBox(fit: BoxFit.contain ,child: Text(widget.mainWord, style: TextStyle(fontSize: 72.0, fontFamily: widget.mainWord.isArabic() ? context.read<Global>().arFont : null))),
                    style: ElevatedButton.styleFrom(
                      fixedSize: Size.fromWidth(mediaQuery.size.width * 0.8),
                      shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
                    ),
                    onPressed: () async {
                      if (playing || !widget.allowAudio) {
                        return;
                      }
                      setLocalState(() {
                        playing = true;
                      });
                      late List<dynamic> temp;
                      temp = await playTextToSpeech(widget.mainWord, context);
                      if(!temp[0] && context.mounted) {
                        alart(context, temp[1]);
                      }
                      setLocalState(() {
                        playing = false;
                      });
                    },
                  );
                }
              ),
            ),
            SizedBox(height: mediaQuery.size.height *0.01),
            ChooseButtons(
              options: widget.choices, 
              onSelected: (value) {
                if(widget.allowMutipleSelect) return widget.onSelected(value);
                if(choosed) {
                  if(widget.onDisAllowMutipleSelect != null) return widget.onDisAllowMutipleSelect!(value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('该页面不允许多次选择'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  return null;
                } else {
                  choosed = true;
                  return widget.onSelected(value);
                }
              }, 
              allowMutipleSelect: widget.allowMutipleSelect, 
              isShowAnimation: widget.allowAnitmation
            ),
            SizedBox(height: mediaQuery.size.height *0.01),
            if(widget.bottomWidget != null) widget.bottomWidget!,
            SizedBox(height: mediaQuery.size.height *0.05),
          ],
        ),
      ),
    );
  }
}

class WordCard extends StatelessWidget {
  final Map<String, dynamic> word;
  final double? width;
  final double? height;
  const WordCard({super.key, required this.word, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Container(
      margin: const EdgeInsets.all(16.0),
      //padding: const EdgeInsets.all(16.0),
      width: mediaQuery.size.width * 0.9,
      height: mediaQuery.size.height * 0.5,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onInverseSurface.withAlpha(150),
        borderRadius: StaticsVar.br,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              fixedSize: Size(mediaQuery.size.width * 0.9, mediaQuery.size.height * 0.2),
              backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
              shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
              padding: const EdgeInsets.all(16.0),
            ),
            icon: const Icon(Icons.volume_up, size: 24.0),
            label: FittedBox(child: Text(word["arabic"], style: TextStyle(fontSize: 64.0, fontFamily: context.read<Global>().arFont))),
            onPressed: (){
              playTextToSpeech(word["arabic"], context);
            },
          ),
          Text(
            ' 中文：${word["chinese"]}\n 示例：${word["explanation"]}\n 归属课程：${word["subClass"]}',
            style: TextStyle(fontSize: mediaQuery.size.height * 0.025),
          )
        ],
      )
    );
  }
}