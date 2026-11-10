// 「单词规律复习」设置页：记忆强度、答题节奏、内容、题型与高级项。
//
// 版式与设置页一致：`SettingItem` 分区 + `SettingRow` 行；滑块统一放在行尾
// 的定宽 `SizedBox` 内，窄屏不会溢出；说明与当前值收进 `SettingRow.note`。
// 设置项直接改 `FSRS().config`（不可变对象 copyWith），靠 `StatefulBuilder`
// 的 setState 重建；只有题型多选需要立刻落盘。

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:arabic_learning/screens/learning/fsrs/fsrs_calibration_page.dart' show FsrsCalibrationPage;
import 'package:arabic_learning/screens/learning/fsrs/fsrs_review_page.dart' show MainFSRSPage;
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/words.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppRadius, AppSpacing;
import 'package:arabic_learning/widgets/kit.dart' show Button, CategoryFilter, SelectChip, SettingItem, SettingRow;
import 'package:arabic_learning/widgets/overlays.dart' show alart, showSnackBar;
import 'package:arabic_learning/core/navigation.dart';

class ForeFSRSSettingPage extends StatelessWidget {
  final bool forceChoosing;
  const ForeFSRSSettingPage({super.key, this.forceChoosing = false});

  /// 复习/推送题型标签（与学习页面的措辞区分，避免沿用“学习”字样）
  static const Map<int, String> reviewCastMap = {
    0: "单词卡片",
    1: "中译阿 选择题",
    2: "阿译中 选择题",
    3: "中译阿 拼写题",
    4: "听力题",
  };

  /// 设置行的内边距：卡片内留一点呼吸感，不改变 `SettingItem` 本身。
  static const EdgeInsets _rowPadding =
      EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0);

  @override
  Widget build(BuildContext context) {
    final FSRS fsrs = FSRS();
    if(fsrs.config.enabled && !forceChoosing) {
      return MainFSRSPage(fsrs: fsrs);
    }
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text("单词规律复习设置"),
      ),
      body: SafeArea(top: false, child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final MediaQueryData media = MediaQuery.of(context);
          // `SettingItem` 的卡片宽度固定为屏幕宽度的 90%，宽屏下把内容区的
          // MediaQuery 宽度夹到 880，避免设置项在大屏上被拉得过长。
          final double cappedWidth = math.min(constraints.maxWidth, 880.0);
          return MediaQuery(
            data: media.copyWith(size: Size(cappedWidth, media.size.height)),
            child: StatefulBuilder(
              builder: (context, setState) {
                final List<String> availableCategories = collectAllCategories();

                /// 滑块行：定宽尾巴 + 当前值/说明写在 note 里，窄屏不溢出。
                Widget sliderRow({
                  required String leading,
                  required IconData icon,
                  required String note,
                  required double value,
                  required double min,
                  required double max,
                  required int divisions,
                  required String label,
                  required ValueChanged<double> onChanged,
                }) {
                  return SettingRow(
                    leading: leading,
                    icon: icon,
                    note: note,
                    end: SizedBox(
                      width: 168.0,
                      child: Slider(
                        value: value,
                        min: min,
                        max: max,
                        divisions: divisions,
                        label: label,
                        onChanged: onChanged,
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  children: [
                    // 记忆强度：三个时间/概率参数
                    SettingItem(
                      title: "记忆强度",
                      padding: _rowPadding,
                      children: [
                        sliderRow(
                          leading: "期望提取率",
                          icon: Icons.track_changes,
                          note: "当前 ${fsrs.config.desiredRetention.toStringAsFixed(2)} "
                              "· 可设 0.75-0.99，建议 0.80-0.95。\n"
                              "你希望有多大概率能回忆起某个单词：值越大要求越容易想起，学习间隔也越短。",
                          value: fsrs.config.desiredRetention,
                          min: 0.75,
                          max: 0.99,
                          divisions: 24,
                          label: fsrs.config.desiredRetention.toStringAsFixed(2),
                          onChanged: (value) {
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                desiredRetention: (value*100).floorToDouble()/100,
                              );
                            });
                          },
                        ),
                        sliderRow(
                          leading: "优秀评分限时",
                          icon: Icons.bolt_outlined,
                          note: "当前 ${fsrs.config.easyDuration} 毫秒 · 可设 1000-5000。\n"
                              "答对且用时低于此值记为优秀；设置过高会让算法认为单词简单，复习间隔被拉长。",
                          value: fsrs.config.easyDuration.toDouble(),
                          min: 1000.0,
                          max: 5000.0,
                          divisions: 40,
                          label: fsrs.config.easyDuration.toString(),
                          onChanged: (value) {
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                easyDuration: value.toInt(),
                              );
                            });
                          },
                        ),
                        sliderRow(
                          leading: "良好评分限时",
                          icon: Icons.timer_outlined,
                          note: "当前 ${fsrs.config.goodDuration} 毫秒 · 可设 2000-10000，需高于优秀评分限时。\n"
                              "答对且用时低于此值记为良好；设置过低会让单词一直留在当天反复学习，遇到这种情况适当调高即可。",
                          value: fsrs.config.goodDuration.toDouble(),
                          min: 2000.0,
                          max: 10000.0,
                          divisions: 80,
                          label: fsrs.config.goodDuration.toString(),
                          onChanged: (value) {
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                goodDuration: value.toInt(),
                              );
                            });
                          },
                        ),
                      ],
                    ),

                    // 答题节奏：自我评级与评分相关开关
                    SettingItem(
                      title: "答题节奏",
                      padding: _rowPadding,
                      children: [
                        SettingRow(
                          leading: "使用自我评级",
                          icon: Icons.psychology_alt_outlined,
                          note: "卡片遮挡中文，由你选择 记得很清楚/还记得/回忆困难/忘了。\n"
                              "此时计时仅作展示，不参与评分；适合清楚自己实力的人启用。",
                          end: Switch(
                            value: fsrs.config.selfEvaluate,
                            onChanged: (value) {
                              setState(() {
                                fsrs.config = fsrs.config.copyWith(
                                  selfEvaluate: value,
                                );
                              });
                            },
                          ),
                        ),
                        if(!fsrs.config.selfEvaluate) SettingRow(
                          leading: "偏好易混词",
                          icon: Icons.compare_arrows,
                          note: "选择题的选项更多按词根挑选相似的单词；关闭时更多考察同课程的单词。\n"
                              "仅在自我评级关闭时生效。",
                          end: Switch(
                            value: fsrs.config.preferSimilar,
                            onChanged: (value) {
                              setState(() {
                                fsrs.config = fsrs.config.copyWith(
                                  preferSimilar: value,
                                );
                              });
                            },
                          ),
                        ),
                        SettingRow(
                          leading: "错选惩罚",
                          icon: Icons.remove_circle_outline,
                          note: "选择题选错时，把错选的那个词记为一次「忘了」，让它更早出现在复习队列中。\n"
                              "只有已加入规律学习的词会被惩罚，陌生词不受影响。",
                          end: Switch(
                            value: fsrs.config.penalizeWrongOption,
                            onChanged: (value) {
                              setState(() {
                                fsrs.config = fsrs.config.copyWith(
                                  penalizeWrongOption: value,
                                );
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    // 内容：每日推送与复习队列
                    SettingItem(
                      title: "内容",
                      padding: _rowPadding,
                      children: [
                        sliderRow(
                          leading: "每日单词推送",
                          icon: Icons.notifications_active_outlined,
                          note: "当前 ${fsrs.config.pushAmount == 0 ? "禁用" : "${fsrs.config.pushAmount} 词"} "
                              "· 0 表示禁用；实际推送数量大概率会少几个。\n"
                              "推送的单词会加入复习，入口在学习页面；当天学不学不影响连胜计数。",
                          value: fsrs.config.pushAmount.toDouble(),
                          min: 0.0,
                          max: 20.0,
                          divisions: 20,
                          label: fsrs.config.pushAmount == 0
                              ? "禁用"
                              : fsrs.config.pushAmount.toString(),
                          onChanged: (double value) {
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                pushAmount: value.round(),
                              );
                            });
                          },
                        ),
                        if(fsrs.config.pushAmount != 0 && availableCategories.isNotEmpty)
                          CategoryFilter(
                            available: availableCategories,
                            selected: fsrs.config.pushCategories.toSet(),
                            description: "仅从所选分类中推送新词；不选择表示不筛选。可多选，满足所属分类中任意一个即可。",
                            onChanged: (Set<String> value) {
                              setState(() {
                                fsrs.config = fsrs.config.copyWith(pushCategories: value.toList());
                              });
                            },
                          ),
                        SettingRow(
                          leading: "强化记忆循环",
                          icon: Icons.repeat,
                          note: "开启后同一张卡需要连续回答两次：第一次达到「好」及以上不记录，再次达到才提交一次（评级以第二次为准）；第二次未达「好」则两次都不记录。",
                          end: Switch(
                            value: fsrs.config.reinforceMemory,
                            onChanged: (value) {
                              setState(() {
                                fsrs.config = fsrs.config.copyWith(
                                  reinforceMemory: value,
                                );
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    // 题型：复习/推送的随机题型（自我评级下不适用）
                    if(!fsrs.config.selfEvaluate) SettingItem(
                      title: "题型",
                      padding: _rowPadding,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "勾选多个题型后，复习与每日推送会在每个单词上随机选用其中一种；"
                              "至少保留一项。「单词卡片」在复习中以自我评级呈现。",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: 6.0,
                              runSpacing: 6.0,
                              children: List<Widget>.generate(reviewCastMap.length, (int index) {
                                final bool isSelected = fsrs.config.reviewQuestionSections.contains(index);
                                return SelectChip(
                                  label: reviewCastMap[index]!,
                                  selected: isSelected,
                                  onSelected: (bool value) {
                                    final Set<int> next = fsrs.config.reviewQuestionSections.toSet();
                                    if(value) {
                                      next.add(index);
                                    } else {
                                      next.remove(index);
                                    }
                                    if(next.isEmpty) {
                                      alart(context, "至少保留一项");
                                      return;
                                    }
                                    // 仅修改集合本身，不触发 createScheduler（那会启用 FSRS 并重建 Scheduler）
                                    setState(() {
                                      fsrs.config = fsrs.config.copyWith(
                                        reviewQuestionSections: (next.toList()..sort()),
                                      );
                                    });
                                    fsrs.save(immediate: true); // 设置项需立刻落盘
                                  },
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // 高级：个性化校准
                    SettingItem(
                      title: "高级",
                      padding: _rowPadding,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SettingRow(
                              leading: "个性化校准",
                              icon: Icons.tune,
                              note: "通过一次小测试测出你对新词的初始记忆强度，自动调整新词的初始复习间隔。",
                              end: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    fsrs.config.personalFactor == 1.0
                                        ? "默认"
                                        : "${fsrs.config.personalFactor.toStringAsFixed(2)}×",
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: fsrs.config.personalFactor == 1.0
                                          ? null
                                          : scheme.primary,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final BuildContext pageContext = context;
                                      final double? result = await pushPage<double>(
                                        context,
                                        const FsrsCalibrationPage(),
                                      );
                                      if (!pageContext.mounted) return;
                                      if (result != null) {
                                        showSnackBar(pageContext, "已应用个性化系数 ${result.toStringAsFixed(2)}×");
                                      }
                                      setState((){});
                                    },
                                    child: const Text("开始校准"),
                                  ),
                                ],
                              ),
                            ),
                            if (fsrs.config.personalFactor != 1.0)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () {
                                    fsrs.applyPersonalFactor(1.0);
                                    setState((){});
                                  },
                                  child: const Text("恢复默认"),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    // 保存 / 重置
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.xs,
                        AppSpacing.sm,
                        0.0,
                      ),
                      child: Button(
                        size: const Size.fromHeight(100),
                        onPressed: (){
                          fsrs.createScheduler(prefs: AppData().storage);
                          alart(context, "设置完成，重新进入规律学习页面即可开始", onConfirmed: (){Navigator.popUntil(context, (route) => route.isFirst);});
                        },
                        icon: const Icon(Icons.done),
                        child: const Text("确认"),
                      ),
                    ),
                    if (fsrs.config.enabled) Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Button(
                        backgroundColor: scheme.errorContainer,
                        foregroundColor: scheme.onErrorContainer,
                        size: const Size.fromHeight(80),
                        shape: AppRadius.cardShape,
                        onPressed: (){
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("重置并停用 FSRS?"),
                              content: const Text("这将永久清除所有规律学习进度及配置，且不可恢复！"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
                                TextButton(
                                  onPressed: () {
                                    fsrs.config = FSRSConfig(enabled: false);
                                    fsrs.save(immediate: true);
                                    Navigator.popUntil(context, (route) => route.isFirst);
                                  },
                                  child: Text("确认清空", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.error)),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: Icon(Icons.delete_forever, color: scheme.error),
                        child: Text("重置并停用", style: theme.textTheme.labelLarge?.copyWith(color: scheme.error)),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      )),
    );
  }
}
