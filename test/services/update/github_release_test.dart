// GitHub Release 纯逻辑测试：版本比较、JSON 解析、ABI → 资产名匹配、APK 校验规则。
//
// 全部使用字符串常量作为样例数据，不联网、不依赖平台通道。

import 'dart:convert';

import 'package:arabic_learning/services/update/github_release.dart';
import 'package:flutter_test/flutter_test.dart';

/// `/releases/latest` 的真实结构（字段有删减）。
const String _latestReleaseJson = '''
{
  "tag_name": "v1.2.0",
  "name": "v1.2.0",
  "body": "## 更新内容\\n- 修复若干问题",
  "draft": false,
  "prerelease": false,
  "assets": [
    {
      "name": "app-armeabi-v7a-release.apk",
      "browser_download_url": "https://github.com/OctagonalStar/arabic_learning/releases/download/v1.2.0/app-armeabi-v7a-release.apk",
      "size": 12345678
    },
    {
      "name": "app-arm64-v8a-release.apk",
      "browser_download_url": "https://github.com/OctagonalStar/arabic_learning/releases/download/v1.2.0/app-arm64-v8a-release.apk",
      "size": 13456789
    },
    {
      "name": "app-x86_64-release.apk",
      "browser_download_url": "https://github.com/OctagonalStar/arabic_learning/releases/download/v1.2.0/app-x86_64-release.apk",
      "size": 14567890
    },
    {
      "name": "checksums.txt",
      "browser_download_url": "https://github.com/OctagonalStar/arabic_learning/releases/download/v1.2.0/checksums.txt",
      "size": 128
    }
  ]
}
''';

/// release 详情接口（`/releases/tags/{tag}`）结构，与 `/latest` 一致。
const String _releaseDetailJson = '''
{
  "id": 12345,
  "tag_name": "v1.3.0",
  "html_url": "https://github.com/OctagonalStar/arabic_learning/releases/tag/v1.3.0",
  "body": "release detail body",
  "draft": false,
  "prerelease": false,
  "assets": [
    {
      "name": "app-arm64-v8a-release.apk",
      "browser_download_url": "https://example.com/app-arm64-v8a-release.apk",
      "size": 1000
    }
  ]
}
''';

void main() {
  group('版本号比较', () {
    test('带 v 前缀与不带前缀等价', () {
      expect(parseGithubTag('v1.2.3'), parseGithubTag('1.2.3'));
      expect(parseGithubTag('V1.2.3'), parseGithubTag('v1.2.3'));
    });

    test('三段版本逐段比较，1.10 大于 1.9（字典序陷阱）', () {
      final int v110 = parseGithubTag('v1.10.0')!;
      final int v19 = parseGithubTag('v1.9.0')!;
      expect(v110, greaterThan(v19));
      // 字符串字典序会给出相反结论，确认比较走的是整数编码而非字符串。
      expect('1.10.0'.compareTo('1.9.0'), lessThan(0));
      expect(isNewerVersion(v110, v19), isTrue);
    });

    test('patch 位同样按数值比较', () {
      expect(
        isNewerVersion(parseGithubTag('v1.2.10')!, parseGithubTag('v1.2.9')!),
        isTrue,
      );
    });

    test('相等不算更新', () {
      expect(
        isNewerVersion(parseGithubTag('v1.2.0')!, parseGithubTag('v1.2.0')!),
        isFalse,
      );
    });

    test('两段版本按缺省 0 补齐', () {
      expect(parseGithubTag('v1.10'), parseGithubTag('v1.10.0'));
      expect(versionIntToString(parseGithubTag('v1.10')!), '1.10.0');
    });

    test('预发布后缀与构建号被忽略', () {
      expect(parseGithubTag('v1.2.0-beta.1'), parseGithubTag('v1.2.0'));
      expect(parseGithubTag('v1.2.0+42'), parseGithubTag('v1.2.0'));
    });

    test('无法解析的 tag 返回 null', () {
      expect(parseGithubTag('latest'), isNull);
      expect(parseGithubTag('v'), isNull);
      expect(parseGithubTag('v0.0.0'), isNull);
      expect(parseGithubTag(''), isNull);
    });
  });

  group('release JSON 解析', () {
    test('解析 /releases/latest：tag、正文、APK 资产', () {
      final GithubRelease release = GithubRelease.parse(
        _decode(_latestReleaseJson),
      );
      expect(release.tag, 'v1.2.0');
      expect(release.version, parseGithubTag('v1.2.0'));
      expect(release.notes, contains('更新内容'));
      expect(release.isDraftOrPrerelease, isFalse);
      // 非 .apk 资产被过滤。
      expect(release.apkAssets, hasLength(3));
      expect(
        release.apkAssets.map((ReleaseAsset a) => a.name),
        everyElement(endsWith('.apk')),
      );
      expect(release.apkAssets.first.size, 12345678);
    });

    test('解析 release 详情：忽略额外字段，结构与 /latest 相同', () {
      final GithubRelease release = GithubRelease.parse(
        _decode(_releaseDetailJson),
      );
      expect(release.tag, 'v1.3.0');
      expect(release.notes, 'release detail body');
      expect(release.apkAssets, hasLength(1));
      expect(
        release.apkAssets.single.url,
        'https://example.com/app-arm64-v8a-release.apk',
      );
    });

    test('tag_name 缺失时 tag 为 null 且 version 为 null', () {
      final GithubRelease release = GithubRelease.parse(<String, dynamic>{
        'body': 'no tag',
      });
      expect(release.tag, isNull);
      expect(release.version, isNull);
      expect(release.apkAssets, isEmpty);
    });

    test('tag_name 为空串时 version 为 null', () {
      final GithubRelease release = GithubRelease.parse(<String, dynamic>{
        'tag_name': '',
      });
      expect(release.tag, '');
      expect(release.version, isNull);
    });

    test('draft / prerelease 被识别', () {
      expect(
        GithubRelease.parse(<String, dynamic>{
          'tag_name': 'v1.0.0',
          'draft': true,
        }).isDraftOrPrerelease,
        isTrue,
      );
      expect(
        GithubRelease.parse(<String, dynamic>{
          'tag_name': 'v1.0.0',
          'prerelease': true,
        }).isDraftOrPrerelease,
        isTrue,
      );
    });

    test('非法 JSON 文本在 decode 阶段抛 FormatException', () {
      expect(() => _decode('{not json'), throwsFormatException);
    });

    test('非 Map 的 JSON（数组 / 字符串 / null）解析抛 Exception', () {
      expect(
        () => GithubRelease.parse(_decode('[]')),
        throwsA(isA<Exception>()),
      );
      expect(
        () => GithubRelease.parse(_decode('"oops"')),
        throwsA(isA<Exception>()),
      );
      expect(() => GithubRelease.parse(null), throwsA(isA<Exception>()));
      expect(GithubRelease.tryParse(null), isNull);
    });

    test('assets 缺失或类型错误时返回空列表', () {
      expect(
        GithubRelease.parse(<String, dynamic>{'tag_name': 'v1.0.0'}).apkAssets,
        isEmpty,
      );
      expect(
        GithubRelease.parse(<String, dynamic>{
          'tag_name': 'v1.0.0',
          'assets': 'nope',
        }).apkAssets,
        isEmpty,
      );
    });

    test('资产缺少下载地址或 size 非法时的降级', () {
      final GithubRelease release = GithubRelease.parse(<String, dynamic>{
        'tag_name': 'v1.0.0',
        'assets': <dynamic>[
          <String, dynamic>{'name': 'app-arm64-v8a-release.apk'},
          <String, dynamic>{
            'name': 'app-x86_64-release.apk',
            'browser_download_url': 'https://example.com/x.apk',
          },
          'not a map',
        ],
      });
      // 缺 browser_download_url 的资产被丢弃。
      expect(release.apkAssets, hasLength(1));
      expect(release.apkAssets.single.size, 0);
    });
  });

  group('CPU 架构 → 安装包文件名匹配', () {
    final List<ReleaseAsset> assets = GithubRelease.parse(
      _decode(_latestReleaseJson),
    ).apkAssets;

    test('arm64-v8a 匹配 app-arm64-v8a-release.apk', () {
      expect(
        pickApkAsset(assets, const <String>['arm64-v8a'])?.name,
        'app-arm64-v8a-release.apk',
      );
    });

    test('armeabi-v7a 匹配 app-armeabi-v7a-release.apk', () {
      expect(
        pickApkAsset(assets, const <String>['armeabi-v7a'])?.name,
        'app-armeabi-v7a-release.apk',
      );
    });

    test('x86_64 匹配 app-x86_64-release.apk', () {
      expect(
        pickApkAsset(assets, const <String>['x86_64'])?.name,
        'app-x86_64-release.apk',
      );
    });

    test('按设备 ABI 优先级取首个可匹配项', () {
      expect(
        pickApkAsset(assets, const <String>[
          'mips',
          'x86_64',
          'arm64-v8a',
        ])?.name,
        'app-x86_64-release.apk',
      );
    });

    test('无匹配时返回 null', () {
      expect(pickApkAsset(assets, const <String>['mips']), isNull);
      expect(
        pickApkAsset(const <ReleaseAsset>[], const <String>['arm64-v8a']),
        isNull,
      );
    });

    test('ABI 列表为空时回退到 arm64-v8a', () {
      expect(
        pickApkAsset(assets, const <String>[])?.name,
        'app-arm64-v8a-release.apk',
      );
    });

    test('universal 通用包优先于任何 ABI 匹配', () {
      final List<ReleaseAsset> withUniversal = <ReleaseAsset>[
        ...assets,
        const ReleaseAsset(
          name: 'app-universal-release.apk',
          url: 'https://example.com/app-universal-release.apk',
          size: 1,
        ),
      ];
      expect(
        pickApkAsset(withUniversal, const <String>['x86_64'])?.name,
        'app-universal-release.apk',
      );
    });

    test('armeabi 视为 armeabi-v7a', () {
      expect(abiToken('armeabi'), 'armeabi-v7a');
      expect(abiToken('mips'), isNull);
    });

    test('确定性下载地址与工作流资产名一致', () {
      expect(
        buildDeterministicAssetUrl('v1.2.0', const <String>['arm64-v8a']),
        'https://github.com/OctagonalStar/arabic_learning/releases/download/'
        'v1.2.0/app-arm64-v8a-release.apk',
      );
      expect(
        buildDeterministicAssetUrl('v1.2.0', const <String>['mips']),
        isNull,
      );
    });
  });

  group('APK 包名 / 版本号校验规则', () {
    test('包名与版本号均合法时通过', () {
      expect(
        verifyApkMetadata(
          packageName: expectedApkPackageName,
          versionCode: 102000,
          currentVersionCode: 101000,
        ),
        isTrue,
      );
    });

    test('版本号等于当前版本时通过（允许重装同版本）', () {
      expect(
        verifyApkMetadata(
          packageName: expectedApkPackageName,
          versionCode: 101000,
          currentVersionCode: 101000,
        ),
        isTrue,
      );
    });

    test('版本号低于当前版本时拒绝', () {
      expect(
        verifyApkMetadata(
          packageName: expectedApkPackageName,
          versionCode: 100999,
          currentVersionCode: 101000,
        ),
        isFalse,
      );
    });

    test('包名不符时拒绝', () {
      expect(
        verifyApkMetadata(
          packageName: 'com.example.other',
          versionCode: 102000,
          currentVersionCode: 101000,
        ),
        isFalse,
      );
      expect(
        verifyApkMetadata(
          packageName: '',
          versionCode: 102000,
          currentVersionCode: 101000,
        ),
        isFalse,
      );
      expect(
        verifyApkMetadata(
          packageName: null,
          versionCode: 102000,
          currentVersionCode: 101000,
        ),
        isFalse,
      );
    });

    test('版本号缺失或非数字时失败关闭', () {
      expect(
        verifyApkMetadata(
          packageName: expectedApkPackageName,
          versionCode: null,
          currentVersionCode: 101000,
        ),
        isFalse,
      );
      expect(
        verifyApkMetadata(
          packageName: expectedApkPackageName,
          versionCode: 102000,
          currentVersionCode: null,
        ),
        isFalse,
      );
      expect(
        verifyApkMetadata(
          packageName: expectedApkPackageName,
          versionCode: 'abc',
          currentVersionCode: 101000,
        ),
        isFalse,
      );
    });

    test('字符串版本号被宽松解析', () {
      expect(
        verifyApkMetadata(
          packageName: expectedApkPackageName,
          versionCode: '102000',
          currentVersionCode: '101000',
        ),
        isTrue,
      );
      expect(toIntOrNull(1.0), 1);
      expect(toIntOrNull(null), isNull);
    });
  });
}

/// 以 JSON 文本构造「已解析」的响应体，模拟 Dio 的 `response.data`。
dynamic _decode(String json) => jsonDecode(json);
