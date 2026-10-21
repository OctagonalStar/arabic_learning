// 单选状态通知器（原 lib/funcs/utili.dart 拆分）。
// 供阅读题等单选 UI 用 ChangeNotifierProvider 共享当前选中项。

import 'package:flutter/foundation.dart' show ChangeNotifier;

class SingleSelectionNotifier with ChangeNotifier {
  // 目前唯一用途是选项下标：null 表示未选择。
  int? _value;

  int? get value => _value;

  void changeTo(int? value) {
    _value = value;
    notifyListeners();
  }
}
