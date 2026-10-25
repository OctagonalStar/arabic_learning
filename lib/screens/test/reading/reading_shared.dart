// 阅读题模块共享的常量 / 小工具：文字倍率、生成配置模型、Hero tag 生成。

import 'package:arabic_learning/models/reading.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppBreakpoints;
import 'package:flutter/material.dart';

/// 阅读文本缩放倍率：按可用宽度分档。
///
/// 原先固定 3 倍在窄竖屏（分栏后文章栏更窄）会显著偏大，这里改为：
/// 手机宽度用较小倍率，平板 / 桌面适当放大，兼顾可读性与不溢出。
TextScaler readingTextScaler(double width) {
  if (width < AppBreakpoints.mobile) return TextScaler.linear(1.8);
  if (width < AppBreakpoints.tablet) return TextScaler.linear(2.2);
  return TextScaler.linear(2.6);
}

class QuestionConfig {
  /// 0: 未定义, 1: 阅读，2: 完形，稍后再做成常量
  int testType = 0;

  /// 0：未定义，1: 保留（原 AI API 直连，已随小程序试用版移除）, 2: AI Prompt, 3: 现有JSON导入, 4: Github仓库
  int sourceType = 0;

  /// 文章主题
  String theme = "";

  /// 题目数量 2-10 / 5-20
  int questionAmount = 5;

  /// 文章难度 0-10
  int difficulty = 4;

  /// 发音符号
  bool tashkeel = false;
}

/// 阅读题列表 → 详情页共享的 Hero tag。
///
/// [ReadingUnit] 没有自增 id，这里使用导入去重所用的内容哈希作为业务身份；
/// 列表项再拼接其位置 [listIndex]，即使数据中出现内容完全相同的重复题目，
/// 同一路由内的 tag 也不会冲突（未从列表进入时为 `x`，不参与飞行）。
String readingUnitHeroTag(ReadingUnit unit, {int? listIndex}) =>
    'reading-unit-${listIndex ?? 'x'}-${unit.getHash().join('-')}';
