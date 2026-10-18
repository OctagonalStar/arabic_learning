// 版本号编解码工具（纯 Dart，无平台依赖）。
//
// 本项目使用整数编码版本号，规则为：`major*100000 + minor*1000 + patch`，
// 例如 `1.1.0 -> 101000`，与 `StaticsVar.appVersion` 保持一致。
// 因此 minor 与 patch 各占 3 位十进制（取值 0-999）。

/// 将版本字符串转换为整数编码。
///
/// 宽容解析：允许前导 `v`/`V`；忽略 `+build` 构建号与 `-prerelease`
/// 预发布后缀；不足三位时缺省部分按 `0` 计（`"1.1" -> 101000`）。
/// 无法解析时返回 `0`。
int versionStringToInt(String version) {
  return _tryParse(version) ?? 0;
}

/// 将整数编码的版本号还原为 `major.minor.patch` 字符串。
///
/// 例如 `101000 -> "1.1.0"`；非法值（`<= 0`）返回 `"0.0.0"`。
String versionIntToString(int version) {
  if (version <= 0) return "0.0.0";
  final int major = version ~/ 100000;
  final int minor = (version % 100000) ~/ 1000;
  final int patch = version % 1000;
  return "$major.$minor.$patch";
}

/// 解析 GitHub Release 的 tag（形如 `"v1.2.0"`）为整数编码。
///
/// `"v1.2.0" -> 102000`；无法解析或解析结果为 `0` 时返回 `null`。
int? parseGithubTag(String tag) {
  final int? value = _tryParse(tag);
  if (value == null || value <= 0) return null;
  return value;
}

/// [candidate] 是否比 [current] 更新（严格大于）。
bool isNewerVersion(int candidate, int current) => candidate > current;

/// 从 GitHub `/releases/latest` 的 302 `Location` 中解析 Release tag。
///
/// 例：`https://github.com/OctagonalStar/arabic_learning/releases/tag/v1.1.0`
/// → `v1.1.0`。不含 `/releases/tag/` 段（例如仓库尚无 Release，跳到
/// `/releases`）或解析失败时返回 `null`。实现上不依赖具体的 owner/repo 名称，
/// 因此同样适用于 fork。
///
/// 注意：只负责提取原始 tag 文本（如 `v1.1.0`），是否为合法版本号交由
/// [parseGithubTag] 判断。
String? parseReleaseRedirectTag(String location) {
  const String marker = '/releases/tag/';
  final int index = location.lastIndexOf(marker);
  if (index < 0) return null;

  String segment = location.substring(index + marker.length);
  // 去掉 query / fragment（`?...#...`）。
  final int cut = segment.indexOf(RegExp(r'[?#]'));
  if (cut >= 0) segment = segment.substring(0, cut);

  final String tag;
  try {
    tag = Uri.decodeComponent(segment).trim();
  } catch (_) {
    // 非法的百分号编码视为解析失败。
    return null;
  }
  return tag.isEmpty ? null : tag;
}

/// 内部宽容解析：失败返回 `null`（用于区分合法的 `0` 与非法输入）。
int? _tryParse(String version) {
  String value = version.trim();
  if (value.isEmpty) return null;

  // 去掉前导 v/V
  if (value.startsWith('v') || value.startsWith('V')) {
    value = value.substring(1);
  }

  // 去掉 +build 构建号
  final int plusIndex = value.indexOf('+');
  if (plusIndex != -1) value = value.substring(0, plusIndex);

  // 去掉 -prerelease 预发布后缀
  final int dashIndex = value.indexOf('-');
  if (dashIndex != -1) value = value.substring(0, dashIndex);

  value = value.trim();
  if (value.isEmpty) return null;

  final List<String> parts = value.split('.');
  final List<int> numbers = <int>[0, 0, 0];
  for (int i = 0; i < parts.length; i++) {
    final String part = parts[i].trim();
    if (part.isEmpty) return null;
    final int? number = int.tryParse(part);
    if (number == null || number < 0) return null;
    // 超过三段的额外部分宽容忽略。
    if (i < 3) numbers[i] = number;
  }
  return numbers[0] * 100000 + numbers[1] * 1000 + numbers[2];
}
