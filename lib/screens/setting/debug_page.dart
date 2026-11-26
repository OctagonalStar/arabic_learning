import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/widgets/kit.dart' show TextContainer;
import 'package:arabic_learning/core/adaptive.dart' show AdaptiveScope;
import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/models/config.dart' show Config;
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion, AppSpacing;

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<StatefulWidget> createState() => _DebugPage();
}

class _DebugPage extends State<DebugPage> {
  ScrollController controller = ScrollController();

  @override
  void dispose(){
    controller.dispose();
    super.dispose();
  }

  /// 按日志级别着色，便于在捕获列表里快速定位异常。
  Color? _logColor(BuildContext context, String logLine) {
    if (logLine.contains("[SERVER]")) return context.semanticColors.error;
    if (logLine.contains("WARNING")) return context.semanticColors.warning;
    if (logLine.contains("FINE")) return Theme.of(context).colorScheme.onSurfaceVariant;
    return null;
  }

  @override
  Widget build(BuildContext context) {

    List<String> debugInfo = [];

    // 基础信息
    debugInfo.add("Date Time: ${DateTime.now().toIso8601String()}");
    debugInfo.add("Version Code: ${StaticsVar.appVersion}");
    debugInfo.add("Host Name: ${io.Platform.localHostname}");
    debugInfo.add("Device System: ${io.Platform.operatingSystem}");
    debugInfo.add("Device System Version: ${io.Platform.operatingSystemVersion}");
    debugInfo.add("Environment: ${io.Platform.environment}");
    debugInfo.add("WideScreen: ${AdaptiveScope.of(context).isWide}");

    // 存储类型
    debugInfo.add("Storage Type: ${AppData().storage.type ? "SharedPreferences" : "IndexDB"}");

    return Scaffold(
      appBar: AppBar(
        title: Text("调试设置"),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.arrow_upward),
        onPressed: (){
          controller.animateTo(0, duration: AppMotion.medium, curve: AppMotion.standardCurve);
        }
      ),
      body: SafeArea(top: false, child: ListView(
        controller: controller,
        children: [
          TextContainer(text: "该页面为软件调试/测试和bug反馈使用，非必要请勿开启日志捕获，以免性能损耗", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            child: SwitchListTile(
              secondary: const Icon(Icons.logo_dev),
              title: const Text("启用软件内日志捕获"),
              value: AppData().config.debug.enableInternalLog,
              onChanged: (value) {
                context.read<Global>().patchConfig(
                  (Config config) => config.copyWith(
                    debug: config.debug.copyWith(enableInternalLog: value),
                  ),
                );
                setState(() {});
              },
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            child: ListTile(
              leading: const Icon(Icons.logo_dev_outlined),
              title: const Text("日志等级"),
              trailing: DropdownMenu<int>(
                initialSelection: AppData().config.debug.internalLevel,
                requestFocusOnTap: false,
                width: 168,
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 0, label: "Level.ALL"),
                  DropdownMenuEntry(value: 1, label: "Level.FINEST"),
                  DropdownMenuEntry(value: 2, label: "Level.FINER"),
                  DropdownMenuEntry(value: 3, label: "Level.FINE"),
                  DropdownMenuEntry(value: 4, label: "Level.INFO"),
                  DropdownMenuEntry(value: 5, label: "Level.WARNING"),
                  DropdownMenuEntry(value: 6, label: "Level.SEVERE"),
                  DropdownMenuEntry(value: 7, label: "Level.SHOUT"),
                  DropdownMenuEntry(value: 8, label: "Level.OFF"),
                ],
                onSelected: (value) {
                  context.read<Global>().patchConfig(
                    (Config config) => config.copyWith(
                      debug: config.debug.copyWith(internalLevel: value),
                    ),
                  );
                },
              ),
            ),
          ),
           ExpansionTile(
            title: Text("日志捕获内容"),
            children: [
              Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (int index = 0;
                        index < AppData().internalLogCapture.length;
                        index++) ...<Widget>[
                      if (index > 0) const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: SizedBox(
                          width: double.infinity,
                          child: SelectableText(
                            AppData().internalLogCapture[
                                AppData().internalLogCapture.length - index - 1],
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _logColor(
                                context,
                                AppData().internalLogCapture[
                                    AppData().internalLogCapture.length - index - 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            ],
          ),
          ExpansionTile(
            title: Text("调试信息"),
            children: [
              Row(
                children: [
                  Expanded(child: TextContainer(text: "调试信息中可能包含部分敏感信息，若要发给他人请先自行检查", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error))),
                  IconButton(
                    tooltip: "复制",
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: debugInfo.join("\n")));
                    },
                    icon: const Icon(Icons.copy),
                  )
                ],
              ),
              TextContainer(text: debugInfo.join("\n")),
            ],
          )
        ],
      )),
    );
  }
}