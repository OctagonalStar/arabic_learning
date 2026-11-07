// 原生端的 blob URL 桩：浏览器对象只在 Web 构建里存在。

import 'dart:typed_data';

String createBlobUrl(Uint8List bytes, {String mimeType = 'audio/wav'}) {
  throw UnsupportedError('Web only');
}

void revokeBlobUrl(String url) {}
