import 'dart:math';

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/core/adaptive.dart' show AdaptiveTabBody;
import 'package:arabic_learning/core/date_utils.dart';
import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/theme/tokens.dart' show AppRadius;
import 'package:arabic_learning/theme/typography.dart';
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/overlays.dart' show alart;
import 'package:arabic_learning/widgets/shared.dart' show StatCard;
import 'package:arabic_learning/services/words.dart';
import 'package:arabic_learning/services/tts.dart';
import 'package:arabic_learning/screens/setting/dict_manage_page.dart';
import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/services/fsrs.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 HomePage");
    FSRS fsrs = FSRS();

    // 尺寸全部由 Tab 实际可用高度/宽度推导并夹在合理区间：
    // 矮横屏下自动压缩，手机竖屏与桌面下与原比例观感接近。
    return AdaptiveTabBody(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double gapSmall = clampDouble(height * 0.01, 4.0, 12.0);
        final double statHeight = clampDouble(height * 0.18, 64.0, 160.0);
        final double statSpacing = clampDouble(height * 0.03, 6.0, 24.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DailyWord(
              width: width * 0.9,
              height: clampDouble(height * 0.3, 88.0, 280.0),
            ),
            SizedBox(height: gapSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                StatCard(
                  width: width * 0.30,
                  height: statHeight,
                  spacing: statSpacing,
                  label: '连胜天数',
                  value: getStrokeDays(AppData().config.learning).toString(),
                  statusIcon: AppData().config.learning.lastDate == daysSinceEpoch()
                    ? Icon(Icons.done, size: 15.0, color: context.semanticColors.success)
                    : Icon(Icons.error_outline, size: 15.0, color: context.semanticColors.warning),
                ),
                StatCard(
                  width: width * 0.50,
                  height: statHeight,
                  spacing: statSpacing,
                  label: '已学词汇',
                  value: fsrs.config.enabled ? fsrs.config.cards.length.toString() : "未启用",
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                StatCard(
                  width: width * 0.50,
                  height: statHeight,
                  spacing: statSpacing,
                  label: '规律性学习',
                  value: fsrs.config.enabled ? "${fsrs.getWillDueCount().toString()}个待复习" : "未启用",
                ),
                StatCard(
                  width: width * 0.30,
                  height: statHeight,
                  spacing: statSpacing,
                  label: '单词总数',
                  value: AppData().wordCount.toString(),
                ),
              ]
            )
          ],
        );
      },
    );
  }
}

class DailyWord extends StatefulWidget {
  const DailyWord({super.key, required this.width, required this.height});

  /// 卡片宽度：由父级按 Tab 实际可用宽度推导。
  final double width;

  /// 卡片高度：由父级按 Tab 实际可用高度推导（含最小/最大限制）。
  final double height;

  @override
  State<StatefulWidget> createState() => _DailyWord();
}


class _DailyWord extends State<DailyWord> {
  bool playing = false;

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 DailyWord组件");
    // 内部间距按卡片高度等比换算，维持原有 0.02/0.005/0.03 : 0.3 的比例。
    final double titleGap = widget.height * 0.067;
    final double wordGap = widget.height * 0.017;
    final double iconGap = widget.height * 0.1;
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    Random rnd = Random(seed);
    late WordItem data;
    late String dailyWord;
    AppData appData = AppData();
    if(appData.wordCount != 0) {
      data = appData.wordData.words[rnd.nextInt(appData.wordCount)];
      dailyWord = data.arabic;
    }

    return Button(
      onPressed: () async {
        if(playing) return;
        if(appData.wordCount != 0) {
          setState(() {
            playing = true;
          });
          try {
            await playTextToSpeech(dailyWord);
          } catch (e) {
            if(context.mounted) alart(context, e.toString());
          }
          setState(() {
            playing = false;
          });
        } else {
          context.read<Global>().uiLogger.info("跳转: DailyWord => DictManagePage");
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DictManagePage()));
        }
      },
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.card))),
      size: Size(widget.width, widget.height),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '每日一词',
            style: withoutColor(Theme.of(context).textTheme.titleMedium!),
          ),
          SizedBox(height: titleGap),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              children: AppData().wordCount == 0 ? [Text("当前未导入词库数据\n请点此以管理词库")]
                : [
                Text(
                  data.arabic,
                  style: arabicStyle(context, base: withoutColor(Theme.of(context).textTheme.displayMedium!)),
                ),
                SizedBox(height: wordGap),
                Text(
                  data.chinese,
                  style: withoutColor(Theme.of(context).textTheme.titleMedium!),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: iconGap),
                Icon(Icons.volume_up, size: 18.0),
              ],
            )
          ),
        ],
      ),
    );
  }
}