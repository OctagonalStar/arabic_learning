// 大 JSON 解析 / 序列化的平台选择入口。
//
// 原生平台把工作丢进后台 isolate（`json_offload_io.dart`）；Web 没有 isolate
// （`Isolate.run` 在浏览器上不可用），退回同步实现（`json_offload_web.dart`）。
// 与 `core/doh.dart` 同一套条件导出约定：请勿直接 import 分支文件。
//
// 只处理「纯 JSON 值」：isolate 之间只能传可发送类型
// （Map / List / String / int / double / bool / null），因此
// `WordItem` / `DictData` 等自定义类的构造必须留在调用方（主）isolate。
export 'json_offload_web.dart' if (dart.library.io) 'json_offload_io.dart';
