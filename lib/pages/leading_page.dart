import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/vars/global.dart' show Global, AppData;
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, SystemChannels, SystemNavigator;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart' show MarkdownBody;
import 'package:provider/provider.dart';

class PolicyPage extends StatefulWidget {
  const PolicyPage({super.key, required this.isUpdate});
  final bool isUpdate;

  @override
  State<StatefulWidget> createState() => _PolicyPage();
}

class _PolicyPage extends State<PolicyPage> {
  late final String preAnnounce;

  final TextEditingController controller = TextEditingController();

  final Future<String> pp = rootBundle.loadString('assets/help/PrivacyPolicy.md');
  final Future<String> tou = rootBundle.loadString('assets/help/TermsOfUse.md');

  @override
  void initState() {
    preAnnounce = widget.isUpdate 
      ? "软件的《用户协议》或《隐私条款》自上一版本有更新\n"
        "请重新确认授权，点击“同意”即视为您同意新版本条款"
      : "欢迎使用本软件\n"
        "软件开源地址：https://github.com/OctagonalStar/arabic_learning\n"
        "软件完全开源免费，如果您是从收费渠道获得本软件，请立即退款并举报\n\n"
        "在正式使用该软件前你应当阅读并理解《用户协议》和《隐私条款》。\n"
        "若你已理解并接受上述条款，请在页面底部输入框中填写你的用户名，并点击“同意”按钮以确认。";
    super.initState();
  }

  @override
  void dispose(){
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建PP&TOU签署页面");

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
                children: [
                  TextContainer(text: preAnnounce, selectable: true),
                  FutureBuilder(
                    future: tou, 
                    builder: (context, snapshot) => snapshot.hasData ? MarkdownBody(data: snapshot.data!) : CircularProgressIndicator()
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  Divider(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  FutureBuilder(
                    future: pp, 
                    builder: (context, snapshot) => snapshot.hasData ? MarkdownBody(data: snapshot.data!) : CircularProgressIndicator()
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height),
                  if(!widget.isUpdate) TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: "请输入你的用户名",
                      prefixIcon: Icon(Icons.edit),
                    ),
                  )
                ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () async {
                  await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                  SystemNavigator.pop();
                  return;
                },
                child: const Text('不同意', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              ),
              ElevatedButton(
                onPressed: () {
                  if(widget.isUpdate) {
                    context.read<Global>().uiLogger.info("用户已同意条款更新");
                    AppData().config = AppData().config.copyWith(lastTermVersion: StaticsVar.termVersion);
                  } else if(controller.text.isNotEmpty){
                    context.read<Global>().uiLogger.info("用户同意协议，签署名：${controller.text}");
                    AppData().config = AppData().config.copyWith(user: controller.text, lastTermVersion: StaticsVar.termVersion);
                  } else {
                    context.read<Global>().uiLogger.info("用户未填写名称");
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('使用该软件前你应当仔细阅读并理解条款'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  context.read<Global>().updateSetting(refresh: true);
                },
                child: const Text('同意', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              )
            ],
          ),
        ],
      ),
    );
  }
}