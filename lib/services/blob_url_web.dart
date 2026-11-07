// Web blob URL 实现：sherpa 生成的是内存采样，转成 WAV 后用 Blob 交给 <audio>。

import 'dart:js_interop';
import 'dart:typed_data';

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> parts, JSObject options);
}

@JS('URL.createObjectURL')
external String _create(_Blob blob);

@JS('URL.revokeObjectURL')
external void _revoke(String url);

String createBlobUrl(Uint8List bytes, {String mimeType = 'audio/wav'}) =>
    _create(_Blob([bytes.toJS].toJS, {'type': mimeType}.jsify()! as JSObject));

void revokeBlobUrl(String url) => _revoke(url);
