// 应用外壳：MyApp（初始化 FutureBuilder + 主题 MaterialApp）、
// MyHomePage / _MyHomePageState（桌面侧边导航与移动底部导航的自适应外壳）。
// 引导逻辑（日志/窗口/后台任务/runApp）位于 lib/main.dart。

import 'package:arabic_learning/core/adaptive.dart' show AdaptiveData, AdaptiveScope;
import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/statics.dart' show StaticsVar;
import 'package:arabic_learning/screens/home/home_screen.dart';
import 'package:arabic_learning/screens/policy/leading_screen.dart' show PolicyPage;
import 'package:arabic_learning/screens/learning/learning_screen.dart' show LearningPage;
import 'package:arabic_learning/screens/setting/setting_screen.dart' show SettingPage;
import 'package:arabic_learning/screens/test/test_screen.dart' show TestPage;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/theme/tokens.dart' show AppBreakpoints, AppMotion;
import 'package:arabic_learning/widgets/feedback.dart' show LoadingIndicator;
import 'package:arabic_learning/widgets/kit.dart';
import 'package:arabic_learning/widgets/motion.dart' show CrossFadeSwitcher;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// 记忆化的初始化 Future：只在 initState 中创建一次。
  /// Global.init() 内部会 notifyListeners()，若在 build 中创建，
  /// 每次重建都会生成新 Future 并重复初始化（重复解析/写入配置）。
  late Future<bool> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = context.read<Global>().init();
  }

  /// 重试初始化：Global 失败时已自清缓存，这里拿到的是全新一轮初始化。
  void _retryInit() {
    final Future<bool> next = context.read<Global>().init();
    setState(() {
      _initFuture = next;
    });
  }

  /// 初始化失败页：surface 语义色与加载页一致，避免永久停在加载动画。
  Widget _buildInitError(Global global, Object error) {
    final bool platformDark = WidgetsBinding
            .instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    final Color surface = (platformDark ? global.darkThemeData : global.lightThemeData)
        .colorScheme
        .surface;
    return Directionality(
      key: const ValueKey<String>('app-init-error'),
      textDirection: TextDirection.ltr,
      child: Material(
        color: surface,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "初始化失败",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  error.toString(),
                  maxLines: 6,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _retryInit,
                  child: const Text("重试"),
                ),
                const SizedBox(height: 12),
                const Text(
                  "若反复失败，请检查存储空间或导出备份后重装",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("收到应用层构建请求");
    return FutureBuilder(
        future: _initFuture,
        initialData: false,
        builder: (context, asyncSnapshot) {
          final Global global = context.read<Global>();
          final Widget child;
          if (asyncSnapshot.hasError) {
            child = _buildInitError(global, asyncSnapshot.error!);
          } else if(!(asyncSnapshot.data??false)) {
            // 加载页：使用主题 surface 语义色，不再硬编码纯黑。
            final bool platformDark = WidgetsBinding
                    .instance.platformDispatcher.platformBrightness ==
                Brightness.dark;
            final Color loadingSurface = (platformDark
                    ? global.darkThemeData
                    : global.lightThemeData)
                .colorScheme
                .surface;
            child = Container(
              key: const ValueKey<String>('app-loading'),
              width: double.infinity,
              height: double.infinity,
              color: loadingSurface,
              child: const Center(child: LoadingIndicator()),
            );
          } else {
            child = Consumer<Global>(
              key: const ValueKey<String>('app-content'),
              builder: (context, global, child) => MaterialApp(
                title: StaticsVar.appName,
                theme: global.lightThemeData,
                darkTheme: global.darkThemeData,
                themeMode: global.themeMode,
                // 主题色 / 深浅色切换走统一动效 token，切换过程平滑过渡。
                themeAnimationDuration: AppMotion.medium,
                themeAnimationCurve: AppMotion.emphasizedCurve,
                // 在 MaterialApp 之下、Navigator 之上下发响应式数据：
                // home 与所有 push 出的路由共享同一份 AdaptiveData，
                // 取代原先在 build 期写 AppData().isWideScreen 的副作用。
                // 文字缩放上限夹在 1.5：系统更大字号下固定高度卡片不再被撑爆，
                // 主体可读性优先，长文案交给各页面的滚动与 FittedBox 兜底。
                // AdaptiveScope 在最外层读取原始尺寸，顺序不受影响。
                builder: (context, child) => AdaptiveScope(
                  data: AdaptiveData.fromMediaQuery(context),
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.5,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
                home: const MyHomePage()
              )
            );
          }
          // 加载 → 主界面交叉淡入：两种状态携带不同 key 才会触发切换动画，
          // FutureBuilder 的等待/完成语义保持不变。
          return CrossFadeSwitcher(child: child);
        }
      );
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

/// 导航目的地定义：桌面端 NavigationRail 与移动端 NavigationBar 共用
class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({required this.icon, required this.selectedIcon, required this.label});
}

const List<_NavItem> _navItems = [
  _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: '主页'),
  _NavItem(icon: Icons.book_outlined, selectedIcon: Icons.book, label: '学习'),
  _NavItem(icon: Icons.edit_outlined, selectedIcon: Icons.edit, label: '测试'),
  _NavItem(icon: Icons.settings_applications_outlined, selectedIcon: Icons.settings_applications, label: '设置'),
];


class _MyHomePageState extends State<MyHomePage> {
  final PageController _pageController = PageController(initialPage: 0);
  bool _startupPromptsScheduled = false;
  bool _notificationPermissionAsked = false;


  // 构建桌面端布局（侧边导航）
  Widget _buildDesktopLayout(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 DesktopLayout");
    return Row(
      children: [
        // 侧边导航栏
        NavigationRail(
          // 宽度夹在 72–96：小窗口下不缩破 48dp 触控目标，大屏不再随宽度无限加宽。
          minWidth: clampDouble(MediaQuery.sizeOf(context).width * 0.05, 72.0, 96.0),
          selectedIndex: _pageController.hasClients ? _pageController.page!.round() : 0,
          onDestinationSelected: (int index) {
            _onNavigationTapped(index);
          },
          labelType: NavigationRailLabelType.selected,
          destinations: [
            for (final _NavItem item in _navItems)
              NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: Text(item.label),
              ),
          ],
        ),
        // 垂直分隔线
        const VerticalDivider(thickness: 1, width: 1),
        // 主要内容区域
        Expanded(
          child: PageView(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {});
            },
            children: [
              HomePage(),
              LearningPage(),
              TestPage(),
              SettingPage()
            ],
          ),
        ),
      ],
    );
  }

  // 构建移动端布局（底部导航）
  Widget _buildMobileLayout(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 MobileLayout");
    return Column(
      children: [
        // 主要内容区域
        Expanded(
          child: PageView(
            controller: _pageController,
            scrollDirection: Axis.horizontal,
            onPageChanged: (index) {
              setState(() {});
            },
            children: [
              HomePage(),
              LearningPage(),
              TestPage(),
              SettingPage()
            ],
          ),
        ),
        // 底部导航栏
        NavigationBar(
          selectedIndex: _pageController.hasClients ? _pageController.page!.round() : 0,
          onDestinationSelected: (int index) {
            _onNavigationTapped(index);
          },
          // 高度夹在 48–80：矮横屏下保持 48dp 触控目标（主页磁贴在 420 高度
          // 下要求导航栏不高于 52，故不再取更高下限），大屏不随屏高拉高。
          height: clampDouble(MediaQuery.sizeOf(context).height * 0.1, 48.0, 80.0),
          animationDuration: AppMotion.medium,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            for (final _NavItem item in _navItems)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
          ]
        )
      ],
    );
  }

  // 统一的导航点击处理
  void _onNavigationTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: AppMotion.medium,
      curve: AppMotion.standardCurve,
    );
  }

  @override
  void dispose(){
    _pageController.dispose();
    super.dispose();
  }

  /// 启动提示调度：先展示「更新日志」底部弹窗。
  void _scheduleStartupPrompts(Global global) {
    if (_startupPromptsScheduled) return;
    _startupPromptsScheduled = true;
    final bool needChangeLog = global.updateLogRequire;
    if (needChangeLog) {
      global.updateLogRequire = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // 通知权限：仅在启动提示阶段请求一次，不在 build 中创建插件实例。
      // 当前配置无「推送总开关」，保持原有 Android 平台无条件请求的行为。
      if (!_notificationPermissionAsked && !kIsWeb && io.Platform.isAndroid) {
        _notificationPermissionAsked = true;
        FlutterLocalNotificationsPlugin()
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      if (!mounted || !needChangeLog) return;
      final String changeLog = await rootBundle.loadString('CHANGELOG.md');
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        shape: RoundedSuperellipseBorder(side: BorderSide(width: 1.0, color: Theme.of(context).colorScheme.onSurface), borderRadius: StaticsVar.br),
        enableDrag: true,
        // 允许点外部 / 返回键关闭；弹窗内仍保留「知道了」按钮作为明确出口。
        isDismissible: true,
        isScrollControlled: true,
        builder: (context) {
          context.read<Global>().uiLogger.info("构建更新日志通知");
          return Column(
            children: [
              TextContainer(text: "更新内容 软件版本: ${StaticsVar.appVersion.zfill(6)}"),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: Markdown(data: changeLog)
              ),
              Button(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text("知道了")
              )
            ],
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 MyHomePage");
    final global = context.watch<Global>();
    
    if(AppData().isFirstStart) {
      return PolicyPage(isUpdate: false);
    } else if (AppData().config.lastTermVersion != StaticsVar.termVersion) {
      return PolicyPage(isUpdate: true);
    }

    // 启动提示：自动检查更新（Android）优先，其次顺延更新日志。
    _scheduleStartupPrompts(global);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(StaticsVar.appName),
      ),
      body: SafeArea(top: false, child: LayoutBuilder(
        builder: (context, constraints) {
          // 根据屏幕宽度决定使用哪种布局（断点与 AdaptiveScope.isWide 一致）
          if (constraints.maxWidth > AppBreakpoints.mobile) {
            return _buildDesktopLayout(context);
          } else {
            return _buildMobileLayout(context);
          }
        },
      )),
    );
  }
}
