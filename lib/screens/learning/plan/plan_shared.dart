// 「计划学习」页面共用的小工具：日期文案。
//
// 只放纯函数，不读取任何服务单例，方便首页 / 配置页 / 学习页入口卡共用。
// 进度条一律直接使用 Material `LinearProgressIndicator`，这里不再另建组件。

/// `MM月dd日` 日期文案（配置页右侧、首页截止日期）。
String planMonthDay(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return "$month月$day日";
}

/// `yyyy年MM月dd日` 日期文案（逾期提示里带年份，避免跨年歧义）。
String planFullDate(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return "${date.year}年$month月$day日";
}
