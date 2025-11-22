import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class QuestionsSettingLeadingPage extends StatelessWidget{
  const QuestionsSettingLeadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("题型设置")),
      body: ListView(
        children: [
          TextContainer(text: "你可以通过此设置较自由配置每次测试/学习应当测试的题目"),
          EnterSpecificQuestionSettingButton(name: "中阿混合学习", sectionKey: "zh_ar")
        ],
      ),
    );
  }
}

class EnterSpecificQuestionSettingButton extends StatelessWidget {
  final String name;
  final String sectionKey;
  final List<int> allowTypes;
  const EnterSpecificQuestionSettingButton({super.key, required this.name, required this.sectionKey, this.allowTypes = const [0, 1 ,2]});

  @override
  Widget build(BuildContext context) {
    final bool isAllowModify = context.read<Global>().settingData['quiz'][sectionKey]["modifyAllowed"];
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        fixedSize: Size.fromHeight(MediaQuery.of(context).size.height * 0.08),
        shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
      ),
      onPressed: (){
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => QuestionsSettingPage(sectionKey: sectionKey, allowTypes: allowTypes, isAllowModify: isAllowModify)));
      }, 
      child: Row(
        children: [
          Expanded(child: Text(name)),
          Icon(Icons.arrow_forward_ios),
        ],
      )
    );
  }
}

class QuestionsSettingPage extends StatefulWidget {
  final String sectionKey;
  final List<int> allowTypes;
  final bool isAllowModify;
  const QuestionsSettingPage({super.key, required this.sectionKey, required this.allowTypes, required this.isAllowModify});

  @override
  State<StatefulWidget> createState() => _QuestionsSettingPage();
}

class _QuestionsSettingPage extends State<QuestionsSettingPage> {
  List<dynamic>? selectedTypes;
  bool floatButtonFlod = true;
  static const Map<int, String> castMap = {0: "单词卡片学习", 1: "中译阿 选择题", 2: "阿译中 选择题", 3: "中译阿 拼写题"};


  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    selectedTypes ??= context.read<Global>().settingData['quiz'][widget.sectionKey]["questionSections"];
    List<Widget> listTiles = [];
    bool isEven = true;
    for(int index = 0; index < selectedTypes!.length; index++) {
      listTiles.add(
        Container(
          key: Key(index.toString()),
          padding: EdgeInsets.all(8.0),
          // margin: EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            color: isEven ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSecondary,
            borderRadius: BorderRadius.all(Radius.circular(16.0))
          ),
          height: mediaQuery.size.height * 0.08,
          child: Row(
            children: [
              Expanded(child: Text(castMap[selectedTypes![index]] ?? "未知类型")),
              IconButton(
                onPressed: (){
                  if(selectedTypes!.length == 1) {
                    alart(context, "至少保留一项");
                  } else {
                    setState(() {
                      selectedTypes!.removeAt(index.toInt());
                    });
                  }
                }, 
                icon: Icon(Icons.delete)
              ),
              SizedBox(width: mediaQuery.size.width * 0.1)
            ],
          ),
        )
      );
      isEven = !isEven;
    }
    

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        context.read<Global>().updateSetting(refresh: false);
      },
      child: Scaffold(
        appBar: AppBar(title: Text("题型配置: ${widget.sectionKey}")),
        body: Column(
          children: [
            Expanded(
              child: ReorderableListView(
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if(oldIndex < newIndex) newIndex--; // 修正索引
                    int old = selectedTypes!.removeAt(oldIndex);
                    selectedTypes!.insert(newIndex, old);
                  });
                },
                children: listTiles, 
              ),
            ),
            Row(
              children: [
                Switch(
                  value: context.read<Global>().settingData['quiz'][widget.sectionKey]["shuffleInternaly"], 
                  onChanged: (value) {
                    setState(() {
                      context.read<Global>().settingData['quiz'][widget.sectionKey]["shuffleInternaly"] = value;
                    });
                  }
                ),
                Expanded(child: Text("题型内题目乱序")),
              ],
            ),
            Row(
              children: [
                Switch(
                  value: context.read<Global>().settingData['quiz'][widget.sectionKey]["shuffleExternaly"], 
                  onChanged: (value) {
                    setState(() {
                      context.read<Global>().settingData['quiz'][widget.sectionKey]["shuffleExternaly"] = value;
                    });
                  }
                ),
                Expanded(child: Text("题型乱序")),
              ],
            ),
            Row(
              children: [
                Switch(
                  value: context.read<Global>().settingData['quiz'][widget.sectionKey]["shuffleGlobally"], 
                  onChanged: (value) {
                    setState(() {
                      context.read<Global>().settingData['quiz'][widget.sectionKey]["shuffleGlobally"] = value;
                    });
                  }
                ),
                Expanded(child: Text("全局乱序")),
              ],
            )
          ],
        ),
        floatingActionButton: TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0.0,
            end: floatButtonFlod ? 0.0 : 1.0
          ), 
          duration: Duration(milliseconds: 500),
          curve: Curves.bounceOut, 
          builder: (context, value, child) {
            return Container(
              // width: mediaQuery.size.width * 0.07 + mediaQuery.size.width * 0.1 * value,
              // height: mediaQuery.size.height * 0.1 + mediaQuery.size.height * 0.45 * value, //实际稍高一些 避免默认margin导致的溢出
              decoration: BoxDecoration(
                color: Colors.transparent,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if(value > 0.3) ...List.generate(4, (i) {
                    return ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        fixedSize: Size(70 + 150 * value, mediaQuery.size.height * 0.1 * value),
                        backgroundColor: Theme.of(context).colorScheme.onPrimary,
                        shape: i == 0 ? RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(top: Radius.circular(25.0))) : BeveledRectangleBorder()
                      ),
                      onPressed: (){
                        setState(() {
                          selectedTypes!.add(i);
                        });
                      }, 
                      icon: Icon(Icons.add),
                      label: FittedBox(child: Text("添加 ${castMap[i]}")),
                    );
                  }),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      fixedSize: Size(70 + 150 * value, 70),
                      backgroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0), top: value < 0.4 ? Radius.circular(25.0) : Radius.zero))
                    ),
                    onPressed: (){
                      setState(() {
                        floatButtonFlod = !floatButtonFlod;
                      });
                    }, 
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(value > 0.5 ?  Icons.deselect : Icons.add), 
                        if(value > 0.5) FittedBox(child: Text("收起"))
                      ],
                    ),
                  )
                ],
              ),
            );
          }
        )
      ),
    );
  }
}

