import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/license_storage.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;

class ModelDownload extends StatelessWidget { 
  const ModelDownload({super.key});
  @override
  Widget build(BuildContext context) {
    bool isDownloading = false;
    String progress = "获取中";
    return Scaffold(
      appBar: AppBar(
        title: const Text('模型下载'),
      ),
      body: ListView(
        children: [
          TextContainer(text: "使用基于ViTS的文本转语音模型\n下载后会占用本地约60MB的存储空间"),
          TextContainer(text: "一旦开始下载，请勿退出此页面; 若在解压时提示软件无响应，属于正常情况，请选择等待", style: TextStyle(color: Colors.redAccent),),
          StatefulBuilder(
            builder: (context, setLocalState) {
              return ElevatedButton.icon(
                icon: Icon(progress == "已完成" ? Icons.download_done : Icons.download),
                label: Text(isDownloading ? progress : "开始下载"),
                style: ElevatedButton.styleFrom(
                  fixedSize: Size(double.infinity, 100),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(25.0))
                ),
                onPressed: () async{
                  if(isDownloading) return;
                  var basePath = await getApplicationDocumentsDirectory();
                  if(io.File("${basePath.path}/${StaticsVar.modelPath}/ar_JO-kareem-medium.onnx").existsSync() && context.mounted){
                    alart(context, "模型已存在");
                    return;
                  }
                  setLocalState(() {
                    isDownloading = true;
                  });
                  try {
                    await downloadFile('https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-ar_JO-kareem-medium.tar.bz2', '${basePath.path}/arabicLearning/tts/temp.tar.bz2', onDownloading: (count, total){setLocalState((){progress = count == total ? "解压中" : "$count/$total";});});
                  } catch (e) {
                    if(!context.mounted) return;
                    alart(context, "下载失败\n${e.toString()}");
                    return;
                  }
                  await extractTarBz2('${basePath.path}/arabicLearning/tts/temp.tar.bz2', "${basePath.path}/arabicLearning/tts/model/");
                  if(!context.mounted) return;
                  context.read<Global>().loadTTS();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("下载完成")));
                  setLocalState(
                    () {
                      progress = "已完成\n重启软件后可生效";
                      context.read<Global>().modelTTSDownloaded = true;
                    }
                  );
                  if(io.File('${basePath.path}/arabicLearning/tts/temp.tar.bz2').existsSync()){
                    io.File('${basePath.path}/arabicLearning/tts/temp.tar.bz2').delete();
                  }
                }, 
              );
            }
          ),
          SizedBox(height: 20),
          ExpansionTile(
            title: Text("使用接口及模型的开源信息"),
            children: [
              TextContainer(text: "接口开源地址: https://github.com/k2-fsa/sherpa-onnx/"),
              TextContainer(text: '接口授权许可: Apache-2.0\n${LicenseVars.theTTSModelAPILICENSE}'),
              TextContainer(text: "模型开源地址: https://huggingface.co/rhasspy/piper-voices/tree/main/ar/ar_JO/kareem"),
              TextContainer(text: '模型授权许可: MIT License\n${LicenseVars.theModelLICENSE}'),
            ],
          )
                  ],
      )
    );
  }
}