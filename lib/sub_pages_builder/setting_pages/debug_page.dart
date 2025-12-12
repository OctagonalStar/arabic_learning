import 'package:arabic_learning/funcs/ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/vars/global.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<StatefulWidget> createState() => _DebugPage();
}

class _DebugPage extends State<DebugPage> {
  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 DebugPage");
    return Scaffold(
      appBar: AppBar(
        title: Text("调试设置"),
      ),
      body: Column(
        children: [
          TextContainer(text: "该页面为软件调试/测试和bug反馈使用，非必要请勿开启日志捕获，以免性能损耗", style: TextStyle(color: Colors.redAccent)),
          Row(
            children: [
              Icon(Icons.logo_dev),
              Expanded(child: Text("启用软件内日志捕获")),
              Switch(
                value: context.watch<Global>().settingData["Debug"], 
                onChanged: (value){
                  context.read<Global>().settingData["Debug"] = value;
                  context.read<Global>().updateSetting();
                }
              )
            ],
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.7,
            child: ExpansionTile(
              title: Text("日志捕获内容"),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: ListView(
                    children: List.generate(
                      context.watch<Global>().internalLogCapture.length, 
                      (index){
                        final String logLine = context.read<Global>().internalLogCapture[context.read<Global>().internalLogCapture.length - index - 1];
                        return TextContainer(
                          text: logLine, 
                          selectable: true, 
                          style: TextStyle(color: logLine.contains("[SERVER]") ? Colors.redAccent : logLine.contains("WARNING") ? Colors.amberAccent : logLine.contains("FINE") ? Colors.grey : null)
                        );
                      }
                    ),
                  )
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}