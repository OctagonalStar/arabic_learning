// 列表标题 → 详情页 AppBar 标题的共享 Hero。
//
// 阅读题、课文背诵、听抄训练的列表项都复用它；飞行中强制单行缩放，
// 避免 Overlay 丢失源侧 FittedBox 后换行并被飞行框裁切。

import 'package:arabic_learning/core/extensions.dart';
import 'package:material_ui/material_ui.dart';

class HeroTitle extends StatelessWidget {
  final Object tag;
  final String text;
  final TextStyle? style;

  /// 飞行中使用的样式；为空时取目标页 AppBar 的标题样式。
  final TextStyle? flightStyle;

  /// 特性开关：false 时完全不注册 Hero，列表/详情照常显示。
  final bool heroEnabled;

  /// 特性开关：false 时交给 Flutter 默认 Hero shuttle。
  final bool flightShuttleEnabled;

  /// 列表侧用 FittedBox 缩放，详情侧保持原始字号。
  final bool scaleDown;

  final int? maxLines;
  final bool softWrap;
  final TextAlign? textAlign;

  const HeroTitle({
    super.key,
    required this.tag,
    required this.text,
    this.style,
    this.flightStyle,
    this.heroEnabled = true,
    this.flightShuttleEnabled = true,
    this.scaleDown = false,
    this.maxLines,
    this.softWrap = true,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final Widget title = Text(
      text,
      style: style,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: maxLines == 1 ? TextOverflow.ellipsis : null,
      textAlign: textAlign,
      textDirection: text.textDirection,
    );
    final Widget child = scaleDown
        ? FittedBox(fit: BoxFit.scaleDown, child: title)
        : title;
    if (!heroEnabled) return child;
    return Hero(
      tag: tag,
      flightShuttleBuilder: flightShuttleEnabled
          ? (
              BuildContext flightContext,
              Animation<double> animation,
              HeroFlightDirection direction,
              BuildContext fromHeroContext,
              BuildContext toHeroContext,
            ) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textDirection: text.textDirection,
                  style:
                      flightStyle ??
                      Theme.of(flightContext).appBarTheme.titleTextStyle,
                ),
              );
            }
          : null,
      child: child,
    );
  }
}
