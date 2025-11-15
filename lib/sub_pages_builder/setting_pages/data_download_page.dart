
import 'dart:convert';

import 'package:arabic_learning/sub_pages_builder/setting_pages/item_widget.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

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
  Dio dio = Dio();
  Response githubResponse = await dio.getUri(Uri.parse("https://api.github.com/repos/JYinherit/Arabiclearning/contents/词库"));
  if(githubResponse.statusCode != 200) {
    return [
      Text("无法获取词库列表，请检查你的网络链接或稍后重试"),
      Text("回复错误码：${githubResponse.statusCode}"),
      SelectableText("调试信息：${githubResponse.data.toString()}"),
    ];
  }
  List<dynamic> json = githubResponse.data as List<dynamic>;
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
                    var response = await dio.getUri(Uri.parse(f["download_url"]));
                    if(!context.mounted) return ;
                    if(response.statusCode == 200) {
                      context.read<Global>().importData(jsonDecode(response.data) as Map<String, dynamic>, f["name"]);
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