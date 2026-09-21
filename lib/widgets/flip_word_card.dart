// 翻卡式单词卡片组件。
//
// 正面（列表内与展开动画前半段）：阿语发音按钮 + 中文 / 解释 / 归属课程，
// 底部一行小字提示“点击查看更多信息”。
// 点击后卡片从原位置移动到屏幕中心、放大到适宜大小，并绕 Y 轴翻转到背面，
// 同时全屏遮罩由透明逐渐加深；背面复用 [WordCardDetailBody] 展示全部详情。
// 再次点击卡片、点击遮罩或系统返回均触发反向动画回到正面。
//
// 过渡由单个有限 [AnimationController] 驱动（时长取 [AppMotion.mediumLong]），
// 可被 `pumpAndSettle` 收敛；`MediaQuery.disableAnimations`（减弱动态效果）
// 为 true 时跳过过渡直接显示 / 关闭。

import 'dart:math' as math;

import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/theme/tokens.dart' show AppMotion, AppRadius, AppSpacing;
import 'package:arabic_learning/widgets/kit.dart' show WordCardArabicButton, WordCardDetailBody, WordCardInfoRow;
import 'package:flutter/material.dart';

/// 正面卡片底部提示文案。
const String _expandHint = '点击查看更多信息';

/// 背面卡片底部提示文案。
const String _collapseHint = '点击卡片或空白处关闭';

/// 翻卡式单词卡片。
///
/// 正面仅显示中文、解释与归属课程；点击后卡片移动到屏幕中心、放大并翻转到
/// 背面，展示该词的全部详细信息。点击卡片 / 遮罩 / 系统返回可反向关闭。
///
/// [word] :单词数据
///
/// [width] :正面卡片宽度，默认屏幕宽度 * 0.9
///
/// [height] :正面卡片高度，默认屏幕高度 * 0.5
///
/// [enableFlip] :是否允许点击展开翻卡；false 时渲染为静态卡片（无提示行）
class FlipWordCard extends StatefulWidget {
  final WordItem word;
  final double? width;
  final double? height;
  final bool enableFlip;

  const FlipWordCard({
    super.key,
    required this.word,
    this.width,
    this.height,
    this.enableFlip = true,
  });

  @override
  State<FlipWordCard> createState() => _FlipWordCardState();
}

class _FlipWordCardState extends State<FlipWordCard> {
  /// 正面卡片的定位锚点：展开时据此取得源矩形。
  final GlobalKey _cardKey = GlobalKey();

  /// 展开层打开期间隐藏原位卡片，避免与展开层卡片重影。
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double useWidth = widget.width ?? mediaQuery.size.width * 0.9;
    final double useHeight = widget.height ?? mediaQuery.size.height * 0.5;

    final Widget card = SizedBox(
      key: _cardKey,
      width: useWidth,
      height: useHeight,
      child: _FlipCardSurface(
        word: widget.word,
        width: useWidth,
        height: useHeight,
        showBack: false,
        hintText: widget.enableFlip ? _expandHint : null,
      ),
    );

    if (!widget.enableFlip) return card;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context),
      // 展开期间原位卡片不再参与语义树，避免读屏重复播报。
      child: ExcludeSemantics(
        excluding: _expanded,
        child: Opacity(
          opacity: _expanded ? 0.0 : 1.0,
          child: card,
        ),
      ),
    );
  }

  /// 记录源矩形后打开展开层；展开层自身驱动移动 / 放大 / 翻转 / 遮罩动画。
  Future<void> _open(BuildContext context) async {
    if (_expanded) return;
    final RenderBox? box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final Rect sourceRect = box.localToGlobal(Offset.zero) & box.size;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    setState(() {
      _expanded = true;
    });
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      // 遮罩由展开层自绘（需随动画加深），路由自带 barrier 保持透明。
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (BuildContext dialogContext, Animation<double> animation, Animation<double> secondaryAnimation) {
        return _FlipWordCardOverlay(
          word: widget.word,
          sourceRect: sourceRect,
          reduceMotion: reduceMotion,
          onCloseCompleted: _onOverlayClosed,
        );
      },
    );
    if (!mounted || !_expanded) return;
    setState(() {
      _expanded = false;
    });
  }

  /// 反向动画结束后由展开层回调，先恢复原位卡片再 pop，避免闪帧。
  void _onOverlayClosed() {
    if (!mounted || !_expanded) return;
    setState(() {
      _expanded = false;
    });
  }
}

/// 卡片本体：顶部阿语发音按钮 + 0.6 高度的信息区 + 0.1 高度的提示行。
///
/// [showBack] 为 true 时信息区渲染 [WordCardDetailBody]（全部详情），
/// 否则渲染正面摘要（中文 / 解释 / 归属课程）。
class _FlipCardSurface extends StatelessWidget {
  final WordItem word;
  final double width;
  final double height;
  final bool showBack;
  final String? hintText;

  const _FlipCardSurface({
    required this.word,
    required this.width,
    required this.height,
    required this.showBack,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: AppRadius.cardBorder,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Column(
          children: [
            WordCardArabicButton(word: word, width: width, height: height * 0.3),
            SizedBox(
              width: width,
              height: height * 0.6,
              child: showBack
                  ? WordCardDetailBody(word: word, width: width, height: height)
                  : _FlipCardFrontBody(word: word, width: width),
            ),
            SizedBox(
              width: width,
              height: height * 0.1,
              child: hintText == null
                  ? null
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            hintText!,
                            style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 正面摘要：仅中文 / 解释 / 归属课程。
///
/// 所有行按 flex 分配高度且内容经 FittedBox 缩放，任意卡片尺寸下都不溢出。
class _FlipCardFrontBody extends StatelessWidget {
  final WordItem word;
  final double width;

  const _FlipCardFrontBody({required this.word, required this.width});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color labelOdd = scheme.primaryContainer;
    final Color labelEven = scheme.secondaryContainer;
    final double labelWidth = width * 0.2;
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: WordCardInfoRow(
            label: "中文", value: word.chinese, labelWidth: labelWidth,
            labelColor: labelOdd, labelStyle: textTheme.bodyLarge, valueStyle: textTheme.headlineSmall),
        ),
        const Divider(height: 0),
        Expanded(
          flex: 5,
          child: WordCardInfoRow(
            label: "解释", value: word.explanation, labelWidth: labelWidth,
            labelColor: labelEven, labelStyle: textTheme.titleMedium, valueStyle: textTheme.bodyLarge, expandValue: true),
        ),
        const Divider(height: 0),
        Expanded(
          flex: 3,
          child: WordCardInfoRow(
            label: "归属课程", value: word.className, labelWidth: labelWidth,
            labelColor: labelOdd, labelStyle: textTheme.bodyLarge, valueStyle: textTheme.titleMedium,
            labelRadius: BorderRadius.only(bottomLeft: Radius.circular(AppRadius.card))),
        ),
      ],
    );
  }
}

/// 展开层：单个有限动画同时驱动“移动 + 放大 + 翻转 + 遮罩加深”。
class _FlipWordCardOverlay extends StatefulWidget {
  final WordItem word;
  final Rect sourceRect;
  final bool reduceMotion;
  final VoidCallback onCloseCompleted;

  const _FlipWordCardOverlay({
    required this.word,
    required this.sourceRect,
    required this.reduceMotion,
    required this.onCloseCompleted,
  });

  @override
  State<_FlipWordCardOverlay> createState() => _FlipWordCardOverlayState();
}

class _FlipWordCardOverlayState extends State<_FlipWordCardOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.mediumLong);
    if (widget.reduceMotion) {
      // 减弱动态效果：直接呈现终态。
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 反向播放（或直接 pop），随后通知父级恢复原位卡片。
  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    if (!widget.reduceMotion) {
      await _controller.reverse();
    }
    if (!mounted) return;
    widget.onCloseCompleted();
    Navigator.of(context).pop();
  }

  void _onCardTap() {
    if (_closing) return;
    // 展开动画进行中忽略点击，避免动画未完成就反向播放。
    if (!widget.reduceMotion && _controller.isAnimating) return;
    _close();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _close();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double raw = _controller.value;
          final Size screen = MediaQuery.sizeOf(context);
          final Rect targetRect = _targetRect(screen);
          // 移动 / 放大：强调曲线；翻转：标准曲线且略晚于移动开始。
          final double moveT = widget.reduceMotion ? 1.0 : AppMotion.emphasizedCurve.transform(raw);
          final double flipT = widget.reduceMotion
              ? 1.0
              : AppMotion.standardCurve.transform((((raw - 0.12) / 0.88).clamp(0.0, 1.0)));
          final double angle = math.pi * flipT;
          final bool showBack = angle >= math.pi / 2;
          final Rect currentRect = Rect.lerp(widget.sourceRect, targetRect, moveT)!;
          return Stack(
            children: [
              // 遮罩随动画逐渐加深；即使全透明也占满全屏以捕获点击。
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.6 * raw)),
                ),
              ),
              Positioned.fromRect(
                rect: currentRect,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onCardTap,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0015)
                      ..rotateY(angle),
                    child: showBack
                      // 背面再绕 Y 轴旋转 π，抵消外层旋转造成的镜像。
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: _FlipCardSurface(
                            word: widget.word,
                            width: currentRect.width,
                            height: currentRect.height,
                            showBack: true,
                            hintText: _collapseHint,
                          ),
                        )
                      : _FlipCardSurface(
                          word: widget.word,
                          width: currentRect.width,
                          height: currentRect.height,
                          showBack: false,
                          hintText: _expandHint,
                        ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 目标矩形：屏幕居中，宽高分别适配可用空间并保留边距。
  Rect _targetRect(Size screen) {
    final double targetWidth = math.min(screen.width * 0.92, screen.width - AppSpacing.sm);
    final double targetHeight = math.min(screen.height * 0.9, screen.height - AppSpacing.lg);
    final Offset center = Offset(screen.width / 2, screen.height / 2);
    return Rect.fromCenter(center: center, width: targetWidth, height: targetHeight);
  }
}
