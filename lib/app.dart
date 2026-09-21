// 应用外壳：MyApp（初始化 FutureBuilder + 主题 MaterialApp）、
// MyHomePage / _MyHomePageState（桌面侧边导航与移动底部导航的自适应外壳）。
// 引导逻辑（日志/窗口/后台任务/runApp）位于 lib/main.dart。

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/statics.dart' show StaticsVar;
import 'package:arabic_learning/pages/home_page.dart';
import 'package:arabic_learning/pages/leading_page.dart' show PolicyPage;
import 'package:arabic_learning/pages/learning_page.dart' show LearningPage;
import 'package:arabic_learning/pages/setting_page.dart' show SettingPage;
import 'package:arabic_learning/pages/test_page.dart' show TestPage;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/widgets/kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.warning("收到应用层构建请求");
    return FutureBuilder(
        future: context.read<Global>().init(),
        initialData: false,
        builder: (context, asyncSnapshot) {
          if(!(asyncSnapshot.data??false)) {
            return Material(child: Container(width: double.infinity, height: double.infinity, color: Colors.black ,child: Center(child: CircularProgressIndicator())));    
          }
          return Consumer<Global>(
            builder: (context, global, child) => MaterialApp(
              title: StaticsVar.appName,
              themeMode: ThemeMode.system,
              theme: global.themeData,
              home: const MyHomePage()
            )
          );
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

  // 判断是否为桌面端的阈值（可根据需要调整）
  static const double _desktopBreakpoint = 600;


  // 构建桌面端布局（侧边导航）
  Widget _buildDesktopLayout(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 DesktopLayout");
    return Row(
      children: [
        // 侧边导航栏
        NavigationRail(
          minWidth: MediaQuery.of(context).size.width * 0.05,
          selectedIndex: _pageController.hasClients ? _pageController.page!.round() : 0,
          onDestinationSelected: (int index) {
            _onNavigationTapped(index);
          },
          labelType: NavigationRailLabelType.selected,
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
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
          height: MediaQuery.of(context).size.height * 0.1,
          animationDuration: Durations.medium2,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
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
      duration: Durations.medium2,
      curve: StaticsVar.curve,
    );
  }

  @override
  void dispose(){
    _pageController.dispose();
    super.dispose();
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

    if(io.Platform.isAndroid) {
      FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    }

    // 更新日志通知
    if(global.updateLogRequire) {
      context.read<Global>().uiLogger.info("预定更新日志通知");
      global.updateLogRequire = false;
      Future.delayed(Duration(seconds: 1), () async {
        late final String changeLog;
        changeLog = await rootBundle.loadString('CHANGELOG.md');
        if(!context.mounted) return;
        showModalBottomSheet(
          context: context,
          shape: RoundedSuperellipseBorder(side: BorderSide(width: 1.0, color: Theme.of(context).colorScheme.onSurface), borderRadius: StaticsVar.br),
          enableDrag: true,
          isDismissible: false,
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

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary.withAlpha(150),
        title: Text(StaticsVar.appName),
        actions: [
          if(kIsWeb && !AppData().config.regular.hideAppDownloadButton) Button(
            icon: Icon(Icons.add_to_home_screen),
            child: Text('下载APP版本'),
            onPressed: () {
              launchUrl(Uri.parse("https://github.com/OctagonalStar/arabic_learning/releases/latest"));
            }
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 根据屏幕宽度决定使用哪种布局
          if (constraints.maxWidth > _desktopBreakpoint) {
            AppData().isWideScreen = true;
            return _buildDesktopLayout(context);
          } else {
            AppData().isWideScreen = false;
            return _buildMobileLayout(context);
          }
        },
      ),
    );
  }
}
