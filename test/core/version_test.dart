// 版本号工具与版本漂移守卫测试。
//
// 覆盖 lib/core/version.dart 的编解码与比较，并以 pubspec.yaml 作为单一事实
// 来源，校验 `StaticsVar.appVersion` 未在发版后被遗忘同步（否则「检查更新」
// 会把新版本误判为已安装）。纯 Dart，无需平台插件 mock。

import 'dart:io';

import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/core/version.dart';
import 'package:arabic_learning/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('版本号编解码往返', () {
    test('versionStringToInt <-> versionIntToString', () {
      const List<String> versions = <String>[
        '1.0.0',
        '1.1.0',
        '1.12.7',
        '12.34.567',
      ];
      for (final String version in versions) {
        final int encoded = versionStringToInt(version);
        expect(
          versionIntToString(encoded),
          version,
          reason: '版本 $version 往返结果不一致',
        );
      }
    });

    test('编码规则 major*100000 + minor*1000 + patch', () {
      expect(versionStringToInt('1.0.0'), 100000);
      expect(versionStringToInt('1.1.0'), 101000);
      expect(versionStringToInt('1.12.7'), 112007);
      expect(versionStringToInt('12.34.567'), 1234567);
    });
  });

  group('parseGithubTag', () {
    test('合法 tag 解析为整数编码', () {
      expect(parseGithubTag('v1.2.3'), 102003);
      expect(parseGithubTag('V1.1.0'), 101000);
      expect(parseGithubTag('1.1.0'), 101000);
    });

    test('非版本 tag 返回 null', () {
      expect(parseGithubTag('latest'), isNull);
      expect(parseGithubTag('release-notes'), isNull);
      expect(parseGithubTag('v0.0.0'), isNull);
      expect(parseGithubTag(''), isNull);
    });
  });

  group('isNewerVersion', () {
    test('严格大于才算更新', () {
      expect(isNewerVersion(102000, 101000), isTrue);
      expect(isNewerVersion(101000, 101000), isFalse);
      expect(isNewerVersion(100999, 101000), isFalse);
    });
  });

  group('parseReleaseRedirectTag', () {
    test('从真实 302 Location 解析出 tag', () {
      expect(
        parseReleaseRedirectTag(
          'https://github.com/OctagonalStar/arabic_learning/releases/tag/v1.1.0',
        ),
        'v1.1.0',
      );
    });

    test('百分号编码的 tag 会被解码', () {
      expect(
        parseReleaseRedirectTag(
          'https://github.com/o/r/releases/tag/%76%31%2E%31%2E%30',
        ),
        'v1.1.0',
      );
    });

    test('去除 query 与 fragment', () {
      expect(
        parseReleaseRedirectTag(
          'https://github.com/o/r/releases/tag/v1.2.0?foo=1#bar',
        ),
        'v1.2.0',
      );
    });

    test('无 /releases/tag/ 段返回 null', () {
      expect(
        parseReleaseRedirectTag('https://github.com/o/r/releases'),
        isNull,
      );
    });

    test('空串与垃圾输入返回 null', () {
      expect(parseReleaseRedirectTag(''), isNull);
      expect(parseReleaseRedirectTag('not a url'), isNull);
      expect(parseReleaseRedirectTag('https://example.com/foo/bar'), isNull);
    });
  });

  group('buildDeterministicAssetUrl', () {
    test('按 ABI 生成确定性下载地址（与工作流资产名一致）', () {
      const String base =
          'https://github.com/OctagonalStar/arabic_learning/releases/download/v1.1.0';
      expect(
        UpdateService.buildDeterministicAssetUrl('v1.1.0', const <String>[
          'arm64-v8a',
        ]),
        '$base/app-arm64-v8a-release.apk',
      );
      expect(
        UpdateService.buildDeterministicAssetUrl('v1.1.0', const <String>[
          'armeabi-v7a',
        ]),
        '$base/app-armeabi-v7a-release.apk',
      );
      expect(
        UpdateService.buildDeterministicAssetUrl('v1.1.0', const <String>[
          'x86_64',
        ]),
        '$base/app-x86_64-release.apk',
      );
    });

    test('按 ABI 优先级取首个可映射项', () {
      expect(
        UpdateService.buildDeterministicAssetUrl('v1.1.0', const <String>[
          'mips',
          'arm64-v8a',
          'armeabi-v7a',
        ]),
        endsWith('/app-arm64-v8a-release.apk'),
      );
    });

    test('无可用 ABI 标识时返回 null', () {
      expect(
        UpdateService.buildDeterministicAssetUrl('v1.1.0', const <String>[]),
        isNull,
      );
      expect(
        UpdateService.buildDeterministicAssetUrl('v1.1.0', const <String>[
          'mips',
        ]),
        isNull,
      );
    });
  });

  group('版本漂移守卫（pubspec.yaml vs StaticsVar.appVersion）', () {
    test('pubspec 版本号与 StaticsVar.appVersion 同步', () {
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      final RegExpMatch? match = RegExp(
        r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(match, isNotNull, reason: 'pubspec.yaml 缺少 version 行');
      final String version = match!.group(1)!;
      expect(
        versionStringToInt(version),
        StaticsVar.appVersion,
        reason: '发布新版本后请同步更新 StaticsVar.appVersion（当前 pubspec: $version）',
      );
    });
  });
}
