import 'dart:convert';

import 'package:arabic_learning/vars/statics_var.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/sub_pages_builder/setting_pages/help_page.dart' show HelpPage;
import 'package:arabic_learning/sub_pages_builder/setting_pages/item_widget.dart'show SettingItem;
import 'package:arabic_learning/sub_pages_builder/setting_pages/debug_page.dart' show DebugPage;
import 'package:arabic_learning/sub_pages_builder/setting_pages/about_page.dart' show AboutPage;
import 'package:arabic_learning/sub_pages_builder/setting_pages/data_download_page.dart' show DownloadPage;
import 'package:arabic_learning/sub_pages_builder/setting_pages/model_download_page.dart' show ModelDownload;
import 'package:arabic_learning/sub_pages_builder/setting_pages/questions_setting_page.dart' show QuestionsSettingPage;
import 'package:arabic_learning/sub_pages_builder/setting_pages/sync_page.dart' show DataSyncPage;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/vars/config_structure.dart' show AiConfig, AiEndpoint, AiApiMode, kAiPresets;
import 'package:arabic_learning/pages/quiz_bank_page.dart' show QuizBankPage;

class SettingPage extends StatefulWidget { 
  const SettingPage({super.key});
  @override
  State<SettingPage> createState() => _SettingPage();
}

class _SettingPage extends State<SettingPage> {
  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 SettingPage");
    return Consumer<Global>(
      builder: (context, value, child) {
        return ListView(
          children: [
            SettingItem(
              title: "帮助", 
              children: helpEssay(context)
            ),
            SettingItem(
              title: "常规设置",
              padding: EdgeInsets.all(8.0),
              children: regularSetting(context),
            ),
            SettingItem(
              title: "学习设置", 
              children: dataSetting(context), 
            ),
            SettingItem(
              title: "音频设置", 
              children: audioSetting(context), 
            ),
            SettingItem(
              title: "AI 练习设置",
              children: aiSetting(context),
            ),
            SettingItem(
              title: "关于", 
              children: aboutSetting(context), 
            ),
          ],
        );
      },
    );
  }

  List<Widget> helpEssay(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return [
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
        ),
        onPressed: (){
          context.read<Global>().uiLogger.info("跳转: SettingPage => HelpPage");
          Navigator.push(context, MaterialPageRoute(builder: (context) => HelpPage()));
        }, 
        child: Row(
          children: [
            Icon(Icons.help, size: 24.0),
            SizedBox(width: mediaQuery.size.width * 0.01),
            Expanded(child: Text("常见问题", textAlign: TextAlign.start)),
            Icon(Icons.arrow_forward_ios)
          ]
        ),
      )
    ];
  }

  List<Widget> regularSetting(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    AppData appData = AppData();

    return  [
      Row(
        children: [
          Icon(Icons.color_lens, size: 24.0),
          SizedBox(width: mediaQuery.size.width * 0.01),
          Expanded(child: Text("主题颜色:")),
          DropdownButton<int>(
            value: appData.config.regular.theme,
            items: const [
              DropdownMenuItem(value: 0, child: Text('樱粉')),
              DropdownMenuItem(value: 1, child: Text('海蓝')),
              DropdownMenuItem(value: 2, child: Text('草绿')),
              DropdownMenuItem(value: 3, child: Text('金黄')),
              DropdownMenuItem(value: 4, child: Text('柑橘')),
              DropdownMenuItem(value: 5, child: Text('雅紫')),
              DropdownMenuItem(value: 6, child: Text('木棕')),
              DropdownMenuItem(value: 7, child: Text('冷灰')),
              DropdownMenuItem(value: 8, child: Text('茶香')),
              DropdownMenuItem(value: 9, child: Text('烟蓝')),
              DropdownMenuItem(value: 10, child: Text('星青'))
            ],
            onChanged: (value) async {
              context.read<Global>().uiLogger.info("更新主题颜色: $value");
              AppData().config = AppData().config.copyWith(
                regular: AppData().config.regular.copyWith(theme: value)
              );
              context.read<Global>().updateSetting();
            },
          ),
        ],
      ),
      Row(
        children: [
          Icon(Icons.brightness_4, size: 24.0),
          SizedBox(width: mediaQuery.size.width * 0.01),
          Expanded(child: Text("深色模式:")),
          Switch(
            value: appData.config.regular.darkMode,
            onChanged: (value) {
              context.read<Global>().uiLogger.info("更新深色模式设置: $value");
              AppData().config = AppData().config.copyWith(
                regular: AppData().config.regular.copyWith(darkMode: value)
              );
              context.read<Global>().updateSetting();
            },
          )
        ],
      ),
      Row(
        children: [
          Icon(Icons.font_download, size: 24.0),
          SizedBox(width: mediaQuery.size.width * 0.01),
          Expanded(child: Text("字体设置:")),
          DropdownButton<int>(
            value: appData.config.regular.font,
            items: [
              DropdownMenuItem(value: 0, child: Text('默认字体')),
              DropdownMenuItem(value: 1, child: Text('仅阿语使用备用字体')),
              DropdownMenuItem(value: 2, child: Text('中阿均使用备用字体')),
            ],
            onChanged: (value) {
              context.read<Global>().uiLogger.info("更新字体设置: $value");
              if(value == 2 && kIsWeb) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("网页版加载中文字体需要较长时间，请先耐心等待"), duration: Duration(seconds: 3),),
                );
              }
              AppData().config = AppData().config.copyWith(
                regular: AppData().config.regular.copyWith(font: value)
              );
              Provider.of<Global>(context, listen: false).updateSetting();
            },
          )
        ]
      ),
      if(kIsWeb) Row(
        children: [
          Icon(Icons.hide_source, size: 24.0),
          SizedBox(width: mediaQuery.size.width * 0.01),
          Expanded(child: Text("隐藏网页版右上角APP下载按钮")),
          Switch(
            value: AppData().config.regular.hideAppDownloadButton,
            onChanged: (value) {
              context.read<Global>().uiLogger.info("更新网页端APP下载按钮隐藏设置: $value");
              AppData().config = AppData().config.copyWith(
                regular: AppData().config.regular.copyWith(hideAppDownloadButton: value)
              );
              context.read<Global>().updateSetting();
            },
          )
        ],
      ),
    ];
  }
  
  List<Widget> dataSetting(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return [
      Column(
        children: [
          Row(
            children: [
              SizedBox(width: mediaQuery.size.width * 0.02),
              Icon(Icons.download, size: 24.0),
              SizedBox(width: mediaQuery.size.width * 0.01),
              Expanded(child: Text("导入词库数据")),
              Text("词库中现有: ${AppData().wordCount}"),
              SizedBox(width: mediaQuery.size.width * 0.02),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  fixedSize: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.06),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(25.0)))
                ),
                onPressed: () {
                  context.read<Global>().uiLogger.info("跳转: SettingPage => DownloadPage");
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => DownloadPage()));
                },
                icon: Icon(Icons.cloud_download),
                label: Text("线上下载")
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  fixedSize: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.06),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(25.0)))
                ),
                onPressed: () async {
                  context.read<Global>().uiLogger.info("选择手动导入单词");
                  FilePickerResult? result = await FilePicker.pickFiles(
                    allowMultiple: false,
                    type: FileType.custom,
                    allowedExtensions: ['json'],
                  );
                  if (result != null) {
                    String jsonString;
                    PlatformFile platformFile = result.files.first;
                    if (platformFile.bytes != null){
                      jsonString = utf8.decode(platformFile.bytes!);
                    } else if (platformFile.path != null && !kIsWeb) {
                      jsonString = await io.File(platformFile.path!).readAsString();
                    } else {
                      if (!context.mounted) return;
                      context.read<Global>().uiLogger.warning("文件导入错误: bytes和path均为null");
                      alart(context, "文件 \"${platformFile.name}\" \n无法读取：bytes和path均为null。");
                      return;
                    }
                    if (!context.mounted) return;
                    try{
                      context.read<Global>().uiLogger.fine("文件读取完成，开始解析");
                      Map<String, dynamic> jsonData = json.decode(jsonString);
                      AppData().importDictData(jsonData, platformFile.name);
                      alart(context, "文件 \"${platformFile.name}\" \n已导入。");
                      context.read<Global>().uiLogger.info("文件解析成功");
                    } catch (e) {
                      if (!context.mounted) return;
                      context.read<Global>().uiLogger.severe("文件 ${platformFile.name} 无效: $e");
                      alart(context, '文件 ${platformFile.name} 无效：\n$e');
                    }
                  }
                },
              icon: Icon(Icons.file_open),
              label: Text("文件导入"))
            ],
          ),
        ],
      ),
      // ── 旧数据迁移按钮（仅当存在未迁移词汇时显示）────────────────
      const _MigrateButton(),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          shape: BeveledRectangleBorder()
        ),
        onPressed: (){
          context.read<Global>().uiLogger.info("跳转: SettingPage => QuestionsSettingPage");
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => QuestionsSettingPage()));
        }, 
        child: Row(
          children: [
            Icon(Icons.quiz),
            Expanded(child: Text("题型配置")),
            Icon(Icons.arrow_forward_ios)
          ],
        )
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0)))
        ),
        onPressed: (){
          context.read<Global>().uiLogger.info("跳转: SettingPage => DataSyncPage");
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => DataSyncPage()));
        }, 
        child: Row(
          children: [
            Icon(Icons.sync),
            Expanded(child: Text("数据备份及同步")),
            Icon(Icons.arrow_forward_ios)
          ],
        )
      ),
    ];
  }

  List<Widget> audioSetting(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return [
      Column(
        children: [
          Row(
            children: [
              SizedBox(width: mediaQuery.size.width * 0.02),
              Icon(Icons.api, size: 24.0),
              SizedBox(width: mediaQuery.size.width * 0.01),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentGeometry.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("选择文本转语音接口"),
                      Text("默认使用系统自带的文本转语音接口，但有些厂商可能没有阿拉伯语支持\n若使用\"神经网络合成语音\"你必须使用APP端并下载模型。", style: TextStyle(fontSize: 8.0, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          DropdownButton(
            value: AppData().config.audio.audioSource, 
            onChanged: (value) {
              context.read<Global>().uiLogger.info("更新音频接口: $value");
              if(value == 1) alart(context, "警告: \n来自\"TextReadTTS.com\"的音频不支持发音符号，且只能合成40字以内的文本。\n开启此功能请知悉。");
              AppData().config = AppData().config.copyWith(
                audio: AppData().config.audio.copyWith(audioSource: value)
              );
              context.read<Global>().updateSetting();
            },
            items: [
              DropdownMenuItem(value: 0, child: Text("系统文本转语音", overflow: TextOverflow.ellipsis,)),
              DropdownMenuItem(value: 1, child: Text("请求TextReadTTS.com的语音", overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 2, 
                enabled: kIsWeb ? false : (AppData().modelTTSDownloaded ? true : false), 
                child: Text("神经网络合成语音", 
                  overflow: TextOverflow.ellipsis, 
                  style: TextStyle(color: kIsWeb ? Colors.grey : (AppData().modelTTSDownloaded ? null : Colors.grey))
                ),
              )
            ],
            isExpanded: true,
          ),
          SizedBox(width: mediaQuery.size.width * 0.02),
        ],
      ),
      Row(
        children: [
          SizedBox(width: mediaQuery.size.width * 0.02),
          Icon(Icons.speed, size: 24.0),
          SizedBox(width: mediaQuery.size.width * 0.01),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("设置播放速度"),
                Text("默认为1.0，即正常播放速度。", style: TextStyle(fontSize: 8.0, color: Colors.grey))
              ]
            )
          ),
          Slider(
            value: AppData().config.audio.playRate,
            min: 0.5,
            max: 1.5,
            divisions: 10,
            label: "${AppData().config.audio.playRate}",
            onChanged: (value) {
              setState(() {
                AppData().config = AppData().config.copyWith(
                  audio: AppData().config.audio.copyWith(playRate: value)
                );
              });
            },
            onChangeEnd: (value) {
              context.read<Global>().uiLogger.info("更新音频速度设置: $value");
              context.read<Global>().updateSetting();
            },
          ),
          SizedBox(width: mediaQuery.size.width * 0.02),
        ]
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0))),
        ),
        onPressed: () {
          if(kIsWeb) {
            alart(context, "此功能仅支持APP端。\n要是你是果儿的话...那我没招了，抱歉");
          } else {
            context.read<Global>().uiLogger.info("跳转: SettingPage => ModelDownload");
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => ModelDownload()));
          }
        },
        child: Row(
          children: [
            Icon(Icons.model_training, size: 24.0),
            SizedBox(width: mediaQuery.size.width * 0.01),
            Expanded(
              child: Text("下载神经网络文本转语音模型")
            ),
            Icon(Icons.arrow_forward_ios, size: 28.0)
          ],
        ),
      )
    ];
  }

  List<Widget> aboutSetting(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return [
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(top: Radius.circular(25.0))),
        ),
        onPressed: (){
          context.read<Global>().uiLogger.info("跳转: SettingPage => DebugPage");
          Navigator.push(context, MaterialPageRoute(builder: (context)=>DebugPage()));
        }, 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Icons.bug_report, size: 24.0),
            SizedBox(width: mediaQuery.size.width * 0.01),
            Expanded(
              child: Text("调试信息")
            ),
            Icon(Icons.arrow_forward_ios)
          ],
        )
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
          shape: BeveledRectangleBorder(),
        ),
        onPressed: () {
          context.read<Global>().uiLogger.info("打开Github项目网站");
          launchUrl(Uri.parse("https://github.com/OctagonalStar/arabic_learning/"));
        }, 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Icons.star_rounded, size: 24.0),
            SizedBox(width: mediaQuery.size.width * 0.01),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("项目地址"),
                  Text("去github上点个star~", style: TextStyle(fontSize: 8.0, color: Colors.grey))
                ],
              ),
            ),
            Icon(Icons.open_in_new),
          ],
        ),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0))),
        ),
        onPressed: () {
          context.read<Global>().uiLogger.info("跳转: SettingPage => AboutPage");
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => AboutPage()));
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Icons.adb, size: 24.0),
            SizedBox(width: mediaQuery.size.width * 0.01),
            Expanded(
              child: Text("关于该软件"),
            )
          ],
        ),
      ),
    ];
  }

  // ── AI 练习配置 ──────────────────────────────────────────────────────────────────────────
  List<Widget> aiSetting(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    AppData appData = AppData();
    AiConfig ai = appData.config.ai;

    /// 更新当前选中 endpoint 的某个字段后保存
    void saveEndpoint(AiEndpoint updatedEndpoint) {
      final newEndpoints = ai.endpoints.map((e) {
        return e.id == ai.selectedEndpointId ? updatedEndpoint : e;
      }).toList();
      ai = ai.copyWith(endpoints: newEndpoints);
      appData.config = appData.config.copyWith(ai: ai);
      context.read<Global>().updateSetting(refresh: false);
    }

    // 匹配当前 baseUrl 是否与某个预设对应
    String? matchedPreset = _matchPresetName(ai.currentEndpoint.baseUrl);

    return [
      // ── 服务商预设选择器 ────────────────────────────────────────────────
      Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: StaticsVar.br,
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('选择服务商'),
          subtitle: Text(
            matchedPreset ?? '自定义',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _showPresetPicker(context, ai, saveEndpoint),
        ),
      ),

      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: StatefulBuilder(builder: (ctx, ss) {
          final endpoint = ai.currentEndpoint;
          final ctrl = TextEditingController(text: endpoint.baseUrl);
          ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
          return TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: 'API 地址（Base URL）',
              hintText: 'https://api.openai.com',
              border: OutlineInputBorder(borderRadius: StaticsVar.br),
              suffixIcon: IconButton(
                icon: const Icon(Icons.done),
                onPressed: () => saveEndpoint(ai.currentEndpoint.copyWith(baseUrl: ctrl.text.trim())),
              ),
            ),
            keyboardType: TextInputType.url,
            onSubmitted: (v) => saveEndpoint(ai.currentEndpoint.copyWith(baseUrl: v.trim())),
          );
        }),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: StatefulBuilder(builder: (ctx, ss) {
          bool obscure = true;
          final endpoint = ai.currentEndpoint;
          final ctrl = TextEditingController(text: endpoint.apiKey);
          return StatefulBuilder(builder: (ctx2, ss2) {
            return TextField(
              controller: ctrl,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                border: OutlineInputBorder(borderRadius: StaticsVar.br),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => ss2(() => obscure = !obscure),
                    ),
                    IconButton(
                      icon: const Icon(Icons.done),
                      onPressed: () => saveEndpoint(ai.currentEndpoint.copyWith(apiKey: ctrl.text.trim())),
                    ),
                  ],
                ),
              ),
              onSubmitted: (v) => saveEndpoint(ai.currentEndpoint.copyWith(apiKey: v.trim())),
            );
          });
        }),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: StatefulBuilder(builder: (ctx, ss) {
          final endpoint = ai.currentEndpoint;
          final ctrl = TextEditingController(text: endpoint.model);
          ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
          return TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: '模型名称',
              hintText: 'gpt-4o-mini / gemini-3-flash-preview',
              border: OutlineInputBorder(borderRadius: StaticsVar.br),
              suffixIcon: IconButton(
                icon: const Icon(Icons.done),
                onPressed: () => saveEndpoint(ai.currentEndpoint.copyWith(model: ctrl.text.trim())),
              ),
            ),
            onSubmitted: (v) => saveEndpoint(ai.currentEndpoint.copyWith(model: v.trim())),
          );
        }),
      ),
      StatefulBuilder(builder: (ctx, ss) {
        int count = ai.defaultQuestionCount;
        return Row(
          children: [
            const Icon(Icons.format_list_numbered),
            const SizedBox(width: 8),
            const Expanded(child: Text('每次出题数量')),
            Slider(
              min: 1, max: 20, divisions: 9,
              value: count.toDouble(),
              label: '$count 题',
              onChanged: (v) => ss(() => count = v.round()),
              onChangeEnd: (v) {
                ai = ai.copyWith(defaultQuestionCount: v.round());
                appData.config = appData.config.copyWith(ai: ai);
                context.read<Global>().updateSetting(refresh: false);
              },
            ),
            SizedBox(width: 32, child: Text('$count', textAlign: TextAlign.center)),
          ],
        );
      }),
      StatefulBuilder(builder: (ctx, ss) {
        int batchSize = ai.readingBatchSize;
        return Row(
          children: [
            const Icon(Icons.auto_stories),
            const SizedBox(width: 8),
            const Expanded(child: Text('阅读每批词汇量')),
            Slider(
              min: 10, max: 50, divisions: 8,
              value: batchSize.toDouble(),
              label: '$batchSize 词/篇',
              onChanged: (v) => ss(() => batchSize = v.round()),
              onChangeEnd: (v) {
                ai = ai.copyWith(readingBatchSize: v.round());
                appData.config = appData.config.copyWith(ai: ai);
                context.read<Global>().updateSetting(refresh: false);
              },
            ),
            SizedBox(width: 40, child: Text('$batchSize 词', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
          ],
        );
      }),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          minimumSize: Size(mq.size.width, 52),
          shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
        ),
        onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const QuizBankPage())),
        icon: const Icon(Icons.library_books),
        label: const Text('查看 AI 题库'),
      ),
    ];
  }

  /// 根据 baseUrl 匹配预设名称，用于在 UI 上展示当前服务商
  String? _matchPresetName(String baseUrl) {
    final trimmed = baseUrl.trimRight();
    for (final p in kAiPresets) {
      if (p.baseUrl == trimmed) return p.name;
    }
    return null;
  }

  /// 弹出服务商预设选择面板
  void _showPresetPicker(
    BuildContext context,
    AiConfig ai,
    void Function(AiEndpoint) saveEndpoint,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final current = ai.currentEndpoint.baseUrl.trimRight();
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text('选择 AI 服务商', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    ...kAiPresets.map((preset) {
                      final isSelected = preset.baseUrl == current;
                      return ListTile(
                        leading: Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        ),
                        title: Text(preset.name,
                          style: isSelected
                            ? TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)
                            : null,
                        ),
                        subtitle: Text(preset.hint, style: const TextStyle(fontSize: 12)),
                        trailing: Text(
                          preset.mode == AiApiMode.geminiNative ? 'Gemini 原生' : 'OpenAI 兼容',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        onTap: () {
                          saveEndpoint(ai.currentEndpoint.copyWith(
                            name: preset.name,
                            baseUrl: preset.baseUrl,
                            mode: preset.mode,
                            model: preset.defaultModel,
                          ));
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                    // 自定义选项
                    ListTile(
                      leading: Icon(
                        _matchPresetName(ai.currentEndpoint.baseUrl) == null
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                        color: _matchPresetName(ai.currentEndpoint.baseUrl) == null
                          ? Theme.of(context).colorScheme.primary : null,
                      ),
                      title: const Text('其他 OpenAI 兼容接口'),
                      subtitle: const Text('手动填写 Base URL', style: TextStyle(fontSize: 12)),
                      onTap: () => Navigator.pop(ctx),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── 旧词库迁移按钮（独立 StatefulWidget，自管理进度状态）────────────
class _MigrateButton extends StatefulWidget {
  const _MigrateButton();
  @override
  State<_MigrateButton> createState() => _MigrateButtonState();
}

class _MigrateButtonState extends State<_MigrateButton> {
  bool _working = false;
  String _status = "";

  /// 统计当前有多少词是旧格式（source 为空）
  int get _pendingCount => AppData().wordData.words
      .where((w) => w.meanings.length == 1 && w.meanings[0].source.isEmpty)
      .length;

  Future<void> _doMigrate() async {
    setState(() { _working = true; _status = "正在连接在线词库..."; });

    // 1. 收集已导入的词库文件名集合
    final Set<String> importedSources = AppData().wordData.classes
        .map((s) => s.sourceJsonFileName)
        .toSet();

    // 2. 尝试从 GitHub 获取在线词库列表
    List<Map<String, String>> toReimport = []; // [{name, download_url}]
    try {
      final Dio dio = Dio();
      final response = await dio.getUri(
        Uri.parse("https://api.github.com/repos/${StaticsVar.onlineDictOwner}/Arabiclearning/contents/词库"),
      );
      if (response.statusCode == 200) {
        final List<dynamic> files = response.data as List<dynamic>;
        for (final f in files) {
          if (f["type"] == "file" && importedSources.contains(f["name"] as String)) {
            toReimport.add({"name": f["name"] as String, "url": f["download_url"] as String});
          }
        }
      }
    } catch (_) {
      // 网络失败时 fallback
      toReimport.clear();
    }

    if (toReimport.isEmpty) {
      // ── Fallback：无网络或在线没有对应词库，原地填充 source 字段 ──
      if (!mounted) return;
      setState(() { _status = "网络不可用，正在原地迁移..."; });
      final int count = AppData().migrateOldWordData();
      if (!mounted) return;
      setState(() { _working = false; _status = ""; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(count > 0 ? "原地迁移完成，补充了 $count 个词的来源信息。" : "无需迁移，数据已是最新格式。"),
        duration: const Duration(seconds: 4),
      ));
      return;
    }

    // 3. 逐个重新下载并导入（dataFormater 对已存在的词只追加 meaning，不改索引）
    final Dio dio = Dio();
    int reimportedCount = 0;
    for (int i = 0; i < toReimport.length; i++) {
      final item = toReimport[i];
      if (!mounted) return;
      setState(() { _status = "重新导入 ${item['name']} (${i + 1}/${toReimport.length})..."; });
      try {
        final res = await dio.getUri(Uri.parse(item["url"]!));
        if (res.statusCode == 200) {
          AppData().importDictData(
            jsonDecode(res.data is String ? res.data : jsonEncode(res.data)) as Map<String, dynamic>,
            item["name"]!,
          );
          reimportedCount++;
        }
      } catch (e) {
        AppData().logger.warning("重新导入 ${item['name']} 失败: $e");
      }
    }

    if (!mounted) return;
    setState(() { _working = false; _status = ""; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("在线重新导入完成，共更新了 $reimportedCount 个词库，一词多义已更新。"),
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final int pending = _pendingCount;
    // 迁移完成后隐藏按钮
    if (pending == 0 && !_working) return const SizedBox.shrink();

    final MediaQueryData mediaQuery = MediaQuery.of(context);

    if (_working) {
      return Container(
        height: mediaQuery.size.height * 0.07,
        alignment: Alignment.center,
        color: Theme.of(context).colorScheme.tertiaryContainer.withAlpha(180),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(_status, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
        backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
        shape: const BeveledRectangleBorder(),
      ),
      icon: const Icon(Icons.cloud_sync),
      label: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("更新旧词库数据（兼容一词多义）"),
          Text(
            "检测到 $pending 个词缺少来源信息，点击从在线词库重新导入以支持多义。",
            style: TextStyle(fontSize: 10.0, color: Colors.grey.shade600),
          ),
        ],
      ),
      onPressed: () async {
        final bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("更新旧词库数据"),
            content: Text(
              "检测到 $pending 个词缺少来源信息。\n\n"
              "将优先联网重新下载已导入的词库（约 ${AppData().wordData.classes.length} 个），"
              "以自动补充一词多义数据。\n\n"
              "• FSRS 复习记录完全保留\n"
              "• 词汇索引不会改变\n"
              "• 无网络时自动原地迁移\n\n"
              "确定继续？",
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消")),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("确定")),
            ],
          ),
        );
        if (confirmed != true) return;
        await _doMigrate();
      },
    );
  }
}
