import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/widgets/feedback.dart' show LoadingIndicator;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/overlays.dart' show alart, showSnackBar;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 内置词库：列出随安装包分发的词库（[AppData.builtinDicts]）并一键导入。
///
/// 小程序分支没有网络，原来的「从 GitHub 下载在线词库」整页改成这个离线页面；
/// 词库以 gzip 打包在 assets 里，解压和解析都在 [AppData.importBuiltinDict] 完成。
class BuiltinDictPage extends StatelessWidget {
  const BuiltinDictPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("内置词库")),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text("以下词库已随安装包内置，无需联网。导入后即可离线使用；重复导入会替换该词库的旧内容。"),
            ),
            for (final BuiltinDict dict in AppData.builtinDicts)
              _BuiltinDictRow(dict: dict),
          ],
        ),
      ),
    );
  }
}

class _BuiltinDictRow extends StatefulWidget {
  const _BuiltinDictRow({required this.dict});

  final BuiltinDict dict;

  @override
  State<_BuiltinDictRow> createState() => _BuiltinDictRowState();
}

class _BuiltinDictRowState extends State<_BuiltinDictRow> {
  bool _busy = false;

  bool get _imported => AppData().wordData.classes.any(
    (SourceItem source) => source.sourceJsonFileName == widget.dict.source,
  );

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final DictImportResult? result = await AppData().importBuiltinDict(
        widget.dict,
      );
      if (!mounted) return;
      if (result == null) {
        alart(context, "「${widget.dict.title}」导入失败，请查看调试日志。");
      } else {
        context.read<Global>().uiLogger.info(
          "内置词库[${widget.dict.title}]导入完成",
        );
        showSnackBar(
          context,
          "「${widget.dict.title}」导入成功\n${result.message}",
        );
      }
    } catch (e) {
      if (!mounted) return;
      context.read<Global>().uiLogger.severe(
        "内置词库[${widget.dict.title}]导入异常: $e",
      );
      alart(context, "「${widget.dict.title}」导入失败：\n$e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool imported = _imported;
    return ListTile(
      title: Text(widget.dict.title),
      subtitle: Text(imported ? "已导入" : "未导入"),
      trailing: _busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: LoadingIndicator(),
            )
          : Button(
              icon: Icon(imported ? Icons.refresh : Icons.download),
              onPressed: imported
                  ? () => alart(
                      context,
                      "确认重新导入「${widget.dict.title}」？\n将用内置版本替换该词库的现有内容，学习进度保留。",
                      onConfirmed: _import,
                    )
                  : _import,
              child: Text(imported ? "重新导入" : "导入"),
            ),
    );
  }
}
