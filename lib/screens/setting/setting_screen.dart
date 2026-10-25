import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/widgets/kit.dart' show SettingItem, SettingRedirctButton, SettingRow;
import 'package:arabic_learning/widgets/overlays.dart' show showSnackBar;
import 'package:arabic_learning/models/config.dart' show Config, RegularConfig;
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/app_data.dart';

import 'package:arabic_learning/screens/setting/help_page.dart' show HelpPage;
import 'package:arabic_learning/screens/setting/debug_page.dart' show DebugPage;
import 'package:arabic_learning/screens/setting/about_page.dart' show AboutPage;
import 'package:arabic_learning/screens/setting/dict_manage_page.dart' show DictManagePage;
import 'package:arabic_learning/screens/setting/questions_setting_page.dart'
    show QuestionsSettingPage;
import 'package:arabic_learning/screens/setting/synonym_page.dart' show SynonymPage;
import 'package:arabic_learning/screens/learning/fsrs_screens.dart'
    show ForeFSRSSettingPage;

/// 设置页。
///
/// 小程序试用版分支：发音、动态取色、DoH、WebDAV 同步、软件更新、APP 下载
/// 全部移除，项目地址只作为文本显示（小程序内无法打开外部链接）。
class SettingPage extends StatefulWidget {
  const SettingPage({super.key});
  @override
  State<SettingPage> createState() => _SettingPage();
}

class _SettingPage extends State<SettingPage> {
  @override
  Widget build(BuildContext context) {
    AppData appData = AppData();

    return Consumer<Global>(
      builder: (context, value, child) {
        return ListView(
          children: [
            SettingItem(
              title: "帮助",
              children: [
                SettingRedirctButton(title: "常见问题", icon: Icons.help, target: HelpPage())
              ],
            ),
            SettingItem(
              title: "常规设置",
              padding: EdgeInsets.all(8.0),
              children: [
                SettingRow(
                  leading: "主题颜色",
                  icon: Icons.color_lens,
                  end: DropdownButton<int>(
                    value: appData.config.regular.theme,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('樱粉')),
                      DropdownMenuItem(value: 1, child: Text('海蓝')),
                      DropdownMenuItem(value: 2, child: Text('草绿')),
                      DropdownMenuItem(value: 3, child: Text('金黄')),
                      DropdownMenuItem(value: 4, child: Text('柑橘')),
                      DropdownMenuItem(value: 5, child: Text('雅紫')),
                      DropdownMenuItem(value: 6, child: Text('木棕')),
                      DropdownMenuItem(value: 7, child: Text('冷灰')),
                      DropdownMenuItem(value: 8, child: Text('茶香')),
                      DropdownMenuItem(value: 9, child: Text('烟蓝')),
                      DropdownMenuItem(value: 10, child: Text('星青')),
                    ],
                    onChanged: (value) async {
                      context.read<Global>().uiLogger.info("更新主题颜色: $value");
                      context.read<Global>().patchConfig(
                        (Config config) => config.copyWith(
                          regular: config.regular.copyWith(
                            theme: value,
                          ),
                        ),
                      );
                    },
                  )
                ),
                SettingRow(
                  leading: "深色模式",
                  icon: Icons.brightness_4,
                  note: "跟随系统 / 强制浅色 / 强制深色",
                  end: DropdownButton<int>(
                    value: appData.config.regular.themeMode,
                    items: const [
                      DropdownMenuItem(
                        value: RegularConfig.themeModeSystem,
                        child: Text('跟随系统'),
                      ),
                      DropdownMenuItem(
                        value: RegularConfig.themeModeLight,
                        child: Text('浅色'),
                      ),
                      DropdownMenuItem(
                        value: RegularConfig.themeModeDark,
                        child: Text('深色'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      context.read<Global>().uiLogger.info("更新深色模式: $value");
                      context.read<Global>().patchConfig(
                        (Config config) => config.copyWith(
                          regular: config.regular.copyWith(
                            themeMode: value,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SettingRow(
                  leading: "字体设置", 
                  icon: Icons.font_download,
                  note: "若你的系统上阿语/中文字体异常，可在此更换备用",
                  end: DropdownButton<int>(
                    value: appData.config.regular.font,
                    items: [
                      DropdownMenuItem(value: 0, child: Text('默认字体')),
                      DropdownMenuItem(value: 1, child: Text('仅阿语使用备用字体')),
                      DropdownMenuItem(value: 2, child: Text('中阿均使用备用字体')),
                    ],
                    onChanged: (value) {
                      context.read<Global>().uiLogger.info("更新字体设置: $value");
                      if (value == 2 && kIsWeb) {
                        showSnackBar(context, "网页版加载中文字体需要较长时间，请先耐心等待");
                      }
                      Provider.of<Global>(
                        context,
                        listen: false,
                      ).patchConfig(
                        (Config config) => config.copyWith(
                          regular: config.regular.copyWith(
                            font: value,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            SettingItem(
              title: "学习设置",
              children: [
                SettingRedirctButton(title: "题型配置",icon: Icons.quiz, target: QuestionsSettingPage()),
                SettingRedirctButton(title: "同义词管理", icon: Icons.sync_alt, target: SynonymPage()),
                SettingRedirctButton(title: "词库管理", icon: Icons.library_books, target: DictManagePage()),
                SettingRedirctButton(title: "复习配置", icon: Icons.bookmark, target: ForeFSRSSettingPage(forceChoosing: true)),
              ],
            ),
            SettingItem(
              title: "关于",
              children: [
                SettingRedirctButton(title: "调试信息", icon: Icons.bug_report, target: DebugPage()),
                SettingRow(
                  leading: "项目地址",
                  icon: Icons.link,
                  note: "github.com/OctagonalStar/arabic_learning",
                  end: const SizedBox(),
                ),
                SettingRedirctButton(title: "关于本软件", icon: Icons.adb, target: AboutPage())
              ],
            ),
          ],
        );
      },
    );
  }
}
