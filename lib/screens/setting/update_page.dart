// 应用内更新的下载页（Android）。
//
// 承载更新流程里所有「有状态、可取消、需跨前后台」的阶段：
// 下载进度 / 下载完成 / 未知来源权限引导 / 错误重试。
//
// 设计要点：
// - 复用 `model_download_page.dart` 的「按钮 + 原生 LinearProgressIndicator」
//   模式，状态由 `UpdateService`（变更通知单例）驱动；
// - 用 `WidgetsBindingObserver` 在回到前台时对账：下载结果由 service 自行刷新，
//   本页额外处理「用户去系统设置授予未知来源权限后返回」的自动重试；
// - 本文件同时导出若干更新相关的公共小工具（版本号格式化、错误归类、项目主页
//   地址），供 `lib/widgets/update_sheet.dart` 复用。

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/statics.dart' show StaticsVar;
import 'package:arabic_learning/core/version.dart' show versionIntToString;
import 'package:arabic_learning/services/update_service.dart';
import 'package:arabic_learning/theme/tokens.dart'
    show AppMotion, AppRadius, AppSemanticColors, AppSpacing;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/motion.dart' show CrossFadeSwitcher;
import 'package:arabic_learning/widgets/overlays.dart' show alart, showSnackBar;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 把内部版本号（如 `101000`）格式化为展示串（如 `1.1.0`）。
///
/// 委托 [versionIntToString]（编码约定：`major * 100000 + minor * 1000 + patch`），
/// 仅额外提供「无效值返回空串」这一展示层兜底（共享实现返回 `"0.0.0"`）。
String formatUpdateVersionInt(int value) {
  if (value <= 0) return "";
  return versionIntToString(value);
}

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

/// 应用内更新的下载页。
///
/// 由 `showUpdateSheet`（`lib/widgets/update_sheet.dart`）在用户选择
/// 「立即更新」后通过 `Navigator.push(MaterialPageRoute(...))` 打开。
class UpdatePage extends StatefulWidget {
  /// 创建下载页。
  const UpdatePage({super.key});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> with WidgetsBindingObserver {
  final UpdateService _service = UpdateService();

  /// 是否正在等待用户从系统设置里授予「未知来源」权限。
  ///
  /// 只有用户主动发起安装后才会置真，避免每次回前台都误触发自动安装。
  bool _awaitingPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    // 回到前台对账：下载结果是 service 的职责（其自身会 notifyListeners）；
    // 这里额外在「刚去过权限设置」时重试一次安装。
    if (_awaitingPermission) {
      _awaitingPermission = false;
      _service.retryInstallIfPermitted();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (BuildContext context, Widget? child) {
        final bool downloading = _service.stage == UpdateStage.downloading;
        return PopScope<Object?>(
          canPop: !downloading,
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            if (didPop) return;
            final bool leave = await _confirmLeaveWhileDownloading();
            if (leave && context.mounted) Navigator.of(context).pop();
          },
          child: Scaffold(
            appBar: AppBar(title: const Text("下载更新")),
            body: SafeArea(top: false, child: _centered(_buildBody(context))),
          ),
        );
      },
    );
  }

  /// 宽屏（>= 600）时内容居中并限制在 560 宽；内容可滚动，主按钮不会溢出。
  Widget _centered(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560.0),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: child,
        ),
      ),
    );
  }

  /// 按阶段构建主体，状态切换用交叉淡入（`CrossFadeSwitcher` 需不同 key）。
  Widget _buildBody(BuildContext context) {
    switch (_service.stage) {
      case UpdateStage.downloading:
        return _framed('update-downloading', _downloadingBody(context));
      case UpdateStage.ready:
        return _service.needsInstallPermission
            ? _framed('update-permission', _permissionBody(context))
            : _framed('update-ready', _readyBody(context));
      case UpdateStage.error:
        return _framed('update-error', _errorBody(context));
      case UpdateStage.available:
      case UpdateStage.idle:
      case UpdateStage.checking:
        return _framed('update-available', _availableBody(context));
    }
  }

  /// 用不同 key 包一层交叉淡入，保证状态切换有过渡动画。
  Widget _framed(String tag, Widget child) {
    return CrossFadeSwitcher(
      child: KeyedSubtree(key: ValueKey<String>(tag), child: child),
    );
  }

  // ---------------------------------------------------------------- 下载中

  Widget _downloadingBody(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool animationsDisabled =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final int total = _service.totalBytes;
    final int got = _service.downloadedBytes;
    final bool known = total > 0;
    final double? value = known
        ? (got / total).clamp(0.0, 1.0).toDouble()
        : null;
    final int percent = known ? ((value ?? 0.0) * 100).floor() : 0;
    final String version = displayUpdateVersionLabel(
      _service.latestVersionLabel,
    );
    final String speedLine = _speedLine(known: known, got: got, total: total);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.download, size: 48.0, color: scheme.primary),
        const SizedBox(height: AppSpacing.xs),
        Text(
          version.isEmpty ? "正在下载更新…" : "正在下载 $version",
          style: text.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        _ProgressBar(value: value, animationsDisabled: animationsDisabled),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          label: known ? "下载进度 $percent%" : "已下载 ${_mb(got)} MB",
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                known
                    ? "$percent%    ${_mb(got)} MB / ${_mb(total)} MB"
                    : "已下载 ${_mb(got)} MB",
                style: text.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (speedLine.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  speedLine,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Button(
          size: const Size(double.infinity, 56.0),
          backgroundColor: scheme.errorContainer,
          onPressed: () => _confirmCancel(context),
          child: const Text("取消下载"),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          "可以切到后台下载，完成后可在通知栏查看进度（需允许通知）",
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 「速度 · 剩余」行；速度未知时返回空串（调用方据此不渲染该行）。
  String _speedLine({
    required bool known,
    required int got,
    required int total,
  }) {
    final double speed = _service.speedBytesPerSec;
    if (speed <= 0) return "";
    final String speedText = "速度 ${_mbps(speed)} MB/s";
    if (!known) return speedText;
    final double remainingSeconds = (total - got) / speed;
    if (remainingSeconds <= 5) return "$speedText · 即将完成";
    return "$speedText · 剩余约 ${remainingSeconds.ceil()} 秒";
  }

  void _confirmCancel(BuildContext context) {
    alart(
      context,
      "确定要取消下载吗？已下载的内容会被删除。",
      onConfirmed: () {
        _service.cancelDownload();
        if (mounted) Navigator.of(context).maybePop();
      },
    );
  }

  /// 下载中按返回键：确认「后台下载 / 取消」。
  Future<bool> _confirmLeaveWhileDownloading() async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("提示"),
          content: const Text("要改为后台下载吗？"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("继续等待"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
                _service.cancelDownload();
              },
              child: Text(
                "取消下载",
                style: TextStyle(color: context.semanticColors.error),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("后台下载"),
            ),
          ],
        );
      },
    );
    return leave ?? false;
  }

  // ---------------------------------------------------------------- 下载完成

  Widget _readyBody(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final int total = _service.totalBytes;
    final String version = displayUpdateVersionLabel(
      _service.latestVersionLabel,
    );
    final String subtitle = [
      if (version.isNotEmpty) "版本 $version",
      if (total > 0) "${_mb(total)} MB",
    ].join(" · ");

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle,
          size: 48.0,
          color: context.semanticColors.success,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text("下载完成", style: text.titleLarge, textAlign: TextAlign.center),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Button(
          size: const Size(double.infinity, 56.0),
          icon: const Icon(Icons.install_desktop),
          onPressed: _install,
          child: const Text("立即安装"),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => _deletePackage(context),
          child: const Text("删除安装包"),
        ),
      ],
    );
  }

  Future<void> _install() async {
    final bool launched = await _service.install();
    if (!mounted) return;
    if (_service.needsInstallPermission) {
      _awaitingPermission = true;
      setState(() {});
      return;
    }
    // 安装器未能启动：service 会保留 ready 状态，这里给出可见反馈以便重试。
    if (!launched) {
      showSnackBar(context, "安装未完成，请重试");
    }
  }

  /// 删除安装包。
  ///
  /// 说明：[UpdateService] 未单独暴露删除接口，这里复用 `cancelDownload`
  /// （其语义即「删除已下载内容」）清理安装包，随后返回上一页。
  void _deletePackage(BuildContext context) {
    _service.cancelDownload();
    Navigator.of(context).maybePop();
  }

  // ------------------------------------------------------------ 权限引导

  Widget _permissionBody(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final AppSemanticColors semantic = context.semanticColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.warning_amber_rounded, size: 48.0, color: semantic.warning),
        const SizedBox(height: AppSpacing.xs),
        Text(
          "需要允许安装未知来源应用",
          style: text.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          "请在系统设置里允许「${StaticsVar.appName}」安装应用，完成后返回本页，点“立即安装”。",
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Button(
          size: const Size(double.infinity, 56.0),
          backgroundColor: semantic.warning,
          foregroundColor: semantic.onWarning,
          onPressed: () => _goToPermissionSettings(),
          child: const Text("去设置"),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => _confirmPermitted(),
          child: const Text("我已允许"),
        ),
      ],
    );
  }

  /// 打开「未知来源」系统设置。
  ///
  /// 复用 `install()`：权限缺失时由 service 负责跳转系统设置并置
  /// `needsInstallPermission`，返回前台后再由 [didChangeAppLifecycleState] 重试。
  Future<void> _goToPermissionSettings() async {
    _awaitingPermission = true;
    final bool launched = await _service.install();
    if (!mounted) return;
    // 仍缺权限时由 service 置 needsInstallPermission（继续展示引导），无需提示；
    // 权限已具备却启动失败时给出重试提示。
    if (!launched && !_service.needsInstallPermission) {
      showSnackBar(context, "安装未完成，请重试");
    }
    setState(() {});
  }

  /// 用户手动确认「已允许」：立即尝试安装；仍未授权时给出明确提示并留在引导页。
  Future<void> _confirmPermitted() async {
    _awaitingPermission = false;
    final bool ok = await _service.retryInstallIfPermitted();
    if (!mounted) return;
    if (!ok) {
      showSnackBar(context, "仍未获得安装权限，请在系统设置中允许后重试");
    }
  }

  // ---------------------------------------------------------------- 错误

  Widget _errorBody(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final AppSemanticColors semantic = context.semanticColors;
    final UpdateErrorInfo info = describeUpdateError(_service.error);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.error_outline, size: 48.0, color: semantic.error),
        const SizedBox(height: AppSpacing.xs),
        Text(info.title, style: text.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          info.message,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        if (_service.error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            "调试信息：${_service.error}",
            style: text.bodySmall?.copyWith(color: semantic.disabled),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Button(
          size: const Size(double.infinity, 56.0),
          onPressed: () => _handleErrorAction(context, info.action),
          child: Text(info.actionLabel),
        ),
        if (info.action != UpdateErrorAction.dismiss) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text("返回"),
          ),
        ],
      ],
    );
  }

  Future<void> _handleErrorAction(
    BuildContext context,
    UpdateErrorAction action,
  ) async {
    switch (action) {
      case UpdateErrorAction.retry:
        // 安装类错误重试安装，其余（下载类）重试下载。
        final String text = (_service.error ?? "").toString().toLowerCase();
        if (text.contains("install") || text.contains("安装")) {
          await _install();
        } else {
          _service.startDownload();
        }
        return;
      case UpdateErrorAction.openProject:
        await launchUrl(Uri.parse(updateProjectUrl()));
        return;
      case UpdateErrorAction.dismiss:
        if (context.mounted) Navigator.of(context).maybePop();
        return;
    }
  }

  // ------------------------------------------------- 兜底（无下载在途时）

  Widget _availableBody(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String version = displayUpdateVersionLabel(
      _service.latestVersionLabel,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.system_update_alt,
          size: 48.0,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          version.isEmpty ? "准备下载更新" : "准备下载 $version",
          style: text.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Button(
          size: const Size(double.infinity, 56.0),
          onPressed: _service.startDownload,
          child: const Text("开始下载"),
        ),
      ],
    );
  }
}

/// 进度条：确定进度平滑推进；总大小未知时不定期进度；
/// 「减弱动态效果」/测试下退化为静态，保证 `pumpAndSettle` 能结束。
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.animationsDisabled});

  /// 0.0 ~ 1.0；为 null 表示总大小未知（不确定进度）。
  final double? value;

  /// 是否禁用动画。
  final bool animationsDisabled;

  @override
  Widget build(BuildContext context) {
    final double? target = value;
    if (target == null) {
      return LinearProgressIndicator(
        value: animationsDisabled ? 0.0 : null,
        minHeight: 12.0,
        borderRadius: AppRadius.controlBorder,
      );
    }
    if (animationsDisabled) {
      return LinearProgressIndicator(
        value: target,
        minHeight: 12.0,
        borderRadius: AppRadius.controlBorder,
      );
    }
    // `begin` 仅用于首次动画；后续重建会从当前值平滑过渡到新的目标值。
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: target),
      duration: AppMotion.quick,
      curve: AppMotion.standardCurve,
      builder: (BuildContext context, double animated, Widget? child) {
        return LinearProgressIndicator(
          value: animated,
          minHeight: 12.0,
          borderRadius: AppRadius.controlBorder,
        );
      },
    );
  }
}

/// 字节 → MB（一位小数）。
String _mb(int bytes) => (bytes / 1024.0 / 1024.0).toStringAsFixed(1);

/// 字节/秒 → MB/s（一位小数）。
String _mbps(double bytesPerSec) =>
    (bytesPerSec / 1024.0 / 1024.0).toStringAsFixed(1);
