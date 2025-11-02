import 'package:arabic_learning/funcs/ui.dart';
import 'package:flutter/material.dart';
import 'package:arabic_learning/oss_licenses.dart' as oss;

class OpenSourceLicensePage extends StatelessWidget {
  const OpenSourceLicensePage({super.key});

  @override
  Widget build(BuildContext context) {
    List<oss.Package> licenses = oss.allDependencies;
    List<Widget> widgets = [];
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
                Text("${app.spdxIdentifiers.length}个许可 ${app.spdxIdentifiers.toString()}", style: TextStyle(fontSize: 12, color: Colors.grey),),
              ],
            ),
            children: [
              TextContainer(text: app.license??"")
            ],
          ),
          TextContainer(text: "以下是该项目中使用的一些其他开源项目的库及其开源许可证，感谢这些项目及其贡献者的付出。"),
          ...widgets,
        ]
      ),
    );
  }
}