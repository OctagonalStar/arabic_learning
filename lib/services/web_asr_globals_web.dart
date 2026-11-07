// Web 实现：重新注入 asr wrapper，并把其中的类显式挂到 globalThis。

import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/services.dart' show rootBundle;

const String _asrWrapperAsset =
    'packages/sherpa_onnx_web/assets/sherpa-onnx-asr.js';

bool _exposed = false;

Future<void> exposeSherpaOnnxAsrGlobals() async {
  if (_exposed) return;
  if (globalContext.getProperty('OfflineRecognizer'.toJS) != null) {
    _exposed = true;
    return;
  }
  final ByteData data = await rootBundle.load(_asrWrapperAsset);
  final String source = utf8.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  final JSFunction eval =
      globalContext.getProperty('eval'.toJS) as JSFunction;
  // 包在函数里 eval，才能把 class 声明带出来赋值给 globalThis。
  eval.callAsFunction(null, '''
(function () {
$source
globalThis.OfflineRecognizer = OfflineRecognizer;
globalThis.OfflineStream = OfflineStream;
})()
'''.toJS);
  _exposed = true;
}
