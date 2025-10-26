import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/vars/license_storage.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  final Map<String, dynamic> setting;
  const AboutPage({super.key, required this.setting});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text("关于")),
      ),
      body: ListView(
        children: [
          TextContainer(text: "关于"),
          TextContainer(text: "该软件仅供学习使用，请勿用于商业用途。\n该软件基于GNU AFFERO GENERAL PUBLIC LICENSE (Version 3)协议开源，协议原文详见页面底部。", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          TextContainer(text: "目前该软件仅由 OctagonalStar(别问为什么写网名) 一人开发（其实主要是为了学flutter框架写的），如果有什么问题或者提议都欢迎提issue（或者线下真实？）。\n该软件 <Ar 学>，主要是为了帮助大家掌握阿语词汇（毕竟上课词汇都要听晕了）"),
          TextContainer(text: "免责声明"),
          Container(
            margin: EdgeInsets.all(8.0),
            padding: EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSecondary,
              borderRadius: StaticsVar.br,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(LicenseVars.noMyDutyAnnouce),
              ],
            ),
          ),
          TextContainer(text: "GNU AFFERO GENERAL PUBLIC LICENSE (Version 3)开源协议 / GNU AFFERO GENERAL PUBLIC LICENSE"),
          TextContainer(text: "Copyright (C) <2025>  <OctagonalStar>\n该软件通过GNU GENERAL PUBLIC LICENSE (Version 3)协议授权给 \"${setting["User"]}\"，协议内容详见下方："),
          TextContainer(text: LicenseVars.theAPPLICENSE)
        ],
      ),
    );
  }
}