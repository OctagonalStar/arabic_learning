import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/sub_pages_builder/setting_pages/item_widget.dart';
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

  @override
  Widget build(BuildContext context) {
    enabled ??= context.read<Global>().settingData["sync"]["enabled"];

    return Scaffold(
      appBar: AppBar(
        title: Text("同步设置"),
      ),
      body: ListView(
        children: [
          TextContainer(text: "该功能还处在预览阶段", style: TextStyle(color: Colors.redAccent)),
          SyncRemoteSettingWidget(setPageState: setState)
        ],
      ),
    );
  }
}

class SyncRemoteSettingWidget extends StatelessWidget {
  final Function setPageState;
  const SyncRemoteSettingWidget({super.key, required this.setPageState});

  @override
  Widget build(BuildContext context) {
    return Column(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("WebDAV账户"),
                      Row(
                        children: [
                          Text("联通性检查: "),
                          if((context.read<Global>().settingData["sync"]["account"]["uri"] as String).isEmpty) Text("未绑定", style: Theme.of(context).textTheme.labelSmall),
                          Icon(Icons.circle, color: Colors.greenAccent, size: 12)
                        ],
                      )
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
                  ),
                  onPressed: () async {
                    await popAccountSetting(context);
                    setPageState(() {});
                  }, 
                  child: Text("绑定")
                ),
              ],
            ),
          ], 
        )
        
      ],
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