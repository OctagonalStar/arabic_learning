import 'dart:convert';
import 'dart:io';

import 'package:arabic_learning/global.dart';
import 'package:arabic_learning/statics_var.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
        return Column(
          children: [
            settingItem(mediaQuery, regularSetting(mediaQuery, context, setting), "常规设置"),
            settingItem(mediaQuery, dataSetting(mediaQuery, context, setting), "数据设置"),
            settingItem(mediaQuery, audioSetting(mediaQuery, context, setting), "音频设置"),
          ],
        );
      },
    );
  }

  Widget settingItem(MediaQueryData mediaQuery, List<Widget> list, String title) {
    List<Container> decoratedContainers = list.map((widget) {
      return Container(
        width: mediaQuery.size.width * 0.90,
        height: mediaQuery.size.height * 0.08,
        // margin: container.margin,
        padding: EdgeInsets.all(8.0),
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
            children: [
              Text("导入词库数据"),
              Text("词库中现有: ${Provider.of<Global>(context, listen: false).wordCount}", 
                      style: TextStyle(fontSize: 8.0, color: Colors.grey))
            ],
          )),
          ElevatedButton(onPressed: () async {
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
              } else if (platformFile.path != null) {
                jsonString = await File(platformFile.path!).readAsString();
              } else {
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
                Map<String, dynamic> jsonData = json.decode(jsonString);
                Provider.of<Global>(context, listen: false).importData(jsonData);
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
          child: Text("选择文件"))
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
              fit: BoxFit.contain,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
              // set["audio"]["playRate"] = value;
              print(value);
              //context.read<Global>().updateSetting(set);
            },
          ),
        ]
      )
    ];
  }
}

