// 应用内更新的「发现新版本」底部弹窗，以及唯一入口 [showUpdateSheet]。
//
// 复用 `lib/app.dart` 中更新日志弹窗的 `showModalBottomSheet` 模式；弹窗内容
// 抽为 [UpdateAvailableSheet]，由 `UpdateService`（变更通知单例）驱动。
//
// 说明：本文件位于 widgets 层，但为满足「单一入口」要求（启动与设置页
// 「检查更新」都只调用 [showUpdateSheet]），这里直接 push 下载页
// [UpdatePage]，因此存在本方案唯一的 widgets -> screens 反向 import。

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/statics.dart' show StaticsVar;
import 'package:arabic_learning/screens/setting/update_page.dart'
    show
        UpdateErrorAction,
        UpdateErrorInfo,
        UpdatePage,
        describeUpdateError,
        displayUpdateVersionLabel,
        formatUpdateVersionInt,
        updateProjectUrl;
import 'package:arabic_learning/services/update_service.dart';
import 'package:arabic_learning/theme/tokens.dart'
    show AppBreakpoints, AppRadius, AppSemanticColors, AppSpacing;
import 'package:arabic_learning/widgets/feedback.dart' show LoadingIndicator;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/motion.dart' show FadeSlideIn;
import 'package:arabic_learning/widgets/overlays.dart' show showSnackBar;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 弹窗中「立即更新 / 查看下载」的返回值：调用方据此打开下载页。
enum UpdateSheetResult { download }

/// 应用内更新的**唯一提示入口**。
///
/// 启动静默检查命中更新后，以及设置页「检查更新」被点击时，都应调用本函数：
/// - 若当前尚无检查结果（[UpdateStage.idle]），先手动检查一次，避免弹空白弹窗；
/// - 已是最新则用轻提示告知并直接返回，不弹窗；
/// - 否则弹出 [UpdateAvailableSheet]；用户选择「立即更新」后打开 [UpdatePage]。
Future<void> showUpdateSheet(BuildContext context) async {
  final UpdateService service = UpdateService();

  if (service.stage == UpdateStage.idle) {
    await service.check(manual: true);
    if (!context.mounted) return;
    if (service.lastCheckWasUpToDate) {
      showSnackBar(context, "已是最新版本");
      return;
    }
  }
  if (!context.mounted) return;

  final ColorScheme scheme = Theme.of(context).colorScheme;
  final UpdateSheetResult? result =
      await showModalBottomSheet<UpdateSheetResult>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        // 与更新日志弹窗同款外观（app.dart:243）。
        shape: RoundedSuperellipseBorder(
          side: BorderSide(width: 1.0, color: scheme.onSurface),
          borderRadius: StaticsVar.br,
        ),
        builder: (BuildContext context) => const UpdateAvailableSheet(),
      );

  if (!context.mounted) return;
  if (result == UpdateSheetResult.download) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const UpdatePage(),
      ),
    );
  }
}

/// 「发现新版本」底部弹窗内容；随 [UpdateService] 状态自动重绘。
///
/// 面板高度：默认不高于屏高 72%，长更新内容在面板内滚动；
/// 内容超长时可「展开全部」放宽到屏高 95%（主按钮始终固定可见）。
/// 宽屏（>= [AppBreakpoints.mobile]）时内容限制在 560 宽并居中。
class UpdateAvailableSheet extends StatefulWidget {
  /// 创建弹窗内容。
  const UpdateAvailableSheet({super.key});

  @override
  State<UpdateAvailableSheet> createState() => _UpdateAvailableSheetState();
}

class _UpdateAvailableSheetState extends State<UpdateAvailableSheet> {
  final UpdateService _service = UpdateService();

  /// 是否展开全部更新内容（放大面板高度）。
  bool _notesExpanded = false;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: ListenableBuilder(
        listenable: _service,
        builder: (BuildContext context, Widget? child) {
          final ColorScheme scheme = Theme.of(context).colorScheme;
          final Size size = MediaQuery.sizeOf(context);
          // 宽屏时内容 560 居中（手机宽度 < 560 时两侧留白为 0）。
          final double horizontalPadding = size.width >= AppBreakpoints.mobile
              ? (size.width - 560.0) / 2
              : 0.0;
          final double sheetMaxHeight =
              size.height * (_notesExpanded ? 0.95 : 0.72);

          return Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: StaticsVar.br,
            ),
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: sheetMaxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: _body(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (_service.stage) {
      case UpdateStage.idle:
      case UpdateStage.checking:
        return _checkingBody(context);
      // 已下载完成（ready）复用「发现新版本」版式，仅把主按钮换成安装：
      // 此时无需再下载，直接进入 [UpdatePage] 的 ready 界面。
      case UpdateStage.available:
      case UpdateStage.ready:
        return _availableBody(context);
      case UpdateStage.downloading:
        return _inProgressBody(context);
      case UpdateStage.error:
        return _errorBody(context);
    }
  }

  // ------------------------------------------------------------ 检查中

  Widget _checkingBody(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool animationsDisabled =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dragHandle(context),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 不确定进度在「减弱动态效果」/测试下退化为静态图形，
              // 保证 pumpAndSettle 能结束。
              if (animationsDisabled)
                const Icon(Icons.hourglass_empty, size: 36.0)
              else
                const LoadingIndicator(),
              const SizedBox(height: AppSpacing.sm),
              Text("正在检查更新…", style: text.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("关闭"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ 有更新

  Widget _availableBody(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String notes = _service.releaseNotes ?? "";
    final bool hasNotes = notes.trim().isNotEmpty;
    // 已下载完成时无需再下载，主按钮改为「立即安装」并直接进入下载页。
    final bool ready = _service.stage == UpdateStage.ready;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 中间内容（含长更新日志）可滚动；底部动作区固定可见。
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dragHandle(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.sm,
                    0.0,
                  ),
                  child: Text(
                    "发现新版本",
                    style: text.titleLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.sm,
                    AppSpacing.xs,
                  ),
                  child: _versionCompare(context),
                ),
                if (hasNotes) ...[
                  const Divider(height: 1.0),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.xs,
                    ),
                    child: Text(
                      "更新内容",
                      style: text.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: AppRadius.controlBorder,
                      ),
                      child: MarkdownBody(data: notes),
                    ),
                  ),
                  if (_notesLikelyLong(notes))
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _notesExpanded = !_notesExpanded),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_notesExpanded ? "收起" : "展开全部"),
                            Icon(
                              _notesExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 18.0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1.0),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Button(
            size: const Size(double.infinity, 56.0),
            icon: const Icon(Icons.system_update_alt),
            onPressed: () => ready
                ? _openInstallPage(context)
                : _startDownload(context),
            child: Text(ready ? "立即安装" : "立即更新"),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            0.0,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    // 本次进程内不再自动提示该版本。
                    _service.dismissForSession();
                    Navigator.of(context).pop();
                  },
                  child: const Text("稍后再说"),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => _skipVersion(context),
                  child: const Text("跳过此版本"),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _versionCompare(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String current = formatUpdateVersionInt(_service.currentVersionInt);
    final String latest = displayUpdateVersionLabel(
      _service.latestVersionLabel,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      children: [
        Text(
          current.isEmpty ? "当前版本" : "当前版本 $current",
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        Icon(Icons.arrow_forward, size: 16.0, color: scheme.onSurfaceVariant),
        Text(
          latest.isEmpty ? "新版本" : "新版本 $latest",
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _skipVersion(BuildContext context) async {
    await _service.skipVersion();
    if (context.mounted) Navigator.of(context).pop();
  }

  void _startDownload(BuildContext context) {
    _service.startDownload();
    Navigator.of(context).pop(UpdateSheetResult.download);
  }

  /// 已下载完成：不再触发下载，直接让调用方打开 [UpdatePage]（其渲染 ready 界面）。
  void _openInstallPage(BuildContext context) {
    Navigator.of(context).pop(UpdateSheetResult.download);
  }

  /// 更新日志是否「可能很长」——用于决定是否显示「展开全部」。
  ///
  /// 简单启发式：字符数或换行数超过阈值即视为长内容，避免为空测量引入额外布局。
  bool _notesLikelyLong(String notes) {
    if (notes.length > 240) return true;
    int lineBreaks = 0;
    for (final int codeUnit in notes.codeUnits) {
      if (codeUnit == 0x0A) lineBreaks++;
    }
    return lineBreaks > 8;
  }

  // ------------------------------------------- 下载中 / 已下载（再次打开）

  Widget _inProgressBody(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool ready = _service.stage == UpdateStage.ready;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dragHandle(context),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ready ? Icons.check_circle : Icons.download,
                size: 48.0,
                color: ready ? context.semanticColors.success : scheme.primary,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                ready ? "下载完成" : "正在下载更新…",
                style: text.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Button(
                size: const Size(double.infinity, 56.0),
                onPressed: () =>
                    Navigator.of(context).pop(UpdateSheetResult.download),
                child: Text(ready ? "前往安装" : "查看下载进度"),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("关闭"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ 错误

  Widget _errorBody(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final AppSemanticColors semantic = context.semanticColors;
    final UpdateErrorInfo info = describeUpdateError(_service.error);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 错误文案与调试信息可能很长：中间可滚动，底部动作按钮固定可见。
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dragHandle(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.sm,
                    AppSpacing.xs,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48.0,
                        color: semantic.error,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        info.title,
                        style: text.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        info.message,
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (_service.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: SelectableText(
                      "调试信息：${_service.error}",
                      style: text.bodySmall?.copyWith(color: semantic.disabled),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Button(
            size: const Size(double.infinity, 56.0),
            onPressed: () => _handleErrorAction(context, info.action),
            child: Text(info.actionLabel),
          ),
        ),
        if (info.action != UpdateErrorAction.dismiss)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              0.0,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("关闭"),
            ),
          ),
      ],
    );
  }

  Future<void> _handleErrorAction(
    BuildContext context,
    UpdateErrorAction action,
  ) async {
    switch (action) {
      case UpdateErrorAction.retry:
        await _service.check(manual: true);
        return;
      case UpdateErrorAction.openProject:
        await launchUrl(Uri.parse(updateProjectUrl()));
        return;
      case UpdateErrorAction.dismiss:
        if (context.mounted) Navigator.of(context).pop();
        return;
    }
  }

  Widget _dragHandle(BuildContext context) {
    return Center(
      child: Container(
        width: 40.0,
        height: 4.0,
        margin: const EdgeInsets.only(top: AppSpacing.xs),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2.0),
        ),
      ),
    );
  }
}
