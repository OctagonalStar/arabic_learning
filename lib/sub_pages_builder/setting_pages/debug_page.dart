import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  void dispose(){
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 DebugPage");

    List<String> debugInfo = [];

    // 基础信息
    debugInfo.add("Date Time: ${DateTime.now().toIso8601String()}");
    debugInfo.add("Version Code: ${StaticsVar.appVersion}");
    debugInfo.add("Host Name: ${io.Platform.localHostname}");
    debugInfo.add("Device System: ${io.Platform.operatingSystem}");
    debugInfo.add("Device System Version: ${io.Platform.operatingSystemVersion}");
    debugInfo.add("Environment: ${io.Platform.environment}");
    debugInfo.add("WideScreen: ${AppData().isWideScreen}");

    // 存储类型
    debugInfo.add("Storage Type: ${AppData().storage.type ? "SharedPreferences" : "IndexDB"}");

    return Scaffold(
      appBar: AppBar(
        title: Text("调试设置"),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.arrow_upward),
        onPressed: (){
          controller.animateTo(0, duration: Durations.medium2, curve: StaticsVar.curve);
        }
      ),
      body: ListView(
        controller: controller,
        children: [
          TextContainer(text: "该页面为软件调试/测试和bug反馈使用，非必要请勿开启日志捕获，以免性能损耗", style: TextStyle(color: Colors.redAccent)),
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
                  value: AppData().config.debug.enableInternalLog, 
                  onChanged: (value){
                    AppData().config = AppData().config.copyWith(
                      debug: AppData().config.debug.copyWith(enableInternalLog: value)
                    );
                    setState(() {
                      context.read<Global>().updateSetting();
                    });
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
                  value:AppData().config.debug.internalLevel,
                  onChanged: (value) {
                    AppData().config = AppData().config.copyWith(
                      debug: AppData().config.debug.copyWith(internalLevel: value)
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
                  AppData().internalLogCapture.length, 
                  (index){
                    final String logLine = AppData().internalLogCapture[AppData().internalLogCapture.length - index - 1];
                    return Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onPrimary,
                        borderRadius: index == 0 
                          ? BorderRadius.vertical(top: Radius.circular(10.0)) 
                          : index == AppData().internalLogCapture.length-1 
                            ? BorderRadius.vertical(bottom: Radius.circular(10.0)) 
                            : BorderRadius.all(Radius.circular(5.0))
                      ),
                      margin: EdgeInsets.all(2.0),
                      padding: EdgeInsets.all(4.0),
                      child: SelectableText(logLine, style: TextStyle(color: logLine.contains("[SERVER]") ? Colors.redAccent : logLine.contains("WARNING") ? Colors.amberAccent : logLine.contains("FINE") ? Colors.grey : null)),
                    );
                  }
                ),
              )
            ],
          ),
          ExpansionTile(
            title: Text("调试信息"),
            children: [
              Row(
                children: [
                  Expanded(child: TextContainer(text: "调试信息中可能包含部分敏感信息，若要发给他人请先自行检查", style: TextStyle(color: Colors.redAccent))),
                  Button(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: debugInfo.join("\n")));
                    },
                    child: Icon(Icons.copy),
                  )
                ],
              ),
              TextContainer(text: debugInfo.join("\n")),
            ],
          )
        ],
      ),
    );
  }
}