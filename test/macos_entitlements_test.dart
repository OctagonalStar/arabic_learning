import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// macOS 沙盒构建的回归保护：
/// - 缺少 user-selected.read-write 时 file_picker 会直接拒绝导入/导出；
/// - 缺少 network.client 时 Dio（词库下载、WebDAV、TTS）无法访问网络。
void main() {
  group('macOS 沙盒 entitlements', () {
    const files = [
      'macos/Runner/DebugProfile.entitlements',
      'macos/Runner/Release.entitlements',
    ];

    for (final path in files) {
      test('$path 允许用户选择文件读写并允许出站网络', () {
        final content = File(path).readAsStringSync();
        expect(
          content,
          contains('com.apple.security.files.user-selected.read-write'),
        );
        expect(content, contains('com.apple.security.network.client'));
      });
    }

    test('Release 构建保持开启 App Sandbox', () {
      final content = File(files.last).readAsStringSync();
      expect(content, contains('com.apple.security.app-sandbox'));
    });
  });
}
