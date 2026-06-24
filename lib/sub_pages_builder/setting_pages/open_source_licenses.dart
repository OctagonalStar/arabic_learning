import 'package:arabic_learning/funcs/ui.dart';
import 'package:flutter/material.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/oss_licenses.dart' as oss;
import 'package:arabic_learning/vars/license_storage.dart';
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
            ],
          ),
          TextContainer(text: "以下是该项目中使用的一些其他开源项目的库及其开源许可证，感谢这些项目及其贡献者的付出。"),
          ...widgets,
        ]
      ),
    );
  }
}