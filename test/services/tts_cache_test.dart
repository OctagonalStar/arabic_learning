import 'dart:io';

import 'package:arabic_learning/services/tts.dart' show pruneTtsClipCache;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tts_clip_cache_test_');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  File addFile(String name, {required DateTime modified, int bytes = 1}) {
    final File file = File('${dir.path}/$name')
      ..writeAsBytesSync(List<int>.filled(bytes, 0));
    file.setLastModifiedSync(modified);
    return file;
  }

  test('清理超过有效期的缓存文件', () {
    final DateTime now = DateTime.now();
    final File old = addFile(
      'old.wav',
      modified: now.subtract(const Duration(days: 8)),
    );
    final File fresh = addFile('fresh.wav', modified: now);

    pruneTtsClipCache(dir.path, maxAge: const Duration(days: 7));

    expect(old.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);
  });

  test('总容量超限时按修改时间淘汰最旧文件', () {
    final DateTime now = DateTime.now();
    final File oldest = addFile(
      'oldest.wav',
      modified: now.subtract(const Duration(minutes: 3)),
      bytes: 1024,
    );
    final File middle = addFile(
      'middle.wav',
      modified: now.subtract(const Duration(minutes: 2)),
      bytes: 1024,
    );
    final File newest = addFile(
      'newest.wav',
      modified: now.subtract(const Duration(minutes: 1)),
      bytes: 1024,
    );
    final File ignored = addFile(
      'keep.txt',
      modified: now.subtract(const Duration(minutes: 4)),
      bytes: 4096,
    );

    pruneTtsClipCache(dir.path, maxBytes: 2048);

    expect(oldest.existsSync(), isFalse);
    expect(middle.existsSync(), isTrue);
    expect(newest.existsSync(), isTrue);
    expect(ignored.existsSync(), isTrue);
  });
}
