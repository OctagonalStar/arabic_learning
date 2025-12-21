import 'package:arabic_learning/funcs/noification.dart';
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logging/logging.dart';

import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/global.dart' show Global;
import 'package:arabic_learning/vars/license_storage.dart' show LicenseVars;
import 'package:arabic_learning/vars/statics_var.dart' show StaticsVar;
import 'package:arabic_learning/pages/home_page.dart';
import 'package:arabic_learning/pages/learning_page.dart'show LearningPage;
import 'package:arabic_learning/pages/setting_page.dart'show SettingPage;
import 'package:arabic_learning/pages/test_page.dart' show TestPage;
import 'package:workmanager/workmanager.dart' show Workmanager, Constraints;

void main() async {
  Logger.root.level = kDebugMode ? Level.ALL : Level.OFF;
  if (kDebugMode){
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.time}-[${record.loggerName}][${record.level.name}]: ${record.message}');
    });
  }
  
  final Logger logger = Logger("enter");
  logger.info("日志加载成功");
  WidgetsFlutterBinding.ensureInitialized();

  if(io.Platform.isAndroid) {
    Workmanager().initialize(callbackDispatcher);
    Workmanager().registerPeriodicTask(
      "dynamic-notification-task",
      "fetchAndShowNotification",
      frequency: Duration(minutes: 30),
      constraints: Constraints(),
    );
  }
  

  if (StaticsVar.isDesktop) {
    await windowManager.ensureInitialized();
    logger.info("检测到当前为桌面端，正在加载窗口配置");
    WindowOptions windowOptions = WindowOptions(
      size: Size(1300, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: StaticsVar.appName,
      minimumSize: Size(400, 700),
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    logger.info("窗口配置加载完成");
  }
  // final global = Global();
  // await global.init();
  runApp(
    ChangeNotifierProvider(
      create: (context) => Global()..init(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("收到应用层构建请求");
    return context.watch<Global>().inited? 
      MaterialApp(
        title: StaticsVar.appName,
        themeMode: ThemeMode.system,
        theme: context.read<Global>().themeData,
        home: context.read<Global>().globalConfig.egg.stella
          ? Scaffold(
            body: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: MemoryImage(context.read<Global>().stella!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const MyHomePage(title: StaticsVar.appName),
              ],
            ),)
          : const MyHomePage(title: StaticsVar.appName),
      )
      : Material(child: Container(width: double.infinity, height: double.infinity, color: Colors.black ,child: Center(child: CircularProgressIndicator())));    
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
  int currentIndex = 1;
  bool onSlip = false;
  final PageController _pageController = PageController(initialPage: 1);
  static const Duration _duration = Duration(milliseconds: 500);
  bool disPlayedFirst = false;

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
          selectedIndex: currentIndex,
          onDestinationSelected: (int index) {
            _onNavigationTapped(index);
          },
          labelType: NavigationRailLabelType.selected,
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.book_outlined),
              selectedIcon: Icon(Icons.book),
              label: Text('学习'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: Text('主页'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.edit_outlined),
              selectedIcon: Icon(Icons.edit),
              label: Text('测试'),
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
              if (onSlip) return;
              setState(() {
                currentIndex = index;
              });
            },
            // physics: const NeverScrollableScrollPhysics(), // 禁用滑动
            children: _pageList,
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
              if (onSlip) return;
              setState(() {
                currentIndex = index;
              });
            },
            children: _pageList,
          ),
        ),
        // 底部导航栏
        NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (int index) {
            _onNavigationTapped(index);
          },
          height: MediaQuery.of(context).size.height * 0.1,
          animationDuration: Duration(milliseconds: 500),
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.book_outlined),
              selectedIcon: Icon(Icons.book),
              label: '学习',
            ),
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '主页',
            ),
            NavigationDestination(
              icon: Icon(Icons.edit_outlined),
              selectedIcon: Icon(Icons.edit),
              label: '测试',
            ),
          ]
        )
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

  final TextEditingController controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 MyHomePage");
    final gob = context.watch<Global>();
    if(gob.firstStart) {
      context.read<Global>().uiLogger.info("构建首次启动页面");
      return Scaffold(
        body: PopScope(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                    children: [
                      SelectableText('欢迎使用本软件，请先阅读使用说明。', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 36)),
                      SelectableText("软件开源地址：https://github.com/OctagonalStar/arabic_learning"),
                      SelectableText(LicenseVars.noMyDutyAnnouce),
                      SelectableText("若你已理解并接受上述条款，请向下翻页，并在底部输入框中填写你的名字，并点击“我没异议”按钮以确认。"),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                      if(kIsWeb) SelectableText(LicenseVars.theWebSpecialAnnouce),
                      Text('招募软件图标ing\n有想法或者有现有设计可以联系我', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 18)),
                      SizedBox(height: MediaQuery.of(context).size.height),
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: "请输入你的名字",
                          prefixIcon: Icon(Icons.edit),
                        ),
                      )
                    ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
                    ),
                    onPressed: () async {
                      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                      SystemNavigator.pop();
                      return;
                    },
                    child: const Text('我有异议', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 24)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: StaticsVar.br)
                    ),
                    onPressed: () async {
                      if(controller.text.isNotEmpty){
                        context.read<Global>().uiLogger.info("用户同意协议，签署名：${controller.text}");
                        context.read<Global>().acceptAggrement(controller.text);
                      } else {
                        context.read<Global>().uiLogger.info("用户未填写名称");
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('使用该软件前你应当仔细阅读并理解条款'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                    },
                    child: const Text('我没异议', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 24)),
                  )
                ],
              ),
            ],
          ),
        ),
      );
    }
    if(io.Platform.isAndroid) {
      FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    }
    // 更新日志通知
    if(gob.updateLogRequire) {
      context.read<Global>().uiLogger.info("预定更新日志通知");
      gob.updateLogRequire = false;
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
            return Material(
              child: Column(
                children: [
                  TextContainer(text: "更新内容 软件版本: ${StaticsVar.appVersion.zfill(6)}"),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: Markdown(data: changeLog)
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      fixedSize: Size(double.infinity, MediaQuery.of(context).size.height * 0.07)
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    }, 
                    child: Text("知道了")
                  )
                ],
              )
            );
          },
        );
      });
    }
    _pageList = [
      LearningPage(),
      HomePage(),
      TestPage()
    ];
    return Scaffold(
      backgroundColor: context.read<Global>().globalConfig.egg.stella ? Colors.transparent : null,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary.withAlpha(150),
        title: Text(widget.title),
        actions: [
          if(kIsWeb && !gob.globalConfig.regular.hideAppDownloadButton) ElevatedButton.icon(
            icon: Icon(Icons.add_to_home_screen),
            label: Text('下载APP版本'),
            onPressed: () {
              launchUrl(Uri.parse("https://github.com/OctagonalStar/arabic_learning/releases/latest"));
            }
          ),
          IconButton(
            onPressed: () {
              context.read<Global>().uiLogger.info("跳转: MyHomePage => SettingPage");
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => SettingPage()));
            }, 
            icon: Icon(Icons.settings)
          )
        ],
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
