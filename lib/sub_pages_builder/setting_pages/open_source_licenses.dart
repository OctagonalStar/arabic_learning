import 'package:arabic_learning/funcs/ui.dart';
import 'package:flutter/material.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/oss_licenses.dart' as oss;
import 'package:arabic_learning/vars/license_storage.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class OpenSourceLicensePage extends StatelessWidget {
  const OpenSourceLicensePage({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 OpenSourceLicensePage");
    List<oss.Package> licenses = [...oss.allDependencies];
    List<Widget> widgets = [];

    // 字体许可证
    licenses.add(
      oss.Package(
        name: "Vazirmatn", 
        description: "Vazirmatn Font", 
        authors: ["Saber Rastikerdar <saber.rastikerdar@gmail.com>"], 
        isMarkdown: false, 
        isSdk: false, 
        dependencies: [], 
        devDependencies: [],
        spdxIdentifiers: ["OFL"],
        license: LicenseVars.theVazirmatnLicense
      )
    );
    licenses.add(
      oss.Package(
        name: "NotoSansSC", 
        description: "NotoSansSC Font", 
        authors: ["Adobe"], 
        isMarkdown: false, 
        isSdk: false, 
        dependencies: [], 
        devDependencies: [],
        spdxIdentifiers: ["OFL"],
        license: LicenseVars.theNotoSansSCLicense
      )
    );

    for(oss.Package x in licenses) {
      widgets.add(
        ExpansionTile(
          title: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(x.name),
              Text("${x.spdxIdentifiers.length}个许可 ${x.spdxIdentifiers.toString()}", style: TextStyle(fontSize: 12, color: Colors.grey),),
            ],
          ),
          children: [
            TextContainer(text: x.license ?? "")
          ],
        )
      );
    }
    oss.Package app = oss.thisPackage;
    return Scaffold(
      appBar: AppBar(
        title: Text("开放源代码许可"),
      ),
      body: ListView(
        children: [
          TextContainer(text: "本软件的许可证"),
          ExpansionTile(
            title: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.name),
                Text("${app.spdxIdentifiers.length}个许可 ${app.spdxIdentifiers.toString()}", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            children: [
              TextContainer(text: app.license??""),
              if(context.read<Global>().globalConfig.regular.theme == 10) ElevatedButton.icon(
                onPressed: () {
                  context.read<Global>().uiLogger.warning("触发彩蛋 #00s");
                  alart(context, "荏苒的时光足以使沧海化为桑田...", delayConfirm: Duration(seconds: 3),
                  onConfirmed: (){
                    alart(context, "往昔英雄的伟名也已深埋于尘土之下...", delayConfirm: Duration(seconds: 3),
                    onConfirmed: (){
                      alart(context, "苍翠茂盛的树木在大地上盘根，钢铁的足音响彻于天际...", delayConfirm: Duration(seconds: 3),
                      onConfirmed: (){
                        alart(context, "曾几何时如繁华般绚烂多姿的文明，也已寻不到一丝踪迹...", delayConfirm: Duration(seconds: 3),
                        onConfirmed: (){
                          alart(context, "尽管如此...", delayConfirm: Duration(seconds: 3),
                          onConfirmed: (){
                            alart(context, "尽管如此，人类如今仍在这颗星球上顽强生存...", delayConfirm: Duration(seconds: 3),
                            onConfirmed: (){
                              alart(context, "致敬: 終のステラ (星之终途)", delayConfirm: Duration(seconds: 3),
                              onConfirmed: (){
                                alart(context, "注：你开启了一项彩蛋功能\n若要关闭请再次点击此按钮\n请*手动*重启软件以应用更改...", delayConfirm: Duration(seconds: 3),
                                onConfirmed: (){
                                  context.read<Global>().globalConfig = context.read<Global>().globalConfig.copyWith(
                                    egg: context.read<Global>().globalConfig.egg.copyWith(stella: !context.read<Global>().globalConfig.egg.stella)
                                  );
                                  context.read<Global>().updateSetting();
                                  SystemNavigator.pop();
                                });
                              });
                            });
                          });
                        });
                      });
                    });
                  });
                }, 
                icon: Icon(Icons.egg),
                label: Text("华生，你发现了盲点（彩蛋 #00s）..."),
              )
            ],
          ),
          TextContainer(text: "以下是该项目中使用的一些其他开源项目的库及其开源许可证，感谢这些项目及其贡献者的付出。"),
          ...widgets,
        ]
      ),
    );
  }
}