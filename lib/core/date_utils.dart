// 基准日期工具
//
// 学习连胜以 2025/11/1 为基准日期（见 Global.updateLearningStreak 中的说明），
// 后台通知、连胜计算、首页状态等多处都需要「距基准日期的天数」。
// 本文件仅依赖 dart:core，不引入 Flutter / 插件，因此可以安全地被
// workmanager 后台 isolate（services/notifications.dart）导入。

/// 学习连胜的日期基准（2025/11/1）
final DateTime learningEpoch = DateTime(2025, 11, 1);

/// 返回从 [learningEpoch] 到 [now] 的天数；[now] 缺省为当前时间
int daysSinceEpoch([DateTime? now]) =>
    (now ?? DateTime.now()).difference(learningEpoch).inDays;
