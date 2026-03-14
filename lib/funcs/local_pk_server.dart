import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:arabic_learning/funcs/ui.dart';
import 'package:archive/archive.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/config_structure.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:flutter/material.dart' show BuildContext, PageController, Durations;
import 'package:logging/logging.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_webrtc/flutter_webrtc.dart';

class PKServer with ChangeNotifier{
  final Logger logger = Logger("PKServer");
  bool isServer = false;
  bool inited = false;
  RTCPeerConnection? _connection;
  RTCDataChannel? _channel;
  static const Map<String, dynamic> _rtcConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };
  static const Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };
  String? exitMessage;
  int packageAmount = 0;
  PageController? pageController;
  List<SourceItem> selectableSource = [];
  ClassSelection? classSelection;
  late int rndSeed;
  Duration? delay;
  bool preparedP1 = false;
  bool preparedP2 = false;
  late PKState pkState;
  bool over = false;
  DateTime? startTime;
  bool get connected => _connection?.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
  String? connectpwd;

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }

  Future<void> initHost(bool isHoster, BuildContext context, {String? offer}) async {
    isServer = isHoster;

    try {
      logger.info("正在初始化WebRTC");
      _connection = await createPeerConnection(_rtcConfig, _rtcConstraints);
      _connection!.onConnectionState = (state) {
        logger.info("连接状态变更: $state");
        if(state == RTCPeerConnectionState.RTCPeerConnectionStateFailed && _channel != null && !over) {
            disconnect();
            pageController!.jumpToPage(4);
        }
        notifyListeners();
      };
      if(isServer) {
        _channel = await _connection!.createDataChannel("Connection", RTCDataChannelInit());
        logger.info("已创建信道");
        _channel!.onMessage = ((msg) {
          logger.fine('收到消息：${msg.text}');
        });
        _setupDataChannel();
        RTCSessionDescription offer = await _connection!.createOffer(_rtcConstraints);
        await _connection!.setLocalDescription(offer);
        // 等待 ICE 收集完毕后再生成最终字符串，防止 Candidate 丢失
        await _waitForIceGathering(); 
      } else {
        await _connection!.setRemoteDescription(RTCSessionDescription(utf8.decode(ZLibDecoderWeb().decodeBytes(base64Decode(offer!))), "offer"));
        await _connection!.setLocalDescription(await _connection!.createAnswer(_rtcConstraints));
        _connection!.onDataChannel = (channel) {
        logger.info("Client 接收到了来自 Server 的 DataChannel: ${channel.label}");
          _channel = channel;
          _setupDataChannel();
        };
        await _waitForIceGathering();
      }
    } catch (e) {
      if(!context.mounted) return;
      alart(context, "构建连接错误: $e");
    }
    
    notifyListeners();
  }

  Future<void> _waitForIceGathering() async {
    if (_connection!.iceGatheringState == RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    
    final completer = Completer<void>();
    _connection!.onIceGatheringState = (state) async {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        if (!completer.isCompleted) completer.complete();
        String sdp = (await _connection!.getLocalDescription())!.sdp!;
        sdp = optimizeSdp(sdp);
        connectpwd = base64Encode(ZLibEncoderWeb().encodeBytes(utf8.encode(sdp), level: 9));
        logger.info("最终的SDP: $sdp");
        inited = true;
        notifyListeners();
      }
    };
    
    // 增加超时保护（某些网络下可能收不到完成信号）
    return completer.future.timeout(const Duration(seconds: 15), onTimeout: () async {
      logger.info("ICE 收集超时，尝试使用当前收集到的 Candidate");
      String sdp = (await _connection!.getLocalDescription())!.sdp!;
      sdp = optimizeSdp(sdp);
      connectpwd = base64Encode(ZLibEncoderWeb().encodeBytes(utf8.encode(sdp), level: 9));
      inited = true;
      notifyListeners();
    });
  }

  static String optimizeSdp(String sdp) {
    List<String> lines = sdp.split('\r\n');
    List<String> newLines = [];
    bool inDataBlock = false;
    for (var line in lines) {
      if(
        line.startsWith('v=') || 
        line.startsWith('o=') || 
        line.startsWith('s=') || 
        line.startsWith('t=') ||
        line.startsWith('a=ice-ufrag:') ||
        line.startsWith('a=ice-pwd:') ||
        line.startsWith('a=fingerprint:') || 
        line.startsWith('a=setup:') ||
        line.startsWith('a=sctp-port:') ||
        line.startsWith('a=mid:')
        ){
        newLines.add(line);
        continue;
      }
      if (line.startsWith('m=')) {
        if(line.contains("application")) {
          inDataBlock = true;
        } else {
          inDataBlock = false;
        }
      }
      if (inDataBlock) {
        newLines.add(line);
      }
    }
    return newLines.join('\r\n');
  }

  void _setupDataChannel() {
    _channel?.onMessage = (RTCDataChannelMessage message) {
      handleReceivedMessage(message.text);
    };
    _channel?.onDataChannelState = (state) {
      logger.fine("Channel 状态: $state");
      notifyListeners();
    };
  }

  void setPageControler(PageController pageController) => this.pageController = pageController;

  Future<void> loadAnswer(String answer, BuildContext context) async {
    await _connection!.setRemoteDescription(RTCSessionDescription(utf8.decode(ZLibDecoderWeb().decodeBytes(base64Decode(answer))), "answer"));
    while(!connected || _channel?.state != RTCDataChannelState.RTCDataChannelOpen){
      await Future.delayed(Duration(seconds: 1));
      logger.fine("等待连接远程");
    }
    _channel!.send(RTCDataChannelMessage("ping"));
    _questVersionCheck();
  }

  void disconnect({bool normal = false}) async {
    _channel?.close();
    _connection?.close();
    _channel = null;
    _connection = null;
  }

  void _questVersionCheck() async => _channel!.send(RTCDataChannelMessage(json.encode({"step": 0, "version": StaticsVar.appVersion})));

  void _questDictExchange() async {
    AppData appData = AppData();
    _channel!.send(RTCDataChannelMessage(
      json.encode({
        "step": 1,
        "dictSum": List<String>.generate(appData.wordData.classes.length, (int index) => 
          appData.wordData.classes[index].getHash(appData.wordData.words), growable: false)
      })
    ));
  }

  void setSelectedClass(ClassSelection selection) {
    classSelection = selection;
    rndSeed = Random().nextInt(1024);
    _channel!.send(RTCDataChannelMessage(json.encode({
      "step": 2,
      "selected": List<String>.generate(classSelection!.selectedClass.length, (int index) => classSelection!.selectedClass[index].toString(), growable: false),
      "rndSeed": rndSeed
    })));
  }

  void setPrepare() {
    preparedP1 = true;
    pkState = PKState(
      testWords: getSelectedWords(AppData().wordData, classSelection!.selectedClass, doShuffle: true, shuffleSeed: rndSeed), 
      selfProgress: [], 
      sideProgress: []
    );
    logger.fine("已完成PKState初始化");
    _channel!.send(RTCDataChannelMessage(json.encode({
      "step": 3
    })));
    if(isServer && preparedP1 && preparedP2) _questStartTime();
    notifyListeners();
  }

  void _questStartTime(){
    startTime = DateTime.now().add(Duration(seconds: 5));
    Future.delayed(Duration(seconds: 5), () => pageController!.nextPage(duration: Durations.medium2, curve: StaticsVar.curve));
    _channel!.send(RTCDataChannelMessage(json.encode({
      "step": 4,
      "startTime": startTime?.add(delay!).toIso8601String()
    })));
    notifyListeners();
  }

  void handleReceivedMessage(String? message) {
    if(message == null) return;
    
    // 方便在日志里跟踪一个包
    final int packageid = packageAmount++;

    // 处理心跳包
    if(message == "ping") {
      logger.finer("[$packageid] 回复心跳包");
      _channel!.send(RTCDataChannelMessage("pong"));
      Future.delayed(Duration(seconds: 5), (){
        if(_channel?.state == RTCDataChannelState.RTCDataChannelOpen) {
          logger.finer("发送心跳包");
          _channel!.send(RTCDataChannelMessage("ping"));
        }
      });
      return;
    }
    if(message == "pong") {
      return;
    }

    // 处理数据包
    Map<String, dynamic>? data;
    int step = -1;
    try {
      data = json.decode(message);
      if(data == null) throw Exception("null decoded");
      step = data["step"]??-1;
      if(step == -1) throw Exception("null step block");
    } catch (e) {
      logger.warning("[$packageid] 解析数据包错误: $e;原信息: $message");
      return;
    }

    AppData appData = AppData();

    switch(step){
      /// 版本号检查结果 from Client
      case 0 when data.containsKey("accepted"): {
        logger.fine("[$packageid] 获取到版本检查结果");
        if(data["accepted"]??false) {
          logger.fine("[$packageid] 版本检查通过");
          _questDictExchange();
        } else {
          logger.warning("[$packageid] 版本检查未能通过，我方版本为${StaticsVar.appVersion}，对方版本为${data["version"]}");
          exitMessage = "版本检查未能通过，我方版本为${StaticsVar.appVersion}，对方版本为${data["version"]}";
          disconnect();
        }
        break;
      }
      /// 版本号检查 from Server
      case 0 when data.containsKey("version"): {
        logger.fine("[$packageid] 进行版本匹配检查");
        if(data["version"] == StaticsVar.appVersion) {
          logger.fine("[$packageid] 版本检查通过");
          _channel!.send(RTCDataChannelMessage(json.encode({"step": 0, "accepted": true})));
        } else {
          logger.warning("[$packageid] 版本检查未能通过，我方版本为${StaticsVar.appVersion}，对方版本为${data["version"]}");
          _channel!.send(RTCDataChannelMessage(json.encode({"step": 0, "accepted": false, "version": StaticsVar.appVersion})));
        }
        break;
      }
      /// 词库共通检查结果 from Client
      case 1 when data.containsKey("accepted"): {
        logger.fine("[$packageid] 获取到词库检查结果");
        if(data["accepted"]) {
          delay = DateTime.parse(data["time"]).difference(DateTime.now());
          List sumList = data["dictSum"];
          selectableSource.clear();
          for(SourceItem source in appData.wordData.classes) {
            if(sumList.contains(source.getHash(appData.wordData.words))) selectableSource.add(source);
            logger.fine("[$packageid] 计算得到${source.sourceJsonFileName}在哈希中有匹配");
          }
          pageController!.nextPage(duration: Durations.medium2, curve: StaticsVar.curve);
        } else {
          logger.warning("[$packageid] 双端没有任意词库匹配");
          exitMessage = "双端没有任意词库匹配";
          disconnect();
        }
        break;
      }
      /// 词库共通检查 from Server
      case 1 when data.containsKey("dictSum"): {
        logger.fine("[$packageid] 进行词库检查");
        List sumList = data["dictSum"];
        selectableSource.clear();
        for(SourceItem source in appData.wordData.classes) {
          if(sumList.contains(source.getHash(appData.wordData.words))) {
            selectableSource.add(source);
            logger.fine("[$packageid] 计算得到${source.sourceJsonFileName}在哈希中有匹配");
          }
        }
        if(selectableSource.isNotEmpty) {
          _channel!.send(RTCDataChannelMessage(json.encode({
            "step": 1, 
            "accepted": true, 
            "dictSum": List.generate(selectableSource.length, (int index) => selectableSource[index].getHash(appData.wordData.words)),
            "time": DateTime.now().toIso8601String()
          })));
          pageController!.nextPage(duration: Durations.medium2, curve: StaticsVar.curve);
        } else {
          _channel!.send(RTCDataChannelMessage(json.encode({
            "step": 1,
            "accepted": false
          })));
          logger.warning("[$packageid] 双端没有任意词库匹配");
          exitMessage = "双端没有任意词库匹配";
        }
        break;
      }
      /// 接受房主发送选择情况 from Server
      case 2 when data.containsKey("selected"): {
        logger.fine("[$packageid] 接收到房主的课程选择");
        rndSeed = data["rndSeed"];
        List<ClassItem> selectedClass = [];
        for(SourceItem sourceItem in selectableSource) {
          for(ClassItem classItem in sourceItem.subClasses){
            if(data["selected"].contains(classItem.toString())){
              selectedClass.add(classItem);
            }
          }
        }
        classSelection = ClassSelection(selectedClass: selectedClass, countInReview: false);
        pageController!.nextPage(duration: Durations.medium2, curve: StaticsVar.curve);
        break;
      }
      /// 接受对方完成准备 from both
      case 3: {
        preparedP2 = true;
        if(isServer && preparedP1 && preparedP2) _questStartTime();
        notifyListeners();
        break;
      }
      /// 接受服务端的开始时间 from Server
      case 4: {
        startTime = DateTime.parse(data["startTime"]);
        Future.delayed(-DateTime.now().difference(startTime!), 
          ()=>pageController!.nextPage(duration: Durations.medium2, curve: StaticsVar.curve));
        notifyListeners();
        break;
      }
      /// 同步双端状态 from both
      case 5: {
        pkState.sideProgress = List.generate(data["progress"].length, (int index)=>data!["progress"][index] as bool);
        if(data["tookenTime"] != null) {
          pkState.sideTookenTime = data["tookenTime"];
          over = true;
        }
        notifyListeners();
      }
    }
  }

  void updateState(bool correct) {
    pkState.selfProgress.add(correct);
    if(pkState.selfProgress.length == pkState.testWords.length) {
      pkState.selfTookenTime = DateTime.now().difference(startTime!).inSeconds;
    }
    _channel!.send(RTCDataChannelMessage(json.encode({
      "step": 5,
      "progress": pkState.selfProgress,
      "tookenTime": pkState.selfTookenTime
    })));
    notifyListeners();
  }

  double calculatePt(List<bool> progress, int tookenTime) {
    int correctCount = 0;
    for(bool value in progress) {
      if(value) correctCount++;
    }
    return 750*(correctCount/progress.length) + 250 - tookenTime;
  }
}

class PKState {
  List<WordItem> testWords;
  List<bool> selfProgress;
  int? selfTookenTime;
  List<bool> sideProgress;
  int? sideTookenTime;

  PKState({required this.testWords, required this.selfProgress, required this.sideProgress});
}