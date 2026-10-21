// UI 控件库入口（barrel）。
//
// 本文件只做 re-export，不再承载实现；实现按职责拆分到同目录的：
// - widgets/app_button.dart       基础按钮 Button
// - widgets/text_container.dart   纯展示容器 TextContainer
// - widgets/category_chips.dart   分类标签 CategoryChips / 筛选 CategoryFilter / 单选 chip SelectChip
// - widgets/choose_buttons.dart   选择题选项 ChooseButtons / ChooseButtonBox
// - widgets/class_select.dart     课程选择 popSelectClasses / classesSelectionList / ClassSelectPage
// - widgets/setting_controls.dart 设置控件 SettingItem / SettingRow / SettingRedirctButton
//
// 保留本文件是为了让既有 `import '.../widgets/kit.dart'` 的调用点零改动；
// 新增代码请优先直接 import 对应的实现文件。

export 'package:arabic_learning/widgets/app_button.dart';
export 'package:arabic_learning/widgets/category_chips.dart';
export 'package:arabic_learning/widgets/choose_buttons.dart';
export 'package:arabic_learning/widgets/class_select.dart';
export 'package:arabic_learning/widgets/setting_controls.dart';
export 'package:arabic_learning/widgets/text_container.dart';
