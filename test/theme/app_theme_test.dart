import 'package:arabic_learning/theme/app_theme.dart';
import 'package:arabic_learning/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildTheme', () {
    test('亮 / 暗两态均能构建且为 Material 3', () {
      for (final Brightness brightness in Brightness.values) {
        final ColorScheme scheme = ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: brightness,
        );
        final ThemeData theme = buildTheme(scheme, fontFamily: 'NotoSansSC');
        expect(theme.useMaterial3, isTrue);
        expect(theme.colorScheme.brightness, brightness);
      }
    });

    test('携带语义色主题扩展', () {
      final ThemeData theme = buildTheme(
        ColorScheme.fromSeed(seedColor: Colors.teal),
      );
      final AppSemanticColors? semantic =
          theme.extension<AppSemanticColors>();
      expect(semantic, isNotNull);
      expect(semantic!.success, isNot(equals(semantic.error)));
    });

    test('关键组件主题已配置', () {
      final ThemeData theme = buildTheme(
        ColorScheme.fromSeed(seedColor: Colors.teal),
      );
      expect(theme.appBarTheme.backgroundColor, isNotNull);
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.navigationBarTheme.backgroundColor, isNotNull);
      expect(theme.navigationRailTheme.backgroundColor, isNotNull);
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.dialogTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.bottomSheetTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(theme.elevatedButtonTheme.style, isNotNull);
      expect(theme.textButtonTheme.style, isNotNull);
      expect(theme.iconButtonTheme.style, isNotNull);
      expect(theme.chipTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.sliderTheme.activeTrackColor, isNotNull);
      expect(theme.switchTheme.thumbColor, isNotNull);
      expect(theme.dividerTheme.color, isNotNull);
      expect(theme.expansionTileTheme.iconColor, isNotNull);
      expect(theme.floatingActionButtonTheme.backgroundColor, isNotNull);
      expect(theme.listTileTheme.titleTextStyle, isNotNull);
    });
  });
}
