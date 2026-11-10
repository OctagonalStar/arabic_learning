// 纯展示容器（原 widgets/kit.dart 拆分）。
// 承载带背景色的文本框容器 [TextContainer]。
// 由 widgets/kit.dart 统一 export，调用方仍从 kit.dart 导入。

import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:flutter/material.dart';

/// 带背景色的文本容器；[selectable] 为真时可选中复制。
///
/// [animated] 开启后背景从 0.85 长到完整尺寸，整段文本淡入并上移约 8px，
/// 系统开启「减弱动态效果」时直接显示。
class TextContainer extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool selectable;
  final Size? size;
  final TextAlign? textAlign;
  final bool animated;
  const TextContainer({super.key, 
                      required this.text, 
                      this.style,
                      this.size,
                      this.animated = true,
                      this.selectable = false,
                      this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    // 默认 18 号正文：由主题 `textTheme.titleMedium`（已按历史尺寸微调）提供。
    final TextStyle actualStyle =
        style ?? Theme.of(context).textTheme.titleMedium!;
    final Widget content = (selectable) 
        ? SelectableText(text, style: actualStyle, textAlign: textAlign)
        : Text(text, style: actualStyle, textAlign: textAlign);
    // 入场只改透明度与位移，不影响尺寸/换行，因此多行文本也能整体淡入。
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final BoxDecoration decoration = BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: StaticsVar.br,
    );
    return Container(
      width: size?.width,
      height: size?.height,
      margin: EdgeInsets.all(16.0),
      child: (animated && !reduceMotion)
        ? TweenAnimationBuilder<double>(
          // 文本变化（如复习答题后追加用时）要重新入场；Tween 终点不变时
          // 原 State 不会重播，故按文本换 key。
          key: ValueKey<String>(text),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: AppMotion.mediumLong,
          curve: AppMotion.standardCurve,
          // 背景与文本共用这一个进度：背景只缩放装饰层（不参与布局，
          // 内容撑开尺寸），文本淡入并上移 8px。
          builder: (context, value, child) => Stack(
            fit: StackFit.passthrough,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Transform.scale(
                  scale: 0.85 + 0.15 * value,
                  child: DecoratedBox(decoration: decoration),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0.0, (1.0 - value) * 8.0),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
          child: content,
        ) : Container(
          padding: EdgeInsets.all(8.0),
          decoration: decoration,
          child: content,
        )
    );
  }
}
