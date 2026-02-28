import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:arabic_learning/funcs/ui.dart' show alart;
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/config_structure.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:flutter/material.dart' show BuildContext;
import 'package:logging/logging.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:dio/dio.dart' as dio;

class PKServer with ChangeNotifier{
  final Logger logger = Logger("PKServer");
  bool isServer = false;
  late int rndSeed;
  List<SourceItem> selectableSource = [];
  ClassSelection? classSelection;
  late Global global;
  DateTime? startTime;
  bool preparedP1 = false;
  bool preparedP2 = false;
  late PKState pkState;
  late RTCPeerConnection _connection;
  late RTCDataChannel _channel;
  bool started = false;
  Duration? delay;
  late RTCSessionDescription _offer;
  late RTCSessionDescription _answer;
  bool get connected {
    return false;
    //return _connection.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
  }

  String? get connectpwd {
    return base64Encode(ZLibEncoderWeb().encodeBytes(utf8.encode(isServer ? _offer.sdp! : _answer.sdp!)));
  }

  void renew() {
    selectableSource = [];
    classSelection = null;
    startTime = null;
    preparedP1 = false;
    preparedP2 = false;
    started = false;
    delay = null;
  }

  Future<bool> initHost(bool isHoster, Global outerglobal, {String? offer}) async {
    isServer = isHoster;
    global = outerglobal;

    logger.info("正在初始化WebRTC");
    _connection = await createPeerConnection({'iceServers': []});
    _channel = await _connection.createDataChannel("Connection", RTCDataChannelInit());
    _channel.onMessage = ((msg) {
      logger.fine('收到消息：${msg.text}');
    });

    if(isServer) {
      logger.fine("正在生成Offer");
      _offer = await _connection.createOffer();
      logger.info("offer详情: ${_offer.sdp}");
      await _connection.setLocalDescription(_offer);
    } else {
      await _connection.setRemoteDescription(RTCSessionDescription(utf8.decode(ZLibDecoderWeb().decodeBytes(base64Decode(offer!))), "offer"));
      _answer = await _connection.createAnswer();
    }
    return true;
  }

  void loadAnswer(String answer) async {
    await _connection.setRemoteDescription(RTCSessionDescription(utf8.decode(ZLibDecoderWeb().decodeBytes(base64Decode(answer))), "answer"));
    while(!connected){
      Future.delayed(Duration(seconds: 1));
      logger.fine("尝试连接远程");
    }
    _channel.send(RTCDataChannelMessage("hello"));
  }

//  Future<bool> startHost() async {
//    if(started) return true;
//    _port = Random().nextInt(55535)+10000;
//    logger.fine("正在启动服务，随机端口: $_port");
//    final router = Router();
//
//    router.get('/api/check', (Request req) {
//      logger.fine("收到check请求");
//      return Response.ok(
//        '{"version":${StaticsVar.appVersion}}',
//        headers: {'Content-Type': 'application/json'},
//      );
//    });
//
//    router.post('/api/testDictSum', (Request req) async {
//      if(connected == true) return Response.forbidden("");
//      Map<String, dynamic> body = json.decode(await req.readAsString());
//      logger.fine("收到testDictSum请求，负载: $body");
//      // {
//      //  "dictSum": ["SHA256", ...]
//      // }
//      List sumList = body["dictSum"];
//      selectableSource.clear();
//      for(SourceItem source in global.wordData.classes) {
//        if(sumList.contains(source.getHash(global.wordData.words))) selectableSource.add(source);
//        logger.fine("计算得到${source.sourceJsonFileName}在哈希中有匹配");
//      }
//      if(selectableSource.isNotEmpty) connected = true;
//      notifyListeners();
//      return Response.ok(json.encode({
//        "accept": selectableSource.isNotEmpty,
//        "allowed": List<String>.generate(selectableSource.length, (int index) => selectableSource[index].getHash(global.wordData.words), growable: false)
//        }),
//        headers: {'Content-Type': 'application/json'}
//      );
//    });
//
//    router.get('/api/selection', (Request req) {
//      logger.fine("收到selection请求");
//      if(classSelection == null) {
//        logger.fine("房主暂未完成选择，statue: false");
//        return Response.ok(json.encode({"statue": false}), headers: {'Content-Type': 'application/json'});
//      }
//      rndSeed = Random().nextInt(1024);
//      logger.finer("随机种子: $rndSeed");
//      return Response.ok(
//        json.encode(
//          {
//            "statue": true,
//            "selected": List<String>.generate(classSelection!.selectedClass.length, (int index) => classSelection!.selectedClass[index].getHash(), growable: false),
//            "seed": rndSeed
//          }
//        ),
//        headers: {'Content-Type': 'application/json'},
//      );
//    });
//
//    router.post('/api/prepare', (Request req) async {
//      Map<String, dynamic> body = json.decode(await req.readAsString());
//      logger.fine("收到prepare请求，负载 $body");
//
//      if(body["time"] != null && delay == null) {
//        delay = DateTime.tryParse(body["time"])!.difference(DateTime.now());
//        logger.info("已加载双端延迟补偿: ${delay!.inSeconds}秒");
//      }
//      if(body["prepared"]) {
//        preparedP2 = true;
//        logger.fine("对方准备完毕");
//        if(preparedP1 && startTime == null) {
//          startTime = DateTime.now().add(Duration(seconds: 5));
//          pkState = PKState(
//            testWords: getSelectedWords(global.wordData, classSelection!.selectedClass, doShuffle: true, shuffleSeed: rndSeed), 
//            selfProgress: [], 
//            sideProgress: []
//          );
//          logger.fine("已生成开始时间: $startTime(添加delay后为: ${startTime?.add(delay!).toIso8601String()}); PKState已初始化");
//        }
//        notifyListeners();
//      }
//      
//      
//      return Response.ok(json.encode({
//        "prepared": preparedP1,
//        "start": startTime?.add(delay!).toIso8601String()
//        }),
//        headers: {'Content-Type': 'application/json'}
//      );
//    });
//
//    router.post('/api/sync', (Request req) async {
//      Map<String, dynamic> body = json.decode(await req.readAsString());
//      logger.finer("收到sync请求，负载: $body");
//      bool changed = false;
//      if(body["progress"] != null && body["progress"].length != pkState.sideProgress.length) {
//        pkState.sideProgress = List.generate(body["progress"].length, (int index) => body["progress"][index] as bool);
//        logger.fine("已更新本地PKState.sideProgress");
//        changed = true;
//      }
//      if(pkState.sideProgress.length == pkState.testWords.length && body["tooken"] != null) {
//        pkState.sideTookenTime = body["tooken"];
//        logger.fine("已更新本地PKState.sideTookenTime");
//        changed = true;
//      }
//      if(changed) notifyListeners();
//      if(pkState.selfTookenTime != null) logger.fine("回报本地tokenTime: ${pkState.selfTookenTime}");
//      return Response.ok(json.encode({
//        "progress": pkState.selfProgress,
//        "tooken": pkState.selfTookenTime
//        }),
//        headers: {'Content-Type': 'application/json'}
//      );
//    });
//
//    router.get('/api/done', (Request req) async {
//      logger.info("收到done请求");
//      Future.delayed(Duration(seconds: 1), () {
//        stopHost();
//      });
//      notifyListeners();
//      return Response.ok(null);
//    });
//
//    _connection = await io.serve(
//      router.call,
//      '0.0.0.0', // 局域网可访问
//      _port,
//    );
//
//    logger.fine("服务端已启动");
//    started = true;
//    return true;
//  }


//  Future<int> testConnect(String connectpwd) async {
//    List<int>? addressinfo = decodeConnectPwd(connectpwd);
//    if(addressinfo == null) {
//      logger.severe("联机口令解析失败，终止连接");
//      return 1;
//    }
//    serverAddress = "http://${_localIP!.split(".")[0]}.${addressinfo[0]}.${addressinfo[1]}.${addressinfo[2]}:${addressinfo[3]}";
//    logger.info("服务端口解析结果: $serverAddress");
//    final checkRes = await client.get("$serverAddress/api/check");
//    if(checkRes.statusCode != 200) {
//      logger.severe("连接服务端失败");
//      return 2;
//    }
//    if(checkRes.data["version"] != StaticsVar.appVersion) {
//      logger.severe("版本校验不通过，对方版本为: ${checkRes.data["version"]}，我方为${StaticsVar.appVersion}");
//      return 3;
//    }
//    logger.fine("双端版本校验通过");
//    final dictRes = await client.post(
//      "$serverAddress/api/testDictSum", 
//      data: {
//        "dictSum": List<String>.generate(global.wordData.classes.length, (int index) => global.wordData.classes[index].getHash(global.wordData.words), growable: false)
//      }
//    );
//    if(dictRes.statusCode != 200) {
//      logger.severe("连接服务端失败");
//      return 2;
//    }
//    if(!dictRes.data["accept"]) {
//      logger.severe("本地与服务端无可使用的相同词库");
//      return 4;
//    }
//    selectableSource.clear();
//    List remoteDict = dictRes.data["allowed"];
//    for(SourceItem source in global.wordData.classes) {
//      if(remoteDict.contains(source.getHash(global.wordData.words))) selectableSource.add(source);
//    }
//    connected = true;
//    notifyListeners();
//    return 0;
//  }

//  Future<void> watingSelection(BuildContext context, Function onEnd) async {
//    logger.fine("开始等待服务端选择课程");
//    bool isException = false;
//    while(classSelection == null) {
//      await Future.delayed(Duration(seconds: 1));
//      try{
//        logger.fine("正在检查选择情况");
//        final selectionRes = await client.get("$serverAddress/api/selection", options: dio.Options(connectTimeout: Duration(seconds: 1)));
//        if(selectionRes.statusCode != 200) throw Exception("Unexcepted statusCode: ${selectionRes.statusCode}");
//        Map payload = selectionRes.data;
//        logger.finer("此次检查结果: $payload");
//        if(!payload["statue"]) continue;
//        rndSeed = payload["seed"];
//        List<ClassItem> selectedClass = [];
//        for(SourceItem sourceItem in selectableSource) {
//          for(ClassItem classItem in sourceItem.subClasses){
//            if(payload["selected"].contains(classItem.getHash())){
//              selectedClass.add(classItem);
//            }
//          }
//        }
//        classSelection = ClassSelection(selectedClass: selectedClass, countInReview: false);
//      } catch (e) {
//        logger.shout("连接服务端发生错误: $e");
//        if(context.mounted) alart(context, "连接丢失 ${e.toString()}", onConfirmed: () => Navigator.popUntil(context, (route) => route.isFirst));
//        isException = true;
//        break;
//      } 
//    }
//    if(!isException) onEnd();
//  }
//
//  Future<void> watingPrepare(BuildContext context) async {
//    logger.fine("开始等待双端准备");
//    while (!preparedP2 || startTime == null) {
//      try{
//        logger.fine("正在交换等待情况");
//        await Future.delayed(Duration(seconds: 1));
//        final prepareRes = await client.post(
//          "$serverAddress/api/prepare", 
//          data: {
//            "prepared": preparedP1,
//            "time": DateTime.now().toIso8601String()
//          }
//        );
//        if(prepareRes.statusCode != 200) throw Exception("Unexcepted statusCode: ${prepareRes.statusCode}");
//        logger.finer("交换结果: ${prepareRes.data}");
//        bool changed = false;
//        if(preparedP2 != prepareRes.data["prepared"]) {
//          preparedP2 = prepareRes.data["prepared"];
//          changed = true;
//        }
//        if(preparedP1 && preparedP2 && prepareRes.data["start"] != null) {
//          startTime = DateTime.tryParse(prepareRes.data["start"]) as DateTime;
//          changed = true;
//        }
//        if(changed) notifyListeners();
//      } catch (e) {
//        logger.shout("连接服务端失败: $e");
//        if(context.mounted) alart(context, "连接丢失 ${e.toString()}", onConfirmed: () => Navigator.popUntil(context, (route) => route.isFirst));
//        break;
//      }
//    }
//  }
//
  void initPK(BuildContext context) {
    pkState = PKState(
      testWords: getSelectedWords(global.wordData, classSelection!.selectedClass, doShuffle: true, shuffleSeed: rndSeed), 
      selfProgress: [], 
      sideProgress: []
    );
    logger.fine("已完成PKState初始化");
//    syncPKState(context);
  }

//  Future<void> syncPKState(BuildContext context) async {
//    logger.info("开始进行双端状态同步");
//    int expCount = 0;
//    while(pkState.selfTookenTime == null || pkState.sideTookenTime == null) {
//      try{
//        if(expCount == 5) {
//          break;
//        }
//        await Future.delayed(Duration(milliseconds: 500));
//        logger.finer("进行状态数据交换");
//        final syncRes = await client.post(
//          "$serverAddress/api/sync",
//          data: {
//            "progress": pkState.selfProgress,
//            "tooken": null
//          },
//          options: dio.Options(connectTimeout: Duration(seconds: 1))
//        );
//        if(syncRes.statusCode != 200) throw Exception("Unexcepted statusCode: ${syncRes.statusCode}");
//        logger.finer("对方交换结果为: ${syncRes.data}");
//        bool changed = false;
//        if(syncRes.data["progress"] != null && syncRes.data["progress"].length != pkState.sideProgress.length) {
//          pkState.sideProgress = List.generate(syncRes.data["progress"].length, (int index) => syncRes.data["progress"][index] as bool);
//          logger.fine("已更新本地PKState.sideProgress");
//          changed = true;
//        }
//        if(pkState.sideProgress.length == pkState.testWords.length && syncRes.data["tooken"] != null) {
//          logger.fine("已更新本地PKState.sideTookenTime");
//          pkState.sideTookenTime = syncRes.data["tooken"];
//          changed = true;
//        }
//        expCount = 0;
//        if(changed) notifyListeners();
//      } catch (e) {
//        logger.shout("同步状态失败 $e");
//        expCount++;
//      }
//    }
//    if(expCount == 5) {
//      if(context.mounted) alart(context, "连接丢失 无法连接到服务端", onConfirmed: () => Navigator.popUntil(context, (route) => route.isFirst));
//    }
//    try{
//      await client.post(
//        "$serverAddress/api/sync",
//        data: {
//          "progress": pkState.selfProgress,
//          "tooken": pkState.selfTookenTime
//        },
//        options: dio.Options(connectTimeout: Duration(seconds: 1))
//      );
//      client.get("$serverAddress/api/done");
//      logger.fine("已通知服务端联机进程完成");
//    } catch (e) {
//      logger.shout("同步状态失败 $e");
//    }
//    
//  }

  void updateState(bool correct) {
    pkState.selfProgress.add(correct);
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