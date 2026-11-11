// 更新流程的纯展示逻辑：版本号格式化、错误归类与项目主页地址。
//
// 放在 services 层，供下载页（screens）与更新提示弹窗（widgets）共用，
// 避免 widgets 为了几个纯函数反向 import screen。

import 'package:arabic_learning/services/update_service.dart' show UpdateService;
import 'package:flutter/foundation.dart' show immutable;

/// 展示用版本号：去掉 GitHub tag 常见的前导 `v`（如 `v1.2.0` → `1.2.0`）。
String displayUpdateVersionLabel(String? label) {
  final String value = (label ?? "").trim();
  if (value.isEmpty) return "";
  return value.startsWith("v") || value.startsWith("V")
      ? value.substring(1)
      : value;
}

/// 项目主页（最新发布页）地址，取自 [UpdateService] 的仓库常量。
String updateProjectUrl() =>
    "https://github.com/${UpdateService.owner}/${UpdateService.repo}/releases/latest";

/// 错误发生后主按钮的动作类别。
enum UpdateErrorAction {
  /// 重试当前操作（下载 / 安装）。
  retry,

  /// 打开项目主页手动下载。
  openProject,

  /// 无需更多操作，关闭即可。
  dismiss,
}

/// 面向用户的错误描述（标题 + 说明 + 动作）。
@immutable
class UpdateErrorInfo {
  const UpdateErrorInfo({
    required this.title,
    required this.message,
    required this.action,
    required this.actionLabel,
  });

  /// 一句话原因。
  final String title;

  /// 补充说明 / 建议。
  final String message;

  /// 主按钮动作。
  final UpdateErrorAction action;

  /// 主按钮文案。
  final String actionLabel;
}

/// 将底层错误归类为用户可读的 [UpdateErrorInfo]。
///
/// [UpdateService] 只暴露 `Object? error`，且其文案既有中文（如
/// `未找到可下载的安装包`）也可能是原始异常；这里按错误文本的中英文特征
/// 归类，识别不到时按「网络失败」处理（最常见）。
UpdateErrorInfo describeUpdateError(Object? error) {
  final String text = (error ?? "").toString().toLowerCase();
  // 限流（GitHub 403 / 次数已达上限）。
  if (text.contains("403") ||
      text.contains("rate limit") ||
      text.contains("rate_limit") ||
      text.contains("ratelimit") ||
      text.contains("已达上限") ||
      text.contains("过于频繁")) {
    return const UpdateErrorInfo(
      title: "请求过于频繁",
      message: "GitHub 暂时限制了访问，请稍后再试",
      action: UpdateErrorAction.dismiss,
      actionLabel: "知道了",
    );
  }
  // 存储空间不足。
  if (text.contains("enospc") ||
      text.contains("no space") ||
      text.contains("空间不足")) {
    return const UpdateErrorInfo(
      title: "存储空间不足",
      message: "请清理一些空间后重试",
      action: UpdateErrorAction.retry,
      actionLabel: "重试",
    );
  }
  // 安装包校验失败（包名 / 版本号不匹配）。
  if (text.contains("signature") ||
      text.contains("verify") ||
      text.contains("mismatch") ||
      text.contains("versioncode") ||
      text.contains("校验") ||
      text.contains("不匹配") ||
      text.contains("包名")) {
    return const UpdateErrorInfo(
      title: "安装包校验未通过",
      message: "这个安装包与当前应用不一致，为安全起见已阻止安装。请到项目主页重新下载",
      action: UpdateErrorAction.openProject,
      actionLabel: "打开项目主页",
    );
  }
  // 当前设备 / 平台不支持应用内更新。
  if (text.contains("不支持")) {
    return const UpdateErrorInfo(
      title: "当前设备暂不支持",
      message: "请到项目主页手动下载最新版本",
      action: UpdateErrorAction.openProject,
      actionLabel: "打开项目主页",
    );
  }
  // 没有可下载的安装包。
  if (text.contains("未找到") ||
      text.contains("没有提供") ||
      text.contains(".apk") ||
      text.contains("asset")) {
    return const UpdateErrorInfo(
      title: "未找到安装包",
      message: "这个版本暂时没有提供安卓安装包，请到项目主页手动下载",
      action: UpdateErrorAction.openProject,
      actionLabel: "打开项目主页",
    );
  }
  // 安装器启动 / 安装过程失败。
  if (text.contains("install") || text.contains("安装")) {
    return const UpdateErrorInfo(
      title: "安装未完成",
      message: "你可以重新尝试安装",
      action: UpdateErrorAction.retry,
      actionLabel: "重试",
    );
  }
  return const UpdateErrorInfo(
    title: "网络连接失败",
    message: "请检查网络后重试",
    action: UpdateErrorAction.retry,
    actionLabel: "重试",
  );
}
