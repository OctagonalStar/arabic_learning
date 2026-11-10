import 'package:arabic_learning/core/statics.dart';
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';

/// 向导里的大号类型选择卡片：标题 + 说明 + 右向箭头。
///
/// [width] / [height] 都给时锁定为固定尺寸；副标题在空间不足时等比缩小，
/// 而不是撑破按钮。
class TypeChooseCard extends StatelessWidget {
  final Widget mainTitle;
  final Widget? subTitle;
  final double? width;
  final double? height;
  final VoidCallback onTap;

  const TypeChooseCard({
    super.key,
    required this.mainTitle,
    required this.onTap,
    this.subTitle,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        fixedSize: width != null && height != null ? Size(width!, height!) : null,
        shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
      ),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          mainTitle,
          if (subTitle != null)
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: width != null
                      ? clampDouble(width! - 48.0, 120.0, double.infinity)
                      : null,
                  child: subTitle!,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Icon(Icons.arrow_forward_ios),
          ),
        ],
      ),
    );
  }
}
