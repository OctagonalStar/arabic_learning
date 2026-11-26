// 响应式基础层：`AdaptiveData`（只读布局数据）与 `AdaptiveScope`（InheritedWidget）。
//
// 取代原先由 lib/app.dart 在 build 期写入 `AppData().isWideScreen` 的副作用：
// 布局数据现在由 MaterialApp 下方的 `AdaptiveScope` 统一下发，叶子组件通过
// `AdaptiveScope.of(context)` 读取；缺失 scope（独立 widget / 测试）时回退到
// `MediaQuery` 现算，保证不崩溃。
//
// 同时提供定向策略纯函数 `shouldLockPortrait`，供 main.dart 与单测复用。

import 'package:arabic_learning/theme/tokens.dart' show AppBreakpoints;
import 'package:flutter/widgets.dart';

/// 断点相关的只读布局数据（逻辑像素）。
@immutable
class AdaptiveData {
  const AdaptiveData({required this.width, required this.height});

  /// 按当前 `MediaQuery` 现算（无 `AdaptiveScope` 时的回退路径）。
  factory AdaptiveData.fromMediaQuery(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    return AdaptiveData(width: size.width, height: size.height);
  }

  /// 逻辑宽度。
  final double width;

  /// 逻辑高度。
  final double height;

  /// 是否宽屏（宽度 > [AppBreakpoints.mobile]），语义等同原 `isWideScreen`。
  bool get isWide => width > AppBreakpoints.mobile;

  /// 是否处于平板宽度区间（600 <= width < 1024）。
  bool get isTablet => AppBreakpoints.isTablet(width);

  /// 是否横屏（宽 > 高）。
  bool get isLandscape => width > height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdaptiveData && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// 将 [AdaptiveData] 下发给整棵子树的 `InheritedWidget`。
class AdaptiveScope extends InheritedWidget {
  const AdaptiveScope({super.key, required this.data, required super.child});

  /// 当前布局数据。
  final AdaptiveData data;

  /// 读取最近的 [AdaptiveData]；没有 scope 时按当前 `MediaQuery` 现算。
  static AdaptiveData of(BuildContext context) =>
      maybeOf(context) ?? AdaptiveData.fromMediaQuery(context);

  /// 读取最近的 [AdaptiveData]；没有 scope 时返回 null。
  static AdaptiveData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdaptiveScope>()?.data;

  @override
  bool updateShouldNotify(AdaptiveScope oldWidget) => data != oldWidget.data;
}

/// 手机（窄屏设备）是否应锁定竖屏：最短边 < [AppBreakpoints.mobile]。
///
/// 平板 / 桌面 / Web 传 false，允许全部方向。
bool shouldLockPortrait(double shortestSide) =>
    shortestSide < AppBreakpoints.mobile;

/// 顶层 Tab 页的自适应容器：按可用约束计算内容尺寸，并在高度不足时提供滚动兜底。
///
/// [builder] 会收到父级实际约束（`constraints.maxHeight` 为 Tab 可视高度，
/// 已扣除 AppBar / 导航栏），应优先据此推导卡片与间距尺寸；返回的 [Column]
/// 需使用 [MainAxisSize.min] 以便在滚动容器中测量。
///
/// 桌面端导航已改为 IndexedStack（不再整页纵向翻页），因此这里始终允许纵向
/// 滚动，矮窗口下内容可按需滚动，不再与转页手势冲突。
class AdaptiveTabBody extends StatelessWidget {
  const AdaptiveTabBody({super.key, required this.builder});

  /// 依据实际约束构建页面内容。
  final Widget Function(BuildContext context, BoxConstraints constraints) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: builder(context, constraints),
          ),
        );
      },
    );
  }
}
