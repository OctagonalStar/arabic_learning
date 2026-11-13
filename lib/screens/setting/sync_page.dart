import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/widgets/feedback.dart' show LoadingIndicator, ProgressBar;
import 'package:arabic_learning/widgets/kit.dart' show Button, SettingItem;
import 'package:arabic_learning/widgets/overlays.dart' show alert, showSnackBar;
import 'package:arabic_learning/widgets/shared.dart' show appInputDecoration;
import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppSpacing;
import 'package:arabic_learning/services/sync.dart';
import 'package:arabic_learning/models/config.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/app_data.dart';
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

  /// 传输进度 0.0~1.0；null 表示尚未开始或总大小未知（不确定进度）。
  /// 用 ValueNotifier 只重建进度所在行，避免整页 rebuild 反复触发联通性测试。
  final ValueNotifier<double?> uploadProgress = ValueNotifier<double?>(null);
  final ValueNotifier<double?> downloadProgress = ValueNotifier<double?>(null);

  /// 联通性检查只在绑定账户与首次进入时发起，页面 rebuild 不再重复请求。
  late Future<List<dynamic>> connectivityTest;

  @override
  void initState() {
    super.initState();
    connectivityTest = _testConnection();
  }

  @override
  void dispose() {
    uploadProgress.dispose();
    downloadProgress.dispose();
    super.dispose();
  }

  WebDAV get _webdav => WebDAV(
    uri: AppData().config.webSync.account.uri,
    user: AppData().config.webSync.account.userName,
    password: AppData().config.webSync.account.passWord,
  );

  Future<List<dynamic>> _testConnection() => WebDAV.test(
    AppData().config.webSync.account.uri,
    AppData().config.webSync.account.userName,
    password: AppData().config.webSync.account.passWord,
  );

  /// 进度回调很密集，仅在整数百分比变化时通知进度条。
  void _setProgress(int count, int total, {required bool upload}) {
    if (total <= 0) return;
    final double value = (count / total).clamp(0.0, 1.0);
    final ValueNotifier<double?> notifier = upload ? uploadProgress : downloadProgress;
    final double? current = notifier.value;
    if (current != null && (current - value).abs() < 0.01) return;
    notifier.value = value;
  }

  Future<void> _upload() async {
    context.read<Global>().uiLogger.info("用户上传数据");
    setState(() {
      isUploading = true;
    });
    uploadProgress.value = null;
    final WebDAV webdav = _webdav;
    try {
      if (!webdav.isReachable) await webdav.connect();
      if (!mounted) return;
      await webdav.upload(
        AppData().storage,
        onProgress: (int count, int total) => _setProgress(count, total, upload: true),
      );
    } catch (e) {
      if (!mounted) return;
      alert(context, e.toString());
      setState(() {
        isUploading = false;
      });
      uploadProgress.value = null;
      return;
    }
    if (!mounted) return;
    setState(() {
      isUploading = false;
    });
    uploadProgress.value = null;
    alert(context, "已上传");
  }

  Future<void> _download() async {
    context.read<Global>().uiLogger.info("用户恢复数据");
    setState(() {
      isDownloading = true;
    });
    downloadProgress.value = null;
    final WebDAV webdav = _webdav;
    try {
      if (!webdav.isReachable) await webdav.connect();
      if (!mounted) return;
      await webdav.download(
        AppData().storage,
        onProgress: (int count, int total) => _setProgress(count, total, upload: false),
      );
      if (!mounted) return;
      context.read<Global>().conveySetting();
      await context.read<Global>().reloadStoredData();
    } catch (e) {
      if (!mounted) return;
      alert(context, e.toString());
      setState(() {
        isDownloading = false;
      });
      downloadProgress.value = null;
      return;
    }
    if (!mounted) return;
    setState(() {
      isDownloading = false;
    });
    downloadProgress.value = null;
    alert(context, "已恢复\n部分设置可能需要软件重启后才能生效");
  }

  @override
  Widget build(BuildContext context) {
    enabled ??= AppData().config.webSync.enabled;
    MediaQueryData mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("同步设置"),
      ),
      body: SafeArea(top: false, child: ListView(
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
                  Button(
                    onPressed: () async {
                      await popAccountSetting(context);
                      setState(() {
                        connectivityTest = _testConnection();
                      });
                    }, 
                    child: Text("绑定")
                  ),
                ],
              ),
              Row(
                children: [
                  Text("联通性检查: "),
                  if(AppData().config.webSync.account.uri.isEmpty) Text("未绑定", style: Theme.of(context).textTheme.labelSmall),
                  FutureBuilder(
                    future: connectivityTest,
                    builder: (context, snapshot) {
                      if(snapshot.hasError) {
                        return Row(
                          children: [
                            Icon(Icons.circle, color: context.semanticColors.error, size: 18),
                            Text("在测试中遇到了未知的异常", style: Theme.of(context).textTheme.labelSmall)
                          ],
                        );
                      }
                      if(snapshot.connectionState == ConnectionState.waiting) {
                        return LoadingIndicator(size: 18, strokeWidth: 2);
                      }
                      if(snapshot.hasData) {
                        return Row(
                          children: [
                            Icon(Icons.circle, color: snapshot.data![1] ? context.semanticColors.success : snapshot.data![0] ? context.semanticColors.warning : context.semanticColors.error, size: 18)
                          ],
                        );
                      }
                      return LoadingIndicator();
                    },
                  )
                ],
              ),
              _SyncActionRow(
                icon: Icons.cloud_upload,
                title: "上传数据",
                subtitle: "将本地配置上传到WebDAV服务器",
                actionLabel: "上传",
                running: isUploading,
                progress: uploadProgress,
                onPressed: () => alert(
                  context,
                  "确认将本地配置上传到WebDAV服务器？\n服务器上的备份将被覆盖。",
                  destructive: true,
                  confirmLabel: "上传",
                  onConfirmed: _upload,
                ),
              ),
              _SyncActionRow(
                icon: Icons.cloud_download,
                title: "恢复数据",
                subtitle: "从WebDAV服务器恢复配置",
                actionLabel: "恢复",
                running: isDownloading,
                progress: downloadProgress,
                onPressed: () => alert(
                  context,
                  "确认从WebDAV服务器恢复配置？\n本地数据将被覆盖。",
                  destructive: true,
                  confirmLabel: "恢复",
                  onConfirmed: _download,
                ),
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
                        Text("将当前软件数据作为文件导出", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))
                      ],
                    ),
                  ),
                  Button(
                    onPressed: () async {
                      try{
                        if(await FilePicker.saveFile(
                          dialogTitle: "导出数据",
                          windowsOptions: WindowsOptions(lockParentWindow: true),
                          fileName: "export.json",
                          bytes: utf8.encode(jsonEncode(AppData().storage.export())),
                        ) != null) {
                          if(context.mounted) {
                            showSnackBar(context, "导出完成");
                          }
                        }
                      } catch (e){
                        if(!context.mounted) return;
                        context.read<Global>().uiLogger.severe(e);
                        showSnackBar(context, "导出时发生错误: $e");
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
                        Text("将文件中的配置覆盖软件配置", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))
                      ],
                    ),
                  ),
                  Button(
                    onPressed: () async {
                      context.read<Global>().uiLogger.info("导入软件数据");
                      final String jsonString;
                      final PlatformFile platformFile;
                      try {
                        final PlatformFile? result = await FilePicker.pickFile(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                        );
                        if (result == null) return;
                        platformFile = result;
                        final List<int> bytes = await platformFile.readAsBytes();
                        if (bytes.isNotEmpty) {
                          jsonString = utf8.decode(bytes);
                        } else if (platformFile.path != null && !kIsWeb) {
                          jsonString = await io.File(platformFile.path!).readAsString();
                        } else {
                          if (!context.mounted) return;
                          context.read<Global>().uiLogger.warning("备份数据导入错误: bytes和path均为null");
                          alert(context, "文件 \"${platformFile.name}\" \n无法读取：bytes和path均为null。");
                          return;
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        context.read<Global>().uiLogger.severe("备份数据读取失败: $e");
                        alert(context, "文件读取失败：\n$e");
                        return;
                      }
                      if (context.mounted) {
                        try{
                          context.read<Global>().uiLogger.fine("备份数据读取完成，开始解析");
                          // 必须 await：SQLite 后端要把 fsrsData 异步灌回数据库，
                          // 否则随后的 reloadStoredData 会读到旧数据。
                          await AppData().storage.recovery(jsonDecode(jsonString));
                          if(!context.mounted) return;
                          context.read<Global>().conveySetting();
                          await context.read<Global>().reloadStoredData();
                          if(!context.mounted) return;
                          alert(context, "备份数据 \"${platformFile.name}\" \n已恢复\n部分设置可能需要软件重启后才能生效");
                          context.read<Global>().uiLogger.info("备份数据 \"${platformFile.name}\" \n已导入。");
                        } catch (e) {
                          if (!context.mounted) return;
                          context.read<Global>().uiLogger.severe("文件 ${platformFile.name} 无效: $e");
                          alert(context, '文件 ${platformFile.name} 无效：\n$e');
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
      )),
    );
  }
}


/// WebDAV 上传 / 恢复共用的一行：图标 + 文案 + 进度条 + 操作按钮。
class _SyncActionRow extends StatelessWidget {
  const _SyncActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.running,
    required this.progress,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final bool running;
  /// 0.0~1.0；null 表示总大小未知（不确定进度）。
  final ValueListenable<double?> progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // 进度变化只重建本行，不触碰页面上其余（含联通性检查）的组件。
    return ValueListenableBuilder<double?>(
      valueListenable: progress,
      builder: (BuildContext context, double? value, Widget? child) {
        return Row(
          children: [
            Icon(icon),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Text(subtitle, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  if (running) ...[
                    const SizedBox(height: AppSpacing.xs),
                    ProgressBar(value: value),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            running
            ? Text(value == null ? "请稍候…" : "${(value * 100).round()}%")
            : Button(onPressed: onPressed, child: Text(actionLabel)),
          ],
        );
      },
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
      uriController.text = AppData().config.webSync.account.uri;
      accountController.text = AppData().config.webSync.account.userName;
      passwdController.text = AppData().config.webSync.account.passWord;
      return AlertDialog(
        title: Text("设置WebDAV同步"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autocorrect: false,
              controller: uriController,
              maxLines: 1,
              decoration: appInputDecoration(
                context,
                labelText: "WebDAV地址",
                icon: Icon(Icons.webhook),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              autocorrect: false,
              controller: accountController,
              maxLines: 1,
              decoration: appInputDecoration(
                context,
                labelText: "用户名",
                icon: Icon(Icons.account_box_outlined),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              autocorrect: false,
              controller: passwdController,
              maxLines: 1,
              keyboardType: TextInputType.visiblePassword,
              decoration: appInputDecoration(
                context,
                labelText: "密码",
                icon: Icon(Icons.password),
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () {
              uriController.clear();
              accountController.clear();
              passwdController.clear();
            },
            child: Text("清空"),
          ),
          Button(
            onPressed: () {
              uriController.dispose();
              accountController.dispose();
              passwdController.dispose();
              Navigator.pop(context);
            },
            child: Text("取消"),
          ),
          Button(
            onPressed: (){
              try{
                Uri.parse(uriController.text);
                if(uriController.text.isNotEmpty && !uriController.text.contains("http")) throw Exception("WebDAV URI must contain http");
              } catch (e) {
                alert(context, e.toString());
                return;
              }
              context.read<Global>().patchConfig(
                (Config config) => config.copyWith(
                  webSync: config.webSync.copyWith(
                    account: SyncAccountConfig(
                      uri: uriController.text,
                      userName: accountController.text,
                      passWord: passwdController.text
                    )
                  )
                )
              );
              uriController.dispose();
              accountController.dispose();
              passwdController.dispose();
              Navigator.pop(context);
            }, 
            child: Text("确认")
          ),
        ],
      );
    }
  );
}