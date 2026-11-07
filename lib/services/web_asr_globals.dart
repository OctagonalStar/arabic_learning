// Web 补丁：sherpa-onnx-asr.js 用 `class OfflineRecognizer` 声明，
// class 只会进全局词法环境、不会成为 globalThis 的属性，而 Dart 绑定是按
// 属性名取构造函数，于是报 "OfflineRecognizer not found"。
// 这里在 wasm 与 wrapper 加载后把它显式挂到 globalThis 上。非 Web 空实现。

import 'package:arabic_learning/services/web_asr_globals_stub.dart'
    if (dart.library.html) 'package:arabic_learning/services/web_asr_globals_web.dart'
    as impl;

void exposeSherpaOnnxAsrGlobals() => impl.exposeSherpaOnnxAsrGlobals();
