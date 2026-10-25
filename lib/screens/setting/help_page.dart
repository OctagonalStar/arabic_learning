import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// 常见问题。
///
/// 小程序试用版分支：原来只有一条「点击发音后没有声音」的 FAQ（读 `assets/help/audio.md`），
/// 而发音功能已整体移除，改为直接说明试用版的已知限制。
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const String _faq = """
## 为什么没有发音？

小程序试用版移除了全部发音功能（系统 TTS 与在线语音在微信小程序里都无法使用）。
如需发音，请使用桌面端或 Android 客户端。

## 为什么没有在线词库下载、同步和 AI 出题？

小程序试用版不发起任何网络请求。词库已随安装包内置，
在「设置 → 学习设置 → 词库管理 → 内置词库」中一键导入。

## 阅读理解题怎么来？

在「测试 → 阅读理解 → 添加」里使用「复制提示词」拿到题目模板，
自行用任意 AI 生成 JSON 后，用「粘贴 JSON」导入。全程不联网。

## 学习数据存在哪？

只存在本机（微信小程序的本地存储），不备份、不上传。
卸载小程序会一并清除。
""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("常见问题")),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [MarkdownBody(data: _faq)],
        ),
      ),
    );
  }
}
