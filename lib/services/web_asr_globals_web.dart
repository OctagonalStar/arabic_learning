// Web 实现：把 asr wrapper 里全局词法作用域的 class 复制到 globalThis。

import 'dart:js_interop';

@JS('eval')
external JSAny? _globalEval(JSString code);

void exposeSherpaOnnxAsrGlobals() {
  _globalEval('''
(() => {
  const g = globalThis;
  if (typeof OfflineRecognizer !== 'undefined' && !g.OfflineRecognizer) {
    g.OfflineRecognizer = OfflineRecognizer;
  }
  if (typeof OfflineStream !== 'undefined' && !g.OfflineStream) {
    g.OfflineStream = OfflineStream;
  }
})()
'''.toJS);
}
