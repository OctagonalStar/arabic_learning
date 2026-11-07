// Web 补丁：sherpa-onnx-asr.js 的 OfflineRecognizer 是 `class` 声明，
// 而 sherpa_onnx_web 用间接 eval 注入脚本——class 只会留在那次 eval 的临时
// 词法环境里、调用结束即丢弃，既不是 globalThis 属性也不可再生。
// Dart 绑定按属性名取构造函数，于是必然报 "OfflineRecognizer not found"。
// 这里把同一份 wrapper 再包一层函数 eval 一次，主动挂到 globalThis。
// 上游 1.13.8 / 2.0.1 均未修复。

import 'package:arabic_learning/services/web_asr_globals_stub.dart'
    if (dart.library.html) 'package:arabic_learning/services/web_asr_globals_web.dart'
    as impl;

Future<void> exposeSherpaOnnxAsrGlobals() =>
    impl.exposeSherpaOnnxAsrGlobals();
