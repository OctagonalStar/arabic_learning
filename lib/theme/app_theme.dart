// 主题构建：由 `ColorScheme` 推导一套 Material 3 `ThemeData`，并补全组件主题。
//
// `buildTheme` 是纯函数（不读取全局状态），由 `Global` 传入当前 `ColorScheme`
// 与字体家族调用。亮 / 暗两套主题共用同一套组件主题规则，仅 `scheme` 不同。

import 'package:flutter/material.dart';

import 'package:arabic_learning/theme/tokens.dart';

/// 构建应用主题。
///
/// [scheme] 为已解析的颜色方案（种子色或动态取色）；
/// [fontFamily] / [fontFamilyFallback] 沿用现有字体逻辑（由 `Global` 传入）。
/// [fontFamilyFallback] 为字体回退链（如 `[Vazirmatn]` 或
/// `[Vazirmatn, NotoSansSC]`），不会改变 [fontFamily] 的现有语义。
ThemeData buildTheme(
  ColorScheme scheme, {
  String? fontFamily,
  List<String>? fontFamilyFallback,
}) {
  final ThemeData base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    extensions: <ThemeExtension<dynamic>>[AppSemanticColors.of(scheme)],
  );

  final TextTheme text = _buildTextTheme(base.textTheme);
  final AppSemanticColors semantic = AppSemanticColors.of(scheme);
  final Color disabled = semantic.disabled;

  final BorderRadius controlRadius = AppRadius.controlBorder;
  final BorderRadius cardRadius = AppRadius.cardBorder;

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    splashFactory: InkSparkle.splashFactory,

    // —— 页面转场 ——
    // 全平台统一使用 Material 3 的 FadeForwards 转场（Android U 风格）：
    // 新页淡入 + 旧页左移，避免各平台系统默认转场造成观感不一致。
    // 所有 `MaterialPageRoute` 自动继承，无需在调用点单独指定。
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      },
    ),

    // —— 顶部栏 ——
    appBarTheme: AppBarThemeData(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 3,
      backgroundColor: scheme.surfaceContainer,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: scheme.surfaceTint,
      titleTextStyle: text.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),

    // —— 卡片 ——
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: scheme.surfaceTint,
      shadowColor: scheme.shadow,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: cardRadius),
    ),

    // —— 导航 ——
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.secondaryContainer,
      indicatorShape: RoundedRectangleBorder(borderRadius: controlRadius),
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final Color color = states.contains(WidgetState.selected)
            ? scheme.onSurface
            : scheme.onSurfaceVariant;
        return text.labelMedium?.copyWith(color: color);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final Color color = states.contains(WidgetState.selected)
            ? scheme.onSecondaryContainer
            : scheme.onSurfaceVariant;
        return IconThemeData(color: color, size: 24.0);
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      elevation: 0,
      backgroundColor: scheme.surfaceContainer,
      useIndicator: true,
      indicatorColor: scheme.secondaryContainer,
      indicatorShape: RoundedRectangleBorder(borderRadius: controlRadius),
      selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle:
          text.labelMedium?.copyWith(color: scheme.onSurface),
      unselectedLabelTextStyle:
          text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
    ),

    // —— 输入 ——
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      floatingLabelStyle: text.bodySmall?.copyWith(color: scheme.primary),
      errorStyle: text.bodySmall?.copyWith(color: scheme.error),
      border: OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: scheme.primary, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: scheme.error, width: 2.0),
      ),
    ),

    // —— 弹层 ——
    dialogTheme: DialogThemeData(
      elevation: 6,
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: scheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: cardRadius),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      titleTextStyle: text.headlineSmall?.copyWith(color: scheme.onSurface),
      contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      backgroundColor: scheme.surfaceContainerLow,
      modalBackgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: scheme.surfaceTint,
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 3,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
      insetPadding: const EdgeInsets.all(AppSpacing.sm),
      shape: RoundedRectangleBorder(borderRadius: controlRadius),
    ),

    // —— 按钮 ——
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: semantic.disabledContainer,
        disabledForegroundColor: disabled,
        elevation: 1,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        disabledForegroundColor: disabled,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        disabledForegroundColor: disabled,
        highlightColor: scheme.primary.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: 3,
      focusElevation: 3,
      hoverElevation: 4,
      highlightElevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control + 4.0),
      ),
    ),

    // —— 选择控件 ——
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.secondaryContainer,
      disabledColor: semantic.disabledContainer,
      surfaceTintColor: scheme.surfaceTint,
      labelStyle: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
      secondaryLabelStyle:
          text.labelLarge?.copyWith(color: scheme.onSecondaryContainer),
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: controlRadius),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4.0,
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.12),
      valueIndicatorColor: scheme.primary,
      valueIndicatorTextStyle: text.labelMedium?.copyWith(color: scheme.onPrimary),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return disabled;
        if (states.contains(WidgetState.selected)) return scheme.onPrimary;
        return scheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return semantic.disabledContainer;
        }
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return scheme.surfaceContainerHighest;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected) ||
            states.contains(WidgetState.disabled)) {
          return Colors.transparent;
        }
        return scheme.outline;
      }),
    ),

    // —— 列表 / 分隔 ——
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1.0,
      space: 1.0,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      textColor: scheme.onSurface,
      collapsedTextColor: scheme.onSurface,
      iconColor: scheme.onSurfaceVariant,
      collapsedIconColor: scheme.onSurfaceVariant,
      tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      shape: RoundedRectangleBorder(borderRadius: controlRadius),
      collapsedShape: RoundedRectangleBorder(borderRadius: controlRadius),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      titleTextStyle: text.bodyLarge?.copyWith(color: scheme.onSurface),
      subtitleTextStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      shape: RoundedRectangleBorder(borderRadius: controlRadius),
    ),
  );
}

/// 在 M3 默认字阶上做少量微调，使历史内联字号收敛到最接近的文本角色。
///
/// - `titleMedium` 16 → 18：对齐历史 `TextContainer` 默认 18 号正文；
/// - 其余角色沿用 M3 默认（labelSmall 11 / labelMedium 12 / bodyMedium 14 /
///   bodyLarge 16 / titleLarge 22 / headlineSmall 24 / headlineMedium 28 /
///   headlineLarge 32 / displaySmall 36 / displayMedium 45 / displayLarge 57）。
TextTheme _buildTextTheme(TextTheme base) {
  return base.copyWith(
    titleMedium: base.titleMedium?.copyWith(fontSize: 18.0),
  );
}
