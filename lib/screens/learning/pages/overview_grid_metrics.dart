// 词汇总览 / 查找共用的网格列数推导：从 learning_pages_build.dart 拆分而来。
import 'dart:math';

import 'package:arabic_learning/services/app_data.dart' show AppData;

/// 词汇总览 / 查找网格列数：用户固定列数（>0）优先，否则按可用宽度约每
/// 300 逻辑像素一列，至少一列。
int overviewGridColumns(double availableWidth) {
  final int forced = AppData().config.learning.overviewForceColumn;
  if(forced > 0) return forced;
  return max(1, availableWidth ~/ 300);
}
