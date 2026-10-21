// 新增阅读题流程的第 3 步：生成配置（难度 / 主题 / 数量）与提交。
// 支持 AI API 直连、AI Prompt 复制、现有 JSON 粘贴三种来源。

import 'dart:convert';

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/models/reading.dart';
import 'package:arabic_learning/screens/test/reading/reading_ai_generator.dart';
import 'package:arabic_learning/screens/test/reading/reading_shared.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/http_client.dart';
import 'package:arabic_learning/widgets/feedback.dart' show LoadingIndicator;
import 'package:arabic_learning/widgets/kit.dart' show Button, SettingItem, SettingRow;
import 'package:arabic_learning/widgets/overlays.dart' show alart;
import 'package:arabic_learning/widgets/shared.dart' show appInputDecoration;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

class QuestionConfigPage extends StatefulWidget {
  final QuestionConfig qconfig;
  const QuestionConfigPage({super.key, required this.qconfig});

  @override
  State<QuestionConfigPage> createState() => _QuestionConfigPage();
}

class _QuestionConfigPage extends State<QuestionConfigPage> {
  final TextEditingController themeEditController = TextEditingController();
  final TextEditingController apiAddressEditController = TextEditingController();
  final TextEditingController apiKeyEditController = TextEditingController();
  final TextEditingController apiModelEditController = TextEditingController();
  final TextEditingController promptEditController = TextEditingController();
  bool adding = false;

  Future<void> processSummon(QuestionConfig qconfig) async {
    if(adding == true) return;
    setState(() {
      adding = true;
    });
    qconfig.theme = themeEditController.text == "" ? getRandomTheme() : themeEditController.text;
    switch (qconfig.sourceType) {
      case 1 : {
        String prompt = buildPrompt(qc: qconfig, useSafe: true);
        final Dio dio = createDio();
        try {
          final ReadingUnit? unit = await requestReadingUnitFromApi(
            dio: dio,
            qconfig: qconfig,
            prompt: prompt,
            apiAddress: apiAddressEditController.text,
            apiKey: apiKeyEditController.text,
            apiModel: apiModelEditController.text,
          );
          if(unit != null) {
            AppData().readingData.units.add(unit);
            AppData().saveReadingData();
            // ignore: use_build_context_synchronously
            if(context.mounted) alart(context, "添加成功: ${unit.title}");
          }
        } catch (e) {
          // ignore: use_build_context_synchronously
          if(context.mounted) alart(context, "生成错误: $e");
        }
        break;
      }
      case 2 : {
        promptEditController.text = buildPrompt(qc: qconfig,useSafe: false);
        showModalBottomSheet(
          context: context, 
          shape: RoundedRectangleBorder(borderRadius: StaticsVar.br, side: BorderSide(width: 1.0, color: Theme.of(context).colorScheme.outlineVariant)),
          builder: (context) {
            return Container(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        Text("复制以下文本，在你的AI软件中新建一个对话，将提示词粘贴进去进行生成。再将以大括号开头结尾的一段文本复制回来到导入JSON中使用。"),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.copy),
                              onPressed: (){
                                Clipboard.setData(ClipboardData(text: promptEditController.text));
                              }
                            )
                          ],
                        ),
                        TextField(
                          controller: promptEditController,
                          textDirection: TextDirection.ltr,
                          maxLines: 10,
                          decoration: appInputDecoration(
                            context,
                            labelText: "Prompt",
                          )
                        )
                      ],
                    )
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: (){
                          Navigator.popUntil(context, (route) =>  route.isFirst);
                        }, 
                        child: Text("返回到主页")
                      ),
                      ElevatedButton(
                        onPressed: (){
                          Navigator.pop(context);
                        }, 
                        child: Text("返回重新编辑")
                      ),
                    ],
                  )
                ],
              ),
            );
          }
        );
        break;
      }
      case 3: {
        late ReadingUnit unit;
        AppData appData = AppData();
        try {
          unit = ReadingUnit.buildFromMap(jsonDecode(themeEditController.text), type: qconfig.testType, tashkeel: qconfig.tashkeel);
          if(unit.title.isEmpty) throw Exception("Unit Title is null");
          if(unit.passage.isEmpty) throw Exception("Unit Passage is null");
          if(unit.questions.isEmpty) throw Exception("Unit Questions is null");
          if(appData.readingData.units.any((testunit) => testunit.getHash() == unit.getHash())) throw Exception("Unit already exist");
        } catch (e) { 
          alart(context, e.toString());
          break;
        }
        appData.readingData.units.add(unit);
        appData.saveReadingData();
        alart(
          context, 
          "添加成功",
          onConfirmed: () => Navigator.popUntil(context, (route) => route.isFirst),
        );
      }
    }
    // 等待期间页面可能已被销毁（如导航返回），此时不再更新状态。
    if (!mounted) return;
    setState(() {
      adding = false;
    });
  }

  String getRandomTheme(){
    return randomReadingTheme(widget.qconfig.difficulty);
  }

  @override
  void dispose() {
    themeEditController.dispose();
    apiAddressEditController.dispose();
    apiKeyEditController.dispose();
    apiModelEditController.dispose();
    promptEditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if(widget.qconfig.testType == 2 && widget.qconfig.questionAmount < 10){
      widget.qconfig.questionAmount = 15;
    }

    return ListView(
      children: [
        widget.qconfig.sourceType != 3 
        ? SettingItem(
          title: "题目生成配置", 
          children: [
            if(widget.qconfig.sourceType == 1) SettingRow(
              leading: "API接口地址", 
              icon: Icons.webhook,
              end: Expanded(
                child: TextField(
                  controller: apiAddressEditController,
                  maxLines: 1,
                  decoration: appInputDecoration(context)
                ),
              ),
              note: "从你的AI提供商获取，要求兼容OpenAI标准，例如DeepSeek的API地址为 https://api.deepseek.com \n如果出错，可以在地址末尾加入 /v1 尝试\n注意：末尾不要有 / "
            ),
            if(widget.qconfig.sourceType == 1) SettingRow(
              leading: "API key", 
              icon: Icons.key,
              end: Expanded(
                child: TextField(
                  controller: apiKeyEditController,
                  maxLines: 1,
                  decoration: appInputDecoration(context)
                ),
              ),
              note: "你的API Key，注意，本软件不保存你的API Key，请自行妥善保管"
            ),
            if(widget.qconfig.sourceType == 1) SettingRow(
              leading: "API模型", 
              icon: Icons.webhook,
              end: Expanded(
                child: TextField(
                  controller: apiModelEditController,
                  maxLines: 1,
                  decoration: appInputDecoration(context)
                ),
              ),
              note: "你要使用的AI模型名称，通常你的提供商会提供给你，例如: deepseek-v4-flash"
            ),
            SettingRow(
              icon: Icons.align_vertical_bottom,
              leading: "文章难度", 
              end: Slider(
                value: widget.qconfig.difficulty.toDouble(), 
                label: widget.qconfig.difficulty.toString(),
                onChanged: (double value){
                  setState(() {
                    widget.qconfig.difficulty = value.round();
                  });
                },
                min: 0,
                max: 10,
                divisions: 10,
              ),
              note: """给AI的标准是这么写的：
0-2级：词汇可能含基础生活词，句式限简单陈述句，篇幅建议50-80词;
3-4级：词汇可能含常用动词变位与介词，句式允并列句，篇幅建议80-120词;
5-6级：词汇可能含派生名词与固定搭配，句式允条件句和关系从句，篇幅建议120-160词;
7-8级：词汇可能含稀有三母简式动词，句式允长复合句和虚拟式，篇幅建议160-200词;
9-10级：词汇可能含学术术语，句式允嵌套从句和强调句，篇幅建议200-250词;""",
            ),
            SettingRow(
              icon: Icons.title,
              leading: "文章主题", 
              end: Expanded(
                child: TextField(
                  controller: themeEditController,
                  textDirection: themeEditController.text.textDirection,
                  maxLines: 1,
                  decoration: appInputDecoration(
                    context,
                    hintText: "留空自动随机",
                    suffix: IconButton(
                      onPressed: (){
                        setState(() {
                          themeEditController.text = getRandomTheme();
                        });
                      }, 
                      icon: Icon(Icons.auto_awesome)
                    )
                  )
                ),
              )
            ),
            SettingRow(
              icon: Icons.web_stories,
              leading: "题目数量", 
              end: Slider(
                value: widget.qconfig.questionAmount.toDouble(), 
                label: widget.qconfig.questionAmount.toString(),
                onChanged: (double value){
                  setState(() {
                    widget.qconfig.questionAmount = value.round();
                  });
                },
                min: widget.qconfig.testType == 1 ? 2 : 10,
                max: widget.qconfig.testType == 1 ? 10 : 20,
                divisions: widget.qconfig.testType == 1 ? 8 : 10,
              )
            ),
            SettingRow(
              icon: Icons.question_mark,
              leading: "需要完整发音符号？", 
              end: Switch(
                value: widget.qconfig.tashkeel, 
                onChanged: (bool value) {
                  setState(() {
                    widget.qconfig.tashkeel = value;
                  });
                }
              )
            ),
          ]
        )
        : TextField(
          controller: themeEditController,
          textDirection: TextDirection.ltr,
          maxLines: 20,
          decoration: appInputDecoration(
            context,
            hintText: "粘贴从AI工具中生成的文本",
          ),
        ),
        SizedBox(height: 20),
        Button(
          size: Size.fromHeight(100),
          icon: adding ? LoadingIndicator() : Icon(Icons.check),
          onPressed: () => processSummon(widget.qconfig), 
          child: Text(adding ? "添加中..." : "确认")
        )
      ],
    ) ;
  }
}
