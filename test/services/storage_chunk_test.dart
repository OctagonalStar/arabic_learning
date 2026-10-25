import 'package:arabic_learning/package_replacement/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart' as shpr;

/// 小程序 `wx.setStorage` 单键上限 1MB，超限的值必须走分片。
/// 分片路径只在 Web（kIsWeb && shared_preferences 后端）启用，测试里手动打开开关。
void main() {
  Future<SharedPreferences> chunkedStorage() async {
    shpr.SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences storage = SharedPreferences();
    storage.type = true;
    storage.chunked = true;
    storage.prefs = await shpr.SharedPreferences.getInstance();
    return storage;
  }

  test('超过一片的值分片写入、原样读回，并清掉旧分片', () async {
    final SharedPreferences storage = await chunkedStorage();
    final String value = 'a' * (SharedPreferences.chunkChars * 2 + 5);

    expect(await storage.setString("wordData", value), isTrue);
    // 主键只剩分片标记，不再是全文
    expect(SharedPreferences.chunkCount(storage.prefs.getString("wordData")), 3);
    expect(storage.getString("wordData"), value);
    expect(storage.export()["wordData"], value);

    // 换成小值：旧分片要清掉，否则会把新值拼错
    expect(await storage.setString("wordData", '{"Words":[]}'), isTrue);
    expect(storage.getString("wordData"), '{"Words":[]}');
    expect(
      storage.prefs.getKeys().where((String k) => k.contains("\u0000p")),
      isEmpty,
    );
  });

  test('未超限的值直接整串存储', () async {
    final SharedPreferences storage = await chunkedStorage();
    final String value = 'a' * SharedPreferences.chunkChars;

    expect(await storage.setString("settingData", value), isTrue);
    expect(SharedPreferences.chunkCount(storage.prefs.getString("settingData")), 0);
    expect(storage.getString("settingData"), value);
  });

  test('未启用分片时（原生端）行为不变', () async {
    final SharedPreferences storage = await chunkedStorage();
    storage.chunked = false;
    final String value = 'a' * (SharedPreferences.chunkChars * 2);

    expect(await storage.setString("wordData", value), isTrue);
    expect(storage.prefs.getString("wordData"), value);
    expect(storage.getString("wordData"), value);
  });
}
