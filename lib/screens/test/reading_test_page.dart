// 阅读题模块入口（barrel）。
//
// 具体实现已按职责拆分到 `lib/screens/test/reading/` 下：
// - `reading_list_page.dart`      列表页 / 列表项 / 标签
// - `reading_add_page.dart`       新增流程三步向导 + 类型选择卡片
// - `reading_config_page.dart`    生成配置页（含三种来源提交逻辑）
// - `reading_question_page.dart`  作答页
// - `reading_conclude_page.dart`  结算页
// - `reading_ai_generator.dart`   AI 提示词与 HTTP 生成客户端（纯逻辑）
// - `reading_shared.dart`         文字倍率 / QuestionConfig / Hero tag
//
// 这里保留全部对外符号的导出路径不变，外部仍从
// `package:arabic_learning/screens/test/reading_test_page.dart` 导入。

export 'reading/reading_ai_generator.dart';
export 'reading/reading_add_page.dart';
export 'reading/reading_conclude_page.dart';
export 'reading/reading_config_page.dart';
export 'reading/reading_list_page.dart';
export 'reading/reading_question_page.dart';
export 'reading/reading_shared.dart';
