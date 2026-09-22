import 'package:arabic_learning/core/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldLockPortrait（定向策略纯函数）', () {
    test('手机最短边 < 600 -> 锁竖屏', () {
      expect(shouldLockPortrait(320), isTrue);
      expect(shouldLockPortrait(360), isTrue);
      expect(shouldLockPortrait(599.9), isTrue);
    });

    test('平板 / 桌面 / Web 最短边 >= 600 -> 不锁', () {
      expect(shouldLockPortrait(600), isFalse);
      expect(shouldLockPortrait(800), isFalse);
      expect(shouldLockPortrait(1280), isFalse);
    });
  });

  group('AdaptiveData 断点（复用 AppBreakpoints.mobile = 600）', () {
    test('isWide 严格大于 600', () {
      expect(const AdaptiveData(width: 600, height: 800).isWide, isFalse);
      expect(const AdaptiveData(width: 600.1, height: 800).isWide, isTrue);
    });

    test('isTablet 命中 [600, 1024)', () {
      expect(const AdaptiveData(width: 599, height: 800).isTablet, isFalse);
      expect(const AdaptiveData(width: 600, height: 800).isTablet, isTrue);
      expect(const AdaptiveData(width: 1023, height: 800).isTablet, isTrue);
      expect(const AdaptiveData(width: 1024, height: 800).isTablet, isFalse);
    });

    test('isLandscape 按宽高比较', () {
      expect(const AdaptiveData(width: 800, height: 1280).isLandscape, isFalse);
      expect(const AdaptiveData(width: 1280, height: 800).isLandscape, isTrue);
    });

    test('相等性由宽高决定', () {
      expect(
        const AdaptiveData(width: 400, height: 800),
        const AdaptiveData(width: 400, height: 800),
      );
      expect(
        const AdaptiveData(width: 400, height: 800),
        isNot(const AdaptiveData(width: 400, height: 801)),
      );
    });
  });

  group('AdaptiveScope', () {
    testWidgets('scope 内优先读取下发数据', (WidgetTester tester) async {
      late AdaptiveData read;
      AdaptiveData? maybe;
      await tester.pumpWidget(
        AdaptiveScope(
          data: const AdaptiveData(width: 1200, height: 700),
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) {
                read = AdaptiveScope.of(context);
                maybe = AdaptiveScope.maybeOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(read.width, 1200);
      expect(read.height, 700);
      expect(read.isWide, isTrue);
      expect(maybe, isNotNull);
    });

    testWidgets('无 scope 时回退 MediaQuery 现算', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late AdaptiveData read;
      AdaptiveData? maybe;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              read = AdaptiveScope.of(context);
              maybe = AdaptiveScope.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(read.width, 390);
      expect(read.height, 844);
      expect(read.isWide, isFalse);
      expect(maybe, isNull);
    });
  });
}
