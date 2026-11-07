// Web 播放实现：每次播放新建一个 <audio> 元素，用完丢掉。
// 这样不会出现旧 src 残留或 blob 被提前释放导致播上一条音频。

import 'dart:async';
import 'dart:js_interop';

@JS('Audio')
extension type _Audio._(JSObject _) implements JSObject {
  external factory _Audio();
  external set src(String value);
  external JSPromise<JSAny?> play();
  external void pause();
}

/// 当前正在播放的元素；换一段时先停掉旧的。
_Audio? _current;

Future<void> playWavBlobUrl(String url, Duration duration) async {
  final _Audio? old = _current;
  final _Audio audio = _Audio();
  audio.src = url;
  _current = audio;
  old?.pause();

  // 播放失败（如浏览器自动播放策略）不抛出，交给时长等待收尾。
  audio.play().toDart.then((JSAny? _) {}, onError: (Object _) {});
  await Future<void>.delayed(duration);
  if (identical(_current, audio)) audio.pause();
}
