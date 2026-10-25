import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/models/config.dart';
import 'package:arabic_learning/theme/theme_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeResolver.themeModeFromConfig', () {
    test('0/1/2 分别映射 system/light/dark', () {
      expect(
        ThemeResolver.themeModeFromConfig(
          const RegularConfig(themeMode: RegularConfig.themeModeSystem),
        ),
        ThemeMode.system,
      );
      expect(
        ThemeResolver.themeModeFromConfig(
          const RegularConfig(themeMode: RegularConfig.themeModeLight),
        ),
        ThemeMode.light,
      );
      expect(
        ThemeResolver.themeModeFromConfig(
          const RegularConfig(themeMode: RegularConfig.themeModeDark),
        ),
        ThemeMode.dark,
      );
    });

    test('未知值回退 system', () {
      expect(
        ThemeResolver.themeModeFromConfig(const RegularConfig(themeMode: 99)),
        ThemeMode.system,
      );
    });
  });

  group('ThemeResolver.darkModeFromThemeMode', () {
    test('light→false, dark→true', () {
      expect(ThemeResolver.darkModeFromThemeMode(RegularConfig.themeModeLight), isFalse);
      expect(ThemeResolver.darkModeFromThemeMode(RegularConfig.themeModeDark), isTrue);
    });

    test('system 使用 fallback', () {
      expect(
        ThemeResolver.darkModeFromThemeMode(
          RegularConfig.themeModeSystem,
          fallback: true,
        ),
        isTrue,
      );
      expect(
        ThemeResolver.darkModeFromThemeMode(RegularConfig.themeModeSystem),
        isFalse,
      );
    });
  });

  group('ThemeResolver.seedScheme', () {
    test('按 brightness 生成且使用主题色列表', () {
      const RegularConfig config = RegularConfig(theme: 1);
      final ColorScheme light =
          ThemeResolver.seedScheme(config, Brightness.light);
      final ColorScheme dark =
          ThemeResolver.seedScheme(config, Brightness.dark);
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(
        light,
        ColorScheme.fromSeed(
          seedColor: StaticsVar.themeList[1],
          brightness: Brightness.light,
        ),
      );
    });

    test('theme 越界时回退到默认索引 9', () {
      final ColorScheme scheme =
          ThemeResolver.seedScheme(const RegularConfig(theme: 999), Brightness.light);
      expect(
        scheme,
        ColorScheme.fromSeed(
          seedColor: StaticsVar.themeList[9],
          brightness: Brightness.light,
        ),
      );
    });
  });
}
