import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';

class LearningFSRSPage extends StatelessWidget {
  const LearningFSRSPage({super.key});

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    int choosedScheme = 0;
    int getChosenScheme([int? scheme]) {
      if (scheme != null) {
        choosedScheme = scheme;
        return choosedScheme;
      }
      return choosedScheme;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("FSRS-抗遗忘学习"),
      ),
      body: StatefulBuilder(
        builder: (context, setState) {
          return ListView(
            children: [
              TextContainer(text: "该页面仍在开发中...", style: TextStyle(color: Colors.redAccent, fontSize: 24)),
              TextContainer(text: "FSRS（Forgetting Spaced Repetition System）是一种基于遗忘曲线的间隔重复学习系统，旨在帮助用户更有效地记忆信息。通过调整复习间隔，FSRS能够最大限度地提高记忆的持久性，减少遗忘的发生。\n为了让您更个性化地学习，请选择一个适合您的难度方案："),
              SizedBox(height: mediaQuery.size.height * 0.02),
              difficultyButton(
                context,
                "简单 (Easy)",
                "标准: \n- 期望提取率为 80%\n- 2秒内答对为优秀\n- 8秒内答对为良好",
                1,
                getChosenScheme,
                setState,
              ),
              difficultyButton(
                context,
                "良好 (Fine)",
                "标准: \n- 期望提取率为 85%\n- 1秒内答对为优秀\n- 5秒内答对为良好",
                2,
                getChosenScheme,
                setState,
              ),
              difficultyButton(
                context,
                "一般 (OK~)",
                "标准: \n- 期望提取率为 90%\n- 0.8秒内答对为优秀\n- 3秒内答对为良好",
                3,
                getChosenScheme,
                setState,
              ),
              difficultyButton(
                context,
                "困难 (Emm...)",
                "标准: \n- 期望提取率为 95%\n- 0.5秒内答对为优秀\n- 1.6秒内答对为良好",
                4,
                getChosenScheme,
                setState,
              ),
              difficultyButton(
                context,
                "地狱 (Impossible)",
                "标准: \n- 期望提取率为 99%\n- 0.3秒内答对为优秀\n- 1秒内答对为良好",
                5,
                getChosenScheme,
                setState,
              ),
            ]
          );
        }
      ),
    );
  }
}

Widget difficultyButton(BuildContext context, String label, String subLabel, int scheme, Function getChosenScheme, Function setLocalState) {
  return AnimatedContainer(
    margin: const EdgeInsets.all(16.0),
    duration: const Duration(milliseconds: 500),
    curve: StaticsVar.curve,
    decoration: BoxDecoration(
      color: getChosenScheme() == scheme ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onInverseSurface,
      borderRadius: StaticsVar.br,
    ),
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(16.0),
        //fixedSize: Size.fromHeight(50.0),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: StaticsVar.br,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                Text(subLabel, style: TextStyle(fontSize: 12.0, color: Colors.grey)),
              ],
            )
          ),
          if (getChosenScheme() == scheme) const Icon(Icons.check, size: 24.0),
          if (getChosenScheme() == scheme) ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward, size: 24.0),
            onPressed: () {
              // Go to the next step
            },
            label: const Text("下一步"),
          )
        ],
      ),
      onPressed: () {
        setLocalState(() {
          getChosenScheme(scheme);
        });
      },
    )
  );
}