// 设置类控件（原 widgets/kit.dart 拆分）。
// 承载设置分区 [SettingItem]、单行设置项 [SettingRow] 与跳转按钮
// [SettingRedirectButton]。
// 由 widgets/kit.dart 统一 export，调用方仍从 kit.dart 导入。
//
// 布局对齐 M3：分区是一张 Card，跳转项是 ListTile，普通设置行保留 Flex
// 布局以兼容 `end` 里的 Slider / Expanded 等伸缩控件。

import 'package:arabic_learning/theme/tokens.dart' show AppSpacing;
import 'package:arabic_learning/core/navigation.dart';
import 'package:material_ui/material_ui.dart';

/// 设置分区：标题 + 一张 Card，子项之间用 Divider 分隔。
class SettingItem extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry? padding;
  final List<Widget> children;

  const SettingItem({
    super.key,
    required this.title,
    required this.children,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(),
                if (padding == null)
                  children[i]
                else
                  Padding(padding: padding!, child: children[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 单行设置项：图标 + 标题/说明 + 右侧控件。
///
/// [end] 可以是 Switch、DropdownButton、按钮，也可以是 `Expanded` /
/// `Slider`；因此这里保留 Flex 布局，不使用 ListTile 的固定 trailing 槽位。
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
    final ThemeData theme = Theme.of(context);
    final Widget header = Row(
      children: [
        Icon(icon, size: 24.0, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(leading, style: theme.textTheme.bodyLarge),
              if (note != null)
                Text(
                  note!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    // 大字号下把右侧控件放到下一行：固定尾部控件在 2 倍字号时会把
    // Row 撑爆，而 ListTile 的 trailing 同样不具备收缩能力。
    final bool stacked = MediaQuery.textScalerOf(context).scale(1.0) >= 1.5;
    final Widget trailing = end is Flexible ? (end as Flexible).child : end;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                if (trailing is! SizedBox)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 24.0 + AppSpacing.sm,
                      top: AppSpacing.xs,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: trailing,
                    ),
                  ),
              ],
            )
          : Row(
              children: [
                Expanded(child: header),
                const SizedBox(width: AppSpacing.sm),
                end,
              ],
            ),
    );
  }
}

/// 跳转设置项：ListTile + 尾部 chevron。
class SettingRedirectButton extends StatelessWidget {
  const SettingRedirectButton({
    super.key,
    required this.title,
    required this.target,
    this.icon = Icons.settings,
  });

  final String title;
  final IconData icon;
  final Widget target;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: scheme.primary),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      onTap: () => pushPage(context, target),
    );
  }
}
