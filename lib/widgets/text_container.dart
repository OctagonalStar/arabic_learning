// 纯展示容器（原 widgets/kit.dart 拆分）。
// 承载带背景色的文本框容器 [TextContainer]。
// 由 widgets/kit.dart 统一 export，调用方仍从 kit.dart 导入。

import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:flutter/material.dart';

// Base Widgets 较为基础的Widget

/// 文本框容器
/// 
/// 显示一个带文本的容器，有背景色
/// 
/// [text] :显示的文本 必须
/// 
/// [style] :自定义文本的属性TextStyle 默认为null
/// 
/// [selectable] :控制文本能否被选中（复制等操作需要） 默认为false
/// 
/// [size] :文本容器的大小 默认为null（自适应）
/// 
/// [textAlign] :控制文本排布方向 默认为null（自适应）
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
                      this.animated = false,
                      this.selectable = false,
                      this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    // 默认 18 号正文：由主题 `textTheme.titleMedium`（已按历史尺寸微调）提供。
    final TextStyle actualStyle =
        style ?? Theme.of(context).textTheme.titleMedium!;
    return Container(
      width: size?.width,
      height: size?.height,
      margin: EdgeInsets.all(16.0),
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: StaticsVar.br,
      ),
      child: (animated)
        ? TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: text.length.toDouble()), 
          duration: AppMotion.long2,
          curve: AppMotion.standardCurve,
          builder: (context, value, child) {
            if(value == text.length.toDouble()) return child!;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text.substring(0, value.floor()), style: actualStyle, textAlign: textAlign, maxLines: 1),
                Text(text[value.floor()], style: actualStyle.copyWith(color: actualStyle.color?.withAlpha((255 * value.remainder(1)).round()) ?? Theme.of(context).textTheme.bodyLarge!.color!.withAlpha((255 * value.remainder(1)).round())), maxLines: 1)
              ],
            );
          },
          child: (selectable) 
            ? SelectableText(text,style: actualStyle, textAlign: textAlign, maxLines: 1)
            : Text(text,style: actualStyle, textAlign: textAlign, maxLines: 1)
        ) : (selectable) 
            ? SelectableText(text,style: actualStyle, textAlign: textAlign)
            : Text(text,style: actualStyle, textAlign: textAlign)
    );
  }
}
