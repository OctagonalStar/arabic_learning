// 字体解析与文本样式 helper 集中定义（T-3.7）。
//
// - [arabicStyle] / [arabicTextStyle]：统一从 `Global.arFont` 取阿语备用字体，
//   替代各页面手写 `context.read<Global>().arFont`；行为与旧写法一致
//   （未启用备用字体时 `arFont == null`，保留 [base] 的字体设置）。
// - [withoutColor]：剥离文本角色的颜色，仅保留排版属性。按钮子文本、选项反馈
//   动画等场景的前景色由外层 `DefaultTextStyle`（按钮 `foregroundColor`）动态
//   决定，直接使用文本角色会带入角色自身的 `onSurface` 颜色并覆盖动态前景色。

import 'package:arabic_learning/core/extensions.dart' show StringExtensions;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 阿拉伯语文本样式：在 [base] 上套用当前配置的阿语备用字体。
///
/// 若 [base] 为 null，则等价于旧写法 `TextStyle(fontFamily: arFont)`。
/// 未启用备用字体（`arFont == null`）时保留 [base] 原有字体设置。
TextStyle arabicStyle(BuildContext context, {TextStyle? base}) {
  return (base ?? const TextStyle()).copyWith(
    fontFamily: context.read<Global>().arFont,
  );
}

/// 依据 [text] 是否包含阿拉伯语字符，自动决定是否套用阿语备用字体。
///
/// 适用于阿 / 中混排的选项、释义等文本；非阿语文本原样返回 [base]。
TextStyle arabicTextStyle(BuildContext context, String text, {TextStyle? base}) {
  final TextStyle style = base ?? const TextStyle();
  if (!text.isArabic()) return style;
  return arabicStyle(context, base: style);
}

/// 仅保留 [base] 的排版属性（字号 / 字重 / 字体 / 行高 / 字距等），剥离颜色。
///
/// 用于颜色需继续由外层 `DefaultTextStyle` 决定的场景，避免文本角色自带颜色
/// 覆盖动态前景色（例如选择题按钮在变黄 / 变红绿时切换的前景色）。
///
/// 必须强制 `inherit: true`：外层 `Theme.of(context).textTheme.*` 在 `MaterialApp`
/// 下常带 `inherit: false`，若沿用该值，`Text` 不会合并 `DefaultTextStyle`，
/// 剥离颜色后无颜色可继承，最终回退到引擎默认色（白色）——浅色模式下按钮文字
/// 就会变成不可读的白字。
TextStyle withoutColor(TextStyle base) {
  return TextStyle(
    inherit: true,
    fontFamily: base.fontFamily,
    fontFamilyFallback: base.fontFamilyFallback,
    fontSize: base.fontSize,
    fontWeight: base.fontWeight,
    fontStyle: base.fontStyle,
    letterSpacing: base.letterSpacing,
    wordSpacing: base.wordSpacing,
    textBaseline: base.textBaseline,
    height: base.height,
    leadingDistribution: base.leadingDistribution,
    locale: base.locale,
    shadows: base.shadows,
    fontFeatures: base.fontFeatures,
    fontVariations: base.fontVariations,
    decoration: base.decoration,
    decorationColor: base.decorationColor,
    decorationStyle: base.decorationStyle,
    decorationThickness: base.decorationThickness,
    debugLabel: base.debugLabel,
    overflow: base.overflow,
  );
}
