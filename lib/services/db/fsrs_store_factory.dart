// drift 存储的对外入口（条件导入隔离）。
//
// 原生平台 → `fsrs_drift_store.dart`（dart:io + drift + sqlite3）
// Web      → `fsrs_drift_store_stub.dart`（恒返回 null，绝不引入 drift/wasm）
//
// 因此本文件可以在任何平台安全导入。

import 'package:arabic_learning/services/db/fsrs_drift_store_stub.dart'
    if (dart.library.io) 'package:arabic_learning/services/db/fsrs_drift_store.dart'
    as impl;
import 'package:arabic_learning/services/db/fsrs_store.dart' show FsrsStore;

/// 打开 SQLite 存储；Web 或任何失败情况下返回 null（调用方回退 JSON 存储）。
///
/// [legacyJson] 为旧版 `fsrsData`，用于首启迁移；
/// [legacyHotKv] 为需要从 shared_preferences 迁出的高频键；
/// [databasePath] 仅测试使用：显式指定库文件位置，避免落到开发机的
/// 真实应用文档目录（drift 在后台 isolate 里打开库，拿不到测试 mock 的
/// `path_provider`）。
Future<FsrsStore?> openDriftStore({
  String? legacyJson,
  Map<String, String>? legacyHotKv,
  String? databasePath,
}) =>
    impl.openFsrsDriftStore(
      legacyJson: legacyJson,
      legacyHotKv: legacyHotKv,
      databasePath: databasePath,
    );
