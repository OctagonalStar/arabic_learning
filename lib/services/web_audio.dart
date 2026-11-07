// Web 端播放 WAV blob URL。
//
// just_audio 在 Web 上复用同一个 <audio> 元素，换歌时会出现旧的 blob 被
// 释放、或新 src 未生效仍播上一条的问题；本地合成是内存里的整段 WAV，
// 直接用一次性 <audio> 元素最稳。非 Web 走 stub。

import 'package:arabic_learning/services/web_audio_stub.dart'
    if (dart.library.html) 'package:arabic_learning/services/web_audio_web.dart'
    as impl;

/// 播放 [url] 指向的音频，等待 [duration] 后返回（等价于播放完这一段）。
Future<void> playWavBlobUrl(String url, Duration duration) =>
    impl.playWavBlobUrl(url, duration);
