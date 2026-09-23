// 全平台统一的路由转场。
//
// 沿用 Flutter Material 3 的 FadeForwards（共享轴 X：新页自右轻移淡入、
// 旧页向左轻移淡出），仅把转场时长收敛到 [AppMotion] 单一来源，使其与顶栏
// Tab 切换、阅读题标题 Hero、翻卡展开层等保持同一套动效 token。

import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:flutter/material.dart';

/// 全平台统一的路由转场 builder。
///
/// 行为与 [FadeForwardsPageTransitionsBuilder] 一致（含旧页的 delegated 转场），
/// 唯一区别是 [transitionDuration] 取自 [AppMotion]（400ms），而不再使用其
/// 内建的 450ms，从而让路由转场与全应用其余动效共用同一时长来源。
class AppPageTransitionsBuilder extends FadeForwardsPageTransitionsBuilder {
  const AppPageTransitionsBuilder({super.backgroundColor});

  @override
  Duration get transitionDuration => AppMotion.mediumLong;
}
