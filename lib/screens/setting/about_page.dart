import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/widgets/kit.dart' show Button, TextContainer;
import 'package:arabic_learning/widgets/shared.dart' show SettingCard;
import 'package:arabic_learning/screens/setting/open_source_licenses.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 AboutPage");
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text("关于")),
      ),
      body: ListView(
        children: [
          TextContainer(text: "该软件仅供学习使用，请勿用于商业用途。\n该软件基于GNU AFFERO GENERAL PUBLIC LICENSE (Version 3)协议开源，协议原文详见页面底部。", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          TextContainer(text: "Copyright (C) <2025>  <OctagonalStar>\n该软件通过GNU GENERAL PUBLIC LICENSE (Version 3)协议授权给 \"${AppData().config.user}\"，协议内容详见开放源代码许可页面"),
          TextContainer(text: "目前该软件主要由 OctagonalStar(别问为什么写网名) 开发，如果有什么问题或者提议都欢迎提issue（或者线下真实？）。\n该软件 <Ar 学>，主要是为了帮助大家掌握阿语词汇"),
          Button(
            size: Size.fromHeight(MediaQuery.of(context).size.height * 0.1),
            onPressed: () {
              context.read<Global>().uiLogger.info("跳转: AboutPage => OpenSourceLicensePage");
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OpenSourceLicensePage(),
                )
              );
            }, 
            icon: Icon(Icons.balance),
            child: Text("开放源代码许可"),
          ),
          TextContainer(text: "用户协议"),
          SettingCard(
            color: Theme.of(context).colorScheme.onSecondary,
            margin: EdgeInsets.all(8.0),
            child: FutureBuilder(
              future: rootBundle.loadString('assets/help/TermsOfUse.md'),
              initialData: "加载中...",
              builder: (context, asyncSnapshot) {
                return MarkdownBody(data: asyncSnapshot.data!);
              }
            )
          ),
          TextContainer(text: "隐私政策"),
          SettingCard(
            color: Theme.of(context).colorScheme.onSecondary,
            margin: EdgeInsets.all(8.0),
            child: FutureBuilder(
              future: rootBundle.loadString('assets/help/PrivacyPolicy.md'),
              initialData: "加载中...",
              builder: (context, asyncSnapshot) {
                return MarkdownBody(data: asyncSnapshot.data!);
              }
            )
          ),
        ],
      ),
    );
  }
}