// 听抄配置：文章确定后调整语速、句间书写间隔与遍间准备时间。

import 'package:arabic_learning/core/extensions.dart';
import 'package:arabic_learning/core/navigation.dart';
import 'package:arabic_learning/core/recitation_text.dart' show splitSentences;
import 'package:arabic_learning/screens/test/dictation/dictation_play_page.dart';
import 'package:arabic_learning/screens/test/dictation/dictation_shared.dart';
import 'package:arabic_learning/services/app_data.dart';
import 'package:arabic_learning/theme/tokens.dart';
import 'package:arabic_learning/theme/typography.dart';
import 'package:arabic_learning/widgets/hero_title.dart';
import 'package:arabic_learning/widgets/kit.dart'
    show Button, SettingSliderRow, TextContainer;
import 'package:material_ui/material_ui.dart';

class DictationConfigPage extends StatefulWidget {
  final DictationArticle article;
  final int? listIndex;

  const DictationConfigPage({super.key, required this.article, this.listIndex});

  @override
  State<DictationConfigPage> createState() => _DictationConfigPageState();
}

class _DictationConfigPageState extends State<DictationConfigPage> {
  DictationConfig config = const DictationConfig();
  late final List<String> sentences = splitSentences(widget.article.passage);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int minutes = (estimateDictationSeconds(sentences, config) / 60)
        .ceil();
    final bool cacheAvailable = AppData().config.audio.audioSource == 2;

    return Scaffold(
      appBar: AppBar(
        title: HeroTitle(
          tag: dictationArticleHeroTag(
            widget.article,
            listIndex: widget.listIndex,
          ),
          text: widget.article.title,
          style: theme.textTheme.headlineSmall,
          flightStyle: theme.textTheme.headlineSmall,
          maxLines: 1,
          softWrap: false,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            TextContainer(
              text:
                  "${widget.article.sourceLabel} · ${sentences.length} 句 · "
                  "难度 ${widget.article.difficulty}\n"
                  "流程固定四遍：正常速度 → 稍慢逐句 → 稍慢逐句 → 正常速度。",
            ),
            if (!cacheAvailable)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  "当前音源无法预缓存音频，播放完成时刻可能有偏差。"
                  "建议在 设置-音频 切换到本地神经网络语音。",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.semanticColors.warning,
                  ),
                ),
              ),
            Card(
              margin: const EdgeInsets.all(AppSpacing.sm),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SpeedRow(
                      label: "第一、四遍语速",
                      value: config.normalSpeed,
                      min: 0.5,
                      max: 1.5,
                      divisions: 10,
                      onChanged: (double value) {
                        setState(() {
                          config = config.copyWith(
                            normalSpeed: value,
                            slowSpeed: value < config.slowSpeed
                                ? value
                                : config.slowSpeed,
                          );
                        });
                      },
                    ),
                    _SpeedRow(
                      label: "第二、三遍语速",
                      value: config.slowSpeed,
                      min: 0.4,
                      max: config.normalSpeed,
                      divisions: ((config.normalSpeed - 0.4) / 0.05).round(),
                      onChanged: (double value) {
                        setState(() {
                          config = config.copyWith(slowSpeed: value);
                        });
                      },
                    ),
                    _SecondsRow(
                      label: "慢速遍每句间隔",
                      value: config.sentenceInterval,
                      min: 3,
                      max: 30,
                      divisions: 27,
                      onChanged: (int value) {
                        setState(() {
                          config = config.copyWith(sentenceInterval: value);
                        });
                      },
                    ),
                    _SecondsRow(
                      label: "两遍之间准备时间",
                      value: config.passInterval,
                      min: 5,
                      max: 60,
                      divisions: 11,
                      step: 5,
                      onChanged: (int value) {
                        setState(() {
                          config = config.copyWith(passInterval: value);
                        });
                      },
                    ),
                    _SecondsRow(
                      label: "开始前倒计时",
                      value: config.countdown,
                      min: 0,
                      max: 30,
                      divisions: 6,
                      step: 5,
                      onChanged: (int value) {
                        setState(() {
                          config = config.copyWith(countdown: value);
                        });
                      },
                    ),
                    _SecondsRow(
                      label: "结束后校对时间",
                      value: config.finalCheck,
                      min: 0,
                      max: 120,
                      divisions: 12,
                      step: 10,
                      onChanged: (int value) {
                        setState(() {
                          config = config.copyWith(finalCheck: value);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                "预计约 $minutes 分钟（含四遍播放与间隔）",
                style: theme.textTheme.bodyLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Button(
                icon: Icon(Icons.rocket_launch, size: 32.0),
                size: const Size.fromHeight(88.0),
                onPressed: () {
                  pushPage(
                    context,
                    DictationPlayPage(
                      article: widget.article,
                      sentences: sentences,
                      config: config,
                    ),
                  );
                },
                child: Text(
                  "开始听抄",
                  style: withoutColor(theme.textTheme.headlineSmall!),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SpeedRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingSliderRow(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      valueText: "${value.toStringAsFixed(2)} 倍",
      onChanged: onChanged,
    );
  }
}

class _SecondsRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int divisions;
  final int step;
  final ValueChanged<int> onChanged;

  const _SecondsRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.step = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SettingSliderRow(
      label: label,
      value: value.toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      divisions: divisions,
      valueText: "$value 秒",
      onChanged: (double sliderValue) {
        onChanged((sliderValue / step).round() * step);
      },
    );
  }
}
