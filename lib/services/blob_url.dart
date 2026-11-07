// blob URL 门面：Web 用浏览器 Blob 播放内存里的音频，其余平台不支持。

import 'dart:typed_data';

import 'package:arabic_learning/services/blob_url_stub.dart'
    if (dart.library.html) 'package:arabic_learning/services/blob_url_web.dart'
    as impl;

String createBlobUrl(Uint8List bytes, {String mimeType = 'audio/wav'}) =>
    impl.createBlobUrl(bytes, mimeType: mimeType);

void revokeBlobUrl(String url) => impl.revokeBlobUrl(url);
