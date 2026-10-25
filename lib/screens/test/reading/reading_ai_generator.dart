// 阅读题 AI 生成相关纯逻辑：提示词拼装与随机主题。
// 小程序试用版无网络，题目生成 HTTP 客户端已移除，仅保留离线提示词复制流程。

import 'dart:math';

import 'package:arabic_learning/core/ai_prompt.dart';
import 'package:arabic_learning/screens/test/reading/reading_shared.dart';

String buildPrompt({required QuestionConfig qc,required bool useSafe}) {
  // testType 默认值为 0（尚未选择题型），此时没有对应的标签集合，
  // 用空列表兜底，避免调用方直接调用时抛 LateInitializationError。
  List<String> questionTags = const <String>[];
  switch (qc.testType) {
    case 1 : questionTags = AIPrompt.readingQuestionTags;
    case 2 : questionTags = AIPrompt.readingFillTags;
  }
  String prompt = AIPrompt.basePrompt
                  .replaceAll("{QuestionType}", qc.testType == 1 ? "阅读理解" : "完形填空")
                  .replaceAll("{Theme}", qc.theme)
                  .replaceAll("{Additional}", qc.testType == 1 ? "" : AIPrompt.readingFillAdditionalPrompt)
                  .replaceAll("{TargetDifficulty}", qc.difficulty.toString())
                  .replaceAll(" {Tashkeel} ", qc.tashkeel ? " 有完整发音符号的 " : "")
                  .replaceAll("{QuestionAmount}", qc.questionAmount.toString())
                  .replaceAll("{QuestionTags}", questionTags.toString());
  if(useSafe){
    prompt = "$prompt\n${AIPrompt.safePrompt}";
  }
  return prompt;
}

/// 按难度分档随机取一个文章主题。
String randomReadingTheme(int difficulty){
  switch (difficulty){
    case > 6 :{
      return AIPrompt.readingThemesHard.elementAt(Random().nextInt(AIPrompt.readingThemesHard.length));
    }
    case > 3 :{
      return AIPrompt.readingThemesMid.elementAt(Random().nextInt(AIPrompt.readingThemesMid.length));
    }
    case >= 0 :{
      return AIPrompt.readingThemesEasy.elementAt(Random().nextInt(AIPrompt.readingThemesEasy.length));
    }
  }
  return "";
}
