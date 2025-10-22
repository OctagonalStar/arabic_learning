import 'package:arabic_learning/global.dart';
import 'package:arabic_learning/statics_var.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
      title: StaticsVar.appName,
      minimumSize: Size(400, 700),
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
  bool disPlayedFirst = false;

  // 判断是否为桌面端的阈值（可根据需要调整）
  static const double _desktopBreakpoint = 600;


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
            scrollDirection: Axis.vertical,
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

  final TextEditingController controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final gob = context.watch<Global>();
    if(gob.firstStart) {
      
      return Scaffold(
        body: PopScope(
          canPop: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                    children: [
                      SelectableText('欢迎使用本软件，请先阅读使用说明。', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 36)),
                      SelectableText("软件开源地址：https://github.com/OctagonalStar/arabic_learning"),
                      SelectableText("由于该软件目前还处在开发阶段，有一些bug是不可避免的。所以在正式使用该软件前你应当阅读并理解以下条款："),
                      SelectableText("1. 该软件仅供学习使用，请勿用于商业用途。"),
                      SelectableText("2. 该软件不会对你的阿拉伯语成绩做出任何担保，若你出现阿拉伯语成绩不理想的情况请先考虑自己的问题 :)"),
                      SelectableText("3. 由于软件在不同系统上运行可能存在兼容性问题，软件出错造成的任何损失（包含精神损伤），软件作者和其他贡献者不会担负任何责任"),
                      SelectableText("4. 你知晓并理解如果你错误地使用软件（如使用错误的数据集）造成的任何后果，乃至二次宇宙大爆炸，都需要你自行承担"),
                      SelectableText("5. 其他在MIT开源协议下的条款"),
                      SelectableText("若你已理解并接受上述条款，请向下翻页，并在底部输入框中填写你的名字，并点击“我没异议”按钮以确认。"),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                      kIsWeb ? SelectableText('检测到当前是在浏览器中运行，请悉知以下内容：\n1. 由于网页端的一些限制，该软件*不一定*能按照预期工作\n2. 软件使用中所有的数据均保存在浏览器缓存中，清空网站缓存可能导致数据永久丢失\n3. 该网页部署于Github Pages，由Github Action自动构建，可能会不定期进行热更新且版本快于发布版。你可以由此更早地体验到新版功能，但也可能遇到新bug。\n4. 由于Github Pages的限制，我*完全不能*保证你是否能正常链接网站\n5. 网站展示效果不代表实际app发布版效果') : SizedBox(),
                      Text('招募软件图标ing\n有想法或者有现有设计可以联系我', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 24)),
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
                      backgroundColor: Colors.teal,
                      shape: ContinuousRectangleBorder(borderRadius: StaticsVar.br)
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
                      backgroundColor: Colors.teal,
                      shape: ContinuousRectangleBorder(borderRadius: StaticsVar.br)
                    ),
                    onPressed: () async {
                      if(controller.text.isNotEmpty){
                        context.read<Global>().acceptAggrement(controller.text);
                      } else {
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
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: kIsWeb ?  [
          ElevatedButton.icon(
            icon: Icon(Icons.add_to_home_screen),
            label: Text('下载APP版本'),
            onPressed: () {
              launchUrl(Uri.parse("https://github.com/OctagonalStar/arabic_learning/releases/latest"));
            }
          )
        ] : [],
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
