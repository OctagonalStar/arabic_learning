// 翻卡式单词卡片组件（项目中唯一的单词卡片实现）。
//
// 卡片由顶部“阿语 + 发音”按钮与主体组成，主体按使用场景切换布局：
// - 正面摘要（默认，词汇总览 / 查找网格单元同样复用）：中文 / 解释 /
//   归属课程三行彩色标签，按 flex 分配高度并由 FittedBox 等比缩小兜底；
// - 反面详情（翻卡后 / `startOnBack`）：中文与解释组成的释义区、词形信息
//   芯片网格、类别标签与归属课程页脚；在给定尺寸内一次性展示全部非空
//   字段，不滚动；字号等按可用宽高响应式放大，超大内容由等比缩小兜底
//   （详见 `_FlipCardDetailBody` 与 `_detailScale`）。
//
// `enableFlip` 为 true 时点击卡片展开：卡片从原位置移动到屏幕中心、放大并
// 绕 Y 轴翻转到反面，同时全屏遮罩由透明逐渐加深；再次点击卡片、点击遮罩或
// 系统返回均触发反向动画回到正面。`masked` 用于 FSRS 自评 / 学习场景遮挡
// 释义，翻卡即揭示全部详情。
//
// 过渡由单个有限 [AnimationController] 驱动（时长取 [AppMotion.mediumLong]），
// 可被 `pumpAndSettle` 收敛；`MediaQuery.disableAnimations`（减弱动态效果）
// 为 true 时跳过过渡直接显示 / 关闭。

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/services/tts.dart' show playTextToSpeech;
import 'package:arabic_learning/theme/tokens.dart' show AppMotion, AppRadius, AppSpacing;
import 'package:arabic_learning/theme/typography.dart' show arabicStyle, withoutColor;
import 'package:arabic_learning/widgets/kit.dart' show Button, CategoryChips;
import 'package:arabic_learning/widgets/shared.dart' show ButtonLabel;
import 'package:flutter/material.dart';

/// 正面卡片底部提示文案（未遮挡释义）。
const String _expandHint = '点击查看更多信息';

/// 正面被遮挡释义时的底部提示文案。
const String _maskedHint = '点击查看释义';

/// 背面卡片底部提示文案。
const String _collapseHint = '点击卡片或空白处关闭';

/// 翻卡式单词卡片。
///
/// 正面显示中文、解释与归属课程；点击后卡片移动到屏幕中心、放大并翻转到
/// 背面，以分组详情一次性展示该词的全部信息（无滚动）。点击卡片 / 遮罩 /
/// 系统返回可反向关闭。
///
/// [word] :单词数据
///
/// [width] :卡片宽度，默认屏幕宽度 * 0.9
///
/// [height] :卡片高度，默认屏幕高度 * 0.5
///
/// [enableFlip] :是否允许点击展开翻卡；false 时渲染为静态卡片（无提示行）
///
/// [masked] :遮住释义（FSRS 自评 / 学习卡）；`enableFlip` 为 true 时点击
/// 卡片翻面即揭示全部详情，为 false 时由调用方切换本参数完成揭示
///
/// [startOnBack] :直接以反面（全部详情）呈现，用于“详解”弹层等静态场景；
/// 此时视为静态卡片，不再触发翻卡
class FlipWordCard extends StatefulWidget {
  final WordItem word;
  final double? width;
  final double? height;
  final bool enableFlip;
  final bool masked;
  final bool startOnBack;

  const FlipWordCard({
    super.key,
    required this.word,
    this.width,
    this.height,
    this.enableFlip = true,
    this.masked = false,
    this.startOnBack = false,
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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 显式宽高始终优先；未显式指定时，高度优先填满父级给出的有界高度
        // （如 `Expanded` 中的题目区），仅在高度无界时回退屏幕高度的一半。
        final double useWidth = widget.width ?? mediaQuery.size.width * 0.9;
        final double useHeight = widget.height ??
            (constraints.hasBoundedHeight
                ? constraints.maxHeight
                : mediaQuery.size.height * 0.5);

        // startOnBack 已直接呈现全部详情，属静态展示，不参与翻卡交互。
        if (widget.startOnBack) {
          return SizedBox(
            key: _cardKey,
            width: useWidth,
            height: useHeight,
            child: _FlipCardSurface(
              word: widget.word,
              width: useWidth,
              height: useHeight,
              showBack: true,
              masked: widget.masked,
            ),
          );
        }

        final Widget card = SizedBox(
          key: _cardKey,
          width: useWidth,
          height: useHeight,
          child: _FlipCardSurface(
            word: widget.word,
            width: useWidth,
            height: useHeight,
            showBack: false,
            // 展开期间原位卡片整体透明，不再绘制遮挡层，避免读屏 / 测试树里
            // 残留第二份“释义已隐藏”。
            masked: widget.masked && !_expanded,
            hintText: widget.enableFlip
                ? (widget.masked ? _maskedHint : _expandHint)
                : null,
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
      },
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
          masked: widget.masked,
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

/// 卡片本体：顶部阿语发音按钮 + 信息区 + 可选提示行。
///
/// 信息区渲染 [WordCardInfoRow] 组成的正面摘要或 [_FlipCardDetailBody] 详情；
/// [masked] 时在信息区叠加毛玻璃遮挡层。
class _FlipCardSurface extends StatelessWidget {
  final WordItem word;
  final double width;
  final double height;
  final bool showBack;
  final bool masked;
  final String? hintText;

  const _FlipCardSurface({
    required this.word,
    required this.width,
    required this.height,
    required this.showBack,
    this.masked = false,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    // 有提示行时信息区占 0.6，静态卡没有提示行则占 0.7，避免底部留白。
    final double bodyShare = hintText == null ? 0.7 : 0.6;
    final Widget body = showBack
        ? _FlipCardDetailBody(word: word)
        : _FlipCardFrontBody(word: word, width: width);
    return ClipRRect(
      borderRadius: AppRadius.cardBorder,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Column(
          children: [
            WordCardArabicButton(word: word, width: width, height: height * 0.3),
            SizedBox(
              width: width,
              height: height * bodyShare,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  body,
                  _FlipCardMaskOverlay(masked: masked),
                ],
              ),
            ),
            if (hintText != null)
              SizedBox(
                width: width,
                height: height * 0.1,
                child: Center(
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

/// 反面（详情）主体：无滚动容器，在给定尺寸内一次性呈现全部非空字段。
///
/// 排版不沿用正面的“标签列 + 值列”信息行，而是分组卡片式 UX：
/// - 释义区：中文最醒目（headlineSmall 加粗），解释为可读段落；
/// - 词形信息：自适应 [Wrap] 的紧凑“标签 / 值”芯片网格（词根、词性、复数、
///   阴阳性、现在式、动名词，逐项判空）；
/// - 类别：标签 chips；页脚：归属课程。
///
/// 所有元素的字号 / 图标 / 内边距 / 间距先按下述缩放因子 [scale] 显式放大，
/// 再按固有尺寸布局（宽度锁定为可用宽度，保证文本正常换行），最后由
/// [FittedBox] 整体等比缩小以适配可用高度：宁可缩小也不滚动 / 溢出。
///
/// [scale] 由信息区可用宽高推导（见 [_detailScale]），小尺寸下为 1.0 保持
/// 现状，大屏 / 展开后的大卡片上明显放大；系统 `textScaler` 会在放大后的
/// 字号上继续叠加，不覆盖用户的无障碍文字缩放。
class _FlipCardDetailBody extends StatelessWidget {
  final WordItem word;

  const _FlipCardDetailBody({required this.word});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double scale = _detailScale(constraints);
        final double gapXs = AppSpacing.xs * scale;
        final double gapXxs = AppSpacing.xxs * scale;
        final List<Widget> morphChips = <Widget>[];
        if (word.root.isNotEmpty) {
          morphChips.add(_FlipCardMorphChip(label: "词根", value: word.root, isArabic: true, scale: scale));
        }
        if (word.pos.isNotEmpty) {
          morphChips.add(_FlipCardMorphChip(label: "词性", value: _wordPosLabel(word.pos), scale: scale));
        }
        if (word.plural.isNotEmpty) {
          morphChips.add(_FlipCardMorphChip(label: "复数", value: word.plural, isArabic: true, scale: scale));
        }
        if (word.gender != null) {
          morphChips.add(_FlipCardMorphChip(label: "阴阳性", value: word.gender! ? "阳性" : "阴性", scale: scale));
        }
        if (word.present.isNotEmpty) {
          morphChips.add(_FlipCardMorphChip(label: "现在式", value: word.present, isArabic: true, scale: scale));
        }
        if (word.masdar.isNotEmpty) {
          morphChips.add(_FlipCardMorphChip(label: "动名词", value: word.masdar, isArabic: true, scale: scale));
        }

        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm * scale,
                gapXs,
                AppSpacing.sm * scale,
                AppSpacing.sm * scale,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 释义区：中文最醒目，解释为可读段落 ──
                  if (word.chinese.isNotEmpty)
                    Text(
                      word.chinese,
                      style: _scaledTextStyle(
                        textTheme.headlineSmall,
                        scale,
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (word.explanation.isNotEmpty) ...[
                    if (word.chinese.isNotEmpty) SizedBox(height: gapXxs),
                    Text(
                      word.explanation,
                      style: _scaledTextStyle(textTheme.bodyMedium, scale, color: scheme.onSurfaceVariant),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // ── 词形信息区：自适应换行的芯片网格 ──
                  if (morphChips.isNotEmpty) ...[
                    SizedBox(height: gapXs),
                    _FlipCardSectionLabel(icon: Icons.spellcheck, label: "词形信息", scale: scale),
                    SizedBox(height: gapXs),
                    Wrap(
                      spacing: gapXs,
                      runSpacing: gapXs,
                      children: morphChips,
                    ),
                  ],
                  // ── 类别标签 ──
                  if (word.categories.isNotEmpty) ...[
                    SizedBox(height: gapXs),
                    _FlipCardSectionLabel(icon: Icons.sell_outlined, label: "类别", scale: scale),
                    SizedBox(height: gapXs),
                    CategoryChips(categories: word.categories, dense: true, scale: scale),
                  ],
                  // ── 页脚：归属课程 ──
                  if (word.className.isNotEmpty) ...[
                    SizedBox(height: AppSpacing.sm * scale),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: gapXs,
                        vertical: gapXxs,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.control * scale),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.menu_book_outlined, size: 14.0 * scale, color: scheme.onPrimaryContainer),
                          SizedBox(width: gapXxs),
                          // 标签在极窄卡片上可收缩（省略号兜底），避免固定宽度
                          // 与右侧课程名抢占空间造成 Row 溢出。
                          Flexible(
                            child: Text(
                              "归属课程",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _scaledTextStyle(textTheme.labelSmall, scale, color: scheme.onPrimaryContainer),
                            ),
                          ),
                          SizedBox(width: gapXs),
                          Expanded(
                            flex: 2,
                            child: Text(
                              word.className,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: _scaledTextStyle(textTheme.labelMedium, scale, color: scheme.onPrimaryContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 反面详情缩放的参考宽度：内容正常换行的基准卡片宽度。
const double _detailScaleBaseWidth = 360.0;

/// 反面详情缩放的参考高度：满字段内容在 `scale = 1` 时的典型固有高度。
///
/// 仅当信息区高度超过该值时才会真正放大，避免在高度受限的小卡上放大后被
/// [FittedBox] 原样缩回（无收益）。
const double _detailScaleBaseHeight = 260.0;

/// 反面详情缩放因子的下限 / 上限。
const double _detailScaleMin = 1.0;
const double _detailScaleMax = 2.0;

/// 由反面信息区的可用宽高推导内容缩放因子。
///
/// `s = clamp(min(maxWidth / 360, maxHeight / 260), 1.0, 2.0)`：
/// 宽高任一方向不足都会限制放大，小尺寸保持 1.0；仅在宽高都有界时生效，
/// 无界约束回退 1.0。放大后的内容由外层 [FittedBox]（scaleDown）兜底，
/// 保证不溢出、不滚动。
double _detailScale(BoxConstraints constraints) {
  if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
    return _detailScaleMin;
  }
  final double raw = math.min(
    constraints.maxWidth / _detailScaleBaseWidth,
    constraints.maxHeight / _detailScaleBaseHeight,
  );
  return raw.clamp(_detailScaleMin, _detailScaleMax).toDouble();
}

/// 显式按 [scale] 放大 [base] 语义角色的字号，并可覆盖颜色 / 字重。
///
/// 不替换 `MediaQuery.textScaler`：系统无障碍文字缩放会在放大后的字号上
/// 继续叠加生效；[base] 未声明字号时回退 14.0。
TextStyle _scaledTextStyle(
  TextStyle? base,
  double scale, {
  Color? color,
  FontWeight? fontWeight,
}) {
  final TextStyle style = base ?? const TextStyle();
  return style.copyWith(
    fontSize: (style.fontSize ?? 14.0) * scale,
    color: color ?? style.color,
    fontWeight: fontWeight ?? style.fontWeight,
  );
}

/// 详情分组标题：主题色小图标 + 小标签，随 [scale] 放大。
class _FlipCardSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final double scale;

  const _FlipCardSectionLabel({required this.icon, required this.label, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.0 * scale, color: scheme.primary),
        SizedBox(width: AppSpacing.xxs * scale),
        Text(
          label,
          style: _scaledTextStyle(
            textTheme.labelSmall,
            scale,
            color: scheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// 词形信息（词根 / 词性 / 复数 / 阴阳性 / 现在式 / 动名词）相对详情正文的
/// 字号放大系数：这些字段是学习者最需要看清的信息，统一放大 50%。
const double _morphTextBoost = 1.5;

/// 词形信息芯片：上标签 / 下值的小型信息块；值过长时以省略号兜底。
///
/// 字号 / 内边距 / 圆角 / 边框随 [scale] 放大，系统 `textScaler` 仍会叠加。
/// 其中标签与值额外乘以 [_morphTextBoost]（+50%），使词根 / 复数 / 现在式 /
/// 动名词等词形信息比说明性文字更醒目。
class _FlipCardMorphChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isArabic;
  final double scale;

  const _FlipCardMorphChip({
    required this.label,
    required this.value,
    this.isArabic = false,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double textScale = scale * _morphTextBoost;
    final TextStyle valueStyle = _scaledTextStyle(textTheme.labelLarge, textScale, color: scheme.onSurface);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs * scale, vertical: AppSpacing.xxs * textScale),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.control * scale),
        border: Border.all(color: scheme.outlineVariant, width: scale),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _scaledTextStyle(textTheme.labelSmall, textScale, color: scheme.onSurfaceVariant),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isArabic ? arabicStyle(context, base: valueStyle) : valueStyle,
          ),
        ],
      ),
    );
  }
}

/// 释义遮挡层：毛玻璃 + 锁图标，由 [masked] 参数驱动、无本地状态。
///
/// 自身不拦截点击，翻卡展开仍由外层卡片手势处理；`masked` 变化时 blur 与
/// 文案随 [AppMotion.extraLong1] 淡入 / 淡出。
class _FlipCardMaskOverlay extends StatelessWidget {
  final bool masked;

  const _FlipCardMaskOverlay({required this.masked});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: masked ? 1.0 : 0.0, end: masked ? 1.0 : 0.0),
      duration: AppMotion.extraLong1,
      curve: AppMotion.standardCurve,
      builder: (BuildContext context, double value, Widget? child) {
        if (value <= 0.001) return const SizedBox.shrink();
        return IgnorePointer(
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.card)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14.0 * value, sigmaY: 14.0 * value),
                  child: ColoredBox(color: scheme.surface.withValues(alpha: 0.5 * value)),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 20.0,
                        color: scheme.onSurfaceVariant.withValues(alpha: value),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        "释义已隐藏",
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: value),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 卡片内的双栏信息行：左侧标签容器 + 右侧内容，供正面摘要使用。
///
/// [labelStyle] / [valueStyle] 为语义文本角色；省略时分别回退
/// `bodyLarge` / `titleMedium`。
class WordCardInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final double labelWidth;
  final Color labelColor;
  final double? height;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool isArabicValue;
  final bool expandValue;
  final BorderRadius? labelRadius;

  const WordCardInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.labelWidth,
    required this.labelColor,
    this.height,
    this.labelStyle,
    this.valueStyle,
    this.isArabicValue = false,
    this.expandValue = false,
    this.labelRadius,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle resolvedValueStyle = valueStyle ?? textTheme.titleMedium!;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: labelWidth,
            decoration: BoxDecoration(
              color: labelColor,
              borderRadius: labelRadius,
            ),
            alignment: Alignment.center,
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(label, style: labelStyle ?? textTheme.bodyLarge),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ClipRect(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: expandValue
                    ? Text(
                        value,
                        style: isArabicValue
                            ? arabicStyle(context, base: resolvedValueStyle)
                            : resolvedValueStyle,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: isArabicValue
                              ? arabicStyle(context, base: resolvedValueStyle)
                              : resolvedValueStyle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单词卡片顶部的阿语发音按钮：点击朗读 [word] 的 `arabic`。
///
/// 卡片正面与反面共用，保证阿语展示风格一致。
class WordCardArabicButton extends StatelessWidget {
  final WordItem word;
  final double width;
  final double height;

  const WordCardArabicButton({
    super.key,
    required this.word,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    // 用 SizedBox 收紧到卡片给定的槽位：M3 按钮默认最小高度（40 / 48）
    // 大于小卡片 0.3 倍高度时，否则会撑破卡片布局。
    return SizedBox(
      width: width,
      height: height,
      child: Button(
        size: Size(width, height),
        icon: const Icon(Icons.volume_up, size: 24.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.vertical(top: Radius.circular(AppRadius.card))),
        onPressed: (){
          playTextToSpeech(word.arabic);
        },
        child: ButtonLabel(child: Text(word.arabic, style: arabicStyle(context, base: withoutColor(Theme.of(context).textTheme.displayLarge!)))),
      ),
    );
  }
}

/// 词性的中文展示（未知值原样显示）
String _wordPosLabel(String pos) {
  switch(pos) {
    case "Nominals": return "名词";
    case "Verbs": return "动词";
    case "Phrases and Clauses": return "短语与从句";
    case "Particles": return "虚词";
    case "Adverbial Expressions": return "状语表达";
    default: return pos;
  }
}

/// 展开层：单个有限动画同时驱动“移动 + 放大 + 翻转 + 遮罩加深”。
class _FlipWordCardOverlay extends StatefulWidget {
  final WordItem word;
  final Rect sourceRect;
  final bool reduceMotion;
  final bool masked;
  final VoidCallback onCloseCompleted;

  const _FlipWordCardOverlay({
    required this.word,
    required this.sourceRect,
    required this.reduceMotion,
    required this.masked,
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
                          masked: widget.masked,
                          hintText: widget.masked ? _maskedHint : _expandHint,
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
