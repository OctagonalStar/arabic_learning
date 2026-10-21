// `core/json_offload.dart` 的原生实现（dart:io 平台）。
//
// 词库 JSON 有 2~6MB，`jsonDecode` 在主 isolate 上要几十毫秒到上百毫秒，
// 启动时足以吃掉首帧。这里用 `Isolate.run` 把解码搬到临时后台 isolate：
// 传进去的是 String，传回来的是纯 JSON 值（Map/List/String/num/bool/null），
// 都是可发送类型；`WordItem` 等自定义类仍在主 isolate 构造。
//
// 实测（Linux x86_64 / Dart 3.13 / 合成词库，`dart run` 而非 flutter test，
// 后者会禁用 isolate —— 见 [_isolateOffloadAvailable]）：
//
//   词数   体积     sync 总耗时 / 最长主 isolate 阻塞   isolate 总耗时 / 最长阻塞
//    500   86KB         1.1ms /  2.5ms                    2.3ms /  2.1ms
//   2000  349KB         3.1ms /  6.4ms                    5.4ms /  3.6ms
//   5000  878KB         9.8ms / 18.9ms                   11.0ms / 10.5ms
//  12000  2.1MB        14.8ms / 30.6ms                   25.5ms /  7.9ms
//  20000  3.6MB        26.5ms / 48.5ms                   43.5ms / 11.8ms
//  35000  6.3MB        54.0ms / 76.2ms                   72.0ms / 11.2ms
//
// 结论：isolate 路径的**总耗时**更高（起 isolate + 消息拷贝 ≈ 1.3~1.4x），
// 但主 isolate 的**最长连续阻塞**从 76ms 降到 11ms —— 这正是「不卡首帧」的
// 目标，所以宁可多花一点总时间。低于 [kJsonOffloadThreshold] 时收益为零
// （甚至略亏），故直接同步解析。

import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:isolate';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// 小于该长度的文本直接在调用方 isolate 解析。
///
/// 由上面的实测表定：约 256KB（≈1500 词）以下，同步解码的最长阻塞仍在
/// 3ms 量级，卸载到 isolate 只会多付一次往返。词库（通常 350KB~6MB）与
/// 较大的阅读数据会走 isolate，设置类的小键保持同步。
const int kJsonOffloadThreshold = 256 * 1024;

/// 是否允许把解码/编码搬到后台 isolate。
///
/// `flutter test` 下必须禁用：`testWidgets` 运行在 `FakeAsync` 区里，真实的
/// isolate 消息永远不会被泵送，`Isolate.run` 的 Future 会永久挂起（实测超时）。
/// 这与 `services/db/fsrs_drift_store.dart` 用 `FLUTTER_TEST` 区分测试环境的
/// 做法一致；测试因此走同步路径，行为与改造前完全相同。
bool get _isolateOffloadAvailable =>
    debugForceIsolateOffload ??
    (Platform.environment['FLUTTER_TEST'] != 'true');

/// 测试钩子：强制开启 / 关闭 isolate 卸载（`null` 表示按平台环境自动判断）。
///
/// 普通 `test()`（非 `testWidgets`，没有 FakeAsync）可以把它设为 `true`，
/// 从而在 `flutter test` 里真正覆盖 isolate 往返分支；用例结束必须复位。
/// 生产代码不得设置它。
@visibleForTesting
bool? debugForceIsolateOffload;

/// 解析 JSON 文本；大文本在后台 isolate 解码。
///
/// 解码失败的异常（`FormatException`）会从 isolate 原样传回主 isolate，
/// 与同步解码的失败行为一致（调用方原本靠它判断「数据损坏」）。
Future<Object?> decodeJsonOffMain(String source) async {
  if (!_isolateOffloadAvailable || source.length < kJsonOffloadThreshold) {
    return jsonDecode(source);
  }
  return Isolate.run(() => jsonDecode(source));
}

/// 序列化为 JSON 文本；编码在后台 isolate 完成。
///
/// 只用于启动阶段的一次性数据迁移写回（`wordData` 2~6MB），
/// 调用方需自行处理「编码期间数据已被更新」的竞态（见 AppData 的代际号）。
///
/// 编码的 isolate 收益比解码小（6MB 时同步 6.4ms / isolate 7.5ms，总耗时几乎
/// 持平），但它同样把主 isolate 的阻塞挪走了，且只发生在「存量数据需要纠正」
/// 这种一次性场景，所以不额外加阈值判断。
Future<String> encodeJsonOffMain(Object? value) async {
  if (!_isolateOffloadAvailable) return jsonEncode(value);
  return Isolate.run(() => jsonEncode(value));
}
