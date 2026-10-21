// `core/json_offload.dart` 的 Web 实现。
//
// 浏览器上没有真正的 isolate（`Isolate.run` 会抛 UnsupportedError），
// 因此这里全部退回同步解析 / 序列化。调用方接口保持一致（Future 返回），
// 便于原生 / Web 共用同一段业务代码。

import 'dart:convert';

/// 解析 JSON 文本。Web 上为同步解码，异常以失败 Future 形式抛出。
Future<Object?> decodeJsonOffMain(String source) async => jsonDecode(source);

/// 序列化为 JSON 文本。Web 上为同步编码。
Future<String> encodeJsonOffMain(Object? value) async => jsonEncode(value);
