// 词库管理页：查看/删除已安装词库、导入新词库，并提供索引修复与未归属词条清理。
// 说明：删除词库仅解除归属（保留词条本体）；清理未归属词条会真正删词并重排位置。

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/models/dict.dart' show SourceItem;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart'
    if (dart.library.io) 'dart:io'
    as io;
import 'package:arabic_learning/screens/setting/data_download_page.dart'
    show DownloadPage;
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppRadius, AppSpacing;
import 'package:arabic_learning/widgets/kit.dart' show Button, SettingItem;
import 'package:arabic_learning/widgets/overlays.dart' show alart, showSnackBar;

class DictManagePage extends StatefulWidget {
  const DictManagePage({super.key});

  @override
  State<DictManagePage> createState() => _DictManagePage();
}

class _DictManagePage extends State<DictManagePage> {
  /// 已安装词库为空时的提示卡片。
  Widget _emptyHint(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
          "暂无词库，请在下方导入",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// 单个已安装词库的卡片（展示词条/课程数量，可删除）。
  Widget _sourceCard(BuildContext context, SourceItem s) {
    final int wordCount = s.subClasses
        .expand((c) => c.wordIndexs)
        .toSet()
        .length;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: ListTile(
        leading: const Icon(Icons.menu_book),
        title: Text(s.name.trim()),
        subtitle: Text("词条 $wordCount · 课程 ${s.subClasses.length}"),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          tooltip: "删除词库",
          onPressed: () => _confirmDelete(context, s),
        ),
      ),
    );
  }

  /// 删除词库确认弹窗：共享的 [alart] 只有一个“确定”按钮，这里需要双按钮。
  void _confirmDelete(BuildContext context, SourceItem s) {
    context.read<Global>().uiLogger.info("请求删除词库: ${s.name}");
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("删除词库「${s.name}」？"),
        content: Text(
          "将解除「${s.name}」及其课程的归属，词条本体保留（不影响复习进度）。此操作不可撤销。",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              final String? name = AppData().deleteDictSource(
                s.sourceJsonFileName,
              );
              Navigator.pop(dialogContext);
              if (context.mounted) {
                setState(() {});
                showSnackBar(context, "已删除词库：${name ?? s.name}");
              }
            },
            child: Text(
              "删除",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 彻底删除未被任何课程引用的词条；有复习卡片时给出不可恢复警告。
  void _cleanupOrphans(BuildContext context) {
    final Set<int> orphans = AppData().unreferencedWordIds();
    if (orphans.isEmpty) {
      showSnackBar(context, "没有未归属词条");
      return;
    }
    final int affected = FSRS().countCardsFor(orphans);
    context.read<Global>().uiLogger.info(
      "请求清理未归属词条: ${orphans.length} 个，涉及复习卡片 $affected 张",
    );
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("清理未归属词条？"),
        content: Text(
          "将彻底删除 ${orphans.length} 个未被任何课程引用的词条${affected > 0 ? "，并丢弃这些词条上的 $affected 张复习卡片（进度不可恢复）" : ""}。此操作会重排词条位置，不可撤销。",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              final ({int removedWords, int removedCards}) r = AppData()
                  .compactUnreferencedWords();
              Navigator.pop(dialogContext);
              if (context.mounted) {
                setState(() {});
                showSnackBar(
                  context,
                  "已清理 ${r.removedWords} 个词条，丢弃 ${r.removedCards} 张复习卡片",
                );
              }
            },
            child: Text(
              "确认清理",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 重置词库但把复习进度按词形暂存到内存，供重新导入后恢复。
  void _resetDicts(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("重置词库并保留复习进度？"),
        content: const Text(
          "将清空所有已安装词库及其课程归属（阅读题、同义词标记保留）。清空前的复习进度会暂存在本次会话中，"
          "请在重新导入词库后点击「恢复复习进度」；中途退出应用将无法恢复复习进度。此操作不可撤销。",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              final int pending = AppData().resetDictsPreservingFsrs();
              Navigator.pop(dialogContext);
              if (context.mounted) {
                setState(() {});
                showSnackBar(
                  context,
                  "已重置词库，暂存 $pending 张复习卡片；请重新导入后恢复进度",
                );
              }
            },
            child: Text(
              "确认重置",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 重新导入完成后，按词形恢复暂存的复习进度。
  void _restoreFsrs(BuildContext context) {
    final ({int restored, int dropped}) r = AppData().restoreFsrsFromPending();
    setState(() {});
    alart(
      context,
      r.dropped > 0
          ? "已恢复 ${r.restored} 张复习卡片，丢弃 ${r.dropped} 张（对应词条已不存在）。"
          : "已恢复 ${r.restored} 张复习卡片。",
    );
  }

  /// 放弃暂存的复习进度（永久丢弃）。
  void _discardPending(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("放弃恢复复习进度？"),
        content: const Text("暂存的复习进度将被永久丢弃，不可恢复。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              AppData().discardPendingFsrsRestore();
              Navigator.pop(dialogContext);
              if (context.mounted) {
                setState(() {});
                showSnackBar(context, "已放弃待恢复的复习进度");
              }
            },
            child: Text(
              "确认放弃",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 导入分区：线上下载 + 本地文件导入（本地导入逻辑复制自 SettingPage）。
  Widget _importSection(BuildContext context, MediaQueryData mediaQuery) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Button(
          size: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(AppRadius.card),
            ),
          ),
          onPressed: () async {
            context.read<Global>().uiLogger.info(
              "跳转: DictManagePage => DownloadPage",
            );
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => DownloadPage()),
            );
            // 从下载页返回后刷新已安装词库列表（下载页内可能已导入词库）。
            if (context.mounted) setState(() {});
          },
          icon: const Icon(Icons.cloud_download),
          child: const Text("线上下载"),
        ),
        Button(
          size: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(
              right: Radius.circular(AppRadius.card),
            ),
          ),
          onPressed: () async {
            context.read<Global>().uiLogger.info("选择手动导入单词");
            PlatformFile? result = await FilePicker.pickFile(
              type: FileType.custom,
              allowedExtensions: ['json', 'jsonl'],
            );
            if (result != null) {
              String jsonString;
              PlatformFile platformFile = result;
              try {
                jsonString = await platformFile.xFile.readAsString();
              } catch (e) {
                if (!context.mounted) return;
                if (platformFile.path != null && !kIsWeb) {
                  context.read<Global>().uiLogger.warning(
                    "文件导入错误: 常规方式读取失败:\n$e\n尝试路经读取",
                  );
                  jsonString = await io.File(
                    platformFile.path!,
                  ).readAsString();
                } else {
                  context.read<Global>().uiLogger.severe("文件导入错误: $e");
                  alart(
                    context,
                    "文件 \"${platformFile.name}\" \n无法读取：$e。",
                  );
                  return;
                }
              }
              if (!context.mounted) return;
              try {
                context.read<Global>().uiLogger.fine("文件读取完成，开始解析");
                final DictImportResult result = AppData().importDictData(
                  jsonString,
                  platformFile.name,
                );
                alart(
                  context,
                  "文件 \"${platformFile.name}\" \n已导入。\n${result.message}",
                );
                setState(() {});
                context.read<Global>().uiLogger.info("文件解析成功");
              } catch (e) {
                if (!context.mounted) return;
                context.read<Global>().uiLogger.severe(
                  "文件 ${platformFile.name} 无效: $e",
                );
                alart(context, '文件 ${platformFile.name} 无效：\n$e');
              }
            }
          },
          icon: const Icon(Icons.file_open),
          child: const Text("文件导入"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 DictManagePage");
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final List<SourceItem> sources = AppData().wordData.classes;

    return Scaffold(
      appBar: AppBar(title: const Text("词库管理")),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            SettingItem(
              title: "已安装词库",
              children: [
                if (sources.isEmpty)
                  _emptyHint(context)
                else
                  for (final SourceItem s in sources) _sourceCard(context, s),
              ],
            ),
            SettingItem(
              title: "导入词库",
              children: [_importSection(context, mediaQuery)],
            ),
            SettingItem(
              title: "维护",
              children: [
                Button(
                  size: Size.fromHeight(mediaQuery.size.height * 0.08),
                  icon: const Icon(Icons.build),
                  onPressed: () {
                    final String report = AppData().repairIndexes();
                    alart(context, report);
                  },
                  child: const Text("修复/重建索引"),
                ),
                Button(
                  size: Size.fromHeight(mediaQuery.size.height * 0.08),
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  icon: const Icon(Icons.cleaning_services),
                  onPressed: () => _cleanupOrphans(context),
                  child: const Text("清理未归属词条"),
                ),
                if (AppData().hasPendingFsrsRestore) ...[
                  Button(
                    size: Size.fromHeight(mediaQuery.size.height * 0.08),
                    icon: const Icon(Icons.settings_backup_restore),
                    onPressed: () => _restoreFsrs(context),
                    child: const Text("恢复复习进度"),
                  ),
                  Button(
                    size: Size.fromHeight(mediaQuery.size.height * 0.08),
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    icon: const Icon(Icons.delete_forever),
                    onPressed: () => _discardPending(context),
                    child: const Text("放弃恢复进度"),
                  ),
                ] else
                  Button(
                    size: Size.fromHeight(mediaQuery.size.height * 0.08),
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    icon: const Icon(Icons.restart_alt),
                    onPressed: () => _resetDicts(context),
                    child: const Text("重置词库（保留复习进度）"),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
