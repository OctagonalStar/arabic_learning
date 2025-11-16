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
class WordCard extends StatelessWidget {
  final Map<String, dynamic> word;
  final double? width;
  final double? height;
  final bool useMask;
  const WordCard({super.key, required this.word, this.width, this.height, this.useMask = true});

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    bool hide = useMask;
    return Container(
      margin: const EdgeInsets.all(16.0),
      //padding: const EdgeInsets.all(16.0),
      width: width ?? (mediaQuery.size.width * 0.9),
      height: height ?? (mediaQuery.size.height * 0.5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onInverseSurface.withAlpha(150),
        borderRadius: StaticsVar.br,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              fixedSize: Size(width ?? (mediaQuery.size.width * 0.9), height == null ? (mediaQuery.size.height * 0.2) : height! * 0.4),
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
          Stack(
            children: [
              Center(
                child: Text(' 中文：${word["chinese"]}\n 示例：${word["explanation"]}\n 归属课程：${word["subClass"]}',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.left,
                ),
              ),
              StatefulBuilder(
                builder: (context, setLocalState) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 1.0,
                      end: hide ? 1.0 : 0.0
                    ),
                    duration: Duration(milliseconds: 500),
                    curve: StaticsVar.curve,
                    builder: (context, value, child) {
                      return ClipRRect(
                        borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0)),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10.0 * value,sigmaY: 10.0 * value),
                          enabled: true,
                          child: value == 0.0 ? null : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              fixedSize: Size(width ?? (mediaQuery.size.width * 0.9), height == null ? (mediaQuery.size.height * 0.3) : height! * 0.6),
                              backgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0)))
                            ),
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
  final List<List<String>> beforeSelectedClasses;
  const ClassSelectPage({super.key, this.beforeSelectedClasses = const []});
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

/// 开发中页面
/// 
/// 用于代替还没完成的功能的组件
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