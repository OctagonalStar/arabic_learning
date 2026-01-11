import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/sub_pages_builder/setting_pages/item_widget.dart';
import 'package:arabic_learning/funcs/sync.dart';
import 'package:arabic_learning/vars/config_structure.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;

class DataSyncPage extends StatefulWidget {
  const DataSyncPage({super.key});

  @override
  State<StatefulWidget> createState() => _DataSyncPage();
}

class _DataSyncPage extends State<DataSyncPage> {
  bool? enabled;
  bool isUploading = false;
  bool isDownloading = false;

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 DataSyncPage");
    enabled ??= context.read<Global>().globalConfig.webSync.enabled;
    context.read<Global>().uiLogger.fine("获取WebDAV实例");
    final WebDAV webdav = WebDAV(
      uri: context.read<Global>().globalConfig.webSync.account.uri, 
      user: context.read<Global>().globalConfig.webSync.account.userName,
      password: context.read<Global>().globalConfig.webSync.account.passWord
    );
    MediaQueryData mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("同步设置"),
      ),
      body: ListView(
        children: [
          TextContainer(text: "该功能还处在预览阶段", style: TextStyle(color: Colors.redAccent)),
          SettingItem(
            title: "远程",
            padding: EdgeInsets.all(8.0),
            children: [
              Row(
                children: [
                  Icon(Icons.account_box, size: 36),
                  Expanded(
                    child: Text("WebDAV账户"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
                    ),
                    onPressed: () async {
                      await popAccountSetting(context);
                      setState(() {});
                    }, 
                    child: Text("绑定")
                  ),
                ],
              ),
              Row(
                children: [
                  Text("联通性检查: "),
                  if(context.read<Global>().globalConfig.webSync.account.uri.isEmpty) Text("未绑定", style: Theme.of(context).textTheme.labelSmall),
                  FutureBuilder(
                    future: WebDAV.test(
                      context.read<Global>().globalConfig.webSync.account.uri, 
                      context.read<Global>().globalConfig.webSync.account.userName,
                      password: context.read<Global>().globalConfig.webSync.account.passWord
                    ), 
                    builder: (context, snapshot) {
                      if(snapshot.hasError) {
                        return Row(
                          children: [
                            Icon(Icons.circle, color: Colors.redAccent, size: 18),
                            Text("在测试中遇到了未知的异常", style: TextStyle(fontSize: 8))
                          ],
                        );
                      }
                      if(snapshot.connectionState == ConnectionState.waiting) {
                        return CircularProgressIndicator();
                      }
                      if(snapshot.hasData) {
                        return Row(
                          children: [
                            Icon(Icons.circle, color: snapshot.data![1] ? Colors.greenAccent : snapshot.data![0] ? Colors.amber : Colors.redAccent, size: 18)
                          ],
                        );
                      }
                      return CircularProgressIndicator();
                    },
                  )
                ],
              ),
              Row(
                children: [
                  Icon(Icons.cloud_upload),
                  SizedBox(width: mediaQuery.size.width * 0.01),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("上传数据"),
                        Text("将本地配置上传到WebDAV服务器", style: TextStyle(color: Colors.grey, fontSize: 8.0))
                      ],
                    )
                  ),
                  isUploading 
                  ? CircularProgressIndicator()
                  :ElevatedButton(
                    onPressed: () async {
                      context.read<Global>().uiLogger.info("用户上传数据");
                      setState(() {
                        isUploading = true;
                      });
                      try{
                        if(!webdav.isReachable) await webdav.connect();
                        if(context.mounted) await webdav.upload(context.read<Global>().prefs);
                      } catch (e) {
                        if(!context.mounted) return;
                        alart(context, e.toString());
                        setState(() {isUploading = false;});
                        return;
                      } 
                      setState(() {isUploading = false;});
                      if(!context.mounted) return;
                      alart(context, "已上传");
                    },
                    child: Text("上传")
                  )
                ],
              ),
              Row(
                children: [
                  Icon(Icons.cloud_download),
                  SizedBox(width: mediaQuery.size.width * 0.01),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("恢复数据"),
                        Text("从WebDAV服务器恢复配置", style: TextStyle(color: Colors.grey, fontSize: 8.0))
                      ],
                    )
                  ),
                  isDownloading 
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: () async {
                      context.read<Global>().uiLogger.info("用户恢复数据");
                      setState(() {
                        isDownloading = true;
                      });
                      try{
                        if(!webdav.isReachable) await webdav.connect();
                        if(context.mounted) await webdav.download(context.read<Global>().prefs);
                        if(context.mounted) context.read<Global>().conveySetting();
                      } catch (e) {
                        if(!context.mounted) return;
                        alart(context, e.toString());
                        setState(() {isDownloading = false;});
                        return;
                      } 
                      if(!context.mounted) return;
                      setState(() {isDownloading = false;});
                      alart(context, "已恢复\n部分设置可能需要软件重启后才能生效");
                    },
                    child: Text("恢复")
                  )
                ],
              )
            ],
          ),
          SettingItem(
            title: "本地", 
            padding: EdgeInsets.all(8.0),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(Icons.output),
                  SizedBox(width: mediaQuery.size.width * 0.01),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("导出数据"),
                        Text("将当前软件数据作为文件导出", style: TextStyle(color: Colors.grey, fontSize: 8.0))
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try{
                        if(await FilePicker.platform.saveFile(
                          dialogTitle: "导出数据",
                          lockParentWindow: true,
                          fileName: "export.json",
                          bytes: utf8.encode(jsonEncode(context.read<Global>().prefs.export())),
                        ) != null) {
                          if(context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text("导出完成"),
                            ));
                          }
                        }
                      } catch (e){
                        if(!context.mounted) return;
                        context.read<Global>().uiLogger.severe(e);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("导出时发生错误: $e"),
                        ));
                      }
                    }, 
                    child: Text("导出")
                  )
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(Icons.input),
                  SizedBox(width: mediaQuery.size.width * 0.01),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("导入数据"),
                        Text("将文件中的配置覆盖软件配置", style: TextStyle(color: Colors.grey, fontSize: 8.0))
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      context.read<Global>().uiLogger.info("导入软件数据");
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
                          context.read<Global>().uiLogger.warning("备份数据导入错误: bytes和path均为null");
                          alart(context, "文件 \"${platformFile.name}\" \n无法读取：bytes和path均为null。");
                          return;
                        }
                        if (!context.mounted) return;
                        try{
                          context.read<Global>().uiLogger.fine("备份数据读取完成，开始解析");
                          context.read<Global>().prefs.recovery(jsonDecode(jsonString));
                          if(context.mounted) context.read<Global>().conveySetting();
                          alart(context, "备份数据 \"${platformFile.name}\" \n已恢复\n部分设置可能需要软件重启后才能生效");
                          context.read<Global>().uiLogger.info("备份数据 \"${platformFile.name}\" \n已导入。");
                        } catch (e) {
                          if (!context.mounted) return;
                          context.read<Global>().uiLogger.severe("文件 ${platformFile.name} 无效: $e");
                          alart(context, '文件 ${platformFile.name} 无效：\n$e');
                        }
                      }
                    }, 
                    child: Text("导入")
                  )
                ],
              ),
            ]
          )
        ],
      ),
    );
  }
}


Future<void> popAccountSetting(BuildContext context) async {
  TextEditingController uriController = TextEditingController();
  TextEditingController accountController = TextEditingController();
  TextEditingController passwdController = TextEditingController(); 
  await showDialog<List<String>>(
    context: context,
    builder: (BuildContext context) {
      uriController.text = context.read<Global>().globalConfig.webSync.account.uri;
      accountController.text = context.read<Global>().globalConfig.webSync.account.userName;
      passwdController.text = context.read<Global>().globalConfig.webSync.account.passWord;
      return AlertDialog(
        title: Text("设置WebDAV同步"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autocorrect: false,
              controller: uriController,
              maxLines: 1,
              decoration: InputDecoration(
                labelText: "WebDAV地址",
                icon: Icon(Icons.webhook),
                border: OutlineInputBorder(
                  borderRadius: StaticsVar.br,
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              autocorrect: false,
              controller: accountController,
              maxLines: 1,
              decoration: InputDecoration(
                labelText: "用户名",
                icon: Icon(Icons.account_box_outlined),
                border: OutlineInputBorder(
                  borderRadius: StaticsVar.br,
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              autocorrect: false,
              controller: passwdController,
              maxLines: 1,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                labelText: "密码",
                icon: Icon(Icons.password),
                border: OutlineInputBorder(
                  borderRadius: StaticsVar.br,
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              uriController.clear();
              accountController.clear();
              passwdController.clear();
            },
            child: Text("清空"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text("取消"),
          ),
          ElevatedButton(
            onPressed: (){
              try{
                Uri.parse(uriController.text);
                if(uriController.text.isNotEmpty && !uriController.text.contains("http")) throw Exception("WebDAV URI must contain http");
              } catch (e) {
                alart(context, e.toString());
                return;
              }
              context.read<Global>().globalConfig = context.read<Global>().globalConfig.copyWith(
                webSync: context.read<Global>().globalConfig.webSync.copyWith(
                  account: SyncAccountConfig(
                    uri: uriController.text,
                    userName: accountController.text,
                    passWord: passwdController.text
                  )
                )
              );
              context.read<Global>().updateSetting();
              Navigator.pop(context);
            }, 
            child: Text("确认")
          ),
        ],
      );
    }
  );
}