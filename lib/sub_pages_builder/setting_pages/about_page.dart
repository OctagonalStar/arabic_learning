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
                Text("由于该软件目前还处在开发阶段，有一些bug是不可避免的。所以在正式使用该软件前你应当阅读并理解以下条款："),
                Text("1. 该软件仅供学习使用，请勿用于商业用途。"),
                Text("2. 该软件不会对你的阿拉伯语成绩做出任何担保，若你出现阿拉伯语成绩不理想的情况请先考虑自己的问题 :)"),
                Text("3. 由于软件在不同系统上运行可能存在兼容性问题，软件出错造成的任何损失（包含精神损伤），软件作者和其他贡献者不会担负任何责任"),
                Text("4. 你知晓并理解如果你错误地使用软件（如使用错误的数据集）造成的任何后果，乃至二次宇宙大爆炸，都需要你自行承担"),
                Text("5. 其他在GNU AFFERO GENERAL PUBLIC LICENSE (Version 3)开源协议下的条款"),
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