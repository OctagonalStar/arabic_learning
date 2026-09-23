import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:arabic_learning/widgets/kit.dart' show Button, SettingItem, SettingRedirctButton, SettingRow;
import 'package:arabic_learning/widgets/overlays.dart' show alart, showSnackBar;
import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/models/config.dart' show RegularConfig;
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/screens/setting/help_page.dart'
    show HelpPage;
import 'package:arabic_learning/screens/setting/debug_page.dart'
    show DebugPage;
import 'package:arabic_learning/screens/setting/about_page.dart'
    show AboutPage;
import 'package:arabic_learning/screens/setting/dict_manage_page.dart'
    show DictManagePage;
import 'package:arabic_learning/screens/setting/model_download_page.dart'
    show ModelDownload;
import 'package:arabic_learning/screens/setting/questions_setting_page.dart'
    show QuestionsSettingPage;
import 'package:arabic_learning/screens/setting/sync_page.dart'
    show DataSyncPage;
import 'package:arabic_learning/screens/setting/synonym_page.dart'
    show SynonymPage;
import 'package:arabic_learning/screens/learning/fsrs_screens.dart'
    show ForeFSRSSettingPage;

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});
  @override
  State<SettingPage> createState() => _SettingPage();
}

class _SettingPage extends State<SettingPage> {
  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 SettingPage");
    MediaQueryData mediaQuery = MediaQuery.of(context);
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
                  note: appData.config.regular.dynamicColor
                      ? "动态取色开启时作为回退色"
                      : null,
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
                      AppData().config = AppData().config.copyWith(
                        regular: AppData().config.regular.copyWith(
                          theme: value,
                        ),
                      );
                      context.read<Global>().updateSetting();
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
                      AppData().config = AppData().config.copyWith(
                        regular: AppData().config.regular.copyWith(
                          themeMode: value,
                        ),
                      );
                      context.read<Global>().updateSetting();
                    },
                  ),
                ),
                SettingRow(
                  leading: "动态取色",
                  icon: Icons.palette,
                  note: kIsWeb
                      ? "网页版不支持动态取色，将使用上方主题颜色"
                      : "使用系统壁纸/主题配色（Material You），不支持时回退到主题颜色",
                  end: Switch(
                    value: appData.config.regular.dynamicColor,
                    onChanged: kIsWeb
                        ? null
                        : (value) {
                            context.read<Global>().uiLogger.info(
                              "更新动态取色设置: $value",
                            );
                            AppData().config = AppData().config.copyWith(
                              regular: AppData().config.regular.copyWith(
                                dynamicColor: value,
                              ),
                            );
                            context.read<Global>().updateSetting();
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
                      AppData().config = AppData().config.copyWith(
                        regular: AppData().config.regular.copyWith(
                          font: value,
                        ),
                      );
                      Provider.of<Global>(
                        context,
                        listen: false,
                      ).updateSetting();
                    },
                  ),
                ),
                if (kIsWeb)
                  SettingRow(
                    leading: "隐藏网页版右上角APP下载按钮", 
                    icon: Icons.hide_source, 
                    end: Switch(
                      value: AppData().config.regular.hideAppDownloadButton,
                      onChanged: (value) {
                        context.read<Global>().uiLogger.info(
                          "更新网页端APP下载按钮隐藏设置: $value",
                        );
                        AppData().config = AppData().config.copyWith(
                          regular: AppData().config.regular.copyWith(
                            hideAppDownloadButton: value,
                          ),
                        );
                        context.read<Global>().updateSetting();
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
                SettingRedirctButton(title: "数据备份及同步", icon: Icons.sync, target: DataSyncPage()),
                SettingRedirctButton(title: "复习配置", icon: Icons.bookmark, target: ForeFSRSSettingPage(forceChoosing: true)),
              ],
            ),
            SettingItem(
              title: "音频设置",
              children: [
                Column(
                  children: [
                    SettingRow(
                      leading: "选择文本转语音接口",
                      icon: Icons.api,
                      note: "默认使用系统自带的文本转语音接口，但有些厂商可能没有阿拉伯语支持\n若使用\"神经网络合成语音\"你必须使用APP端并下载模型。",
                      end: SizedBox()
                    ),
                    DropdownButton(
                      value: AppData().config.audio.audioSource,
                      onChanged: (value) {
                        context.read<Global>().uiLogger.info("更新音频接口: $value");
                        if (value == 1) {
                          alart(
                            context,
                            "警告: \n来自\"TextReadTTS.com\"的音频不支持发音符号，且只能合成40字以内的文本。\n开启此功能请知悉。",
                          );
                        }
                        AppData().config = AppData().config.copyWith(
                          audio: AppData().config.audio.copyWith(
                            audioSource: value,
                          ),
                        );
                        context.read<Global>().updateSetting();
                      },
                      items: [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(
                            "系统文本转语音",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text(
                            "请求TextReadTTS.com的语音",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          enabled: !kIsWeb && AppData().modelTTSDownloaded ? true : false,
                          child: Text(
                            "神经网络合成语音",
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: !kIsWeb && AppData().modelTTSDownloaded ? null : context.semanticColors.disabled,
                            ),
                          ),
                        ),
                      ],
                      isExpanded: true,
                    ),
                    SizedBox(width: mediaQuery.size.width * 0.02),
                  ],
                ),
                SettingRow(
                  leading: "设置播放速度", 
                  icon: Icons.speed,
                  note: "默认为1.0，即正常播放速度。",
                  end: Slider(
                    value: AppData().config.audio.playRate,
                    min: 0.5,
                    max: 1.5,
                    divisions: 10,
                    label: "${AppData().config.audio.playRate}",
                    onChanged: (value) {
                      setState(() {
                        AppData().config = AppData().config.copyWith(
                          audio: AppData().config.audio.copyWith(
                            playRate: value,
                          ),
                        );
                      });
                    },
                    onChangeEnd: (value) {
                      context.read<Global>().uiLogger.info(
                        "更新音频速度设置: $value",
                      );
                      context.read<Global>().updateSetting();
                    },
                  )
                ),
                SettingRow(
                  leading: "自动播放发音", 
                  icon: Icons.play_arrow, 
                  note: "开启后将会在<学习>模块中，每进入阿译中选择题时阅读当前单词发音。", 
                  end: Switch(
                    value: appData.config.audio.autoPlay,
                    onChanged: (value) {
                      context.read<Global>().uiLogger.info(
                        "更新自动发音设置: $value",
                      );
                      AppData().config = AppData().config.copyWith(
                        audio: AppData().config.audio.copyWith(
                          autoPlay: value
                        ),
                      );
                      context.read<Global>().updateSetting();
                    },
                  )
                ),
                if(!kIsWeb) SettingRedirctButton(title: "下载神经网络文本转语音模型", icon: Icons.model_training, target: ModelDownload())
              ],
            ),
            SettingItem(
              title: "关于",
              children: [
                SettingRedirctButton(title: "调试信息", icon: Icons.bug_report, target: DebugPage()),
                Button(
                  size: Size.fromHeight(mediaQuery.size.height * 0.08),
                  shape: BeveledRectangleBorder(),
                  onPressed: () {
                    context.read<Global>().uiLogger.info("打开Github项目网站");
                    launchUrl(
                      Uri.parse(
                        "https://github.com/OctagonalStar/arabic_learning/",
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(Icons.star_rounded, size: 24.0),
                      SizedBox(width: mediaQuery.size.width * 0.01),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("项目地址"),
                            Text(
                              "去github上点个star~",
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.open_in_new),
                    ],
                  ),
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

