import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/services/global_state.dart' show Global;
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

  /// 泵起卡片；[disableAnimations] 模拟系统“减弱动态效果”。
  Future<void> pumpCard(
    WidgetTester tester, {
    required Widget child,
    Size size = const Size(400, 800),
    bool disableAnimations = false,
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
              // 保留视图尺寸等既有数据，仅覆盖“减弱动态效果”开关。
              final MediaQueryData base = MediaQuery.of(context);
              return MediaQuery(
                data: base.copyWith(disableAnimations: disableAnimations),
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

  testWidgets('正面仅显示中文 / 解释 / 归属与查看提示，不含详情字段', (WidgetTester tester) async {
    await pumpCard(tester, child: const FlipWordCard(word: word));

    expect(find.text('中文'), findsOneWidget);
    expect(find.text('写'), findsOneWidget);
    expect(find.text('解释'), findsOneWidget);
    expect(find.text('书写；写作，用笔记录文字'), findsOneWidget);
    expect(find.text('归属课程'), findsOneWidget);
    expect(find.text('第二课'), findsOneWidget);
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
    // 原位正面仍以透明态保留在树中，归属课程在正面 / 背面各有一处。
    expect(find.text('归属课程'), findsNWidgets(2));
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

    await tester.tap(find.text('点击查看更多信息'));
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
        expect(tester.takeException(), isNull);
      },
    );
  }

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

  // compact 用于词汇总览 / 查找网格单元：尺寸由网格决定，必须不溢出。
  for (final double side in <double>[200.0, 120.0]) {
    testWidgets(
      'compact 单元 ${side.toInt()}x${side.toInt()} 显示精简信息且不可翻卡',
      (WidgetTester tester) async {
        await pumpCard(
          tester,
          child: FlipWordCard(
            word: word,
            compact: true,
            enableFlip: false,
            width: side,
            height: side,
          ),
        );

        expect(find.text('写'), findsOneWidget);
        expect(find.text('书写；写作，用笔记录文字'), findsOneWidget);
        expect(find.text('第二课'), findsOneWidget);
        for (final String label in <String>[...detailLabels, '词形信息', '点击查看更多信息']) {
          expect(find.text(label), findsNothing, reason: '紧凑体不应出现 $label');
        }

        await tester.tap(find.byType(FlipWordCard));
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
}
