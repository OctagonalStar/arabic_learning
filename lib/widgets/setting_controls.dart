// 设置类控件（原 widgets/kit.dart 拆分）。
// 承载设置分区 [SettingItem]、单行设置项 [SettingRow] 与跳转按钮
// [SettingRedirctButton]。
// 由 widgets/kit.dart 统一 export，调用方仍从 kit.dart 导入。

import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppRadius;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 有关设置的Widget
class SettingRedirctButton extends StatelessWidget {
  const SettingRedirctButton({
    super.key,
    required this.title,
    required this.target,
    this.icon = Icons.settings
  });

  final String title;
  final IconData icon;
  final Widget target;

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
        // 与 SettingItem 卡片形成同一容器的“更亮一层”，整块设置项观感统一；
        // 前置图标用主题主色、尾部箭头用次级前景，稳定传达“可跳转”。
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurface,
        shape: BeveledRectangleBorder(),
      ),
      onPressed: () {
        context.read<Global>().uiLogger.info(
          "跳转: SettingPage => ${target.toString()}",
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => target,
          ),
        );
      },
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          Expanded(child: Text(title)),
          Icon(Icons.arrow_forward_ios, size: 16.0, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.leading,
    required this.end,
    this.icon = Icons.settings,
    this.note,
  });

  final String leading;
  final String? note;
  final IconData icon;
  final Widget end;

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Row(
      children: [
        SizedBox(width: mediaQuery.size.width * 0.02),
        Icon(icon, size: 24.0),
        SizedBox(width: mediaQuery.size.width * 0.01),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(leading),
              if(note != null) Text(
                note!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        end,
        SizedBox(width: mediaQuery.size.width * 0.02)
      ],
    );
  }
}

class SettingItem extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry? padding;
  final List<Widget> children;
  const SettingItem({super.key, required this.title, required this.children, this.padding});

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 SettingItem: $title");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    List<Container> decoratedContainers = List.generate(children.length, (int index) {
      return Container(
        width: mediaQuery.size.width * 0.90,
        padding: padding,
        margin: EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          // 统一用 surfaceContainerLow 作为分区卡片底色；分区内各设置项
          // （SettingRow / SettingRedirctButton）再用更高一层的容器色区分。
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.vertical(top: Radius.circular(index == 0 ? AppRadius.card : 5.0), bottom: Radius.circular(index == children.length-1 ? AppRadius.card : 5.0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: children[index],
      );
    });

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分区标题：主题主色 + 加粗，避免再叠一层灰色容器造成色彩杂乱。
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Center(
          child: Column(
            children: decoratedContainers,
          ),
        ),
      ]
    );
  }
}
