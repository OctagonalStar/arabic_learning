import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/memberships.dart' show WordMembership;
import 'package:arabic_learning/widgets/flip_word_card.dart' show FlipWordCard;
import 'package:arabic_learning/widgets/overlays.dart' show viewAnswer;
import 'package:arabic_learning/widgets/questions.dart' show WordCardQuestion;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// 翻卡单词卡片的行为测试：
/// 正面摘要与提示、展开后背面的全部详情、反向关闭（卡片 / 遮罩）、
/// 动画有限可 pumpAndSettle、减弱动态效果下跳过过渡、无布局异常。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const WordItem word = WordItem(
    arabic: 'يَكْتُبُ',
    chinese: '写',
    explanation: '书写；写作，用笔记录文字',
    className: '第二课',
    id: 3,
    root: 'ك ت ب',
    categories: <String>['基础'],
    pos: 'Verbs',
    plural: 'كُتُبٌ',
    gender: true,
    present: 'يَكْتُبُ',
    masdar: 'كِتَابَةٌ',
  );

  /// 泵起卡片；[disableAnimations] 模拟系统“减弱动态效果”，
  /// [textScaler] 模拟系统无障碍文字缩放。
  Future<void> pumpCard(
    WidgetTester tester, {
    required Widget child,
    Size size = const Size(400, 800),
    bool disableAnimations = false,
    TextScaler? textScaler,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<Global>(
        create: (BuildContext context) => Global(),
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              // 保留视图尺寸等既有数据，仅覆盖“减弱动态效果”开关与文字缩放。
              final MediaQueryData base = MediaQuery.of(context);
              return MediaQuery(
                data: base.copyWith(
                  disableAnimations: disableAnimations,
                  textScaler: textScaler,
                ),
                child: Scaffold(body: Center(child: child)),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 取当前遮罩色（黑色、半透明；卡片自身的不透明容器色不参与匹配）。
  Color? scrimColor(WidgetTester tester) {
    for (final ColoredBox box in tester.widgetList<ColoredBox>(find.byType(ColoredBox))) {
      if (box.color.a > 0.0 && box.color.a < 0.7) return box.color;
    }
    return null;
  }

  testWidgets('正面仅显示中文 / 解释与查看提示，不含详情字段', (WidgetTester tester) async {
    await pumpCard(tester, child: const FlipWordCard(word: word));

    expect(find.text('中文'), findsOneWidget);
    expect(find.text('写'), findsOneWidget);
    expect(find.text('解释'), findsOneWidget);
    expect(find.text('书写；写作，用笔记录文字'), findsOneWidget);
    expect(find.text('归属课程'), findsNothing, reason: '正面不显示归属信息');
    expect(find.text('点击查看更多信息'), findsOneWidget);
    // 正面不应出现详情字段
    for (final String label in <String>['词根', '词性', '复数', '阴阳性', '现在式', '动名词', '类别']) {
      expect(find.text(label), findsNothing, reason: '正面不应出现 $label');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击展开：动画有限可 pumpAndSettle，背面显示全部详情', (WidgetTester tester) async {
    await pumpCard(tester, child: const FlipWordCard(word: word));

    await tester.tap(find.text('点击查看更多信息'));
    await tester.pumpAndSettle();

    for (final String label in <String>['词根', '词性', '复数', '阴阳性', '现在式', '动名词', '类别']) {
      expect(find.text(label), findsOneWidget, reason: '背面应显示 $label');
    }
    // 归属课程只在背面出现（正面已不再显示）。
    expect(find.text('归属课程'), findsOneWidget);
    expect(find.text('动词'), findsOneWidget); // 词性中文化
    expect(find.text('阳性'), findsOneWidget);
    expect(find.text('基础'), findsOneWidget); // 类别标签
    expect(find.text('点击卡片或空白处关闭'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('展开过程中遮罩逐渐加深，结束时不透明且有界', (WidgetTester tester) async {
    await pumpCard(tester, child: const FlipWordCard(word: word));

    await tester.tap(find.text('点击查看更多信息'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final Color? mid = scrimColor(tester);
    expect(mid, isNotNull, reason: '动画半程应已绘制半透明遮罩');
    expect(mid!.a, greaterThan(0.0));
    expect(mid.a, lessThan(0.6));

    await tester.pumpAndSettle();
    final Color? end = scrimColor(tester);
    expect(end, isNotNull);
    expect(end!.a, closeTo(0.6, 0.001));
  });

  testWidgets('再次点击卡片触发反向动画关闭，回到正面', (WidgetTester tester) async {
    await pumpCard(tester, child: const FlipWordCard(word: word));

    await tester.tap(find.text('点击查看更多信息'));
    await tester.pumpAndSettle();
    expect(find.text('词根'), findsOneWidget);

    await tester.tap(find.text('点击卡片或空白处关闭'));
    await tester.pumpAndSettle();

    expect(find.text('词根'), findsNothing);
    expect(find.text('点击卡片或空白处关闭'), findsNothing);
    expect(find.text('点击查看更多信息'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击遮罩触发反向动画关闭', (WidgetTester tester) async {
    await pumpCard(tester, child: const FlipWordCard(word: word));

    await tester.tap(find.text('点击查看更多信息'));
    await tester.pumpAndSettle();
    expect(find.text('词根'), findsOneWidget);

    // 目标卡片居中且留有边距，屏幕角落一定落在遮罩上。
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.text('词根'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('减弱动态效果：跳过过渡直接展开与关闭', (WidgetTester tester) async {
    await pumpCard(tester, child: const FlipWordCard(word: word), disableAnimations: true);

    await tester.tap(find.text('点击查看更多信息'));
    await tester.pump();
    expect(find.text('词根'), findsOneWidget, reason: '跳帧后应立即呈现背面');

    await tester.tap(find.text('点击卡片或空白处关闭'));
    await tester.pump();
    expect(find.text('词根'), findsNothing, reason: '关闭同样不应有过渡');
    expect(tester.takeException(), isNull);
  });

  testWidgets('小屏展开无布局异常', (WidgetTester tester) async {
    await pumpCard(tester, child: const FlipWordCard(word: word), size: const Size(320, 480));

    await tester.tap(find.text('点击查看更多信息'));
    await tester.pumpAndSettle();
    expect(find.text('词根'), findsOneWidget);

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.text('词根'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enableFlip=false 时无提示且不展开', (WidgetTester tester) async {
    await pumpCard(tester, child: const FlipWordCard(word: word, enableFlip: false));

    expect(find.text('点击查看更多信息'), findsNothing);
    await tester.tap(find.byType(FlipWordCard));
    await tester.pumpAndSettle();
    expect(find.text('词根'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('WordCardQuestion 接入翻卡且不改变底部组件可用性', (WidgetTester tester) async {
    int taps = 0;
    await pumpCard(
      tester,
      child: WordCardQuestion(
        word: word,
        bottomWidget: TextButton(
          onPressed: () => taps++,
          child: const Text('下一题'),
        ),
      ),
    );

    expect(find.byType(FlipWordCard), findsOneWidget);
    expect(find.text('下一题'), findsOneWidget);
    await tester.tap(find.text('下一题'));
    expect(taps, 1);

    // WordCardQuestion 现已遮挡释义（masked: true），提示为「点击查看释义」。
    expect(find.text('释义已隐藏'), findsOneWidget);
    await tester.tap(find.text('点击查看释义'));
    await tester.pumpAndSettle();
    expect(find.text('词根'), findsOneWidget);
    // 展开层覆盖期间底部组件仍在原树中，推进逻辑未被改动。
    expect(find.text('下一题'), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一题'));
    expect(taps, 2);
    expect(tester.takeException(), isNull);
  });

  // ── 反面（详情）重设计：无滚动、多尺寸自适应、空字段不渲染 ──

  const WordItem bareWord = WordItem(
    arabic: 'قَلَمٌ',
    chinese: '笔',
    explanation: '',
    className: '',
    id: 7,
  );

  /// 反面应当出现的全部非空字段标签。
  const List<String> detailLabels = <String>[
    '词根', '词性', '复数', '阴阳性', '现在式', '动名词', '类别', '归属课程',
  ];

  testWidgets('startOnBack 静态卡直接展示全部详情且无滚动容器', (WidgetTester tester) async {
    await pumpCard(
      tester,
      child: const FlipWordCard(word: word, enableFlip: false, startOnBack: true),
    );

    for (final String label in detailLabels) {
      expect(find.text(label), findsOneWidget, reason: '反面应显示 $label');
    }
    expect(find.text('词形信息'), findsOneWidget);
    expect(find.text('写'), findsOneWidget);
    expect(find.text('书写；写作，用笔记录文字'), findsOneWidget);
    expect(find.text('第二课'), findsOneWidget);
    expect(find.text('动词'), findsOneWidget);
    expect(find.text('阳性'), findsOneWidget);
    // 静态反面不参与翻卡：无提示行，点击也不展开。
    expect(find.text('点击查看更多信息'), findsNothing);
    await tester.tap(find.byType(FlipWordCard));
    await tester.pumpAndSettle();
    expect(find.text('点击卡片或空白处关闭'), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing, reason: '反面详情不得使用滚动容器');
    expect(tester.takeException(), isNull);
  });

  // 反面详情在手机竖屏 / 横屏、平板双方向与网格单元尺寸下均不得溢出。
  for (final Size size in <Size>[
    const Size(360, 640),
    const Size(480, 420),
    const Size(1280, 800),
    const Size(800, 1280),
    const Size(200, 200),
    const Size(120, 120),
  ]) {
    testWidgets(
      '反面详情在 ${size.width.toInt()}x${size.height.toInt()} 下渲染无溢出且字段齐全',
      (WidgetTester tester) async {
        await pumpCard(
          tester,
          child: const FlipWordCard(word: word, enableFlip: false, startOnBack: true),
          size: size,
        );

        for (final String label in detailLabels) {
          expect(find.text(label), findsOneWidget, reason: '反面应显示 $label');
        }
        expect(find.text('写'), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsNothing, reason: '反面详情不得使用滚动容器');
        expect(tester.takeException(), isNull);
      },
    );
  }

  /// 读取 [text] 对应 [Text] 的显式字号（用于比较响应式缩放）。
  double detailFontSize(WidgetTester tester, String text) {
    return tester.widget<Text>(find.text(text)).style?.fontSize ?? 0.0;
  }

  testWidgets('反面详情在大卡片上按可用尺寸放大字号', (WidgetTester tester) async {
    const Widget card = FlipWordCard(word: word, enableFlip: false, startOnBack: true);

    // 200x200 屏幕：信息区 180x70，低于参考尺寸，缩放因子保持 1.0。
    await pumpCard(tester, child: card, size: const Size(200, 200));
    final double smallSection = detailFontSize(tester, '词形信息');
    final double smallMorph = detailFontSize(tester, '词根');
    final double smallCategory = detailFontSize(tester, '基础');
    final double smallFooter = detailFontSize(tester, '归属课程');
    final double smallChinese = detailFontSize(tester, '写');

    // 800x1280 屏幕：信息区 720x448，min(720/360, 448/260) ≈ 1.72。
    await pumpCard(tester, child: card, size: const Size(800, 1280));
    final double largeSection = detailFontSize(tester, '词形信息');
    final double largeMorph = detailFontSize(tester, '词根');
    final double largeCategory = detailFontSize(tester, '基础');
    final double largeFooter = detailFontSize(tester, '归属课程');
    final double largeChinese = detailFontSize(tester, '写');

    void expectLarger(double small, double large, String name) {
      expect(large, greaterThan(small), reason: '$name 在大卡片上应放大');
    }

    expectLarger(smallSection, largeSection, '分组标题');
    expectLarger(smallMorph, largeMorph, '词形芯片');
    expectLarger(smallCategory, largeCategory, '类别标签');
    expectLarger(smallFooter, largeFooter, '归属页脚');
    expectLarger(smallChinese, largeChinese, '释义文字');

    // 词形信息（词根 / 词性 / 复数 / 阴阳性 / 现在式 / 动名词）应明显大于
    // 说明性分组标题（当前为 +50% 放大）。
    expect(largeMorph, greaterThan(largeSection),
        reason: '词形芯片字号应大于分组标题');

    final double ratio = largeSection / smallSection;
    expect(ratio, greaterThan(1.4), reason: '大卡片上应明显放大');
    expect(ratio, lessThanOrEqualTo(2.0 + 1e-6), reason: '放大倍数不得超过上限');
    expect(tester.takeException(), isNull);
  });

  testWidgets('反面详情缩放有上限：超大可放尺寸不超过 2 倍', (WidgetTester tester) async {
    const Widget card = FlipWordCard(word: word, enableFlip: false, startOnBack: true);

    await pumpCard(tester, child: card, size: const Size(200, 200));
    final double small = detailFontSize(tester, '词形信息');

    await pumpCard(tester, child: card, size: const Size(2000, 2000));
    final double huge = detailFontSize(tester, '词形信息');

    expect(huge, closeTo(small * 2.0, 0.001), reason: '放大倍数应被钳制在 2 倍');
    expect(tester.takeException(), isNull);
  });

  testWidgets('反面详情不覆盖系统文字缩放（textScaler 叠加生效）', (WidgetTester tester) async {
    const Widget card = FlipWordCard(word: word, enableFlip: false, startOnBack: true);

    await pumpCard(tester, child: card, size: const Size(320, 480));
    final double plainStyleSize = detailFontSize(tester, '词形信息');
    final double plainHeight = tester.getSize(find.text('词形信息')).height;

    await pumpCard(
      tester,
      child: card,
      size: const Size(320, 480),
      textScaler: const TextScaler.linear(2.0),
    );
    final double scaledStyleSize = detailFontSize(tester, '词形信息');
    final double scaledHeight = tester.getSize(find.text('词形信息')).height;

    expect(scaledStyleSize, plainStyleSize, reason: '系统缩放不得写入组件显式字号');
    expect(scaledHeight, greaterThan(plainHeight * 1.5), reason: '文字缩放应叠加在组件字号上');
    expect(tester.takeException(), isNull);
  });

  testWidgets('反面详情不渲染空字段', (WidgetTester tester) async {
    await pumpCard(
      tester,
      child: const FlipWordCard(word: bareWord, enableFlip: false, startOnBack: true),
    );

    expect(find.text('笔'), findsOneWidget);
    for (final String label in <String>[...detailLabels, '词形信息']) {
      expect(find.text(label), findsNothing, reason: '$label 为空时不应渲染');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('masked 正面遮挡释义，翻卡揭示后遮挡消失', (WidgetTester tester) async {
    await pumpCard(tester, child: const FlipWordCard(word: word, masked: true));

    expect(find.text('释义已隐藏'), findsOneWidget);
    expect(find.text('点击查看释义'), findsOneWidget);
    expect(find.text('词根'), findsNothing);

    await tester.tap(find.text('点击查看释义'));
    await tester.pumpAndSettle();

    expect(find.text('释义已隐藏'), findsNothing);
    expect(find.text('词根'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('masked 静态卡（enableFlip=false）随参数揭示，不翻卡', (WidgetTester tester) async {
    bool masked = true;
    late StateSetter setLocal;
    await pumpCard(
      tester,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setter) {
          setLocal = setter;
          return FlipWordCard(
            word: word,
            enableFlip: false,
            masked: masked,
            width: 300,
            height: 500,
          );
        },
      ),
    );

    expect(find.text('释义已隐藏'), findsOneWidget);
    expect(find.text('点击查看更多信息'), findsNothing);
    expect(find.text('点击查看释义'), findsNothing);

    setLocal(() {
      masked = false;
    });
    await tester.pumpAndSettle();

    expect(find.text('释义已隐藏'), findsNothing);
    expect(find.text('写'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 词汇总览 / 查找网格单元：复用正面卡的彩色标签行，且默认可翻卡。
  for (final double side in <double>[200.0, 120.0]) {
    testWidgets(
      '网格单元 ${side.toInt()}x${side.toInt()} 使用正面标签行且可翻卡',
      (WidgetTester tester) async {
        await pumpCard(
          tester,
          child: FlipWordCard(word: word, width: side, height: side),
        );

        // 与正面卡一致：中文 / 解释标签行 + 查看提示（归属信息只在背面）。
        expect(find.text('中文'), findsOneWidget);
        expect(find.text('写'), findsOneWidget);
        expect(find.text('解释'), findsOneWidget);
        expect(find.text('书写；写作，用笔记录文字'), findsOneWidget);
        expect(find.text('归属课程'), findsNothing, reason: '正面网格卡不显示归属');
        expect(find.text('点击查看更多信息'), findsOneWidget);
        // 翻卡前不展示详情字段。
        for (final String label in <String>[
          '词根', '词性', '复数', '阴阳性', '现在式', '动名词', '类别', '词形信息',
        ]) {
          expect(find.text(label), findsNothing, reason: '正面网格卡不应出现 $label');
        }
        expect(tester.takeException(), isNull);

        // 网格卡默认允许翻卡：点击后居中放大并翻到详情面。
        await tester.tap(find.text('点击查看更多信息'));
        await tester.pumpAndSettle();
        expect(find.text('词根'), findsOneWidget);
        expect(find.text('点击卡片或空白处关闭'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.text('词根'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('viewAnswer 详解弹层直接展示反面详情且无滚动', (WidgetTester tester) async {
    await pumpCard(
      tester,
      child: Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => viewAnswer(context, word),
          child: const Text('打开详解'),
        ),
      ),
    );

    await tester.tap(find.text('打开详解'));
    await tester.pumpAndSettle();

    for (final String label in detailLabels) {
      expect(find.text(label), findsOneWidget, reason: '详解弹层应显示 $label');
    }
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('背面列出全部归属：多词库 / 多课程，词库名 › 课程名', (WidgetTester tester) async {
    await pumpCard(
      tester,
      child: const FlipWordCard(
        word: word,
        enableFlip: false,
        startOnBack: true,
        memberships: <WordMembership>[
          WordMembership(source: '词库A', course: '第一课'),
          WordMembership(source: '词库B', course: '课程一'),
        ],
      ),
    );

    expect(find.text('归属课程'), findsOneWidget);
    expect(find.text('词库A › 第一课'), findsOneWidget);
    expect(find.text('词库B › 课程一'), findsOneWidget);
    expect(find.text('第二课'), findsNothing, reason: '显式归属应覆盖旧单值 className');
    expect(tester.takeException(), isNull);
  });
}
