// `core/json_offload.dart`（大 JSON 解析 / 序列化的 isolate 卸载）的单元测试。
//
// 重点覆盖 isolate 边界本身：
// - 可发送类型：传 String 进去、取纯 JSON 值（Map/List/String/num/bool/null）回来；
// - 错误传播：isolate 里的 `FormatException` 必须原样传回主 isolate；
// - 阈值：小文本走同步路径（不付 isolate 往返）；
// - 与同步 `jsonDecode` / `jsonEncode` 的结果完全等价。
//
// 注意：`flutter test` 默认禁用 isolate 卸载（`testWidgets` 的 FakeAsync 区
// 不会泵送真实 isolate 消息，`Isolate.run` 会永久挂起）。这里用
// `debugForceIsolateOffload` 在**普通 test()** 里显式开启，真正跑到 isolate 分支。

import 'dart:convert';

import 'package:arabic_learning/core/json_offload.dart';
import 'package:arabic_learning/core/json_offload_io.dart'
    show debugForceIsolateOffload, kJsonOffloadThreshold;
import 'package:flutter_test/flutter_test.dart';

/// 构造一份超过阈值的 JSON（保证走 isolate 分支）。
String _bigJson() {
  final List<Map<String, dynamic>> words = <Map<String, dynamic>>[
    for (int i = 0; i < 4000; i++)
      <String, dynamic>{
        'arabic': 'كلمة$i',
        'chinese': '第 $i 个词的释义，用于测量解析开销',
        'explanation': '说明 $i',
        'subClass': '第 ${i ~/ 50} 课',
        'root': 'كلم',
        'categories': <String>['四级', '常用词'],
        'pos': i.isEven ? 'Nominals' : 'Verbs',
        if (i.isEven) 'gender': true,
      },
  ];
  return jsonEncode(<String, dynamic>{'Words': words});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugForceIsolateOffload = null; // 必须复位，避免污染其它用例
  });

  test('大 JSON 走 isolate：解析结果与同步 jsonDecode 完全一致', () async {
    final String source = _bigJson();
    expect(source.length, greaterThan(kJsonOffloadThreshold),
        reason: '用例前提：文本必须超过卸载阈值');

    debugForceIsolateOffload = true;
    final Object? decoded = await decodeJsonOffMain(source);

    expect(decoded, isA<Map<String, dynamic>>());
    final Map<String, dynamic> map = decoded! as Map<String, dynamic>;
    expect(map['Words'], hasLength(4000));
    // 逐字段比对：确保跨 isolate 没有类型退化（int 变 double、bool 变字符串等）
    final List<dynamic> words = map['Words'] as List<dynamic>;
    final Map<String, dynamic> first = words.first as Map<String, dynamic>;
    expect(first['arabic'], 'كلمة0');
    expect(first['gender'], isA<bool>());
    expect(first['categories'], isA<List<dynamic>>());
    expect((first['categories'] as List<dynamic>).first, isA<String>());

    // 与主 isolate 的同步解析结果逐字节等价
    expect(jsonEncode(map), jsonEncode(jsonDecode(source)));
  });

  test('isolate 里的解码异常原样传回主 isolate（仍是 FormatException）', () async {
    final String broken = '{"Words": [${'x' * (kJsonOffloadThreshold + 1)}';
    expect(broken.length, greaterThan(kJsonOffloadThreshold));

    debugForceIsolateOffload = true;
    await expectLater(
      decodeJsonOffMain(broken),
      throwsA(isA<FormatException>()),
      reason: '调用方靠 FormatException 判定「数据损坏」，不能被包装成 RemoteError',
    );
  });

  test('小文本走同步路径（低于阈值不付 isolate 往返）', () async {
    debugForceIsolateOffload = true;
    final Object? decoded = await decodeJsonOffMain('{"a":1}');
    expect(decoded, <String, dynamic>{'a': 1});
  });

  test('编码：大对象经 isolate 编码后与同步 jsonEncode 等价', () async {
    final Map<String, dynamic> value =
        jsonDecode(_bigJson()) as Map<String, dynamic>;

    debugForceIsolateOffload = true;
    final String offMain = await encodeJsonOffMain(value);

    expect(offMain, jsonEncode(value));
  });

  test('编码：含不可发送类型时抛错（不静默丢数据）', () async {
    debugForceIsolateOffload = true;
    // `DateTime` 不在可发送白名单里；`jsonEncode` 本身也会拒绝它。
    await expectLater(
      encodeJsonOffMain(<String, dynamic>{'t': DateTime(2026)}),
      throwsA(anything),
    );
  });

  test('禁用卸载时（flutter test 默认）走同步路径，行为不变', () async {
    debugForceIsolateOffload = false;
    final String source = _bigJson();
    final Object? decoded = await decodeJsonOffMain(source);
    expect(jsonEncode(decoded), jsonEncode(jsonDecode(source)));
  });
}
