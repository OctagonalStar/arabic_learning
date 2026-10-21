// 阅读题 AI 生成相关纯逻辑：提示词拼装、随机主题、以及兼容 OpenAI 标准
// 的题目生成 HTTP 客户端。不依赖任何 widget，便于单独复用与测试。

import 'dart:convert';
import 'dart:math';

import 'package:arabic_learning/core/ai_prompt.dart';
import 'package:arabic_learning/models/reading.dart';
import 'package:arabic_learning/screens/test/reading/reading_shared.dart';
import 'package:dio/dio.dart';

String buildPrompt({required QuestionConfig qc,required bool useSafe}) {
  late List<String> questionTags;
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

/// 请求兼容 OpenAI 标准的 `/chat/completions` 接口生成一道阅读题。
///
/// [dio] 由调用方在 try 之外创建，与原实现保持一致的异常边界。
/// 返回 `null` 表示接口未返回 200（原实现同样静默跳过，不提示）；
/// 返回内容无法解析或缺少必填字段时抛出异常，由调用方捕获并提示。
Future<ReadingUnit?> requestReadingUnitFromApi({
  required Dio dio,
  required QuestionConfig qconfig,
  required String prompt,
  required String apiAddress,
  required String apiKey,
  required String apiModel,
}) async {
  final Options baseopt = Options(
    headers: {
      "Authorization": "Bearer $apiKey",
      "Content-Type": "application/json"
    }
  );
  final Response res = await dio.post(
    "$apiAddress/chat/completions",
    options: baseopt,
    data: {
      "model": apiModel,
      "messages": [
        {"role": "system", "content": "你是一个阿拉伯语题目JSON生成器，只输出合法的JSON对象，不要使用Markdown代码块"},
        {"role": "user", "content": prompt}
      ],
      "response_format": {"type": "json_object"},
      "temperature": 0.7,
      "stream": false
    }
  );
  if(res.statusCode != 200) return null;
  final ReadingUnit unit = ReadingUnit.buildFromMap(
    jsonDecode(res.data["choices"][0]["message"]["content"]),
    type: qconfig.testType,
    tashkeel: qconfig.tashkeel,
  );
  if(unit.title.isEmpty || unit.passage.isEmpty || unit.questions.isEmpty) {
    throw Exception("AI生成缺少部分内容");
  }
  return unit;
}
