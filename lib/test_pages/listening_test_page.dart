import 'package:arabic_learning/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:arabic_learning/global.dart';

class ForeListeningSettingPage extends StatelessWidget {
  const ForeListeningSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('自主听写预设置'),
      ),
      body: Center(
        child: ListView(
          children: [
            TextContainer(text: "请先完成以下选项以开始听写:"),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary,
                borderRadius: StaticsVar.br,
              ),
              child: Column(
                children: [
                  TextContainer(text: "1. 发音符号测试"),
                  IconButton(
                    onPressed: () {
                      playTextToSpeech("َ", context);
                    }, 
                    icon: Icon(Icons.volume_up, size: 50)
                  ),
                  TextContainer(text: "点击以上按钮，等待约10秒。期间如果你能听到开口短音符音，则说明你当前音源支持发音符号。"),
                  TextContainer(text: "如果你不能听到开口短音符音，请*逐个*尝试以下修复方案：\n1- 关闭设置中的\"使用备用文本转语音接口\"\n2- 在设备系统设置中添加 阿拉伯语语言\n3. 查找设备设置中\"Text To Speech\"或\"文本转语音\"选项，检查是否有阿拉伯语(国际符号为ar-00或ar-SA)支持（由于手机厂商多样性，无法保证所有的手机都支持阿拉伯语）\n4. 如果你是Android系统手机，还可以尝试安装\"Google 语音识别和语音合成\"(包名为com.google.android.tts)\n5. 开发者最近发现了个其他的开源项目支持阿拉伯语TTS，要么等下开发者支持:)")
                ],
              ),
            ),
          ],
        )
      ),
    );
  }
}