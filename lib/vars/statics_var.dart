import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:arabic_learning/package_replacement/fake_dart_io.dart' if (dart.library.io) 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

@immutable
class StaticsVar {
  static const String appName = 'Ar 学';
  static const int appVersion = 100000;
  static const int termVersion = 1;
  static const String modelPath = 'arabicLearning/tts/model/vits-piper-ar_JO-kareem-medium';
  static const Map<String, dynamic> tempConfig = {"SelectedClasses": []};
  static const Curve curve = Curves.fastEaseInToSlowEaseOut;
  static const String onlineDictOwner = 'JYinherit';
  static const String arBackupFont = "Vazirmatn";
  static const String zhBackupFont = "NotoSansSC";
  static const List<String> learningMessage = [
    "⚠️ 警告：您积累的‘知识债’即将逾期。请立即支付5分钟学习时间以避免‘利息’。",
    "友情提示：今日的学习KPI已完成 0%，是时候启动“填鸭”程序了！",
    "你的阴性、阳性、单数、双数、复数... 你都记清楚了吗？",
    "«هل تتذكر ما تعلمته بالأمس؟» ",
    "«إن شاء الله» 你今天会完成学习任务的，对吧？",
    "听说，在沙漠的另一边，有一课书在等你翻开...",
    "..."
  ];
  static const List<MaterialColor> themeList = [
    Colors.pink,
    Colors.blue,
    Colors.green,
    Colors.lime,
    Colors.orange,
    Colors.purple,
    Colors.brown,
    Colors.blueGrey,
    Colors.teal,
    Colors.cyan,
    // 下面的是彩蛋颜色 :)
    MaterialColor(0xFF97FFF6, <int, Color>{
      50: Color(0xFFE0FFFF),
      100: Color(0xFFB3FFFF),
      200: Color(0xFF80FFFF),
      300: Color(0xFF4DFFFF),
      400: Color(0xFF1AFFFF),
      500: Color(0xFF00E6D9),
      600: Color(0xFF00BFB3),
      700: Color(0xFF00998C),
      800: Color(0xFF007366),
      900: Color(0xFF004D40),
    })
  ];
  static final isDesktop = kIsWeb ? false : (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  static final player = AudioPlayer(); // load Player when app start
  static final BorderRadius br = BorderRadius.circular(25.0);
}

@immutable
class AIPrompt {
  static const String safePrompt = """
# 内容合规

## 禁止生成的红线范畴（包括但不限于）
- 政治敏感：涉及当代国家间冲突（如巴以、海湾争端）、特定政权批评、领土主权争议、国际地缘政治博弈。
- 宗教争议：涉及伊斯兰教内部派别（逊尼/什叶）对立、对先知/圣门弟子/《古兰经》的负面或戏谑性讨论、基督教/犹太教等非伊斯兰信仰的贬损、无神论或极端世俗化宣扬。
- 社会禁忌：LGBTQ+议题、婚前/婚外亲密关系描写、色情低俗内容、赌博或酒精/毒品美化。
- 暴力恐怖：任何形式的恐怖主义、极端组织、暴力犯罪细节的正面或中性呈现。

## 主题审查
- 若主题**直接或隐晦地指向**上述任何红线范畴（例如用户误填了“巴以冲突的历史”或“伊斯兰教派差异”），**请立即中止所有生成流程**，不输出任何文章或题目。
- 你必须输出以下**错误JSON对象**（仅此一项，不含其他字段）：{"Error": "SENSITIVE_TOPIC_DETECTED", "Message": "当前主题涉及敏感范畴，请更换主题。"}
""";
  static const String basePrompt = """
# 角色设定
你是一个阿拉伯语 {QuestionType} 生成器。请**只输出**一个合法的JSON对象，不要输出任何其他文字。

# 任务简报
以 {Theme} 为主题生成一篇完整的难度接近 {TargetDifficulty} 的 {Tashkeel} 阿拉伯语文章及相关的 {QuestionAmount} 个题目

# 生成标准（严格参照）

## 1. 题型标签（从以下枚举中选取）
 {QuestionTags} 

## 2. 文章与难度（EssayDifficulty）量化标尺

**文章难度（EssayDifficulty）** 是由文章本身的词汇难度、句法复杂度和主题抽象度决定。

请根据“目标文章难度”数值，严格对照下表控制文章生成：

0-2级：词汇可能含基础生活词，句式限简单陈述句，篇幅建议50-80词;
3-4级：词汇可能含常用动词变位与介词，句式允并列句，篇幅建议80-120词;
5-6级：词汇可能含派生名词与固定搭配，句式允条件句和关系从句，篇幅建议120-160词;
7-8级：词汇可能含稀有三母简式动词，句式允长复合句和虚拟式，篇幅建议160-200词;
9-10级：词汇可能含学术术语，句式允嵌套从句和强调句，篇幅建议200-250词;

## 3. 输出JSON结构
{
  "Essay": "<文章内容>",
  "EssayDifficulty": <整数，严格符合上表标尺，尽量贴近输入的目标难度>,
  "Questions": [
    {
      "Riddle": "<标注变音符号的问题>",
      "Answers": ["<正确>", "<干扰1>", "<干扰2>", "<干扰3>"],
      "Type": "<必须从枚举列表中选取>",
      "Analysis": "<简体中文解析，**严禁使用英文双引号"**，请改用引号「」；提及正确选项时需要完整写出，不可泛化为“第一项”或“A项”>"
    }
  ]
}
""";

  static const List<String> readingQuestionTags = ["细节理解", "主旨概括", "词义猜测", "推理判断", "作者意图", "逻辑排序"];
  static const List<String> readingThemesEasy = [
    "家庭与家人",
    "学校与课堂",
    "日常作息",
    "食物与饮品",
    "天气与季节",
    "自我介绍与朋友",
    "颜色与常见物品",
    "去市场买菜",
    "拜访亲友",
    "我的房间与家居",
    "动物与宠物",
    "节日与假期活动"
  ];
  static const List<String> readingThemesMid = [
    "旅行与交通出行",
    "购物消费与网上购物",
    "健康与就医看诊",
    "工作与职场文化",
    "传统节日与习俗",
    "城市设施与社区生活",
    "环境保护与垃圾分类",
    "社交媒体与日常通讯",
    "学习方法与技能提升",
    "租房与住宿体验",
    "运动与健身",
    "文化差异与跨文化交流"
  ];
  static const List<String> readingThemesHard = [
    "文学诗歌与艺术鉴赏",
    "社会热点现象与批判",
    "经济商业与消费观",
    "科技发展与人类未来",
    "历史事件与人物评析",
    "哲学思辨与道德困境",
    "文化传承与现代冲突",
    "教育体制与改革思考",
    "心理学与自我认知成长",
    "环境气候与可持续发展",
    "人工智能与伦理挑战"
  ];
}