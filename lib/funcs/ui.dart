import 'package:arabic_learning/vars/change_notifier_models.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ClassSelector extends StatelessWidget { 
  const ClassSelector({super.key});
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    if(!context.watch<ClassSelectModel>().initialized) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('选择特定课程单词'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: classesSelectionList(context, mediaQuery)
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              fixedSize: Size(mediaQuery.size.width, mediaQuery.size.height * 0.1),
              shape: ContinuousRectangleBorder(borderRadius: StaticsVar.br),
            ),
            child: Text('确认'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

List<Widget> classesSelectionList(BuildContext context, MediaQueryData mediaQuery) {
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
          child: CheckboxListTile(
            title: Text(className),
            value: context.watch<ClassSelectModel>().selectedClasses.any((e) => e[0] == sourceName && e[1] == className,),
            onChanged: (value) {
              value! ? context.read<ClassSelectModel>().addClass([sourceName, className]) 
                      : context.read<ClassSelectModel>().removeClass([sourceName, className]);
            },
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


void alart(context, String e) {
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