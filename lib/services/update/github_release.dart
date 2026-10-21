// GitHub Release 相关的**纯逻辑**：接口地址、JSON 解析、版本比较、ABI 匹配与
// APK 校验规则。
//
// 本文件刻意不 import Flutter / 平台插件，因此可被单元测试直接调用（不触网、
// 不依赖平台通道）。版本号编解码与比较沿用 `lib/core/version.dart`，并在本文件
// 重导出，便于更新模块内部与测试统一从一处引用。
//
// 解析失败时的异常文案与拆分前保持一致（UI 直接展示 `error.toString()` 之外
// 的文案由 `UpdateService._describeError` 决定，故此处沿用 `Exception` 而非
// `FormatException`，避免改变展示文本）。

import 'package:arabic_learning/core/version.dart';

export 'package:arabic_learning/core/version.dart'
    show
        isNewerVersion,
        parseGithubTag,
        parseReleaseRedirectTag,
        versionIntToString,
        versionStringToInt;

// -----------------------------------------------------------------------------
// 常量
// -----------------------------------------------------------------------------

/// GitHub 仓库所有者。
const String githubOwner = 'OctagonalStar';

/// GitHub 仓库名。
const String githubRepo = 'arabic_learning';

/// 最新 Release 接口（`/latest` 已自动排除 draft 与 prerelease）。
const String githubApiLatestUrl =
    'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

/// 仓库发布页的 `/releases/latest`：会 302 跳转到最新 tag。
///
/// 这是网页请求，**不消耗** GitHub API 的 60 次/小时匿名配额（该配额按 IP
/// 共享，NAT/CGNAT 下极易被同网用户耗尽并返回 403），因此作为首选探测手段。
const String githubLatestReleaseRedirectUrl =
    'https://github.com/$githubOwner/$githubRepo/releases/latest';

/// 项目自身的 Android 包名，用于校验下载的 APK。
const String expectedApkPackageName = 'com.ayuban.arlearning';

/// 更新相关请求统一的 User-Agent（GitHub API 要求带 UA）。
const String updateUserAgent = 'arabic_learning-updater';

/// 原生桥接通道名（见 android/app/src/main/kotlin/com/ayuban/arlearning/MainActivity.kt）。
const String updateMethodChannelName = 'app_update';

// -----------------------------------------------------------------------------
// 资产 / Release 模型
// -----------------------------------------------------------------------------

/// 一个 APK 资产（GitHub Release 的 `assets` 元素）。
class ReleaseAsset {
  /// 资产文件名（含 `.apk` 后缀）。
  final String name;

  /// 浏览器直链（`browser_download_url`）。
  final String url;

  /// 字节数；缺失或非法时为 0（未知）。
  final int size;

  const ReleaseAsset({
    required this.name,
    required this.url,
    required this.size,
  });

  /// 解析单个 asset；非 `.apk`、缺少下载地址或不是 Map 时返回 null。
  static ReleaseAsset? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final String name = raw['name']?.toString() ?? '';
    if (!name.toLowerCase().endsWith('.apk')) return null;
    final String url = raw['browser_download_url']?.toString() ?? '';
    if (url.isEmpty) return null;
    final dynamic size = raw['size'];
    return ReleaseAsset(
      name: name,
      url: url,
      size: size is num ? size.toInt() : 0,
    );
  }
}

/// 解析 release JSON 的 `assets` 字段，仅保留可用的 `.apk` 资产。
List<ReleaseAsset> parseApkAssets(dynamic assets) {
  if (assets is! List) return const <ReleaseAsset>[];
  final List<ReleaseAsset> apks = <ReleaseAsset>[];
  for (final dynamic raw in assets) {
    final ReleaseAsset? asset = ReleaseAsset.tryParse(raw);
    if (asset != null) apks.add(asset);
  }
  return apks;
}

/// GitHub Release 中更新流程关心的字段。
///
/// `/releases/latest` 与 `/releases/tags/{tag}`（release 详情）返回的对象结构
/// 一致，额外字段（`id` / `html_url` / `published_at` 等）会被忽略，因此两者
/// 共用同一个解析器。
class GithubRelease {
  /// 原始 tag 文本（如 `v1.1.0`）；字段缺失时为 null。
  final String? tag;

  /// Release 正文（Markdown）；字段缺失时为 null。
  final String? notes;

  /// 按 ABI 拆分出的 APK 资产（已过滤掉非 `.apk` / 无下载地址的项）。
  final List<ReleaseAsset> apkAssets;

  final bool draft;
  final bool prerelease;

  const GithubRelease({
    required this.tag,
    required this.notes,
    required this.apkAssets,
    this.draft = false,
    this.prerelease = false,
  });

  /// tag 解析出的整数版本号；tag 缺失或无法解析时为 null。
  int? get version => tag == null ? null : parseGithubTag(tag!);

  /// 草稿或预发布（`/latest` 通常已排除，仍做防御性判断）。
  bool get isDraftOrPrerelease => draft || prerelease;

  /// 解析 release JSON 对象。
  ///
  /// 非 Map 响应（如 HTML 错误页、空 body）抛 [Exception]；tag 是否可解析为
  /// 版本号不在此处判定，由调用方读取 [version] 后决定（保持「先判 draft /
  /// prerelease，再解析版本号」的原有顺序）。
  static GithubRelease parse(dynamic json) {
    if (json is! Map) {
      throw Exception('无法解析 GitHub 返回的更新信息');
    }
    return GithubRelease(
      tag: json['tag_name']?.toString(),
      notes: json['body']?.toString(),
      apkAssets: parseApkAssets(json['assets']),
      draft: json['draft'] == true,
      prerelease: json['prerelease'] == true,
    );
  }

  /// 同 [parse]，但非 Map 时返回 null 而不是抛异常。
  static GithubRelease? tryParse(dynamic json) =>
      json is Map ? parse(json) : null;
}

// -----------------------------------------------------------------------------
// ABI 匹配
// -----------------------------------------------------------------------------

/// 将设备 ABI 名映射为资产文件名中的标识；未知 ABI 返回 null。
String? abiToken(String abi) {
  switch (abi) {
    case 'arm64-v8a':
      return 'arm64-v8a';
    case 'armeabi-v7a':
    case 'armeabi':
      return 'armeabi-v7a';
    case 'x86_64':
      return 'x86_64';
    case 'x86':
      return 'x86';
    default:
      return null;
  }
}

/// 从 APK 资产中挑选与设备 ABI 匹配的安装包。
///
/// 工作流只发布按 ABI 拆分的 APK（armeabi-v7a / arm64-v8a / x86_64），
/// 因此必须按设备实际 ABI 匹配，否则会装到不兼容的包。匹配顺序：
/// (1) 文件名含 `universal` 的通用包；
/// (2) 按 [abis] 优先级（`Build.SUPPORTED_ABIS` 从优到劣）匹配文件名 ABI 标识；
/// (3) [abis] 为空（非 Android / 测试）时优先 `arm64-v8a`，否则首个 `.apk`。
/// 均无法匹配时返回 null，由调用方报「未找到可下载的安装包」。
ReleaseAsset? pickApkAsset(List<ReleaseAsset> apks, List<String> abis) {
  if (apks.isEmpty) return null;

  // (1) 通用包（包含全部 ABI）。
  for (final ReleaseAsset asset in apks) {
    if (asset.name.toLowerCase().contains('universal')) return asset;
  }

  // (2) 按设备 ABI 优先级匹配文件名中的 ABI 标识。
  for (final String abi in abis) {
    final String? token = abiToken(abi);
    if (token == null) continue;
    for (final ReleaseAsset asset in apks) {
      if (asset.name.toLowerCase().contains(token)) return asset;
    }
  }

  // (3) 无 ABI 信息（非 Android / 测试）：优先 arm64-v8a，否则任意 APK。
  if (abis.isEmpty) {
    for (final ReleaseAsset asset in apks) {
      if (asset.name.toLowerCase().contains('arm64-v8a')) return asset;
    }
    return apks.first;
  }
  return null;
}

/// 按 tag 与设备 ABI 列表拼出确定性的 APK 下载地址（API 不可用时的兜底）。
///
/// 形如
/// `https://github.com/$githubOwner/$githubRepo/releases/download/<tag>/app-<abiToken>-release.apk`。
/// 资产名与 ABI 标识以 `.github/workflows/FlutterBuild.yml` 中 `--split-per-abi`
/// 产出的 `app-armeabi-v7a-release.apk` / `app-arm64-v8a-release.apk` /
/// `app-x86_64-release.apk` 为准（重命名该工作流时请同步此处）。
///
/// [abis] 按设备优先级排列（`Build.SUPPORTED_ABIS` 从优到劣）；返回首个能映射
/// 出标识的地址。非 Android / 空列表 / 全部 ABI 无法映射时返回 null。
String? buildDeterministicAssetUrl(String tag, List<String> abis) {
  for (final String abi in abis) {
    final String? token = abiToken(abi);
    if (token == null) continue;
    return 'https://github.com/$githubOwner/$githubRepo/releases/download/$tag/'
        'app-$token-release.apk';
  }
  return null;
}

// -----------------------------------------------------------------------------
// 校验规则
// -----------------------------------------------------------------------------

/// 将原生返回的版本号字段宽松地转为 int（int / num / String 均可）。
int? toIntOrNull(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// APK 校验规则：包名必须与 [expectedApkPackageName] 一致，且版本号不得低于
/// 当前安装版本。
///
/// 任一项无法判定（缺失 / 非数字）都视为**校验失败**（失败关闭），避免被截断
/// 或包名不符的安装包进入安装流程。
bool verifyApkMetadata({
  required dynamic packageName,
  required dynamic versionCode,
  required dynamic currentVersionCode,
}) {
  final String pkg = packageName?.toString() ?? '';
  if (pkg.isEmpty || pkg != expectedApkPackageName) return false;

  final int? apkCode = toIntOrNull(versionCode);
  final int? currentCode = toIntOrNull(currentVersionCode);
  if (apkCode == null || currentCode == null || apkCode < currentCode) {
    return false;
  }
  return true;
}
