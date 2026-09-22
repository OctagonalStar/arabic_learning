import 'package:arabic_learning/widgets/feedback.dart' show LoadingIndicator;
import 'package:arabic_learning/widgets/motion.dart' show CrossFadeSwitcher;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class HelpPage extends StatelessWidget{
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getHelpMarkDown(),
      builder: (context, helpEssay) {
        // 加载 → 内容交叉淡入：两种状态携带不同 key 才会触发切换动画。
        return CrossFadeSwitcher(
          child: !helpEssay.hasData
            ? const Center(
                key: ValueKey<String>('help-loading'),
                child: LoadingIndicator(),
              )
            : Scaffold(
                key: const ValueKey<String>('help-content'),
                appBar: AppBar(title: Text("常见问题")),
                body: SafeArea(top: false, child: ListView(
                  children: [
                    ExpansionTile(
                      title: Text("点击发音按钮后没有声音"),
                      children: [
                        MarkdownBody(data: helpEssay.data?.elementAt(0) ?? "")
                      ],
                    )
                  ],
                )),
              ),
        );
      }
    );
  }
}

Future<List<String>> getHelpMarkDown() async {
  return [await rootBundle.loadString('assets/help/audio.md')];
}