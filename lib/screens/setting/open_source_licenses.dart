import 'package:arabic_learning/widgets/kit.dart' show TextContainer;
import 'package:flutter/material.dart';
import 'package:arabic_learning/oss_licenses.dart' as oss;
import 'package:arabic_learning/core/license_storage.dart';
import 'package:arabic_learning/core/statics.dart' show AsrModelInfo, StaticsVar, TtsModelInfo;

class OpenSourceLicensePage extends StatelessWidget {
  const OpenSourceLicensePage({super.key});

  @override
  Widget build(BuildContext context) {
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

    // 可下载的模型权重许可（不随 pubspec 依赖生成，需手动列出）。
    for (final TtsModelInfo m in StaticsVar.ttsModels) {
      licenses.add(
        oss.Package(
          name: "${m.title} · ${m.id}",
          description: "TTS 模型（${m.sizeMB}MB）：${m.sourceUrl}",
          authors: [m.sourceUrl],
          isMarkdown: false,
          isSdk: false,
          dependencies: [],
          devDependencies: [],
          spdxIdentifiers: [m.license],
          license: m.license == "Apache-2.0" ? LicenseVars.theApacheLicense : LicenseVars.theModelLICENSE,
        )
      );
    }
    for (final AsrModelInfo m in StaticsVar.asrModels) {
      licenses.add(
        oss.Package(
          name: "${m.title} · ${m.id}",
          description: "语音识别模型（${m.sizeMB}MB）：${m.sourceUrl}",
          authors: [m.sourceUrl],
          isMarkdown: false,
          isSdk: false,
          dependencies: [],
          devDependencies: [],
          spdxIdentifiers: [m.license],
          license: m.license == "Apache-2.0" ? LicenseVars.theApacheLicense : LicenseVars.theModelLICENSE,
        )
      );
    }

    for(oss.Package x in licenses) {
      widgets.add(
        ExpansionTile(
          title: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(x.name),
              Text("${x.spdxIdentifiers.length}个许可 ${x.spdxIdentifiers.toString()}", style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),),
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
      body: SafeArea(top: false, child: ListView(
        children: [
          TextContainer(text: "本软件的许可证"),
          ExpansionTile(
            title: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.name),
                Text("${app.spdxIdentifiers.length}个许可 ${app.spdxIdentifiers.toString()}", style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
            children: [
              TextContainer(text: app.license??""),
            ],
          ),
          TextContainer(text: "以下是该项目中使用的一些其他开源项目的库及其开源许可证，感谢这些项目及其贡献者的付出。"),
          ...widgets,
        ]
      )),
    );
  }
}