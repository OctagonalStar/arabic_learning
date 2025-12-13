import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/license_storage.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;

class ModelDownload extends StatefulWidget {
  const ModelDownload({super.key});

  @override
  State<StatefulWidget> createState() => _ModelDownload();
}

class _ModelDownload extends State<ModelDownload> { 
  _ModelDownload();
  int totalSize = 1;
  int downloadedSize = 0;
  int progress = 0;
  bool isDownloading = false;
  static const List<String> progresMap = ["开始下载", "获取链接中", "下载中", "解压中", "完成"];


  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 ModelDownload");
    return Scaffold(
      appBar: AppBar(
        title: const Text('模型下载'),
      ),
      body: ListView(
        children: [
          TextContainer(text: "使用基于ViTS的文本转语音模型\n下载后会占用本地约60MB的存储空间"),
          TextContainer(text: "一旦开始下载，请勿退出此页面; 若在解压时提示软件无响应，属于正常情况，请选择等待", style: TextStyle(color: Colors.redAccent),),
          ElevatedButton.icon(
            icon: Icon(progress > 3 ? Icons.download_done : Icons.download),
            label: Text(progresMap[progress]),
            style: ElevatedButton.styleFrom(
              fixedSize: Size(double.infinity, 100),
              shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(25.0))
            ),
            onPressed: () async{
              var basePath = await getApplicationDocumentsDirectory();
              if(io.File("${basePath.path}/${StaticsVar.modelPath}/ar_JO-kareem-medium.onnx").existsSync() && context.mounted){
                context.read<Global>().uiLogger.warning("检测到模型文件存在");
                alart(context, "模型已存在");
                return;
              }
              if(isDownloading) return;
              setState(() {
                isDownloading = true;
                progress ++;
              });
              try {
                await downloadFile('https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-ar_JO-kareem-medium.tar.bz2', '${basePath.path}/arabicLearning/tts/temp.tar.bz2',
                  onDownloading: (count, total){
                    setState(() {
                      progress = 2;
                      downloadedSize = count;
                      totalSize = total;
                    });
                  });
              } catch (e) {
                if(!context.mounted) return;
                context.read<Global>().uiLogger.severe("模型下载错误: $e");
                alart(context, "下载失败\n${e.toString()}");
                setState(() {
                  progress = 0;
                  isDownloading = false;
                });
                return;
              }
              setState(() {
                progress = 3;
              });
              await extractTarBz2('${basePath.path}/arabicLearning/tts/temp.tar.bz2', "${basePath.path}/arabicLearning/tts/model/");
              if(!context.mounted) return;
              context.read<Global>().loadTTS();
              context.read<Global>().uiLogger.info("模型下载完成");
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("下载完成")));
              setState(() {
                progress = 4;
                context.read<Global>().modelTTSDownloaded = true;
              });
              if(io.File('${basePath.path}/arabicLearning/tts/temp.tar.bz2').existsSync()){
                io.File('${basePath.path}/arabicLearning/tts/temp.tar.bz2').delete();
              }
            }, 
          ),
          SizedBox(height: 20),
          LinearProgressIndicator(
            minHeight: MediaQuery.of(context).size.height * 0.08,
            value: downloadedSize/totalSize,
            borderRadius: StaticsVar.br,
          ),
          SizedBox(height: 20),
          ExpansionTile(
            title: Text("模型开源信息"),
            children: [
              TextContainer(text: "模型开源地址: https://huggingface.co/rhasspy/piper-voices/tree/main/ar/ar_JO/kareem"),
              TextContainer(text: '模型授权许可: MIT License\n${LicenseVars.theModelLICENSE}'),
            ],
          )
        ],
      )
    );
  }
}