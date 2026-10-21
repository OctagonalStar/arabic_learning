// 空词库引导弹窗（原 widgets/overlays.dart 中的 showEmptyDictDialog）。
//
// 只负责展示与回调：跳转目标由调用方通过 [showEmptyDictDialog] 的
// `onImport` 注入，本文件不感知任何页面层实现，以维持
// 「widget 层不依赖页面层」的分层约定。

import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 词库为空时的引导弹窗：说明当前没有词库，并提供「去导入词库」的
/// 主按钮与「稍后」的次要出口。
///
/// [context] :Widget树上的context
///
/// [onImport] :点击「去导入词库」后执行的跳转动作，由调用方提供
/// （例如 `() => Navigator.push(... DictManagePage())`）。弹窗会先关闭自身
/// 再调用它，因此回调里不应再依赖弹窗的 dialogContext。
///
/// 触发条件由调用方判定（一般为 `AppData().wordData.words.isEmpty`），
/// 本函数只负责展示；返回该弹窗的 Future，便于测试与串行流程。
Future<void> showEmptyDictDialog(BuildContext context, {required VoidCallback onImport}) async {
  context.read<Global>().uiLogger.info("展示空词库引导弹窗");
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ColorScheme scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        icon: Icon(Icons.library_books_outlined, color: scheme.primary),
        title: const Text("还没有词库"),
        content: const Text(
          "当前未导入任何词库，学习、复习与检索都需要先导入词库。",
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("稍后"),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<Global>().uiLogger.info("跳转: 空词库弹窗 => 导入词库回调");
              onImport();
            },
            icon: const Icon(Icons.download),
            label: const Text("去导入词库"),
          ),
        ],
      );
    },
  );
}
