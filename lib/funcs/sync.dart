import 'dart:convert';
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:webdav_client/webdav_client.dart';

import 'package:arabic_learning/package_replacement/storage.dart' show SharedPreferences;

class WebDAV {
  String uri;
  String user;
  String password;
  WebDAV({required this.uri, required this.user, required this.password});

  bool isReachable = false;
  bool isReadable = false;
  bool isWriteable = false;

  late Client client;

  static Future<List<dynamic>> test(String uri, String user, {String password = ''}) async {
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
    } catch (e) {
      return [false, false, "base setting error: $e"];
    }
    try{
      await tempClient.ping(); // test for connection
    } catch (e) {
      return [false, false, "remote server didn't response: $e"];
    }
    try {
      await tempClient.readDir('/'); // test for read
    } catch (e) {
      return [true, false, 'no read access: $e'];
    }
    try{
      await tempClient.write("TestFile", Uint8List(64)); // test for write
      await tempClient.remove("TestFile");
    } catch (e) {
      return [true, false, 'no write access: $e'];
    }
    return [true, true, 'ok'];
  } 

  Future<void> connect() async {
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
      await client.write("TestFile", Uint8List(64)); // test for write
      isWriteable = true;
      await client.remove("TestFile");
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<bool> upload(SharedPreferences pref,{bool force = false}) async {
    if(isWriteable || force) {
      await client.write("arabic_learning.bak", utf8.encode(jsonEncode(pref.export())));
      return true;
    }
    return false;
  }

  Future<bool> download(SharedPreferences pref,{bool force = false}) async {
    if(isReadable || force) {
      Map<String, dynamic> file = jsonDecode(utf8.decode(await client.read("arabic_learning.bak")));
      pref.recovery(file);
      return true;
    }
    return false;
  }
}