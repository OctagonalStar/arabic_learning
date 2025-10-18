import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;

import 'package:arabic_learning/global.dart';
import 'package:arabic_learning/statics_var.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

Widget settingItem(BuildContext context, MediaQueryData mediaQuery, List<Widget> list, String title, {bool withPadding = true}) {
  List<Container> decoratedContainers = list.map((widget) {
    return Container(
      width: mediaQuery.size.width * 0.90,
      height: mediaQuery.size.height * 0.08,
      // margin: container.margin,
      padding: withPadding ? EdgeInsets.all(8.0) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary,
        borderRadius: BorderRadius.all(Radius.circular(5.0)),
      ),
      child: widget,
    );
  }).toList();
  if(decoratedContainers.length > 1){
    decoratedContainers[0] = Container(
      width: mediaQuery.size.width * 0.90,
      height: mediaQuery.size.height * 0.08,
      margin: decoratedContainers[0].margin,
      padding: decoratedContainers[0].padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0), bottom: Radius.circular(5.0)),
      ),
      child: decoratedContainers[0].child,
    );
    decoratedContainers[decoratedContainers.length - 1] = Container(
      width: mediaQuery.size.width * 0.90,
      height: mediaQuery.size.height * 0.08,
      margin: decoratedContainers[decoratedContainers.length - 1].margin,
      padding: decoratedContainers[decoratedContainers.length - 1].padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(25.0), top: Radius.circular(5.0)),
      ),
      child: decoratedContainers[decoratedContainers.length - 1].child,
    );
  } else {
    decoratedContainers[0] = Container(
      width: mediaQuery.size.width * 0.90,
      height: mediaQuery.size.height * 0.08,
      margin: decoratedContainers[0].margin,
      padding: decoratedContainers[0].padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary,
        borderRadius: BorderRadius.all(Radius.circular(25.0)),
      ),
      child: decoratedContainers[0].child,
    );
  }
  //Add Sizedbox between each item in list
  List<Widget> newList = [];
  for (var i = 0; i < decoratedContainers.length; i++) {
    newList.add(decoratedContainers[i]);
    if (i != decoratedContainers.length - 1) {
      newList.add(SizedBox(height: mediaQuery.size.height * 0.005));
    }
  }
  return Column(
    mainAxisAlignment: MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        margin: EdgeInsets.all(16.0),
        padding: EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onPrimary,
          borderRadius: StaticsVar.br,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      Center(
        child: Column(
          children: newList,
        ),
      ),
    ]
  );
}



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
            settingItem(context, mediaQuery, dataSetting(mediaQuery, context, setting), "数据设置"),
            settingItem(context, mediaQuery, audioSetting(mediaQuery, context, setting), "音频设置"),
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
              DropdownMenuItem(value: 10, child: Text('星青')),
              DropdownMenuItem(value: 11, child: Text('淡绿')),
            ],
            onChanged: (value) async {
              setting['regular']['theme'] = value;
              Provider.of<Global>(context, listen: false).updateSetting(setting);
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
              Provider.of<Global>(context, listen: false).updateSetting(setting);
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
              DropdownMenuItem(value: 0, child: Text('默认')),
              DropdownMenuItem(value: 1, child: Text('备用字体')),
            ],
            onChanged: (value) {
              setting['regular']['font'] = value;
              Provider.of<Global>(context, listen: false).updateSetting(setting);
            },
          )
        ]
      ),
    ];
  }
  List<Widget> dataSetting(MediaQueryData mediaQuery, BuildContext context, Map<String, dynamic> setting) {
    return [
      Row(
        children: [
          Icon(Icons.download, size: 24.0),
          SizedBox(width: mediaQuery.size.width * 0.01),
          Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Text("导入词库数据"),
              Text("词库中现有: ${Provider.of<Global>(context, listen: false).wordCount}", 
                      style: TextStyle(fontSize: 8.0, color: Colors.grey))
            ],
          )),
          SizedBox(
            width: mediaQuery.size.width * 0.55,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => DownloadPage()));
                    },
                    icon: Icon(Icons.cloud_download),
                    label: Text("从线上下载词库")
                  ),
                  SizedBox(width: mediaQuery.size.width * 0.01),
                  ElevatedButton.icon(
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
                          jsonString = await File(platformFile.path!).readAsString();
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
                  label: Text("从文件导入"))
                ],
              ),
            ),
          ),
        ],
      )
    ];
  }

  List<Widget> audioSetting(MediaQueryData mediaQuery, BuildContext context, Map<String, dynamic> setting) {
    var set = context.read<Global>().settingData;
    return [
      Row(
        children: [
          Icon(Icons.api, size: 24.0),
          SizedBox(width: mediaQuery.size.width * 0.01),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentGeometry.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("使用备用文本转语音接口"),
                  Text("默认使用系统自带的文本转语音接口，但有些厂商可能没有阿拉伯语支持\n启用会请求\"TextReadTTS.com\"的音频，但其发音符号支持不佳", style: TextStyle(fontSize: 8.0, color: Colors.grey)),
                ],
              ),
            ),
          ),
          Switch(
            value: set["audio"]["useBackupSource"], 
            onChanged: (value) {
              set["audio"]["useBackupSource"] = value;
              context.read<Global>().updateSetting(set);
            }
          ),
        ],
      ),
      Row(
        children: [
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
              context.read<Global>().updateSetting(set);
            },
          ),
        ]
      )
    ];
  }

  List<Widget> aboutSetting(MediaQueryData mediaQuery, BuildContext context, Map<String, dynamic> setting) {
    return [
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
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

class DownloadPage extends StatelessWidget {
  const DownloadPage({super.key});
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("下载在线词库"),
      ),
      body: FutureBuilder(
        future: downloadList(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || snapshot.data == null) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
          return ListView(
            children: [
              settingItem(context, mediaQuery, snapshot.data!, "来自 Github @${StaticsVar.onlineDictOwner} 学长的词库 (在此表示感谢)")
            ],
          );
        }
      )
    );
  }
}

Future<List<Widget>> downloadList(BuildContext context) async{
  var list = <Widget>[];
  var githubResponse = await http.get(Uri.parse("https://api.github.com/repos/${StaticsVar.onlineDictOwner}/${StaticsVar.onlineDictRepo}/contents/${StaticsVar.onlineDictPath}"));
  if(githubResponse.statusCode != 200) {
    return [
      Text("无法获取词库列表，请检查你的网络链接或稍后重试"),
      Text("回复错误码：${githubResponse.statusCode}"),
      SelectableText("调试信息：${githubResponse.body}"),
    ];
  }
  var json = jsonDecode(githubResponse.body) as List<dynamic>;
  if(!context.mounted) return [Text("无法获取词库列表，请检查你的网络链接或稍后重试"),];
  for(var f in json) {
    if(f["type"] == "file") {
      bool downloaded = context.read<Global>().wordData["Classes"].keys.contains(f["name"]);
      bool inDownloading = false;
      list.add(StatefulBuilder(
        builder: (context, setLocalState) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text(f["name"])),
              inDownloading ? CircularProgressIndicator() 
                            : ElevatedButton.icon(
                icon: Icon(downloaded ? Icons.done : Icons.download),
                label: Text(downloaded ? "已下载" : "下载"),
                onPressed: () async { 
                  if(downloaded) return;
                  setLocalState(() {
                    inDownloading = true;
                  });
                  try {
                    var response = await http.get(Uri.parse(f["download_url"]));
                    if(!context.mounted) return ;
                    if(response.statusCode == 200) {
                      context.read<Global>().importData(jsonDecode(response.body) as Map<String, dynamic>, f["name"]);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("下载成功: ${f["name"]}"),
                      ));
                      setLocalState(() {
                        inDownloading = false;
                        downloaded = true;
                      });
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("下载失败\n${e.toString()}"),
                    ));
                    setLocalState(() {
                      inDownloading = false;
                      downloaded = false;
                    });
                  }
                },
              ),
            ],
          );
        }
      ));
    }
  }
  return list;
}

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
        // mainAxisAlignment: MainAxisAlignment.start,
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.all(8.0),
            padding: EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimary,
              borderRadius: StaticsVar.br,
            ),
            child: Text(
              "关于",
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.all(8.0),
            padding: EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSecondary,
              borderRadius: StaticsVar.br,
            ),
            child: Text("该软件仅供学习使用，请勿用于商业用途。\n该软件基于MIT协议开源，协议原文详见页面底部。", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
          Container(
            margin: EdgeInsets.all(8.0),
            padding: EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSecondary,
              borderRadius: StaticsVar.br,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text("目前该软件仅由 OctagonalStar(别问为什么写网名) 一人开发（其实主要是为了学flutter框架写的），如果有什么问题或者提议都欢迎提issue（或者线下真实？）。"),
                Text("该软件 <Ar 学>，主要是为了帮助大家掌握阿语词汇（毕竟上课词汇都要听晕了）"),
              ],
            ),
          ),
          Container(
            margin: EdgeInsets.all(8.0),
            padding: EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimary,
              borderRadius: StaticsVar.br,
            ),
            child: Text(
              "免责声明",
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
                Text("5. 其他在MIT开源协议下的条款"),
              ],
            ),
          ),
          Container(
            margin: EdgeInsets.all(8.0),
            padding: EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimary,
              borderRadius: StaticsVar.br,
            ),
            child: Text(
              "MIT开源协议 / MIT License",
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
                Text("该软件通过MIT协议授权给 \"${setting["User"]}\" 使用，协议内容详见下方："),
              ],
            ),
          ),
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
                Text("MIT License\n\nCopyright (c) 2025 OctagonalStar\n\nPermission is hereby granted, free of charge, to any person obtaining a copy\nof this software and associated documentation files (the \"Software\"), to deal\nin the Software without restriction, including without limitation the rights\nto use, copy, modify, merge, publish, distribute, sublicense, and/or sell\ncopies of the Software, and to permit persons to whom the Software is\nfurnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all\ncopies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\nIMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\nFITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\nAUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\nLIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\nOUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\nSOFTWARE.\n"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}