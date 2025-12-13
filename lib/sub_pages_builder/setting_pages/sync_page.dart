import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/sub_pages_builder/setting_pages/item_widget.dart';
import 'package:arabic_learning/funcs/sync.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    enabled ??= context.read<Global>().settingData["sync"]["enabled"];
    context.read<Global>().uiLogger.fine("获取WebDAV实例");
    final WebDAV webdav = WebDAV(
      uri: context.read<Global>().settingData["sync"]["account"]["uri"], 
      user: context.read<Global>().settingData["sync"]["account"]["userName"],
      password: context.read<Global>().settingData["sync"]["account"]["passWord"]
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("同步设置"),
      ),
      body: ListView(
        children: [
          TextContainer(text: "该功能还处在预览阶段", style: TextStyle(color: Colors.redAccent)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      if((context.read<Global>().settingData["sync"]["account"]["uri"] as String).isEmpty) Text("未绑定", style: Theme.of(context).textTheme.labelSmall),
                      FutureBuilder(
                        future: WebDAV.test(
                          context.read<Global>().settingData["sync"]["account"]["uri"], 
                          context.read<Global>().settingData["sync"]["account"]["userName"],
                          password: context.read<Global>().settingData["sync"]["account"]["passWord"]
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
                  )
                ], 
              ),
              StatefulBuilder(
                builder: (context, setLocalState) {
                  return SettingItem(
                    title: "同步",
                    padding: EdgeInsets.all(8.0),
                    children: [
                      Row(
                        children: [
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
                              setLocalState(() {
                                isUploading = true;
                              });
                              try{
                                if(!webdav.isReachable) await webdav.connect();
                                if(context.mounted) await webdav.upload(context.read<Global>().prefs);
                              } catch (e) {
                                if(!context.mounted) return;
                                alart(context, e.toString());
                                setLocalState(() {isUploading = false;});
                                return;
                              } 
                              setLocalState(() {isUploading = false;});
                              if(!context.mounted) return;
                              alart(context, "已上传");
                            },
                            child: Text("上传")
                          )
                        ],
                      ),
                      Row(
                        children: [
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
                              setLocalState(() {
                                isDownloading = true;
                              });
                              try{
                                if(!webdav.isReachable) await webdav.connect();
                                if(context.mounted) await webdav.download(context.read<Global>().prefs);
                                if(context.mounted) context.read<Global>().conveySetting();
                              } catch (e) {
                                if(!context.mounted) return;
                                alart(context, e.toString());
                                setLocalState(() {isDownloading = false;});
                                return;
                              } 
                              if(!context.mounted) return;
                              setLocalState(() {isDownloading = false;});
                              alart(context, "已恢复\n部分设置可能需要软件重启后才能生效");
                            },
                            child: Text("恢复")
                          )
                        ],
                      )
                    ],
                  );
                }
              ),
            ],
          ),
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
      uriController.text = context.read<Global>().settingData["sync"]["account"]["uri"];
      accountController.text = context.read<Global>().settingData["sync"]["account"]["userName"];
      passwdController.text = context.read<Global>().settingData["sync"]["account"]["passWord"];
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
              context.read<Global>().settingData["sync"]["account"]["uri"] = uriController.text;
              context.read<Global>().settingData["sync"]["account"]["userName"] = accountController.text;
              context.read<Global>().settingData["sync"]["account"]["passWord"] = passwdController.text;
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