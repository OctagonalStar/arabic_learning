// 主题解析：把 `RegularConfig` 的主题相关配置解析为 `ColorScheme` / `ThemeMode`。
//
// 小程序试用版分支：动态取色（`dynamic_color`，依赖 Android / 桌面原生插件）已移除，
// 配色一律由 `StaticsVar.themeList` 的种子色派生。

import 'package:flutter/material.dart';

import 'package:arabic_learning/core/statics.dart' show StaticsVar;
import 'package:arabic_learning/models/config.dart' show RegularConfig;

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

  /// 基于主题色种子生成配色。
  static ColorScheme seedScheme(RegularConfig config, Brightness brightness) {
    final int index = (config.theme >= 0 && config.theme < StaticsVar.themeList.length)
        ? config.theme
        : 9;
    return ColorScheme.fromSeed(
      seedColor: StaticsVar.themeList[index],
      brightness: brightness,
    );
  }
}
