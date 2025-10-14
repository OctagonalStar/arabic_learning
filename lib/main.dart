import 'package:arabic_learning/global.dart';
import 'package:arabic_learning/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/home_page.dart';
import 'package:arabic_learning/learning_page.dart';
import 'package:arabic_learning/setting_page.dart';
import 'package:arabic_learning/test_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (StaticsVar.isDesktop) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = WindowOptions(
      size: Size(1300, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  final global = Global();
  await global.init();
  runApp(
    ChangeNotifierProvider.value(
      value: global, // 创建状态实例
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<Global>(
      builder: (context, value, child) {
        return MaterialApp(
          title: StaticsVar.appName,
          themeMode: ThemeMode.system,
          theme: value.themeData,
          home: const MyHomePage(title: StaticsVar.appName),
        );
      },
    );
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}


class _MyHomePageState extends State<MyHomePage> {
  late List<Widget> _pageList;
  int currentIndex = 0;
  bool onSlip = false;
  final PageController _pageController = PageController();
  static const Duration _duration = Duration(milliseconds: 500);


  // 判断是否为桌面端的阈值（可根据需要调整）
  static const double _desktopBreakpoint = 600;

  @override
  void initState() {
    super.initState();
    _pageList = [
      HomePage(toPage: (index) {
        _pageController.animateToPage(
          index,
          duration: _duration,
          curve: StaticsVar.curve,
        );
        setState(() {
          currentIndex = index;
        });
      }),
      LearningPage(),
      TestPage(),
      SettingPage(),
    ];
  }

  // 构建桌面端布局（侧边导航）
  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // 侧边导航栏
        NavigationRail(
          selectedIndex: currentIndex,
          onDestinationSelected: (int index) {
            _onNavigationTapped(index);
          },
          labelType: NavigationRailLabelType.selected,
          backgroundColor: Theme.of(context).colorScheme.onPrimary,
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: Text('主页'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.book_outlined),
              selectedIcon: Icon(Icons.book),
              label: Text('学习'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.edit_outlined),
              selectedIcon: Icon(Icons.edit),
              label: Text('测试'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: Text('设置'),
            ),
          ],
        ),
        // 垂直分隔线
        const VerticalDivider(thickness: 1, width: 1),
        // 主要内容区域
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (onSlip) return;
              setState(() {
                currentIndex = index;
              });
            },
            physics: const NeverScrollableScrollPhysics(), // 禁用滑动
            children: _pageList,
          ),
        ),
      ],
    );
  }

  // 构建移动端布局（底部导航）
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        // 主要内容区域
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (onSlip) return;
              setState(() {
                currentIndex = index;
              });
            },
            children: _pageList,
          ),
        ),
        // 底部导航栏
        ConvexAppBar(
          key: ValueKey<int>(currentIndex),
          curve: StaticsVar.curve,
          style: TabStyle.flip,
          backgroundColor: Theme.of(context).colorScheme.primary,
          items: const [
            TabItem(icon: Icons.home_outlined, title: '主页', activeIcon: Icons.home_filled),
            TabItem(icon: Icons.book_outlined, title: '学习', activeIcon: Icons.book),
            TabItem(icon: Icons.edit_outlined, title: '测试', activeIcon: Icons.edit),
            TabItem(icon: Icons.settings_outlined, title: '设置', activeIcon: Icons.settings),
          ],
          initialActiveIndex: currentIndex,
          onTap: _onNavigationTapped,
        ),
      ],
    );
  }

  // 统一的导航点击处理
  void _onNavigationTapped(int index) {
    onSlip = true;
    _pageController.animateToPage(
      index,
      duration: _duration,
      curve: StaticsVar.curve,
    );
    Future.delayed(_duration, () {
      onSlip = false;
    });
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 根据屏幕宽度决定使用哪种布局
          if (constraints.maxWidth > _desktopBreakpoint) {
            Provider.of<Global>(context, listen: false).isWideScreen = true;
            return _buildDesktopLayout(context);
          } else {
            Provider.of<Global>(context, listen: false).isWideScreen = false;
            return _buildMobileLayout(context);
          }
        },
      ),
    );
  }
}

class IconPage extends StatelessWidget {
  final IconData icon;
  final Color color;
  const IconPage({super.key, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 100.0,
            color: color,
          ),
        ],
      ),
    );
  }
}