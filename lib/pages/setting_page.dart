import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io';

import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

Widget settingItem(BuildContext context, MediaQueryData mediaQuery, List<Widget> list, String title, {bool withPadding = true}) {
  List<Container> decoratedContainers = list.map((widget) {
    return Container(
      width: mediaQuery.size.width * 0.90,
      //height: mediaQuery.size.height * 0.08,
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
      //height: mediaQuery.size.height * 0.08,
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
      //height: mediaQuery.size.height * 0.08,
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
      //height: mediaQuery.size.height * 0.08,
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
      TextContainer(text: title),
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
      Column(
        children: [
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
              label: Text("文件导入"))
            ],
          ),
        ],
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
              context.read<Global>().updateSetting(set);
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
              context.read<Global>().updateSetting(set);
            },
          ),
          SizedBox(width: mediaQuery.size.width * 0.02),
        ]
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.onPrimary,
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
          backgroundColor: Theme.of(context).colorScheme.onPrimary,
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
          backgroundColor: Theme.of(context).colorScheme.onPrimary,
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
        children: [
          TextContainer(text: "关于"),
          TextContainer(text: "该软件仅供学习使用，请勿用于商业用途。\n该软件基于MIT协议开源，协议原文详见页面底部。", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
                Text("5. 其他在MIT开源协议下的条款"),
              ],
            ),
          ),
          TextContainer(text: "MIT开源协议 / MIT License"),
          TextContainer(text: "该软件通过MIT协议授权给 \"${setting["User"]}\" 使用，协议内容详见下方："),
          TextContainer(text: "MIT License\n\nCopyright (c) 2025 OctagonalStar\n\nPermission is hereby granted, free of charge, to any person obtaining a copy\nof this software and associated documentation files (the \"Software\"), to deal\nin the Software without restriction, including without limitation the rights\nto use, copy, modify, merge, publish, distribute, sublicense, and/or sell\ncopies of the Software, and to permit persons to whom the Software is\nfurnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all\ncopies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\nIMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\nFITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\nAUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\nLIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\nOUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\nSOFTWARE.\n")
        ],
      ),
    );
  }
}

class ModelDownload extends StatelessWidget { 
  const ModelDownload({super.key});
  @override
  Widget build(BuildContext context) {
    bool isDownloading = false;
    String progress = "获取中";
    return Scaffold(
      appBar: AppBar(
        title: const Text('模型下载'),
      ),
      body: ListView(
        children: [
          TextContainer(text: "使用基于ViTS的文本转语音模型\n下载后会占用本地约60MB的存储空间"),
          TextContainer(text: "一旦开始下载，请勿退出此页面; 若在解压时提示软件无响应，属于正常情况，请选择等待", style: TextStyle(color: Colors.redAccent),),
          StatefulBuilder(
            builder: (context, setLocalState) {
              return ElevatedButton.icon(
                icon: Icon(progress == "已完成" ? Icons.download_done : Icons.download),
                label: Text(isDownloading ? progress : "开始下载"),
                style: ElevatedButton.styleFrom(
                  fixedSize: Size(double.infinity, 100),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(25.0))
                ),
                onPressed: () async{
                  if(isDownloading) return;
                  var basePath = await getApplicationDocumentsDirectory();
                  if(File("${basePath.path}/${StaticsVar.modelPath}/ar_JO-kareem-medium.onnx").existsSync() && context.mounted){
                    alart(context, "模型已存在");
                    return;
                  }
                  setLocalState(() {
                    isDownloading = true;
                  });
                  try {
                    await downloadFile('https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-ar_JO-kareem-medium.tar.bz2', '${basePath.path}/arabicLearning/tts/temp.tar.bz2', onDownloading: (count, total){setLocalState((){progress = count == total ? "解压中" : "$count/$total";});});
                  } catch (e) {
                    if(!context.mounted) return;
                    alart(context, "下载失败\n${e.toString()}");
                    return;
                  }
                  await extractTarBz2('${basePath.path}/arabicLearning/tts/temp.tar.bz2', "${basePath.path}/arabicLearning/tts/model/");
                  if(!context.mounted) return;
                  context.read<Global>().loadTTS();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("下载完成")));
                  setLocalState(
                    () {
                      progress = "已完成\n重启软件后可生效";
                      context.read<Global>().modelTTSDownloaded = true;
                    }
                  );
                  if(File('${basePath.path}/arabicLearning/tts/temp.tar.bz2').existsSync()){
                    File('${basePath.path}/arabicLearning/tts/temp.tar.bz2').delete();
                  }
                }, 
              );
            }
          ),
          SizedBox(height: 20),
          ExpansionTile(
            title: Text("使用接口及模型的开源信息"),
            children: [
              TextContainer(text: "接口开源地址: https://github.com/k2-fsa/sherpa-onnx/"),
              TextContainer(text: '接口授权许可: Apache-2.0\n                                 Apache License\n                           Version 2.0, January 2004\n                        http://www.apache.org/licenses/\n   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION\n   1. Definitions.\n      "License" shall mean the terms and conditions for use, reproduction,\n      and distribution as defined by Sections 1 through 9 of this document.\n      "Licensor" shall mean the copyright owner or entity authorized by\n      the copyright owner that is granting the License.\n      "Legal Entity" shall mean the union of the acting entity and all\n      other entities that control, are controlled by, or are under common\n      control with that entity. For the purposes of this definition,\n      "control" means (i) the power, direct or indirect, to cause the\n      direction or management of such entity, whether by contract or\n      otherwise, or (ii) ownership of fifty percent (50%) or more of the\n      outstanding shares, or (iii) beneficial ownership of such entity.\n      "You" (or "Your") shall mean an individual or Legal Entity\n      exercising permissions granted by this License.\n      "Source" form shall mean the preferred form for making modifications,\n      including but not limited to software source code, documentation\n      source, and configuration files.\n      "Object" form shall mean any form resulting from mechanical\n      transformation or translation of a Source form, including but\n      not limited to compiled object code, generated documentation,\n      and conversions to other media types.\n      "Work" shall mean the work of authorship, whether in Source or\n      Object form, made available under the License, as indicated by a\n      copyright notice that is included in or attached to the work\n      (an example is provided in the Appendix below).\n      "Derivative Works" shall mean any work, whether in Source or Object\n      form, that is based on (or derived from) the Work and for which the\n      editorial revisions, annotations, elaborations, or other modifications\n      represent, as a whole, an original work of authorship. For the purposes\n      of this License, Derivative Works shall not include works that remain\n      separable from, or merely link (or bind by name) to the interfaces of,\n      the Work and Derivative Works thereof.\n      "Contribution" shall mean any work of authorship, including\n      the original version of the Work and any modifications or additions\n      to that Work or Derivative Works thereof, that is intentionally\n      submitted to Licensor for inclusion in the Work by the copyright owner\n      or by an individual or Legal Entity authorized to submit on behalf of\n      the copyright owner. For the purposes of this definition, "submitted"\n      means any form of electronic, verbal, or written communication sent\n      to the Licensor or its representatives, including but not limited to\n      communication on electronic mailing lists, source code control systems,\n      and issue tracking systems that are managed by, or on behalf of, the\n      Licensor for the purpose of discussing and improving the Work, but\n      excluding communication that is conspicuously marked or otherwise\n      designated in writing by the copyright owner as "Not a Contribution."\n      "Contributor" shall mean Licensor and any individual or Legal Entity\n      on behalf of whom a Contribution has been received by Licensor and\n      subsequently incorporated within the Work.\n   2. Grant of Copyright License. Subject to the terms and conditions of\n      this License, each Contributor hereby grants to You a perpetual,\n      worldwide, non-exclusive, no-charge, royalty-free, irrevocable\n      copyright license to reproduce, prepare Derivative Works of,\n      publicly display, publicly perform, sublicense, and distribute the\n      Work and such Derivative Works in Source or Object form.\n   3. Grant of Patent License. Subject to the terms and conditions of\n      this License, each Contributor hereby grants to You a perpetual,\n      worldwide, non-exclusive, no-charge, royalty-free, irrevocable\n      (except as stated in this section) patent license to make, have made,\n      use, offer to sell, sell, import, and otherwise transfer the Work,\n      where such license applies only to those patent claims licensable\n      by such Contributor that are necessarily infringed by their\n      Contribution(s) alone or by combination of their Contribution(s)\n      with the Work to which such Contribution(s) was submitted. If You\n      institute patent litigation against any entity (including a\n      cross-claim or counterclaim in a lawsuit) alleging that the Work\n      or a Contribution incorporated within the Work constitutes direct\n      or contributory patent infringement, then any patent licenses\n      granted to You under this License for that Work shall terminate\n      as of the date such litigation is filed.\n   4. Redistribution. You may reproduce and distribute copies of the\n      Work or Derivative Works thereof in any medium, with or without\n      modifications, and in Source or Object form, provided that You\n      meet the following conditions:\n      (a) You must give any other recipients of the Work or\n          Derivative Works a copy of this License; and\n      (b) You must cause any modified files to carry prominent notices\n          stating that You changed the files; and\n      (c) You must retain, in the Source form of any Derivative Works\n          that You distribute, all copyright, patent, trademark, and\n          attribution notices from the Source form of the Work,\n          excluding those notices that do not pertain to any part of\n          the Derivative Works; and\n      (d) If the Work includes a "NOTICE" text file as part of its\n          distribution, then any Derivative Works that You distribute must\n          include a readable copy of the attribution notices contained\n          within such NOTICE file, excluding those notices that do not\n          pertain to any part of the Derivative Works, in at least one\n          of the following places: within a NOTICE text file distributed\n          as part of the Derivative Works; within the Source form or\n          documentation, if provided along with the Derivative Works; or,\n          within a display generated by the Derivative Works, if and\n          wherever such third-party notices normally appear. The contents\n          of the NOTICE file are for informational purposes only and\n          do not modify the License. You may add Your own attribution\n          notices within Derivative Works that You distribute, alongside\n          or as an addendum to the NOTICE text from the Work, provided\n          that such additional attribution notices cannot be construed\n          as modifying the License.\n      You may add Your own copyright statement to Your modifications and\n      may provide additional or different license terms and conditions\n      for use, reproduction, or distribution of Your modifications, or\n      for any such Derivative Works as a whole, provided Your use,\n      reproduction, and distribution of the Work otherwise complies with\n      the conditions stated in this License.\n   5. Submission of Contributions. Unless You explicitly state otherwise,\n      any Contribution intentionally submitted for inclusion in the Work\n      by You to the Licensor shall be under the terms and conditions of\n      this License, without any additional terms or conditions.\n      Notwithstanding the above, nothing herein shall supersede or modify\n      the terms of any separate license agreement you may have executed\n      with Licensor regarding such Contributions.\n   6. Trademarks. This License does not grant permission to use the trade\n      names, trademarks, service marks, or product names of the Licensor,\n      except as required for reasonable and customary use in describing the\n      origin of the Work and reproducing the content of the NOTICE file.\n   7. Disclaimer of Warranty. Unless required by applicable law or\n      agreed to in writing, Licensor provides the Work (and each\n      Contributor provides its Contributions) on an "AS IS" BASIS,\n      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or\n      implied, including, without limitation, any warranties or conditions\n      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A\n      PARTICULAR PURPOSE. You are solely responsible for determining the\n      appropriateness of using or redistributing the Work and assume any\n      risks associated with Your exercise of permissions under this License.\n   8. Limitation of Liability. In no event and under no legal theory,\n      whether in tort (including negligence), contract, or otherwise,\n      unless required by applicable law (such as deliberate and grossly\n      negligent acts) or agreed to in writing, shall any Contributor be\n      liable to You for damages, including any direct, indirect, special,\n      incidental, or consequential damages of any character arising as a\n      result of this License or out of the use or inability to use the\n      Work (including but not limited to damages for loss of goodwill,\n      work stoppage, computer failure or malfunction, or any and all\n      other commercial damages or losses), even if such Contributor\n      has been advised of the possibility of such damages.\n   9. Accepting Warranty or Additional Liability. While redistributing\n      the Work or Derivative Works thereof, You may choose to offer,\n      and charge a fee for, acceptance of support, warranty, indemnity,\n      or other liability obligations and/or rights consistent with this\n      License. However, in accepting such obligations, You may act only\n      on Your own behalf and on Your sole responsibility, not on behalf\n      of any other Contributor, and only if You agree to indemnify,\n      defend, and hold each Contributor harmless for any liability\n      incurred by, or claims asserted against, such Contributor by reason\n      of your accepting any such warranty or additional liability.\n   END OF TERMS AND CONDITIONS\n   APPENDIX: How to apply the Apache License to your work.\n      To apply the Apache License to your work, attach the following\n      boilerplate notice, with the fields enclosed by brackets "[]"\n      replaced with your own identifying information. (Don\'t include\n      the brackets!)  The text should be enclosed in the appropriate\n      comment syntax for the file format. We also recommend that a\n      file or class name and description of purpose be included on the\n      same "printed page" as the copyright notice for easier\n      identification within third-party archives.\n   Copyright [yyyy] [name of copyright owner]\n   Licensed under the Apache License, Version 2.0 (the "License");\n   you may not use this file except in compliance with the License.\n   You may obtain a copy of the License at\n       http://www.apache.org/licenses/LICENSE-2.0\n   Unless required by applicable law or agreed to in writing, software\n   distributed under the License is distributed on an "AS IS" BASIS,\n   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n   See the License for the specific language governing permissions and\n   limitations under the License.\n'),
              TextContainer(text: "模型开源地址: https://huggingface.co/rhasspy/piper-voices/tree/main/ar/ar_JO/kareem"),
              TextContainer(text: '接口授权许可: MIT License\nMIT License\nCopyright (c) [year] [fullname]\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:\nThe above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.\nTHE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.'),
            ],
          )
                  ],
      )
    );
  }
}