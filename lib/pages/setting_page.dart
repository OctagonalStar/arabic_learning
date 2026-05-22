import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/sub_pages_builder/setting_pages/help_page.dart'
    show HelpPage;
import 'package:arabic_learning/sub_pages_builder/setting_pages/item_widget.dart'
    show SettingItem;
import 'package:arabic_learning/sub_pages_builder/setting_pages/debug_page.dart'
    show DebugPage;
import 'package:arabic_learning/sub_pages_builder/setting_pages/about_page.dart'
    show AboutPage;
import 'package:arabic_learning/sub_pages_builder/setting_pages/data_download_page.dart'
    show DownloadPage;
import 'package:arabic_learning/sub_pages_builder/setting_pages/model_download_page.dart'
    show ModelDownload;
import 'package:arabic_learning/sub_pages_builder/setting_pages/questions_setting_page.dart'
    show QuestionsSettingPage;
import 'package:arabic_learning/sub_pages_builder/setting_pages/sync_page.dart'
    show DataSyncPage;
import 'package:arabic_learning/sub_pages_builder/learning_pages/fsrs_pages.dart'
    show ForeFSRSSettingPage;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart'
    if (dart.library.io) 'dart:io'
    as io;

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
                  end: Switch(
                    value: appData.config.regular.darkMode,
                    onChanged: (value) {
                      context.read<Global>().uiLogger.info(
                        "更新深色模式设置: $value",
                      );
                      AppData().config = AppData().config.copyWith(
                        regular: AppData().config.regular.copyWith(
                          darkMode: value,
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("网页版加载中文字体需要较长时间，请先耐心等待"),
                            duration: Duration(seconds: 3),
                          ),
                        );
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
                Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(width: mediaQuery.size.width * 0.02),
                        Icon(Icons.download, size: 24.0),
                        SizedBox(width: mediaQuery.size.width * 0.01),
                        Expanded(child: Text("导入词库数据")),
                        Text("词库中现有: ${AppData().wordCount}"),
                        SizedBox(width: mediaQuery.size.width * 0.02),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            fixedSize: Size(
                              mediaQuery.size.width * 0.4,
                              mediaQuery.size.height * 0.06,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(25.0),
                              ),
                            ),
                          ),
                          onPressed: () {
                            context.read<Global>().uiLogger.info(
                              "跳转: SettingPage => DownloadPage",
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => DownloadPage(),
                              ),
                            );
                          },
                          icon: Icon(Icons.cloud_download),
                          label: Text("线上下载"),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            fixedSize: Size(
                              mediaQuery.size.width * 0.4,
                              mediaQuery.size.height * 0.06,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.horizontal(
                                right: Radius.circular(25.0),
                              ),
                            ),
                          ),
                          onPressed: () async {
                            context.read<Global>().uiLogger.info("选择手动导入单词");
                            FilePickerResult? result =
                                await FilePicker.pickFiles(
                                  allowMultiple: false,
                                  type: FileType.custom,
                                  allowedExtensions: ['json'],
                                );
                            if (result != null) {
                              String jsonString;
                              PlatformFile platformFile = result.files.first;
                              try {
                                jsonString = await platformFile.xFile
                                    .readAsString();
                              } catch (e) {
                                if (!context.mounted) return;
                                if (platformFile.path != null && !kIsWeb) {
                                  context.read<Global>().uiLogger.warning(
                                    "文件导入错误: 常规方式读取失败:\n$e\n尝试路经读取",
                                  );
                                  jsonString = await io.File(
                                    platformFile.path!,
                                  ).readAsString();
                                } else {
                                  context.read<Global>().uiLogger.severe(
                                    "文件导入错误: $e",
                                  );
                                  alart(
                                    context,
                                    "文件 \"${platformFile.name}\" \n无法读取：$e。",
                                  );
                                  return;
                                }
                              }
                              if (!context.mounted) return;
                              try {
                                context.read<Global>().uiLogger.fine(
                                  "文件读取完成，开始解析",
                                );
                                Map<String, dynamic> jsonData = json.decode(
                                  jsonString,
                                );
                                AppData().importDictData(
                                  jsonData,
                                  platformFile.name,
                                );
                                alart(
                                  context,
                                  "文件 \"${platformFile.name}\" \n已导入。",
                                );
                                context.read<Global>().uiLogger.info("文件解析成功");
                              } catch (e) {
                                if (!context.mounted) return;
                                context.read<Global>().uiLogger.severe(
                                  "文件 ${platformFile.name} 无效: $e",
                                );
                                alart(
                                  context,
                                  '文件 ${platformFile.name} 无效：\n$e',
                                );
                              }
                            }
                          },
                          icon: Icon(Icons.file_open),
                          label: Text("文件导入"),
                        ),
                      ],
                    ),
                  ],
                ),
                SettingRedirctButton(title: "题型配置",icon: Icons.quiz, target: QuestionsSettingPage()),
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
                            style: TextStyle(
                              color: !kIsWeb && AppData().modelTTSDownloaded ? null : Colors.grey,
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withAlpha(150),
                    minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
                    shape: BeveledRectangleBorder(),
                  ),
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
                              style: TextStyle(
                                fontSize: 8.0,
                                color: Colors.grey,
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

class SettingRedirctButton extends StatelessWidget {
  const SettingRedirctButton({
    super.key,
    required this.title,
    required this.target,
    this.icon = Icons.settings
  });

  final String title;
  final IconData icon;
  final Widget target;

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: Size.fromHeight(mediaQuery.size.height * 0.08),
        backgroundColor: Theme.of(
          context,
        ).colorScheme.onPrimary.withAlpha(150),
        shape: BeveledRectangleBorder(),
      ),
      onPressed: () {
        context.read<Global>().uiLogger.info(
          "跳转: SettingPage => ${target.toString()}",
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => target,
          ),
        );
      },
      child: Row(
        children: [
          Icon(icon),
          Expanded(child: Text(title)),
          Icon(Icons.arrow_forward_ios),
        ],
      ),
    );
  }
}

class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.leading,
    required this.end,
    this.icon = Icons.settings,
    this.note,
  });

  final String leading;
  final String? note;
  final IconData icon;
  final Widget end;

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Row(
      children: [
        SizedBox(width: mediaQuery.size.width * 0.02),
        Icon(icon, size: 24.0),
        SizedBox(width: mediaQuery.size.width * 0.01),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(leading),
              if(note != null) Text(
                note!,
                style: TextStyle(fontSize: 12.0, color: Colors.grey),
              ),
            ],
          ),
        ),
        end,
        SizedBox(width: mediaQuery.size.width * 0.02)
      ],
    );
  }
}