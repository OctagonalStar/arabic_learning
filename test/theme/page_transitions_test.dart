import 'package:arabic_learning/theme/app_theme.dart';
import 'package:arabic_learning/theme/page_transitions.dart';
import 'package:arabic_learning/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppPageTransitionsBuilder 时长取自 AppMotion 且保持 FadeForwards 语义', () {
    const AppPageTransitionsBuilder builder = AppPageTransitionsBuilder();
    expect(builder.transitionDuration, AppMotion.mediumLong);
    expect(builder, isA<FadeForwardsPageTransitionsBuilder>());
  });

  test('buildTheme 为全平台注册统一路由转场', () {
    final ThemeData theme = buildTheme(ColorScheme.fromSeed(seedColor: Colors.blue));
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.fuchsia,
    ]) {
      expect(
        theme.pageTransitionsTheme.builders[platform],
        isA<AppPageTransitionsBuilder>(),
        reason: '$platform 应使用统一转场',
      );
    }
  });
}
