// 设计 token 集中定义：间距 / 圆角 / 动效 / 断点 / 语义色。
//
// 本文件只承载常量与主题扩展，不依赖除 Flutter 之外的项目代码，方便被
// widgets / screens / theme 各层复用。`StaticsVar.br` 与 `StaticsVar.curve`
// 直接引用此处的 token，保证既有调用点不破。

import 'package:flutter/material.dart';

/// 间距 token（4 / 8 / 16 / 24 / 32）。
@immutable
class AppSpacing {
  const AppSpacing._();

  /// 4.0 —— 紧凑元素之间（图标与文字）。
  static const double xxs = 4.0;

  /// 8.0 —— 控件内部或相邻控件。
  static const double xs = 8.0;

  /// 16.0 —— 卡片内边距、区块间距。
  static const double sm = 16.0;

  /// 24.0 —— 区块之间。
  static const double md = 24.0;

  /// 32.0 —— 页面级留白。
  static const double lg = 32.0;
}

/// 圆角 token：统一为两档语义（card=25、control=12）。
@immutable
class AppRadius {
  const AppRadius._();

  /// 大圆角（卡片 / 容器 / 底部弹窗），与旧 `StaticsVar.br` 一致。
  static const double card = 25.0;

  /// 小圆角（输入框 / 按钮 / chip 等控件）。
  static const double control = 12.0;

  /// 卡片圆角便捷对象。
  static final BorderRadius cardBorder = BorderRadius.circular(card);

  /// 控件圆角便捷对象。
  static final BorderRadius controlBorder = BorderRadius.circular(control);

  /// 卡片圆角对应的 `RoundedRectangleBorder`。
  static final RoundedRectangleBorder cardShape =
      RoundedRectangleBorder(borderRadius: cardBorder);

  /// 控件圆角对应的 `RoundedRectangleBorder`。
  static final RoundedRectangleBorder controlShape =
      RoundedRectangleBorder(borderRadius: controlBorder);
}

/// 动效 token：常用 `Duration` 与 `Curve`。
///
/// 毫秒级数值沿用 Material 的 `Durations`，秒级长动画单独命名；
/// 所有动画调用点统一引用此处 token，避免散落的字面量。
@immutable
class AppMotion {
  const AppMotion._();

  /// 默认动效曲线（沿用旧的 `StaticsVar.curve`）。
  static const Curve standardCurve = Curves.fastEaseInToSlowEaseOut;

  /// 强调曲线（进入 / 主题切换）。
  static const Curve emphasizedCurve = Curves.easeInOutCubicEmphasized;

  /// 减速曲线（入场）。
  static const Curve decelerateCurve = Curves.easeOutCubic;

  /// 加速曲线（退场）。
  static const Curve accelerateCurve = Curves.easeInCubic;

  /// 线性曲线：仅用于按时间 / 进度做线性映射的场景
  /// （如 PK 开场倒计时、阅读结果页的 Interval 时间轴）。
  static const Curve linearCurve = Curves.linear;

  /// 快速（约 200ms）。
  static const Duration quick = Durations.short4;

  /// 中短（约 250ms，沿用 `Durations.medium1`）。
  static const Duration mediumShort = Durations.medium1;

  /// 常规（约 300ms，沿用 `Durations.medium2`）。
  static const Duration medium = Durations.medium2;

  /// 较慢（约 400ms，沿用 `Durations.medium4`）。
  static const Duration mediumLong = Durations.medium4;

  /// 长（约 500ms，沿用 `Durations.long2`）。
  static const Duration long1 = Durations.long2;

  /// 长（约 600ms，沿用 `Durations.long4`）。
  static const Duration long2 = Durations.long4;

  /// 超长（约 700ms，沿用 `Durations.extralong2`）。
  static const Duration extraLong1 = Durations.extralong2;

  /// 超长（约 800ms，沿用 `Durations.extralong4`）。
  static const Duration extraLong2 = Durations.extralong4;

  /// 秒级（1s）—— 联机结算行、听写进度等慢速动画。
  static const Duration slow = Duration(seconds: 1);

  /// 秒级（2s）—— 联机结算得分条。
  static const Duration slower = Duration(seconds: 2);

  /// 秒级（3s）—— 阅读结果页入场。
  static const Duration slowest = Duration(seconds: 3);

  /// 秒级（4s）—— 结论卡内容揭示。
  static const Duration ultraSlow = Duration(seconds: 4);
}

/// 响应式断点 token（逻辑像素宽度）。
@immutable
class AppBreakpoints {
  const AppBreakpoints._();

  /// 手机 / 平板分界（沿用现有 `_desktopBreakpoint`）。
  static const double mobile = 600.0;

  /// 平板 / 桌面分界。
  static const double tablet = 1024.0;

  /// 大屏桌面分界。
  static const double desktop = 1440.0;

  /// 是否手机宽度。
  static bool isMobile(double width) => width < mobile;

  /// 是否平板宽度。
  static bool isTablet(double width) => width >= mobile && width < tablet;

  /// 是否桌面宽度。
  static bool isDesktop(double width) => width >= tablet;
}

/// 语义色主题扩展：成功 / 警告 / 错误 / 禁用。
///
/// 颜色随亮暗模式自适应；通过 `Theme.of(context).extension<AppSemanticColors>()`
/// 或 [of] 获取。错误色直接沿用 `ColorScheme.error`。
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  /// 成功。
  final Color success;

  /// 成功色上的前景色。
  final Color onSuccess;

  /// 警告。
  final Color warning;

  /// 警告色上的前景色。
  final Color onWarning;

  /// 错误（等同 `ColorScheme.error`）。
  final Color error;

  /// 禁用（前景 / 图标）。
  final Color disabled;

  /// 禁用容器（背景）。
  final Color disabledContainer;

  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.error,
    required this.disabled,
    required this.disabledContainer,
  });

  /// 依据当前 [scheme] 推导语义色。
  factory AppSemanticColors.of(ColorScheme scheme) {
    final bool isDark = scheme.brightness == Brightness.dark;
    return AppSemanticColors(
      success: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
      onSuccess: isDark ? const Color(0xFF00390F) : Colors.white,
      warning: isDark ? const Color(0xFFFFD54F) : const Color(0xFFE65100),
      onWarning: isDark ? const Color(0xFF3E2E00) : Colors.white,
      error: scheme.error,
      disabled: scheme.onSurface.withValues(alpha: 0.38),
      disabledContainer: scheme.onSurface.withValues(alpha: 0.12),
    );
  }

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? error,
    Color? disabled,
    Color? disabledContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      error: error ?? this.error,
      disabled: disabled ?? this.disabled,
      disabledContainer: disabledContainer ?? this.disabledContainer,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      error: Color.lerp(error, other.error, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      disabledContainer:
          Color.lerp(disabledContainer, other.disabledContainer, t)!,
    );
  }
}
