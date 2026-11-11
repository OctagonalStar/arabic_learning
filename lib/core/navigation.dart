import 'package:flutter/material.dart';

/// 页面入栈的唯一入口：路由类型与转场由主题统一提供，调用点只关心打开哪个页面。
Future<T?> pushPage<T>(BuildContext context, Widget page) =>
    pushPageOn<T>(Navigator.of(context), page);

/// 同上，用于回调里已提前捕获 [NavigatorState]（此时原 context 可能已卸载）。
Future<T?> pushPageOn<T>(NavigatorState navigator, Widget page) =>
    navigator.push<T>(MaterialPageRoute<T>(builder: (_) => page));

/// 入栈并替换当前页（用于「配置页 → 执行页」这类不回头的流程）。
Future<T?> replacePage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).pushReplacement<T, dynamic>(
      MaterialPageRoute<T>(builder: (_) => page),
    );
