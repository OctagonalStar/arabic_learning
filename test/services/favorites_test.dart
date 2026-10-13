import 'dart:convert';

import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/favorites.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    // AppData 为单例：初始化一次（storage/basePath），随后每次测试重置收藏。
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
  });

  setUp(() {
    // 单例状态在测试间共享，用 clear 重置内存与存储。
    FavoriteStore().clear();
  });

  group('FavoriteStore 基础操作', () {
    test('toggle 切换状态并保持收藏顺序', () {
      expect(FavoriteStore().contains(3), isFalse);
      expect(FavoriteStore().toggle(3), isTrue);
      expect(FavoriteStore().toggle(7), isTrue);
      expect(FavoriteStore().toggle(3), isFalse); // 取消收藏

      expect(FavoriteStore().contains(3), isFalse);
      expect(FavoriteStore().contains(7), isTrue);
      expect(FavoriteStore().count, 1);
      expect(FavoriteStore().ids, <int>[7]);
    });

    test('count / ids 反映当前收藏（O(1) 命中）', () {
      expect(FavoriteStore().count, 0);
      expect(FavoriteStore().ids, isEmpty);

      FavoriteStore().toggle(1);
      FavoriteStore().toggle(2);
      FavoriteStore().toggle(5);

      expect(FavoriteStore().count, 3);
      expect(FavoriteStore().ids, <int>[1, 2, 5]);
      expect(FavoriteStore().contains(2), isTrue);
      expect(FavoriteStore().contains(4), isFalse);
    });

    test('非法 id 被忽略', () {
      expect(FavoriteStore().toggle(-1), isFalse);
      expect(FavoriteStore().count, 0);
    });

    test('remove / removeAll / clear', () {
      FavoriteStore().toggle(1);
      FavoriteStore().toggle(2);
      FavoriteStore().toggle(3);

      FavoriteStore().remove(2);
      expect(FavoriteStore().ids, <int>[1, 3]);

      FavoriteStore().removeAll(<int>[1, 3, 99]);
      expect(FavoriteStore().count, 0);

      FavoriteStore().toggle(4);
      FavoriteStore().clear();
      expect(FavoriteStore().count, 0);
      expect(FavoriteStore().ids, isEmpty);
    });
  });

  group('FavoriteStore id 重排（remap）', () {
    test('按 oldToNew 平移并丢弃已删除的 id', () {
      FavoriteStore().toggle(0);
      FavoriteStore().toggle(1);
      FavoriteStore().toggle(2);

      // 删除 id=1；0->0、2->1
      FavoriteStore().remap(<int, int>{0: 0, 2: 1});

      expect(FavoriteStore().ids, <int>[0, 1]);
      expect(FavoriteStore().contains(1), isTrue);
      expect(FavoriteStore().count, 2);
    });

    test('全部 id 被删除时清空', () {
      FavoriteStore().toggle(5);
      FavoriteStore().remap(<int, int>{});
      expect(FavoriteStore().count, 0);
    });
  });

  group('FavoriteStore 持久化', () {
    test('save 写入存储键，reload 从存储恢复', () {
      FavoriteStore().toggle(9);
      FavoriteStore().toggle(4);

      final String? raw = AppData().storage.getString(FavoriteStore.storageKey);
      expect(raw, isNotNull);
      final dynamic decoded = jsonDecode(raw!);
      expect(decoded['version'], FavoriteStore.dataVersion);
      expect(decoded['order'], <int>[9, 4]);

      // 直接改写存储：reload 应从存储恢复，而不是沿用内存。
      AppData().storage.setString(
        FavoriteStore.storageKey,
        jsonEncode(<String, dynamic>{
          'version': FavoriteStore.dataVersion,
          'order': <int>[1, 2],
        }),
      );
      FavoriteStore().reload();
      expect(FavoriteStore().ids, <int>[1, 2]);
      expect(FavoriteStore().contains(9), isFalse);
    });

    test('损坏的存储内容回退为空', () {
      AppData().storage.setString(FavoriteStore.storageKey, '{not json');
      FavoriteStore().reload();
      expect(FavoriteStore().count, 0);

      AppData().storage.setString(
          FavoriteStore.storageKey, jsonEncode(<String, dynamic>{'order': 'bad'}));
      FavoriteStore().reload();
      expect(FavoriteStore().count, 0);
    });

    test('init 对空数据安全：结果为空集合', () {
      AppData().storage.setString(FavoriteStore.storageKey, '');
      FavoriteStore().init();
      expect(FavoriteStore().count, 0);
      expect(FavoriteStore().ids, isEmpty);
    });
  });
}
