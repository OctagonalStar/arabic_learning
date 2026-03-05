import 'dart:math';

import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/config_structure.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:arabic_learning/funcs/local_pk_server.dart';


class LocalPKSelectPage extends StatefulWidget {
  const LocalPKSelectPage({super.key});

  @override
  State<StatefulWidget> createState() => _LocalPKSelectPage();
}
class _LocalPKSelectPage extends State<LocalPKSelectPage> {
  final TextEditingController connectpwdController = TextEditingController();
  final MobileScannerController scannerController = MobileScannerController();
  bool isScaning = false;

  void connecting() {
    if(connectpwdController.text.isEmpty) return;
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => 
        ChangeNotifierProvider(
          create: (context) => PKServer(),
          child: LocalPKPage(isServer: false, offer: connectpwdController.text),
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建局域网联机主页面");
    MediaQueryData mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(title: Text("局域网联机")),
      body: Column(
        children: [
          SizedBox(height: mediaQuery.size.height * 0.05),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              fixedSize: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.1),
              shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
            ),
            onPressed: (){
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => ChangeNotifierProvider(
                    create: (context) => PKServer(),
                    child: LocalPKPage(isServer: true),
                  )
                )
              );
            }, 
            icon: Icon(Icons.manage_accounts, size: 36),
            label: Text("我做房主", style: TextStyle(fontSize: 24))
          ),
          Divider(height: mediaQuery.size.height * 0.05, thickness: 3),
          Text("我加入联机", style: Theme.of(context).textTheme.headlineMedium),
          TextField(
            autocorrect: false,
            controller: connectpwdController,
            expands: false,
            maxLines: 1,
            keyboardType: TextInputType.visiblePassword,
            decoration: InputDecoration(
              labelText: "联机口令",
              border: OutlineInputBorder(
                borderRadius: StaticsVar.br,
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              suffix: ElevatedButton(
                onPressed: () async {
                  connecting();
                }, 
                child: Text("加入")
              ),
            ),
            onSubmitted: (text) async {
              connecting();
            },
          ),
          SizedBox(height: mediaQuery.size.height * 0.02),
          ElevatedButton.icon(
            onPressed: () async {
              if(isScaning){
                await scannerController.stop();
                if(context.mounted) context.read<Global>().uiLogger.fine("已关闭摄像头");
              } else {
                try {
                  Set<CameraLensType> lens = await scannerController.getSupportedLenses();
                  if(context.mounted) context.read<Global>().uiLogger.fine(lens);
                } catch (e) {
                  if(context.mounted) alart(context, "尝试启用相机时出现以下问题: $e");
                  return;
                }
              }
              
              setState(() {
                isScaning = !isScaning;
              });
            }, 
            icon: Icon(isScaning ? Icons.stop : Icons.qr_code_scanner),
            label: Text(isScaning ? "停止扫描" : "扫描二维码")
          ),
          if(isScaning) SizedBox(
            width: mediaQuery.size.width * 0.8,
            height: mediaQuery.size.height * 0.4,
            child: MobileScanner(
              controller: scannerController,
              fit: BoxFit.scaleDown,
              onDetect: (barcodes) {
                if(barcodes.barcodes.isEmpty) return;
                setState(() {
                  connectpwdController.text = barcodes.barcodes.first.rawValue??"";
                  isScaning = !isScaning;
                });
                connecting();
              },
            ),
          )
        ],
      ),
    );
  }
}

class LocalPKPage extends StatefulWidget {
  final bool isServer;
  final String? offer;
  const LocalPKPage({super.key, required this.isServer, this.offer});

  @override
  State<StatefulWidget> createState() => _LocalPKPage();
}

class _LocalPKPage extends State<LocalPKPage> {
  final PageController pageController = PageController();

  @override
  void initState() {
    context.read<PKServer>().initHost(widget.isServer, context, offer: widget.offer);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if(context.read<PKServer>().pageController == null) {
      context.read<PKServer>().setPageControler(pageController);
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        context.read<PKServer>().disconnect();
      },
      child: PageView(
        physics: NeverScrollableScrollPhysics(),
        controller: pageController,
        children: [
          widget.isServer ? ServerHostWatingPage() : ClientWatingPage(),
          widget.isServer ? PKClassSelectionPage() : ClientWatingPage(),
          PKPreparePage(),
          PKOngoingPage(),
          PKErrorPage()
        ],
      ),
    );
  }
}

class ServerHostWatingPage extends StatefulWidget {
  const ServerHostWatingPage({super.key});

  @override
  State<StatefulWidget> createState() => _ServerHostWatingPage();
}

class _ServerHostWatingPage extends State<ServerHostWatingPage> {
  bool isScaning = false;
  bool isConnecting = false;
  MobileScannerController scannerController = MobileScannerController();
  TextEditingController connectpwdController = TextEditingController();

  Future<void> connectClient() async {
    try {
      await context.read<PKServer>().loadAnswer(connectpwdController.text, context);
    } catch (e) {
      if(context.mounted) {
        // ignore: use_build_context_synchronously
        alart(context, "连接错误: $e", onConfirmed: () {
          setState(() {
            isConnecting = false;
          });
        });
      }
    }
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建局域网联机课程选择页面");
    MediaQueryData mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.watch<PKServer>().inited ? "准备连接" : "正在启动服务")),
      body: Center(
        child: context.watch<PKServer>().inited
          ? Column(
            children: [
              TextField(
                autocorrect: false,
                controller: connectpwdController,
                expands: false,
                maxLines: 1,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                  labelText: "联机口令",
                  border: OutlineInputBorder(
                    borderRadius: StaticsVar.br,
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  suffix: ElevatedButton(
                    onPressed: () async {
                      if(isConnecting) return;
                      setState(() {
                        isConnecting = true;
                      });
                      connectClient();
                    }, 
                    child: Text("加入")
                  ),
                ),
                onSubmitted: (text) async {
                  if(isConnecting) return;
                  setState(() {
                    isConnecting = true;
                  });
                  connectClient();
                },
              ),
              if(!isConnecting) isScaning
              ? SizedBox(
                width: mediaQuery.size.width * 0.8,
                height: mediaQuery.size.height * 0.4,
                child: MobileScanner(
                  controller: scannerController,
                  fit: BoxFit.scaleDown,
                  onDetect: (barcodes) async {
                    if(barcodes.barcodes.isEmpty || isConnecting) return;
                    setState(() {
                      isConnecting = true;
                      isScaning = false;
                      scannerController.stop();
                    });
                    connectpwdController.text = barcodes.barcodes.first.rawValue!;
                    connectClient();
                  },
                ),
              )
              : Container(
                padding: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  borderRadius: StaticsVar.br,
                  color: Colors.white
                ),
                child: QrImageView(
                  data: context.read<PKServer>().connectpwd!,
                  backgroundColor: Colors.white,
                  version: QrVersions.auto,
                  size: min(mediaQuery.size.width, mediaQuery.size.height) * 0.8,
                ),
              ),
            
            isConnecting
            ? Column(
              children: [
                CircularProgressIndicator(),
                Text("正在构建连接"),
              ],
            )
            : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    if(isScaning) scannerController.stop();
                    setState(() {
                      isScaning = !isScaning;
                    });
                  }, 
                  icon: Icon(isScaning ? Icons.stop : Icons.qr_code_scanner),
                  label: Text(isScaning ? "停止扫描" : "扫描对方的二维码")
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: context.read<PKServer>().connectpwd!));
                  }, 
                  icon: Icon(Icons.copy),
                  label: Text("复制口令到剪切板")
                ),
              ],
            ),
          ],
        )

      : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            Text("服务加载中...\n该过程或将需要一分钟")
          ],
        )
      ),
    );
  }
}

class PKClassSelectionPage extends StatelessWidget {
  const PKClassSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(title: Text("连接成功")),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: mediaQuery.size.height * 0.1),
            TextContainer(text: "你们双方有一下共有词库，请选择其中的课程开始", style: Theme.of(context).textTheme.headlineMedium),
            SizedBox(height: mediaQuery.size.height * 0.05),
            ...List.generate(context.read<PKServer>().selectableSource.length, (int index) => Text(context.read<PKServer>().selectableSource[index].sourceJsonFileName), growable: false),
            SizedBox(height: mediaQuery.size.height * 0.1),
            ElevatedButton(
              onPressed: () async {
                ClassSelection selection = await popSelectClasses(context, forceSelectRange: context.read<PKServer>().selectableSource, withCache: false, withReviewChoose: false);
                if(!context.mounted || selection.selectedClass.isEmpty) return;
                context.read<PKServer>().setSelectedClass(selection);
                context.read<PKServer>().pageController!.nextPage(duration: Durations.medium2, curve: StaticsVar.curve);
              }, 
              child: Text("开始选课")
            )
          ],
        ),
      ),
    );
  }
}

class ClientWatingPage extends StatelessWidget {
  const ClientWatingPage({super.key});
  
  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建局域网联机等待页面");
    MediaQueryData mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.watch<PKServer>().inited ? "收集信息中" : context.watch<PKServer>().connected ? "已连接" : "等待连接")),
      body: Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if(context.watch<PKServer>().inited && !context.watch<PKServer>().connected) 
          ...[Container(
            padding: EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              borderRadius: StaticsVar.br,
              color: Colors.white
            ),
            child: QrImageView(
              data: context.read<PKServer>().connectpwd!,
              backgroundColor: Colors.white,
              version: QrVersions.auto,
              size: min(mediaQuery.size.width, mediaQuery.size.height) * 0.8,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: context.read<PKServer>().connectpwd!));
            },
            icon: Icon(Icons.copy),
            label: Text("复制口令到剪切板")
          )],

          CircularProgressIndicator(),
          Text(context.read<PKServer>().inited ? 
                context.watch<PKServer>().selectableSource.isNotEmpty ? "正在等待房主选择课程" : "请将以上二维码给对方扫描或传递口令"
                : "正在收集信息生成认证\n此过程或将需要一分钟")
        ]
      ))
    );
  }
}

class PKPreparePage extends StatelessWidget {
  const PKPreparePage({super.key});


  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建局域网联机准备页面");
    MediaQueryData mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(title: Text("请准备")),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: mediaQuery.size.height * 0.05),
            TextContainer(text: "已选择以下课程，准备完成后开始"),
            ...List.generate(context.read<PKServer>().classSelection!.selectedClass.length, (int index) => Text(context.read<PKServer>().classSelection!.selectedClass[index].className), growable: false),
            SizedBox(height: mediaQuery.size.height * 0.1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              
              children: [
                Container(
                  padding: EdgeInsets.all(8.0),
                  height: mediaQuery.size.height * 0.3,
                  width: mediaQuery.size.width * 0.4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onPrimary,
                    borderRadius: StaticsVar.br
                  ),
                  child: Column(
                    children: [
                      Text("你", style: Theme.of(context).textTheme.headlineSmall),
                      SizedBox(height: mediaQuery.size.height * 0.05),
                      context.watch<PKServer>().preparedP1
                      ? Text("已准备")
                      : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          fixedSize: Size.fromHeight(mediaQuery.size.height * 0.1),
                          shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
                        ),
                        onPressed: (){
                          context.read<PKServer>().setPrepare();
                        }, 
                        child: Text("准备")
                      ),
                      if(context.watch<PKServer>().preparedP1) Icon(Icons.done, color: Colors.greenAccent, size: 36)
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(8.0),
                  height: mediaQuery.size.height * 0.3,
                  width: mediaQuery.size.width * 0.4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSecondary,
                    borderRadius: StaticsVar.br
                  ),
                  child: Column(
                    children: [
                      Text("对方", style: Theme.of(context).textTheme.headlineSmall),
                      SizedBox(height: mediaQuery.size.height * 0.05),
                      Text("${context.watch<PKServer>().preparedP2 ? "已" : "未"}准备"),
                      if(context.watch<PKServer>().preparedP2) Icon(Icons.done, color: Colors.greenAccent, size: 36)
                    ],
                  ),
                )
              ],
            ),
            if(context.watch<PKServer>().startTime != null) TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 1,
                end: 0
              ), 
              duration: context.read<PKServer>().startTime!.difference(DateTime.now()), 
              builder: (context, value, child) => Column(
                children: [
                  CircularProgressIndicator(value: value),
                  child!
                ],
              ),
              child: Text("即将开始..."),
            )
          ],
        ),
      ),
    );
  }
}

class PKOngoingPage extends StatefulWidget {
  const PKOngoingPage({super.key});

  @override
  State<StatefulWidget> createState() => _PKOngoingPage();
}

class _PKOngoingPage extends State<PKOngoingPage> {
  int state = 0;
  PageController pageController = PageController();
  List<List<String>> choiceOptions = [];

  @override
  void initState() {
    Random rnd = Random(context.read<PKServer>().rndSeed);
    for(WordItem wordItem in context.read<PKServer>().pkState.testWords) {
      List<WordItem> optionWords = getRandomWords(4, AppData().wordData, allowRepet: false, include: wordItem, shuffle: true, rnd: rnd);
      choiceOptions.add(List.generate(4, (int index) => optionWords[index].chinese));
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建局域网联机对局页面");
    MediaQueryData mediaQuery = MediaQuery.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: Text("局域网联机"), automaticallyImplyLeading: false),
        body: Column(
          children: [
            TopScoreBar(state: context.watch<PKServer>().pkState),
            Expanded(
              child: SizedBox(
                width: mediaQuery.size.width,
                child: PageView.builder(
                  controller: pageController,
                  itemCount: context.read<PKServer>().pkState.testWords.length + 1,
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    if(index == context.read<PKServer>().pkState.testWords.length) {
                      if(context.read<PKServer>().pkState.sideTookenTime == null) {
                        return Center(
                          child: Text("等待对方完成中...", style: Theme.of(context).textTheme.headlineSmall),
                        );
                      } else {
                        int selfCorrect = 0;
                        int sideCorrect = 0;
                        for(int i = 0;i < context.read<PKServer>().pkState.testWords.length; i++) {
                          if(context.read<PKServer>().pkState.sideProgress[i]) {
                            sideCorrect++;
                          }
                          if (context.read<PKServer>().pkState.selfProgress[i]) {
                            selfCorrect++;
                          }
                        }
                        double selfPt = context.read<PKServer>().calculatePt(context.read<PKServer>().pkState.selfProgress, context.read<PKServer>().pkState.selfTookenTime!);
                        double sidePt = context.read<PKServer>().calculatePt(context.read<PKServer>().pkState.sideProgress, context.read<PKServer>().pkState.sideTookenTime!);
                        return PKConclue(
                          selfCorrect: selfCorrect, 
                          sideCorrect: sideCorrect, 
                          selfPt: selfPt, 
                          sidePt: sidePt
                        );
                      }
                    }
                    return ChoiceQuestions(
                      mainWord: context.read<PKServer>().pkState.testWords[index].arabic, 
                      choices: choiceOptions[index], 
                      allowAudio: true, 
                      allowAnitmation: false,
                      onSelected: (int choosed) {
                        pageController.nextPage(duration: Durations.medium2, curve: StaticsVar.curve);
                        if(choiceOptions[index][choosed] == context.read<PKServer>().pkState.testWords[index].chinese) {
                          context.read<PKServer>().updateState(true);
                          return true;
                        } else {
                          context.read<PKServer>().updateState(false);
                          return false;
                        }
                      },
                      allowMutipleSelect: false,
                    );
                  }
                ),
              ),
            )
          ],
        )
      ),
    );
  }
}

class PKConclue extends StatelessWidget {
  const PKConclue({
    super.key,
    required this.selfCorrect,
    required this.sideCorrect,
    required this.selfPt,
    required this.sidePt,
  });

  final int selfCorrect;
  final int sideCorrect;
  final double selfPt;
  final double sidePt;

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建局域网联机总结");
    MediaQueryData mediaQuery = MediaQuery.of(context);

    return Column(
      children: [
        Text("回答正确数", style:Theme.of(context).textTheme.titleLarge),
        TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0,
            end: 1
          ), 
          curve: StaticsVar.curve,
          duration: Duration(seconds: 1), 
          builder: (context, value, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(16.0),
                  height: mediaQuery.size.height * 0.1,
                  width: min(value*2, 1) * mediaQuery.size.width * (0.5 + 0.25*((selfCorrect - sideCorrect)/context.read<PKServer>().pkState.testWords.length)),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: Text("你  ${(value*selfCorrect).floor()}", style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.end),
                ),
                Container(
                  padding: EdgeInsets.all(16.0),
                  height: mediaQuery.size.height * 0.1,
                  width: min(value*2, 1) * mediaQuery.size.width * (0.5 - 0.25*((selfCorrect - sideCorrect)/context.read<PKServer>().pkState.testWords.length)),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
                  child: Text("${(value*sideCorrect).floor()}  对方", style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.start),
                ),
              ],
            );
          }
        ),
        SizedBox(height: mediaQuery.size.height * 0.05),
        Text("回答用时", style:Theme.of(context).textTheme.titleLarge),
        TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0,
            end: 1
          ), 
          curve: StaticsVar.curve,
          duration: Durations.medium2, 
          builder: (context, value, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(16.0),
                  height: mediaQuery.size.height * 0.1,
                  width: min(value*2, 1) * mediaQuery.size.width * (0.5 - 0.25*(context.read<PKServer>().pkState.selfTookenTime! - context.read<PKServer>().pkState.sideTookenTime!)/300),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: Text("你  ${(value*context.read<PKServer>().pkState.selfTookenTime!).floor()}秒", style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.end),
                ),
                Container(
                  padding: EdgeInsets.all(16.0),
                  height: mediaQuery.size.height * 0.1,
                  width: min(value*2, 1) * mediaQuery.size.width * (0.5 + 0.25*(context.read<PKServer>().pkState.selfTookenTime! - context.read<PKServer>().pkState.sideTookenTime!)/300),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
                  child: Text("${(value*context.read<PKServer>().pkState.sideTookenTime!).floor()}秒  对方", style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.start),
                ),
              ],
            );
          }
        ),
        SizedBox(height: mediaQuery.size.height * 0.05),
        Text("计算得分", style:Theme.of(context).textTheme.titleLarge),
        TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0,
            end: 1
          ), 
          curve: StaticsVar.curve,
          duration: Duration(seconds: 2), 
          builder: (context, value, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(16.0),
                  height: mediaQuery.size.height * 0.1,
                  width: min(value*2, 1) * mediaQuery.size.width * (0.5 + 0.25*(selfPt - sidePt)/300),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: Text("你  ${(value*selfPt).round()}Pt", style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.end),
                ),
                Container(
                  padding: EdgeInsets.all(16.0),
                  height: mediaQuery.size.height * 0.1,
                  width: min(value*2, 1) * mediaQuery.size.width * (0.5 - 0.25*(selfPt - sidePt)/300),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
                  child: Text("${(value*sidePt).round()}Pt  对方", style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.start),
                ),
              ],
            );
          }
        ),
        Expanded(child: SizedBox()),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            fixedSize: Size(mediaQuery.size.width * 0.8, mediaQuery.size.height * 0.15),
            shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
          ),
          onPressed: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
          icon: Icon(Icons.exit_to_app),
          label: Text("退出"),
        )
      ]
    );
  }
}

class TopScoreBar extends StatelessWidget {
  final PKState state;
  const TopScoreBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SizedBox(width: mediaQuery.size.width * 0.02),
            Text("你的"),
            Expanded(
              child: TweenAnimationBuilder(
                tween: Tween(
                  begin: 0.0,
                  end: context.watch<PKServer>().pkState.selfProgress.length/context.watch<PKServer>().pkState.testWords.length
                ),
                duration: Durations.medium2,
                builder: (context, value, child) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 15,
                    borderRadius: StaticsVar.br,
                  );
                }
              ),
            ),
            SizedBox(width: mediaQuery.size.width * 0.02)
          ],
        ),
        Row(
          children: [
            SizedBox(width: mediaQuery.size.width * 0.02),
            Text("对方"),
            Expanded(
              child: TweenAnimationBuilder(
                tween: Tween(
                  begin: 0.0,
                  end: context.watch<PKServer>().pkState.sideProgress.length/context.watch<PKServer>().pkState.testWords.length
                ),
                duration: Durations.medium2,
                builder: (context, value, child) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 15,
                    borderRadius: StaticsVar.br,
                  );
                }
              ),
            ),
            SizedBox(width: mediaQuery.size.width * 0.02),
          ],
        ),
      ],
    );
  }
}

class PKErrorPage extends StatelessWidget {
  const PKErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 64),
            TextContainer(text: "连接丢失"),
            TextContainer(text: "原因: ${context.read<PKServer>().exitMessage??"未知"}"),
            ElevatedButton(
              onPressed: () => Navigator.pop(context), 
              child: Text("返回")
            )
          ],
        ),
      ),
    );
  }
}