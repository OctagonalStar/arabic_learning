import 'dart:convert';
import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/sub_pages_builder/setting_pages/about_page.dart' show AboutPage;
import 'package:arabic_learning/sub_pages_builder/setting_pages/data_download_page.dart' show DownloadPage;
import 'package:arabic_learning/sub_pages_builder/setting_pages/item_widget.dart';
import 'package:arabic_learning/sub_pages_builder/setting_pages/model_download_page.dart' show ModelDownload;
import 'package:arabic_learning/sub_pages_builder/setting_pages/questions_setting_page.dart' show QuestionsSettingLeadingPage;
import 'package:arabic_learning/vars/global.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;

class SettingPage extends StatefulWidget { 
  const SettingPage({super.key});
  @override
  State<SettingPage> createState() => _SettingPage();
}

class _SettingPage extends State<SettingPage> {
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Consumer<Global>(
      builder: (context, value, child) {
        var setting = value.settingData;
        return ListView(
          children: [
            settingItem(context, mediaQuery, regularSetting(mediaQuery, context, setting), "常规设置"),
            settingItem(context, mediaQuery, dataSetting(mediaQuery, context, setting), "学习设置", withPadding: false),
            settingItem(context, mediaQuery, audioSetting(mediaQuery, context, setting), "音频设置", withPadding: false),
            settingItem(context, mediaQuery, aboutSetting(mediaQuery, context, setting), "关于", withPadding: false),
          ],
        );
      },
    );
  }

  List<Widget> regularSetting(MediaQueryData mediaQuery, BuildContext context, Map<String, dynamic> setting) {
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
              setting['regular']['theme'] = value;
              Provider.of<Global>(context, listen: false).updateSetting();
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
              setting['regular']['hideAppDownloadButton'] = value;
              context.read<Global>().updateSetting();
            },
          )
        ],
      ),
    ];
  }
  
  List<Widget> dataSetting(MediaQueryData mediaQuery, BuildContext context, Map<String, dynamic> setting) {
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
                      showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('错误'),
                          content: Text("文件 \"${platformFile.name}\" \n无法读取：bytes和path均为null。"),
                          actions: <Widget>[
                            TextButton(
                              child: Text('好吧'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            TextButton(
                              child: Text('行吧'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      },
                      );
                      return;
                    }
                    try{
                      if (!context.mounted) return;
                      Map<String, dynamic> jsonData = json.decode(jsonString);
                      Provider.of<Global>(context, listen: false).importData(jsonData, platformFile.name);
                      showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('完成'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("文件 \"${platformFile.name}\" \n已导入。"),
                              Text("少数情况下无法即时刷新词汇总量，可稍后再到设置页面查看~", style: TextStyle(fontSize: 8.0, color: Colors.grey))
                            ],
                          ),
                          actions: <Widget>[
                            TextButton(
                              child: Text('好的'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      },
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('错误'),
                            content: Text('文件 ${platformFile.name} 无效：\n$e'),
                            actions: <Widget>[
                              TextButton(
                                child: Text('好吧'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                              TextButton(
                                child: Text('行吧'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          );
                        }
                      );
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(bottom: Radius.circular(25.0)))
        ),
        onPressed: (){
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => QuestionsSettingLeadingPage()));
        }, 
        child: Row(
          children: [
            Icon(Icons.quiz),
            Expanded(child: Text("题型配置")),
            Icon(Icons.arrow_forward_ios)
          ],
        )
      )
    ];
  }

  List<Widget> audioSetting(MediaQueryData mediaQuery, BuildContext context, Map<String, dynamic> setting) {
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

  List<Widget> aboutSetting(MediaQueryData mediaQuery, BuildContext context, Map<String, dynamic> setting) {
    return [
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(top: Radius.circular(25.0))),
        ),
        onPressed: () {
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
