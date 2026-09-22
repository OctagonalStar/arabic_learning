// 单选状态通知器（原 lib/funcs/utili.dart 拆分）。
// 供阅读题等单选 UI 用 ChangeNotifierProvider 共享当前选中项。

import 'package:flutter/foundation.dart' show ChangeNotifier;

class SingleSelectionNotifier with ChangeNotifier {
  dynamic _value;

  dynamic get value => _value;

  void changeTo(dynamic value) {
    _value = value;
    notifyListeners();
  }
}
