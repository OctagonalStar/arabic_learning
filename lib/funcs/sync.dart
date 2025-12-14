import 'dart:convert';

import 'package:webdav_client/webdav_client.dart';
import 'package:logging/logging.dart';

import 'package:arabic_learning/package_replacement/storage.dart' show SharedPreferences;

class WebDAV {
  String uri;
  String user;
  String password;
  WebDAV({required this.uri, required this.user, required this.password});

  bool isReachable = false;
  bool isReadable = false;

  late Client client;
  final Logger logger = Logger("WebDAV");

  static Future<List<dynamic>> test(String uri, String user, {String password = ''}) async {
    final Logger tempLogger = Logger("WebDAV_Test");
    tempLogger.info("进行WebDAV测试");
    tempLogger.fine("测试uri: $uri");
    Client tempClient = newClient(
      uri,
      user: user,
      password: password
    );
    try{
      tempClient.setHeaders(
        {
          'accept-charset': 'utf-8',
          'Content-Type': 'text/xml',
        },
      );
      tempClient.setConnectTimeout(8000);
      tempClient.setSendTimeout(60000);
      tempClient.setReceiveTimeout(60000);
      tempLogger.fine("完成基础设置");
    } catch (e) {
      tempLogger.warning("基础设置中出现错误: $e");
      return [false, false, "base setting error: $e"];
    }
    try{
      await tempClient.ping(); // test for connection
      tempLogger.fine("PING: 可达性测试成功");
    } catch (e) {
      tempLogger.warning("PING: 可达性测试错误: $e");
      return [false, false, "remote server didn't response: $e"];
    }
    try {
      await tempClient.readDir('/'); // test for read
      tempLogger.fine("READ: 可读性测试成功");
    } catch (e) {
      tempLogger.warning("PING: 可读性测试错误: $e");
      return [true, false, 'no read access: $e'];
    }
    tempLogger.info("所有测试均通过");
    return [true, true, 'ok'];
  } 

  Future<void> connect() async {
    logger.info("正在链接: $uri");
    try{
      client = newClient(
        uri,
        user: user,
        password: password
      );
      client.setHeaders({'accept-charset': 'utf-8'});
      client.setConnectTimeout(8000);
      client.setSendTimeout(8000);
      client.setReceiveTimeout(8000);
      await client.ping(); // test for connection
      isReachable = true;
      await client.readDir(''); // test for read
      isReadable = true;
    } catch (e) {
      logger.warning("链接中出现错误: $e");
      rethrow;
    }
  }

  Future<void> upload(SharedPreferences pref) async {
    logger.info("开始上传文件:");
    try {
        await client.write("arabic_learning.bak", utf8.encode(jsonEncode(pref.export())));
        logger.info("文件上传成功");
        return;
    } catch (e) {
      logger.warning("WebDAV上传失败: $e");
      rethrow;
    }
  }

  Future<void> download(SharedPreferences pref,{bool force = false}) async {
    logger.info("开始恢复文件: 服务可读: $isReadable; force: $force");
    try {
      if(isReadable || force) {
        Map<String, dynamic> file = jsonDecode(utf8.decode(await client.read("arabic_learning.bak")));
        logger.fine("文件下载成功，开始恢复");
        pref.recovery(file);
        return;
      }
      throw Exception("服务不可读，取消恢复");
    } catch (e) {
      logger.warning("WebDAV恢复失败: $e");
      rethrow;
    }
  }
}