// 主题解析：把 `RegularConfig` 的主题相关配置解析为 `ColorScheme` / `ThemeMode`。
//
// - `themeModeFromConfig` / `darkModeFromThemeMode` / `seedScheme` 为纯函数，便于单测；
// - `resolveSchemes` 在开启动态取色且平台支持时向 `dynamic_color` 请求系统配色，
//   任何失败（Web、测试 VM 的 `MissingPluginException`、不支持桌面）均回退种子色。

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;

import 'package:arabic_learning/core/statics.dart' show StaticsVar;
import 'package:arabic_learning/models/config.dart' show RegularConfig;

/// 一对已解析的亮 / 暗配色方案。
@immutable
class ResolvedSchemes {
  /// 亮色配色。
  final ColorScheme light;

  /// 暗色配色。
  final ColorScheme dark;

  const ResolvedSchemes({required this.light, required this.dark});
}

/// 主题解析工具集。
abstract final class ThemeResolver {
  /// `RegularConfig.themeMode` 的取值含义。
  static const int themeModeSystem = 0;
  static const int themeModeLight = 1;
  static const int themeModeDark = 2;

  /// 将 `RegularConfig.themeMode`(0=system,1=light,2=dark) 映射为 [ThemeMode]。
  ///
  /// 兼容旧数据的迁移已在 `RegularConfig.buildFromMap` 完成；此处对未知值回退
  /// 到跟随系统。
  static ThemeMode themeModeFromConfig(RegularConfig config) {
    switch (config.themeMode) {
      case themeModeLight:
        return ThemeMode.light;
      case themeModeDark:
        return ThemeMode.dark;
      case themeModeSystem:
      default:
        return ThemeMode.system;
    }
  }

  /// 依据主题模式推导旧 `darkMode` 布尔值，供降级到旧版本时读取。
  ///
  /// [fallback] 为跟随系统（无法确定）时的取值，默认沿用配置里的旧值。
  static bool darkModeFromThemeMode(int themeMode, {bool fallback = false}) {
    switch (themeMode) {
      case themeModeLight:
        return false;
      case themeModeDark:
        return true;
      case themeModeSystem:
      default:
        return fallback;
    }
  }

  /// 基于主题色种子生成回退配色。
  static ColorScheme seedScheme(RegularConfig config, Brightness brightness) {
    final int index = (config.theme >= 0 && config.theme < StaticsVar.themeList.length)
        ? config.theme
        : 9;
    return ColorScheme.fromSeed(
      seedColor: StaticsVar.themeList[index],
      brightness: brightness,
    );
  }

  /// 解析亮 / 暗配色。
  ///
  /// 当 [config.dynamicColor] 为真且当前平台支持时，优先使用系统动态配色
  /// （Android 的 CorePalette，桌面端的系统强调色）；否则回退到种子色。
  /// 该方法保证不抛出异常。
  ///
  /// 说明：`dynamic_color` 2.x 的 `toColorScheme` 返回 `material_ui` 包自带的
  /// `ColorScheme`，与 Flutter SDK 的 `package:flutter/material.dart` 类型不兼容，
  /// 因此这里只取插件提供的原生调色板 / 强调色，再自行用 Flutter 的
  /// `ColorScheme.fromSeed` 生成方案。
  static Future<ResolvedSchemes> resolveSchemes(RegularConfig config) async {
    if (config.dynamicColor && !kIsWeb) {
      try {
        final palette = await DynamicColorPlugin.getCorePalette();
        if (palette != null) {
          // Android：以主色相 tone 40 作为种子色，派生亮 / 暗完整方案。
          final Color seed = Color(palette.primary.get(40));
          return ResolvedSchemes(
            light: ColorScheme.fromSeed(
              seedColor: seed,
              brightness: Brightness.light,
            ),
            dark: ColorScheme.fromSeed(
              seedColor: seed,
              brightness: Brightness.dark,
            ),
          );
        }

        final Color? accent = await DynamicColorPlugin.getAccentColor();
        if (accent != null) {
          return ResolvedSchemes(
            light: ColorScheme.fromSeed(
              seedColor: accent,
              brightness: Brightness.light,
            ),
            dark: ColorScheme.fromSeed(
              seedColor: accent,
              brightness: Brightness.dark,
            ),
          );
        }
      } on MissingPluginException {
        // 测试 VM / 不支持的平台：无原生实现，回退种子色
      } catch (_) {
        // 任何平台错误都不应让主题解析崩溃
      }
    }

    return ResolvedSchemes(
      light: seedScheme(config, Brightness.light),
      dark: seedScheme(config, Brightness.dark),
    );
  }
}
