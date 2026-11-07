// 下载与解压工具（原 lib/funcs/utili.dart 拆分）。
// downloadFile 统一下载；extractTarBz2 供后台 isolate 解压 tar.bz2 模型包使用。

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:arabic_learning/services/http_client.dart';
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;

/// 下载文件到指定的目录
/// 
/// [url] :文件网址
/// 
/// [savePath] :保存地址
/// 
/// [onDownloading] :下载进程中的回调，传入两个参数(int count, int total)，可用于进度展示
Future<void> downloadFile(String url, String savePath, {ProgressCallback? onDownloading}) async {
  final dio = createDio();
  await dio.download(
    url,
    savePath,
    onReceiveProgress: onDownloading?? (count, total){},
  );
}

/// 把下载内容读进内存（Web 没有文件系统，模型包只能先落内存）。
Future<Uint8List> downloadBytes(String url, {ProgressCallback? onDownloading}) async {
  final response = await createDio().getUri<List<int>>(
    Uri.parse(url),
    options: Options(
      responseType: ResponseType.bytes,
      followRedirects: true,
      validateStatus: (status) => status != null && status < 400,
    ),
    onReceiveProgress: onDownloading,
  );
  final List<int>? data = response.data;
  if (data is Uint8List) return data;
  return Uint8List.fromList(data ?? const <int>[]);
}

@pragma('vm:entry-point') 
void extractTarBz2((String inputPath, String outputPath) args) async {
  final inputPath = args.$1;
  final outputDir = args.$2;
  final bytes = await io.File(inputPath).readAsBytes();

  // 解压 bz2
  final bz2Decoder = BZip2Decoder();
  final tarBytes = bz2Decoder.decodeBytes(bytes);

  // 解包 tar
  final tarArchive = TarDecoder().decodeBytes(tarBytes);

  // 解出文件
  for (final file in tarArchive.files) {
    final filePath = '$outputDir${io.Platform.pathSeparator}${file.name}';
    if (file.isFile) {
      final outFile = io.File(filePath);
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>);
    } else {
      await io.Directory(filePath).create(recursive: true);
    }
  }
}
