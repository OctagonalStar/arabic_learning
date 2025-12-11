import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/sub_pages_builder/setting_pages/item_widget.dart';
import 'package:arabic_learning/sub_pages_builder/setting_pages/about_page.dart' show AboutPage;
import 'package:arabic_learning/sub_pages_builder/setting_pages/data_download_page.dart' show DownloadPage;
import 'package:arabic_learning/sub_pages_builder/setting_pages/model_download_page.dart' show ModelDownload;
import 'package:arabic_learning/sub_pages_builder/setting_pages/questions_setting_page.dart' show QuestionsSettingLeadingPage;
import 'package:arabic_learning/sub_pages_builder/setting_pages/sync_page.dart' show DataSyncPage;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;

class SettingPage extends StatefulWidget { 
  const SettingPage({super.key});
  @override
  State<SettingPage> createState() => _SettingPage();
}

class _SettingPage extends State<SettingPage> {
  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 SettingPage");
    return Scaffold(
      appBar: AppBar(title: Text("设置")),
      body: Consumer<Global>(
        builder: (context, value, child) {
          return ListView(
            children: [
              SettingItem(
                title: "常规设置",
                padding: EdgeInsets.all(8.0),
                children: regularSetting(context, value.settingData),
              ),
              SettingItem(
                title: "学习设置", 
                children: dataSetting(context, value.settingData), 
              ),
              SettingItem(
                title: "音频设置", 
                children: audioSetting(context, value.settingData), 
              ),
              SettingItem(
                title: "关于", 
                children: aboutSetting(context, value.settingData), 
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> regularSetting(BuildContext context, Map<String, dynamic> setting) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return  [
      Row(
        children: [
          Icon(Icons.color_lens, size: 24.0),
          SizedBox(width: mediaQuery.size.width * 0.01),
          Expanded(child: Text("主题颜色:")),
          DropdownButton<int>(
            value: setting['regular']['theme'] ?? 1,
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
              setting['regular']['theme'] = value;
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
            value: setting['regular']['darkMode'] ?? false,
            onChanged: (value) {
              context.read<Global>().uiLogger.info("更新深色模式设置: $value");
              setting['regular']['darkMode'] = value;
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
            value: setting['regular']['font'] ?? 0,
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
              setting['regular']['font'] = value;
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
            value: setting['regular']['hideAppDownloadButton'] ?? false,
            onChanged: (value) {
              context.read<Global>().uiLogger.info("更新网页端APP下载按钮隐藏设置: $value");
              setting['regular']['hideAppDownloadButton'] = value;
              context.read<Global>().updateSetting();
            },
          )
        ],
      ),
    ];
  }
  
  List<Widget> dataSetting(BuildContext context, Map<String, dynamic> setting) {
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
              Text("词库中现有: ${context.read<Global>().wordCount}"),
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
                  FilePickerResult? result = await FilePicker.platform.pickFiles(
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
                      Provider.of<Global>(context, listen: false).importData(jsonData, platformFile.name);
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
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          shape: BeveledRectangleBorder()
        ),
        onPressed: (){
          context.read<Global>().uiLogger.info("跳转: SettingPage => QuestionsSettingLeadingPage");
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => QuestionsSettingLeadingPage()));
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

  List<Widget> audioSetting(BuildContext context, Map<String, dynamic> setting) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    var set = context.read<Global>().settingData;
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
            value: set["audio"]["useBackupSource"], 
            onChanged: (value) {
              context.read<Global>().uiLogger.info("更新音频接口: $value");
              if(value == 1) alart(context, "警告: \n来自\"TextReadTTS.com\"的音频不支持发音符号，且只能合成40字以内的文本。\n开启此功能请知悉。");
              set["audio"]["useBackupSource"] = value;
              context.read<Global>().updateSetting();
            },
            items: [
              DropdownMenuItem(value: 0, child: Text("系统文本转语音", overflow: TextOverflow.ellipsis,)),
              DropdownMenuItem(value: 1, child: Text("请求TextReadTTS.com的语音", overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 2, enabled: kIsWeb ? false : (context.read<Global>().modelTTSDownloaded ? true : false), child: Text("神经网络合成语音", overflow: TextOverflow.ellipsis, style: TextStyle(color: kIsWeb ? Colors.grey : (context.read<Global>().modelTTSDownloaded ? null : Colors.grey))),),
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
            value: set["audio"]["playRate"],
            min: 0.5,
            max: 1.5,
            divisions: 10,
            label: "${set["audio"]["playRate"]}",
            onChanged: (value) {
              setState(() {
                set["audio"]["playRate"] = value;
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

  List<Widget> aboutSetting(BuildContext context, Map<String, dynamic> setting) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return [
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(top: Radius.circular(25.0))),
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
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => AboutPage(setting: setting,)));
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
}
