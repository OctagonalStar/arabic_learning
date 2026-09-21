import 'dart:convert';

import 'package:arabic_learning/funcs/ui.dart' show Button, alart, showSnackBar, SettingItem;
import 'package:arabic_learning/models/dict.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/app_data.dart';

/// 线上词库来源：区块标题 + GitHub contents API 地址
class _DictRepo {
  final String title;
  final String apiUrl;
  const _DictRepo({required this.title, required this.apiUrl});
}

const List<_DictRepo> _dictRepos = [
  _DictRepo(
    title: "来自 Github @JYinherit 学长的词库 (在此表示感谢)",
    apiUrl: "https://api.github.com/repos/JYinherit/Arabiclearning/contents/词库",
  ),
  _DictRepo(
    title: "来自 Github @OctagonalStar",
    apiUrl:
        "https://api.github.com/repos/OctagonalStar/arabic_chinese_edu_words_dataset/contents/",
  ),
];

class DownloadPage extends StatelessWidget {
  const DownloadPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("下载在线词库")),
      body: FutureBuilder(
        future: downloadList(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || snapshot.data == null) {
            return Center(child: CircularProgressIndicator());
          }
          return ListView(children: snapshot.data!);
        },
      ),
    );
  }
}

Future<List<Widget>> downloadList(BuildContext context) async {
  final List<Widget> sections = [];
  Dio dio = Dio();
  for (final _DictRepo repo in _dictRepos) {
    sections.add(await _buildRepoSection(context, dio, repo));
  }
  return sections;
}

/// 构建单个词库仓库的区块（含标题与文件列表），单个仓库失败不影响其他仓库
Future<Widget> _buildRepoSection(BuildContext context, Dio dio, _DictRepo repo) async {
  try {
    Response githubResponse = await dio.getUri(Uri.parse(repo.apiUrl));
    if (githubResponse.statusCode != 200) {
      if (context.mounted) {
        context.read<Global>().uiLogger.severe("线上词库获取失败: ${githubResponse.statusCode}");
      }
      return SettingItem(
        title: repo.title,
        padding: EdgeInsets.all(8.0),
        children: [
          Text("无法获取词库列表，请检查你的网络链接或稍后重试"),
          Text("回复错误码：${githubResponse.statusCode}"),
        ],
      );
    }
    List<dynamic> json = githubResponse.data as List<dynamic>;
    if (!context.mounted) {
      return SettingItem(
        title: repo.title,
        padding: EdgeInsets.all(8.0),
        children: [Text("无法获取词库列表，请检查你的网络链接或稍后重试")],
      );
    }
    context.read<Global>().uiLogger.info("线上词库获取成功: ${repo.title}");

    final List<Widget> children = [];
    for (var f in json) {
      if (f["type"] != "file") continue;
      final String name = (f["name"] ?? "").toString();
      final String lower = name.toLowerCase();
      // 仅接受 .json / .jsonl，跳过 LICENSE 等其他文件
      if (!lower.endsWith(".json") && !lower.endsWith(".jsonl")) continue;
      children.add(_buildFileRow(context, dio, f));
    }
    if (children.isEmpty) children.add(Text("暂无可下载词库"));

    return SettingItem(title: repo.title, padding: EdgeInsets.all(8.0), children: children);
  } catch (e) {
    if (context.mounted) context.read<Global>().uiLogger.severe("线上词库获取失败: $e");
    return SettingItem(
      title: repo.title,
      padding: EdgeInsets.all(8.0),
      children: [
        Text("无法获取词库列表，请检查你的网络链接或稍后重试"),
        SelectableText("调试信息：$e"),
      ],
    );
  }
}

Widget _buildFileRow(BuildContext context, Dio dio, dynamic f) {
  final String fileName = (f["name"] ?? "").toString();
  bool downloaded = AppData().wordData.classes.any(
    (SourceItem source) => source.sourceJsonFileName == fileName,
  );
  bool inDownloading = false;
  return StatefulBuilder(
    builder: (context, setLocalState) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(fileName)),
          inDownloading
              ? CircularProgressIndicator()
              : Button(
                  icon: Icon(downloaded ? Icons.done : Icons.download),
                  onPressed: () async {
                    if (downloaded) return;
                    setLocalState(() {
                      inDownloading = true;
                    });
                    try {
                      context.read<Global>().uiLogger.info("下载词库: $fileName:${f["download_url"]}");
                      var response = await dio.getUri(Uri.parse(f["download_url"]));
                      if (!context.mounted) return;
                      if (response.statusCode == 200) {
                        // JSONL/旧版JSON均按原始文本交给导入器（自动识别格式）
                        final String rawText = response.data is String
                            ? response.data.toString()
                            : jsonEncode(response.data);
                        final DictImportResult result = AppData().importDictData(rawText, fileName);
                        showSnackBar(context, "下载成功: $fileName\n${result.message}");
                        setLocalState(() {
                          inDownloading = false;
                          downloaded = true;
                        });
                      }
                    } catch (e) {
                      context.read<Global>().uiLogger.severe("词库[$fileName]下载失败: $e");
                      alart(context, "下载失败\n${e.toString()}");
                      setLocalState(() {
                        inDownloading = false;
                        downloaded = false;
                      });
                    }
                  },
                  child: Text(downloaded ? "已下载" : "下载"),
                ),
        ],
      );
    },
  );
}
