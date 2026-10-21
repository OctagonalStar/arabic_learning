// 学习结算页：从 learning_pages_build.dart 拆分而来。
import 'dart:async';

import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/shared.dart' show ConclusionCard;
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ConcludePage extends StatefulWidget {
  final List<int> data; // [wordCount, correctCount, secondsCount]
  const ConcludePage({super.key, required this.data});

  @override
  State<ConcludePage> createState() => _ConcludePageState();
}

class _ConcludePageState extends State<ConcludePage> {
  bool visible1 = false;
  bool visible2 = false;
  bool visible3 = false;

  /// 三段式卡片入场计时器：页面提前销毁时统一取消，避免对已卸载的 State setState。
  Timer? _revealTimer1;
  Timer? _revealTimer2;
  Timer? _revealTimer3;

  @override
  void initState() {
    super.initState();
    _revealTimer1 = Timer(Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        visible1 = true;
      });
      _revealTimer2 = Timer(Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() {
          visible2 = true;
        });
        _revealTimer3 = Timer(Duration(milliseconds: 200), () {
          if (!mounted) return;
          setState(() {
            visible3 = true;
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _revealTimer1?.cancel();
    _revealTimer2?.cancel();
    _revealTimer3?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 ConcludePage");
    // 结果卡尺寸按页面实际可用约束推导并夹在合理区间；高度不足时整页可滚动，
    // 避免矮横屏下三张卡片 + 间距 + 按钮超出视口。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double cardHeight = clampDouble(height * 0.2, 88.0, 170.0);
        final double gap = clampDouble(height * 0.05, 12.0, 36.0);
        final double buttonHeight = clampDouble(height * 0.1, 48.0, 96.0);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ConclusionCard(
                    visible: visible1,
                    slideFromLeft: true,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    width: width * 0.8,
                    height: cardHeight,
                    contentBuilder: (context, value) => Row(
                      children: [
                        Expanded(child: SizedBox()),
                        Text("已完成单词:  ", style: Theme.of(context).textTheme.titleLarge),
                        Text((widget.data[0] * value).ceil().toString(), style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                        SizedBox(width: width * 0.05),
                        CircularProgressIndicator(value: value)
                      ],
                    ),
                  ),
                  SizedBox(height: gap),
                  ConclusionCard(
                    visible: visible2,
                    slideFromLeft: false,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    width: width * 0.8,
                    height: cardHeight,
                    contentBuilder: (context, value) => Row(
                      children: [
                        CircularProgressIndicator(value: value * (widget.data[1]/widget.data[0])),
                        SizedBox(width: width * 0.05),
                        Text("回答正确数:  ", style: Theme.of(context).textTheme.titleLarge),
                        Text((widget.data[1] * value).ceil().toString(), style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                        Expanded(child: SizedBox()),
                      ],
                    ),
                  ),
                  SizedBox(height: gap),
                  ConclusionCard(
                    visible: visible3,
                    slideFromLeft: true,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    width: width * 0.8,
                    height: cardHeight,
                    contentBuilder: (context, value) => Row(
                      children: [
                        Expanded(child: SizedBox()),
                        Text("总耗时:  ", style: Theme.of(context).textTheme.titleLarge),
                        Text("${(widget.data[2] * value).ceil().toString()} 秒", style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                        SizedBox(width: width * 0.05),
                        CircularProgressIndicator(value: value)
                      ],
                    ),
                  ),
                  Expanded(child: SizedBox()),
                  Button(
                    size: Size(width, buttonHeight),
                    onPressed: (){
                      Navigator.pop(context, true);
                    },
                    child: Text("返回主页")
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
