import 'package:flutter/material.dart';

import 'package:arabic_learning/core/statics.dart';
import 'package:arabic_learning/screens/learning/fsrs/fsrs_calibration_page.dart' show FsrsCalibrationPage;
import 'package:arabic_learning/screens/learning/fsrs/fsrs_review_page.dart' show MainFSRSPage;
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';
import 'package:arabic_learning/services/words.dart';
import 'package:arabic_learning/widgets/kit.dart' show Button, CategoryFilter, SelectChip, TextContainer;
import 'package:arabic_learning/widgets/overlays.dart' show alart, showSnackBar;
import 'package:arabic_learning/widgets/shared.dart' show SettingCard;

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

  @override
  Widget build(BuildContext context) {
    final FSRS fsrs = FSRS();
    if(fsrs.config.enabled && !forceChoosing) {
      return MainFSRSPage(fsrs: fsrs);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("单词规律复习设置"),
      ),
      body: SafeArea(top: false, child: StatefulBuilder(
        builder: (context, setState) {
          final List<String> availableCategories = collectAllCategories();
          return ListView(
            children: [
              TextContainer(text: "参数配置", textAlign: TextAlign.center),
              SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                margin: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("期望提取率", style: Theme.of(context).textTheme.bodyLarge)),
                        Slider(
                          value: fsrs.config.desiredRetention, 
                          max: 0.99,
                          min: 0.75,
                          divisions: 24,
                          onChanged: (value){
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                desiredRetention: (value*100).floorToDouble()/100
                              );
                            });
                          }
                        ),
                        Text((fsrs.config.desiredRetention).toStringAsFixed(2))
                      ],
                    ),
                    Text("期望提取率 是指期望你有多大概率能回忆起某个单词。通常设置值越大，要求的学习间隔越短。"),
                    Text("允许设置范围 0.75-0.99; 建议不低于0.8，不高于0.95")
                  ],
                ),
              ),
              SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                margin: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("优秀评分限时", style: Theme.of(context).textTheme.bodyLarge)),
                        Slider(
                          value: fsrs.config.easyDuration.toDouble(), 
                          max: 5000.0,
                          min: 1000.0,
                          divisions: 40,
                          onChanged: (value){
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                easyDuration: value.toInt()
                              );
                            });
                          }
                        ),
                        Text(fsrs.config.easyDuration.toString())
                      ],
                    ),
                    Text("优秀评分限时 是指在你回答问题时，回答正确耗时小于多少时评分为优秀(Easy)，单位为毫秒"),
                    Text("允许设置范围 1000-5000; 建议不要设置过高，否则会导致算法认为单词简单而规划间隔过长")
                  ],
                ),
              ),
              SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                margin: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("良好评分限时", style: Theme.of(context).textTheme.bodyLarge)),
                        Slider(
                          value: fsrs.config.goodDuration.toDouble(), 
                          max: 10000.0,
                          min: 2000.0,
                          divisions: 80,
                          onChanged: (value){
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                goodDuration: value.toInt()
                              );
                            });
                          }
                        ),
                        Text(fsrs.config.goodDuration.toString())
                      ],
                    ),
                    Text("良好评分限时 是指在你回答问题时，回答正确耗时小于多少时评分为良好(Good)，单位为毫秒"),
                    Text("允许设置范围 2000-10000; 建议不要设置过低，否则会导致学习阶段单词难以毕业（导致某单词一直被规划为当天内学习），如果你遇到此类情况，将此值适当调高即可。"),
                    Text("请勿设置一个低于优秀评分的数值")
                  ],
                ),
              ),
              SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                margin: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("使用自我评级", style: Theme.of(context).textTheme.bodyLarge)),
                        Switch(
                          value: fsrs.config.selfEvaluate, 
                          onChanged: (value){
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                selfEvaluate: value
                              );
                            });
                          }
                        )
                      ],
                    ),
                    Text("自我评级 开启时会向你展示遮挡了中文的单词卡片，由你自行选择你是 记得很清楚/还记得/回忆困难/忘了"),
                    Text("在此模式下，计时仅作展示，不作为评分依据"),
                    Text("适合清楚自己的实力的人启用")
                  ],
                ),
              ),
              SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                margin: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("每日单词推送", style: Theme.of(context).textTheme.bodyLarge)),
                        Slider(
                          max: 20.0,
                          min: 0.0,
                          divisions: 20,
                          value: fsrs.config.pushAmount.toDouble(), 
                          onChanged: (double value){
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(pushAmount: value.round());
                            });
                          },
                          label: fsrs.config.pushAmount == 0 ? "禁用" : fsrs.config.pushAmount.toString(),
                        )
                      ],
                    ),
                    Text("单词推送 开启后每天会推送新单词 但数量不一定是你所指定的（大概率会少几个） 你可以在学习页面入口进入推送单词学习"),
                    Text("学习的推送单词会加入复习中"),
                    Text("当天是否学习新单词对连胜计数没有影响 学不学可以看你心情"),
                    if(fsrs.config.pushAmount != 0 && availableCategories.isNotEmpty) ...[
                      Divider(),
                      Text("推送词分类筛选：仅从所选分类中推送新词；不选择表示不筛选。可多选，满足所属分类中任意一个即可。", style: Theme.of(context).textTheme.bodyMedium),
                      CategoryFilter(
                        available: availableCategories,
                        selected: fsrs.config.pushCategories.toSet(),
                        onChanged: (Set<String> value) {
                          setState(() {
                            fsrs.config = fsrs.config.copyWith(pushCategories: value.toList());
                          });
                        },
                      )
                    ]
                  ],
                ),
              ),
              if(!fsrs.config.selfEvaluate) SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                margin: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("偏好易混词", style: Theme.of(context).textTheme.bodyLarge)),
                        Switch(
                          value: fsrs.config.preferSimilar, 
                          onChanged: (value){
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                preferSimilar: value
                              );
                            });
                          }
                        )
                      ],
                    ),
                    Text("偏好易混词 开启时选择题的选项更多地按照词根寻找相似的单词进行测试"),
                    Text("关闭时选择题的选项更多地考察同课程的单词"),
                    Text("该选型仅在自我评级关闭时生效")
                  ],
                ),
              ),
              if(!fsrs.config.selfEvaluate) SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                margin: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("复习/推送随机题型", style: Theme.of(context).textTheme.bodyLarge),
                    SizedBox(height: 4.0),
                    Text("勾选多个题型后，复习与每日推送会在每个单词上随机选用其中一种；至少保留一项；其中「单词卡片」在复习中以自我评级（记得很清楚/还记得/回忆困难/忘了）呈现。", style: Theme.of(context).textTheme.bodyMedium),
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
              ),
              SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                margin: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("强化记忆循环", style: Theme.of(context).textTheme.bodyLarge)),
                        Switch(
                          value: fsrs.config.reinforceMemory, 
                          onChanged: (value){
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                reinforceMemory: value
                              );
                            });
                          }
                        )
                      ],
                    ),
                    Text("开启后同一个到期卡片在队列中将按交错顺序出现多次（3次），加深印象。"),
                    Text("关闭后每个词汇当次复习只在队列里出现一次。")
                  ],
                ),
              ),
              SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                margin: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("个性化校准", style: Theme.of(context).textTheme.bodyLarge)),
                        Text(
                          fsrs.config.personalFactor == 1.0
                              ? "默认"
                              : "${fsrs.config.personalFactor.toStringAsFixed(2)}×",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: fsrs.config.personalFactor == 1.0
                                    ? null
                                    : Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                    Text("通过一次小测试测出你对新词的初始记忆强度，自动调整新词的初始复习间隔。"),
                    TextButton(
                      onPressed: () async {
                        final BuildContext pageContext = context;
                        final double? result = await Navigator.push<double>(
                          context,
                          MaterialPageRoute<double>(builder: (BuildContext context) => const FsrsCalibrationPage()),
                        );
                        if (!pageContext.mounted) return;
                        if (result != null) {
                          showSnackBar(pageContext, "已应用个性化系数 ${result.toStringAsFixed(2)}×");
                        }
                        setState((){});
                      },
                      child: const Text("开始校准"),
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
              ),
              SettingCard(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                margin: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("错选惩罚", style: Theme.of(context).textTheme.bodyLarge)),
                        Switch(
                          value: fsrs.config.penalizeWrongOption, 
                          onChanged: (value){
                            setState(() {
                              fsrs.config = fsrs.config.copyWith(
                                penalizeWrongOption: value
                              );
                            });
                          }
                        )
                      ],
                    ),
                    Text("开启后在选择题中选错时，会把错选的那个词记为一次「忘了」，让它更早出现在复习队列中。"),
                    Text("只有已加入规律学习的词会被惩罚，陌生词不受影响。")
                  ],
                ),
              ),
              Button(
                size: Size.fromHeight(100),
                onPressed: (){
                  fsrs.createScheduler(prefs: AppData().storage);
                  alart(context, "设置完成，重新进入规律学习页面即可开始", onConfirmed: (){Navigator.popUntil(context, (route) => route.isFirst);});
                }, 
                icon: Icon(Icons.done),
                child: Text("确认"),
              ),
              if (fsrs.config.enabled) Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Button(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                  size: Size.fromHeight(80),
                  shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
                  onPressed: (){
                    showDialog(
                      context: context, 
                      builder: (context) => AlertDialog(
                        title: Text("重置并停用 FSRS?"),
                        content: Text("这将永久清除所有规律学习进度及配置，且不可恢复！"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: Text("取消")),
                          TextButton(
                            onPressed: () {
                              fsrs.config = FSRSConfig(enabled: false);
                              fsrs.save(immediate: true);
                              Navigator.popUntil(context, (route) => route.isFirst);
                            }, 
                            child: Text("确认清空", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.error))
                          )
                        ],
                      )
                    );
                  },
                  icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
                  child: Text("重置并停用", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.error)),
                ),
              )
            ]
          );
        }
      )),
    );
  }
}
