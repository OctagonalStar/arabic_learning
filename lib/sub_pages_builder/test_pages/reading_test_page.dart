import 'dart:convert';
import 'dart:math';

import 'package:arabic_learning/funcs/ui.dart';
import 'package:arabic_learning/funcs/utili.dart';
import 'package:arabic_learning/vars/config_structure.dart';
import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, DeviceOrientation, SystemChrome;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';


class QuestionConfig {
  /// 0: 未定义, 1: 阅读，2: 完形，稍后再做成常量
  int testType = 0;

  /// 0：未定义，1: AI API, 2: AI Prompt, 3: 现有JSON导入, 4: Github仓库
  int sourceType = 0;

  /// 文章主题
  String theme = "";

  /// 题目数量 2-10 / 5-20
  int questionAmount = 5;

  /// 文章难度 0-10
  int difficulty = 4;

  /// 发音符号
  bool tashkeel = false;
}

class ReadingUnitButton extends StatelessWidget {
  final ReadingUnit unit;
  const ReadingUnitButton({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    List<String> tags = [];
    for(ReadingQuestion question in unit.questions){
      if(!tags.contains(question.type)) tags.add(question.type);
    }

    late Color difficultyColor;
    switch(unit.difficulty){
      case >= 9 :{
        difficultyColor = Colors.black87;
        break;
      }
      case >= 7 :{
        difficultyColor = Colors.deepPurple;
        break;
      }
      case >= 5 :{
        difficultyColor = Colors.red;
        break;
      }
      case >= 3 :{
        difficultyColor = Colors.lime;
        break;
      }
      case >= 1 :{
        difficultyColor = Colors.teal;
        break;
      }
      case >= 0 : {
        difficultyColor = Colors.cyan;
        break;
      }
    }

    int correctTime = 0;
    for(int x in unit.corrects){
      correctTime += x;
    }

    return Container(
      margin: EdgeInsets.all(16.0),
      width: mediaQuery.size.width,
      child: Center(
        child: Button(
          size: Size(mediaQuery.size.width * 0.9, mediaQuery.size.height * 0.1),
          onPressed: () {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => ReadingQuestionPage(unit: unit))
            );
          }, 
          padding: EdgeInsetsGeometry.all(0.0),
          child: Row(
            children: [
              Container(
                width: mediaQuery.size.width * 0.2,
                height: mediaQuery.size.height * 0.15,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentGeometry.centerLeft,
                    end: AlignmentGeometry.centerRight,
                    colors: [
                      difficultyColor,
                      Colors.transparent
                    ]
                  ),
                  borderRadius: StaticsVar.br
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: mediaQuery.size.width * 0.02),
                    Text(
                      unit.difficulty.toString(), 
                      style: TextStyle(fontSize: 64, shadows: [Shadow(blurRadius: 5, color: Colors.white)])
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    unit.title,
                    maxLines: 1,
                    textDirection: unit.title.isArabic() ? TextDirection.rtl : TextDirection.ltr,
                    style: Theme.of(context).primaryTextTheme.displayMedium,
                  ),
                  Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 4.0,
                    children: List.generate(tags.length, (index) => TagMark(tag: tags[index], color: Colors.indigo)),
                  ),
                ],
              ),
              Expanded(child: SizedBox()),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Icon(Icons.arrow_forward_ios),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer
                    ),
                    padding: EdgeInsets.all(8.0),
                    child: Text("历史正确率:${unit.corrects.isEmpty ? "无数据" : (correctTime/(unit.corrects.length * unit.questions.length)).toStringAsFixed(2)}",
                      style: Theme.of(context).primaryTextTheme.bodyLarge),
                  )
                ],
              )
            ],
          )
        ),
      ),
    );
  }
}

class TagMark extends StatelessWidget {
  final String tag;
  final Color color;
  const TagMark({super.key, required this.tag, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: StaticsVar.br
      ),
      padding: EdgeInsets.all(4.0),
      child: Text(tag, style: Theme.of(context).primaryTextTheme.labelMedium),
    );
  }
}

class ReadingTestPage extends StatefulWidget {
  const ReadingTestPage({super.key});

  @override
  State<StatefulWidget> createState() => _ReadingTestPage();
}

class _ReadingTestPage extends State<ReadingTestPage> {
  _ReadingTestPage();

  @override
  Widget build(BuildContext context) {
    AppData appData = AppData();

    return Scaffold(
      appBar: AppBar(title: Text("阅读理解"), actions: [
        IconButton(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ReadingTestAddLeading())), 
          icon: Icon(Icons.add)
        )
      ]),
      body: ListView.builder(
        itemCount: appData.readingData.units.length + 1,
        itemBuilder: (context, index) {
          if(index == appData.readingData.units.length) {
            return TextContainer(text: "没有更多阅读题了，请点击右上角加号添加");
          }
          return ReadingUnitButton(unit: appData.readingData.units[index]);
        }
      ),
    );
  }
}

class ReadingTestAddLeading extends StatefulWidget {
  const ReadingTestAddLeading({super.key});

  @override
  State<StatefulWidget> createState() => _ReadingTestAddLeading();
}

class _ReadingTestAddLeading extends State<ReadingTestAddLeading> {
  final QuestionConfig qconfig = QuestionConfig();

  final PageController _pageController = PageController();

  Function defType(int type, int toPage){
    if(toPage == 1 && (type > 2 || type < 1)) throw Exception("Unknown Question Type: $type");
    if(toPage == 2 && (type > 4 || type < 1)) throw Exception("Unknown Source Type: $type");
    return (){
      switch (toPage){
        case 1: qconfig.testType = type;
        case 2: qconfig.sourceType = type;
      }
      
      _pageController.animateToPage(toPage, duration: Durations.medium2, curve: StaticsVar.curve);
    };
  }

  String scaffoldTitle(){
    switch ((_pageController.hasClients ? _pageController.page ?? 0 : 0).round()) {
      case 0 : return "选择题目类型";
      case 1 : return "选择题目来源";
      case 2 : return "填写相关信息";
    }
    return "Unknown";
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(scaffoldTitle())),
      body: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(),
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TypeChoose(
                  mainTitle: Text("阅读理解", style: Theme.of(context).textTheme.headlineMedium), 
                  rt: defType(1, 1),
                  subTitle: Text("根据给出的文章，选择最合适的答案", style: Theme.of(context).textTheme.bodyMedium),
                  widget: mediaQuery.size.width * 0.8,
                  height: mediaQuery.size.height * 0.2,
                ),
                TypeChoose(
                  mainTitle: Text("完形填空", style: Theme.of(context).textTheme.headlineMedium), 
                  rt: defType(2, 1),
                  subTitle: Text("使用恰当的词语，填补文中的空白", style: Theme.of(context).textTheme.bodyMedium),
                  widget: mediaQuery.size.width * 0.8,
                  height: mediaQuery.size.height * 0.2,
                ),
              ]
            )
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TypeChoose(
                  mainTitle: Text("使用AI API生成", style: Theme.of(context).textTheme.headlineMedium), 
                  rt: defType(1, 2), 
                  subTitle: Text("调用兼容OpenAI标准的接口，直接请求题目生成\n快，题目质量高，错误率低\n可能要向提供商缴费\n如果你不知道\"API\"是什么，那么你不会用这个", style: Theme.of(context).textTheme.bodyMedium), 
                  widget: mediaQuery.size.width * 0.8, 
                  height: mediaQuery.size.height * 0.2
                ),
                TypeChoose(
                  mainTitle: Text("使用AI Prompt生成", style: Theme.of(context).textTheme.headlineMedium), 
                  rt: defType(2, 2), 
                  subTitle: Text("配置题目相关难度后会生成一段AI提示词，由你复制到其他AI软件中，再将结果复制回程序使用\n方便，免费\n质量由你的提供商决定\n警告：不要使用某包，测试中其生成质量远低于其他模型，特别是高难度下", style: Theme.of(context).textTheme.bodyMedium), 
                  widget: mediaQuery.size.width * 0.8, 
                  height: mediaQuery.size.height * 0.2
                ),
                TypeChoose(
                  mainTitle: Text("使用现有JSON导入", style: Theme.of(context).textTheme.headlineMedium), 
                  rt: defType(3, 2), 
                  subTitle: Text("在使用AI Prompt方式获取到结果后选择此项粘贴", style: Theme.of(context).textTheme.bodyMedium), 
                  widget: mediaQuery.size.width * 0.8, 
                  height: mediaQuery.size.height * 0.2
                ),
                TypeChoose(
                  mainTitle: Text("从在线仓库中获取", style: Theme.of(context).textTheme.headlineMedium), 
                  rt: (){alart(context, "都说了在施工了...");}, 
                  subTitle: Text("施工中，暂时无法使用", style: Theme.of(context).textTheme.bodyMedium), 
                  widget: mediaQuery.size.width * 0.8, 
                  height: mediaQuery.size.height * 0.2
                ),
              ],
            ),
          ),
          QuestionConfigPage(qconfig: qconfig),
        ],
      ),
    );
  }
}

class ReadingQuestionPage extends StatefulWidget {
  final ReadingUnit unit;
  const ReadingQuestionPage({super.key, required this.unit});

  @override
  State<StatefulWidget> createState() => _ReadingQuestionPage();
}
class _ReadingQuestionPage extends State<ReadingQuestionPage> {
  _ReadingQuestionPage();

  PageController pageController = PageController();
  late List<SingleSelectionNotifier> choose;
  List<List<String>> options = [];

  @override
  void initState() {
    choose = List<SingleSelectionNotifier>.generate(widget.unit.questions.length, (_) => SingleSelectionNotifier());

    for(ReadingQuestion x in widget.unit.questions){
      options.add(List<String>.from(x.answers)..shuffle());
    }
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight
    ]);
    super.initState();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.unit.title)),
      body: Row(
        children: [
          SizedBox(
            width: mediaQuery.size.width * 0.65,
            height: mediaQuery.size.height,
            child: Markdown(
              data: widget.unit.passage,
              styleSheet: MarkdownStyleSheet(textScaler: TextScaler.linear(3))
            )
          ),
          Divider(),
          Expanded(
            child: PageView.builder(
              controller: pageController,
              itemCount: widget.unit.questions.length+1,
              itemBuilder: (context, int index) {
                return ListView(
                  padding: EdgeInsets.all(16.0),
                  children: [
                    if(index != widget.unit.questions.length) TextContainer(text: widget.unit.questions[index].riddle, style: Theme.of(context).primaryTextTheme.headlineLarge),
                    if(index != widget.unit.questions.length) ChangeNotifierProvider<SingleSelectionNotifier>.value(
                      value: choose[index],
                      builder: (context, child) {
                        return Table(
                          columnWidths: {
                            0: FixedColumnWidth(60),
                            1: FlexColumnWidth()
                          },
                          children: List.generate(widget.unit.questions.length, (i) {
                            return TableRow(
                              decoration: BoxDecoration(
                                color: context.watch<SingleSelectionNotifier>().value == i ? Colors.greenAccent : null,
                                borderRadius: StaticsVar.br
                              ),
                              children: [
                                TextContainer(text: ["A", "B", "C", "D", "E", "F", "G"].elementAt(i)),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Button(
                                    onPressed: () {
                                      if(context.read<SingleSelectionNotifier>().value == i) {
                                        context.read<SingleSelectionNotifier>().changeTo(null);
                                      } else {
                                        context.read<SingleSelectionNotifier>().changeTo(i);
                                      }
                                    },
                                    size: Size.fromWidth(mediaQuery.size.width * 0.2),
                                    child: Text(options[index][i], style: Theme.of(context).primaryTextTheme.headlineMedium),
                                  ),
                                )
                              ]
                            );
                          }),
                        );
                      },
                    ),
                    if(index == widget.unit.questions.length) TextContainer(text: "检查答案"),
                    if(index == widget.unit.questions.length) ...List.generate(
                      widget.unit.questions.length,
                      (int i) => TextContainer(
                        text: "题目\n${widget.unit.questions[i].riddle}\n你的答案\n${choose[i].value==null ? "未选择" : options[i][choose[i].value]}"
                      )
                    ),
                    if(index == widget.unit.questions.length) Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Button(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context, 
                            MaterialPageRoute(builder: (context) => ReadingResultPage(unit: widget.unit, selection: List<int?>.generate(choose.length, (index) => choose[index].value), options: options))
                          );
                        },
                        icon: Icon(Icons.done_all),
                        child: Text("提交"),
                      ),
                    ),
                    TweenAnimationBuilder(
                      tween: Tween<double>(
                        begin: 0,
                        end: index == 0 ? 0 : 0.5
                      ),
                      duration: Durations.medium4,
                      curve: StaticsVar.curve,
                      builder: (context, double i, child) {
                        return  Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if(index != 0 && i > 0.3) Button(
                              size: Size.fromWidth(mediaQuery.size.width * 0.3 * i),
                              icon: Icon(Icons.arrow_back_ios),
                              iconDirection: AxisDirection.left,
                              onPressed: () => pageController.previousPage(duration: Durations.medium4, curve: StaticsVar.curve),
                              child: Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text("上一题"))),
                            ),
                            if(index != widget.unit.questions.length) Button(
                              size: Size.fromWidth(mediaQuery.size.width * 0.3 * (1 - i)),
                              icon: Icon(Icons.arrow_forward_ios),
                              iconDirection: AxisDirection.right,
                              onPressed: () => pageController.nextPage(duration: Durations.medium4, curve: StaticsVar.curve),
                              child: Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text(index == widget.unit.questions.length-1 ? "检查答案" : "下一题"))),
                            ),
                          ],
                        );
                      }
                    )
                  ],
                );
              }
            ),
          )
        ],
      ),
    );
  }
}

// 这个要是要在别的地方用，请改名放到ui.dart里
class TypeChoose extends StatelessWidget {
  final Widget mainTitle;
  final Widget? subTitle;
  final double? widget;
  final double? height;
  final Function rt;
  const TypeChoose({super.key, required this.mainTitle, required this.rt, this.subTitle, this.widget, this.height});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
        fixedSize: widget != null && height != null ? Size(widget!, height!) : null,
        shape: RoundedRectangleBorder(borderRadius: StaticsVar.br),
      ),
      onPressed: () => rt(), 
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          mainTitle,
          ?subTitle,
          Row(
            children: [
              Expanded(child: SizedBox()),
              Icon(Icons.arrow_forward_ios)
            ],
          )
        ],
      )
    );
  }
}

class QuestionConfigPage extends StatefulWidget {
  final QuestionConfig qconfig;
  const QuestionConfigPage({super.key, required this.qconfig});

  @override
  State<StatefulWidget> createState() => _QuestionConfigPage();
}

class _QuestionConfigPage extends State<QuestionConfigPage> {
  final TextEditingController themeEditController = TextEditingController();
  final TextEditingController apiAddressEditController = TextEditingController();
  final TextEditingController apiKeyEditController = TextEditingController();
  final TextEditingController apiModelEditController = TextEditingController();
  final TextEditingController promptEditController = TextEditingController();
  bool adding = false;

  Future<void> processSummon(QuestionConfig qconfig) async {
    if(adding == true) return;
    setState(() {
      adding = true;
    });
    qconfig.theme = themeEditController.text == "" ? getRandomTheme() : themeEditController.text;
    switch (qconfig.sourceType) {
      case 1 : {
        String prompt = buildPrompt(qc: qconfig, useSafe: true);
        final Dio dio = Dio();
        final Options baseopt = Options(
          headers: {
            "Authorization": "Bearer ${apiKeyEditController.text}",
            "Content-Type": "application/json"
          }
        );
        try {
          final Response res = await dio.post(
            "${apiAddressEditController.text}/chat/completions",
            options: baseopt,
            data: {
              "model": apiModelEditController.text,
              "messages": [
                {"role": "system", "content": "你是一个阿拉伯语题目JSON生成器，只输出合法的JSON对象，不要使用Markdown代码块"},
                {"role": "user", "content": prompt}
              ],
              "response_format": {"type": "json_object"},
              "temperature": 0.7,
              "stream": false
            }
          );
          if(res.statusCode == 200) {
            ReadingUnit unit = ReadingUnit.buildFromMap(jsonDecode(res.data["choices"][0]["message"]["content"]), type: qconfig.testType, tashkeel: qconfig.tashkeel);
            if(unit.title.isEmpty || unit.passage.isEmpty || unit.questions.isEmpty) throw Exception("AI生成缺少部分内容");
            
            AppData().readingData.units.add(unit);
            AppData().saveReadingData();
            // ignore: use_build_context_synchronously
            if(context.mounted) alart(context, "添加成功: ${unit.title}");
          }
        } catch (e) {
          // ignore: use_build_context_synchronously
          if(context.mounted) alart(context, "生成错误: $e");
        }
        break;
      }
      case 2 : {
        promptEditController.text = buildPrompt(qc: qconfig,useSafe: false);
        showModalBottomSheet(
          context: context, 
          shape: RoundedRectangleBorder(borderRadius: StaticsVar.br, side: BorderSide(width: 1.0, color: Theme.of(context).colorScheme.onSurface)),
          builder: (context) {
            return Container(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        Text("复制以下文本，在你的AI软件中新建一个对话，将提示词粘贴进去进行生成。再将以大括号开头结尾的一段文本复制回来到导入JSON中使用。"),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.copy),
                              onPressed: (){
                                Clipboard.setData(ClipboardData(text: promptEditController.text));
                              }
                            )
                          ],
                        ),
                        TextField(
                          controller: promptEditController,
                          textDirection: TextDirection.ltr,
                          maxLines: 10,
                          decoration: InputDecoration(
                            labelText: "Prompt",
                            border: OutlineInputBorder(
                              borderRadius: StaticsVar.br,
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                            ),
                          )
                        )
                      ],
                    )
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: (){
                          Navigator.popUntil(context, (route) =>  route.isFirst);
                        }, 
                        child: Text("返回到主页")
                      ),
                      ElevatedButton(
                        onPressed: (){
                          Navigator.pop(context);
                        }, 
                        child: Text("返回重新编辑")
                      ),
                    ],
                  )
                ],
              ),
            );
          }
        );
        break;
      }
      case 3: {
        late ReadingUnit unit;
        AppData appData = AppData();
        try {
          unit = ReadingUnit.buildFromMap(jsonDecode(themeEditController.text), type: qconfig.testType, tashkeel: qconfig.tashkeel);
          if(unit.title.isEmpty) throw Exception("Unit Title is null");
          if(unit.passage.isEmpty) throw Exception("Unit Passage is null");
          if(unit.questions.isEmpty) throw Exception("Unit Questions is null");
          if(appData.readingData.units.any((testunit) => testunit.getHash() == unit.getHash())) throw Exception("Unit already exist");
        } catch (e) { 
          alart(context, e.toString());
          break;
        }
        appData.readingData.units.add(unit);
        appData.saveReadingData();
        alart(
          context, 
          "添加成功",
          onConfirmed: () => Navigator.popUntil(context, (route) => route.isFirst),
        );
      }
    }
    setState(() {
      adding = false;
    });
  }

  String getRandomTheme(){
    switch (widget.qconfig.difficulty){
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

  @override
  void dispose() {
    themeEditController.dispose();
    apiAddressEditController.dispose();
    apiKeyEditController.dispose();
    apiModelEditController.dispose();
    promptEditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        widget.qconfig.sourceType != 3 
        ? SettingItem(
          title: "题目生成配置", 
          children: [
            if(widget.qconfig.sourceType == 1) SettingRow(
              leading: "API接口地址", 
              icon: Icons.webhook,
              end: Expanded(
                child: TextField(
                  controller: apiAddressEditController,
                  maxLines: 1,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: StaticsVar.br,
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
                  )
                ),
              ),
              note: "从你的AI提供商获取，要求兼容OpenAI标准，例如DeepSeek的API地址为 https://api.deepseek.com \n如果出错，可以在地址末尾加入 /v1 尝试\n注意：末尾不要有 / "
            ),
            if(widget.qconfig.sourceType == 1) SettingRow(
              leading: "API key", 
              icon: Icons.key,
              end: Expanded(
                child: TextField(
                  controller: apiKeyEditController,
                  maxLines: 1,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: StaticsVar.br,
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
                  )
                ),
              ),
              note: "你的API Key，注意，本软件不保存你的API Key，请自行妥善保管"
            ),
            if(widget.qconfig.sourceType == 1) SettingRow(
              leading: "API模型", 
              icon: Icons.webhook,
              end: Expanded(
                child: TextField(
                  controller: apiModelEditController,
                  maxLines: 1,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: StaticsVar.br,
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
                  )
                ),
              ),
              note: "你要使用的AI模型名称，通常你的提供商会提供给你，例如: deepseek-v4-flash"
            ),
            SettingRow(
              icon: Icons.align_vertical_bottom,
              leading: "文章难度", 
              end: Slider(
                value: widget.qconfig.difficulty.toDouble(), 
                label: widget.qconfig.difficulty.toString(),
                onChanged: (double value){
                  setState(() {
                    widget.qconfig.difficulty = value.round();
                  });
                },
                min: 0,
                max: 10,
                divisions: 10,
              ),
              note: """给AI的标准是这么写的：
0-2级：词汇可能含基础生活词，句式限简单陈述句，篇幅建议50-80词;
3-4级：词汇可能含常用动词变位与介词，句式允并列句，篇幅建议80-120词;
5-6级：词汇可能含派生名词与固定搭配，句式允条件句和关系从句，篇幅建议120-160词;
7-8级：词汇可能含稀有三母简式动词，句式允长复合句和虚拟式，篇幅建议160-200词;
9-10级：词汇可能含学术术语，句式允嵌套从句和强调句，篇幅建议200-250词;""",
            ),
            SettingRow(
              icon: Icons.title,
              leading: "文章主题", 
              end: Expanded(
                child: TextField(
                  controller: themeEditController,
                  textDirection: themeEditController.text.isArabic() ? TextDirection.rtl : TextDirection.ltr,
                  maxLines: 1,
                  decoration: InputDecoration(
                    hintText: "留空自动随机",
                    border: OutlineInputBorder(
                      borderRadius: StaticsVar.br,
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
                    suffix: IconButton(
                      onPressed: (){
                        setState(() {
                          themeEditController.text = getRandomTheme();
                        });
                      }, 
                      icon: Icon(Icons.auto_awesome)
                    )
                  )
                ),
              )
            ),
            SettingRow(
              icon: Icons.web_stories,
              leading: "题目数量", 
              end: Slider(
                value: widget.qconfig.questionAmount.toDouble(), 
                label: widget.qconfig.questionAmount.toString(),
                onChanged: (double value){
                  setState(() {
                    widget.qconfig.questionAmount = value.round();
                  });
                },
                min: widget.qconfig.testType == 1 ? 2 : 10,
                max: widget.qconfig.testType == 1 ? 10 : 20,
                divisions: widget.qconfig.testType == 1 ? 8 : 10,
              )
            ),
            SettingRow(
              icon: Icons.question_mark,
              leading: "需要完整发音符号？", 
              end: Switch(
                value: widget.qconfig.tashkeel, 
                onChanged: (bool value) {
                  setState(() {
                    widget.qconfig.tashkeel = value;
                  });
                }
              )
            ),
          ]
        )
        : TextField(
          controller: themeEditController,
          textDirection: TextDirection.ltr,
          maxLines: 20,
          decoration: InputDecoration(
            hintText: "粘贴从AI工具中生成的文本",
            border: OutlineInputBorder(
              borderRadius: StaticsVar.br,
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
          )
        ),
        SizedBox(height: 20),
        Button(
          size: Size.fromHeight(100),
          icon: adding ? CircularProgressIndicator() : Icon(Icons.check),
          onPressed: () => processSummon(widget.qconfig), 
          child: Text(adding ? "添加中..." : "确认")
        )
      ],
    ) ;
  }
}

String buildPrompt({required QuestionConfig qc,required bool useSafe}) {
  late List<String> questionTags;
  switch (qc.testType) {
    case 1 : questionTags = AIPrompt.readingQuestionTags;
    case 2 : questionTags = []; // TODO
  }
  String prompt = AIPrompt.basePrompt
                  .replaceAll("{QuestionType}", qc.testType == 1 ? "阅读理解" : "完形填空")
                  .replaceAll("{Theme}", qc.theme)
                  .replaceAll("{TargetDifficulty}", qc.difficulty.toString())
                  .replaceAll(" {Tashkeel} ", qc.tashkeel ? " 有完整发音符号的 " : "")
                  .replaceAll("{QuestionAmount}", qc.questionAmount.toString())
                  .replaceAll("{QuestionTags}", questionTags.toString());
  if(useSafe){
    prompt = "$prompt\n${AIPrompt.safePrompt}";
  }
  return prompt;
}

class ReadingResultPage extends StatelessWidget {
  final ReadingUnit unit;
  final List<int?> selection;
  final List<List<String>> options;
  
  static const Interval downProgress = Interval(0.066, 0.233, curve: StaticsVar.curve);
  static const Interval slideProgress = Interval(0.233, 0.666, curve: StaticsVar.curve);
  static const Interval correctProgress = Interval(0.666, 1, curve: StaticsVar.curve);


  const ReadingResultPage({super.key, required this.unit, required this.selection, required this.options});

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);

    List<bool> correctList = [];
    for(int i = 0;i < selection.length; i++){
      correctList.add(selection[i] == null ? false : options[i][selection[i]!] == unit.questions[i].answers[0]);
    }
    double sp = 0;
    double cp = 0;
    double dp = 0;

    return Scaffold(
      appBar: AppBar(title: Text("测试结果-${unit.title}")),
      body: TweenAnimationBuilder<double>(
        tween: Tween(
          begin: 0.0,
          end: 1.0
        ), 
        curve: Curves.linear,
        duration: Duration(seconds: 3), 
        builder: (context, t, child){
          sp = slideProgress.transform(t);
          cp = correctProgress.transform(t);
          dp = downProgress.transform(t);
    
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RepaintBoundary(
                child: Transform.translate(
                  offset: Offset(0, -mediaQuery.size.height * 0.4 * (1-dp)),
                  child: Opacity(
                    opacity: dp,
                    child: SizedBox(
                      width: mediaQuery.size.width,
                      height: mediaQuery.size.height * 0.3,
                      child: Markdown(data: unit.passage, styleSheet: MarkdownStyleSheet(textScaler: TextScaler.linear(2)))
                    ),
                  ),
                ),
              ),
              Divider(),
              Expanded(
                child: ListView(
                  children: [
                    ...List.generate(
                      unit.questions.length,
                      (int index) {
                        return RepaintBoundary(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Transform.translate(
                                offset: Offset(-(mediaQuery.size.width * 0.4 * (1-(sp-1*index*(1-sp) < 0 ? 0 : sp-1*index*(1-sp)))), 0),
                                child: TextContainer(
                                  size: Size(mediaQuery.size.width * 0.4, mediaQuery.size.height * 0.2),
                                  text: "问题: \n${unit.questions[index].riddle}\n你的答案: \n${selection[index] == null ? "未选择" : options[index][selection[index]!]}",
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(mediaQuery.size.width * 0.5 * (1-(sp-1*index*(1-sp) < 0 ? 0 : sp-1*index*(1-sp))), 0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    borderRadius: StaticsVar.br
                                  ),
                                  width: mediaQuery.size.width * 0.5, 
                                  height: mediaQuery.size.height * 0.2,
                                  padding: EdgeInsets.all(16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      SizedBox(width: mediaQuery.size.width * 0.35, child: Text("正确答案: \n${unit.questions[index].answers[0]}\n解析: \n${unit.questions[index].analysis}", style: Theme.of(context).primaryTextTheme.bodyLarge)),
                                      Expanded(
                                        child: Opacity(
                                          opacity: (cp-1*index*(1-cp) < 0 ? 0 : cp-1*index*(1-cp)),
                                          child: Transform.scale(
                                            scale: 1.5 - 0.5*(cp-1*index*(1-cp) < 0 ? 0 : cp-1*index*(1-cp)),
                                            child: FittedBox(fit: BoxFit.scaleDown, child: Icon(correctList[index] ? Icons.check : Icons.clear, color: correctList[index] ? Colors.greenAccent : Colors.redAccent, size: 96))
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                    RepaintBoundary(
                      child: Opacity(
                        opacity: dp,
                        child: Button(
                          size: Size.fromHeight(mediaQuery.size.height * 0.1),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text("返回"),
                        ),
                      ),
                    )
                  ]
                ),
              ),
            ],
          );
        }
      ),
    );
  }
}