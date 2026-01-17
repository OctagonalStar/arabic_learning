import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:arabic_learning/vars/global.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<StatefulWidget> createState() => _DebugPage();
}

class _DebugPage extends State<DebugPage> {
  ScrollController controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 DebugPage");
    return Scaffold(
      appBar: AppBar(
        title: Text("调试设置"),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.arrow_upward),
        onPressed: (){
          controller.animateTo(0, duration: Duration(milliseconds: 500), curve: StaticsVar.curve);
        }
      ),
      body: ListView(
        controller: controller,
        children: [
          TextContainer(text: "该页面为软件调试/测试和bug反馈使用，非必要请勿开启日志捕获，以免性能损耗", style: TextStyle(color: Colors.redAccent), animated: true),
          Container(
            decoration: BoxDecoration(
              borderRadius: StaticsVar.br,
              color: Theme.of(context).colorScheme.onPrimary
            ),
            padding: EdgeInsets.only(left: 16.0, right: 16.0),
            child: Row(
              children: [
                Icon(Icons.logo_dev),
                Expanded(child: Text("启用软件内日志捕获")),
                Switch(
                  value: context.watch<Global>().globalConfig.debug.enableInternalLog, 
                  onChanged: (value){
                    context.read<Global>().globalConfig = context.read<Global>().globalConfig.copyWith(
                      debug: context.read<Global>().globalConfig.debug.copyWith(enableInternalLog: value)
                    );
                    context.read<Global>().updateSetting();
                  }
                )
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: StaticsVar.br,
              color: Theme.of(context).colorScheme.onSecondary
            ),
            padding: EdgeInsets.only(left: 16.0, right: 16.0),
            child: Row(
              children: [
                Icon(Icons.logo_dev_outlined),
                Expanded(child: Text("日志等级")),
                DropdownButton(
                  items: [
                    DropdownMenuItem(value: 0,child: Text("Level.ALL")),
                    DropdownMenuItem(value: 1,child: Text("Level.FINEST")),
                    DropdownMenuItem(value: 2,child: Text("Level.FINER")),
                    DropdownMenuItem(value: 3,child: Text("Level.FINE")),
                    DropdownMenuItem(value: 4,child: Text("Level.INFO")),
                    DropdownMenuItem(value: 5,child: Text("Level.WARNING")),
                    DropdownMenuItem(value: 6,child: Text("Level.SEVERE")),
                    DropdownMenuItem(value: 7,child: Text("Level.SHOUT")),
                    DropdownMenuItem(value: 8,child: Text("Level.OFF")),
                  ], 
                  value: context.watch<Global>().globalConfig.debug.internalLevel,
                  onChanged: (value) {
                    context.read<Global>().globalConfig = context.read<Global>().globalConfig.copyWith(
                      debug: context.read<Global>().globalConfig.debug.copyWith(internalLevel: value)
                    );
                    context.read<Global>().updateSetting();
                  }
                )
              ],
            ),
          ),
          ExpansionTile(
            title: Text("日志捕获内容"),
            children: [
              Column(
                children: List.generate(
                  context.watch<Global>().internalLogCapture.length, 
                  (index){
                    final String logLine = context.read<Global>().internalLogCapture[context.read<Global>().internalLogCapture.length - index - 1];
                    return Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onPrimary,
                        borderRadius: index == 0 ? BorderRadius.vertical(top: Radius.circular(10.0)) : index == context.watch<Global>().internalLogCapture.length-1 ? BorderRadius.vertical(bottom: Radius.circular(10.0)) : BorderRadius.all(Radius.circular(5.0))
                      ),
                      margin: EdgeInsets.all(2.0),
                      padding: EdgeInsets.all(4.0),
                      child: SelectableText(logLine, style: TextStyle(color: logLine.contains("[SERVER]") ? Colors.redAccent : logLine.contains("WARNING") ? Colors.amberAccent : logLine.contains("FINE") ? Colors.grey : null)),
                    );
                  }
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}