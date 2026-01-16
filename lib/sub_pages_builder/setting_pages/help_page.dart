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
        if(!helpEssay.hasData) return CircularProgressIndicator();

        return Scaffold(
          appBar: AppBar(title: Text("常见问题")),
          body: ListView(
            children: [
              ExpansionTile(
                title: Text("点击发音按钮后没有声音"),
                children: [
                  MarkdownBody(data: helpEssay.data?.elementAt(0) ?? "")
                ],
              )
            ],
          ),
        );
      }
    );
  }
}

Future<List<String>> getHelpMarkDown() async {
  return [await rootBundle.loadString('assets/help/audio.md')];
}