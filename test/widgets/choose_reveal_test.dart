// 选择题释义揭示与长按卡片浮层行为测试：
// 长按回调传对应词条、作答前无释义行、答对（多选）/ 锁定（单选）后全部
// 释义行平滑揭示、optionWords 为 null 时功能禁用（不揭示且保持旧淡化）、
// 减弱动态效果直接呈现释义且无动画残留。
import 'package:arabic_learning/models/dict.dart' show WordItem;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/widgets/kit.dart' show ChooseButtonBox, ChooseButtons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  // 选项与词条一一对应：0/1 为阿语选项（揭示中文），2/3 为中文选项（揭示阿语）。
  final List<WordItem> words = <WordItem>[
    const WordItem(arabic: 'كتاب', chinese: '书', explanation: '', className: '测试', id: 0),
    const WordItem(arabic: 'قلم', chinese: '笔', explanation: '', className: '测试', id: 1),
    const WordItem(arabic: 'مندى', chinese: '门', explanation: '', className: '测试', id: 2),
    const WordItem(arabic: 'نار', chinese: '火', explanation: '', className: '测试', id: 3),
  ];
  // 选项文本与 words 对应：0/1 阿语原文，2/3 中文释义（模拟中译阿 / 阿译中混合）。
  const List<String> options = <String>['كتاب', 'قلم', '门', '火'];

  /// 泵起一组带词条的选项按钮；[disableAnimations] 模拟系统“减弱动态效果”。
  Future<void> pumpChoose(
    WidgetTester tester, {
    required bool? Function(int index) onSelected,
    bool isSingleSelect = false,
    bool lockAfterSelect = false,
    bool disableAnimations = false,
    List<WordItem>? optionWords,
    void Function(WordItem word)? onOptionLongPress,
  }) async {
    tester.view.physicalSize = const Size(800, 600);
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
                child: Scaffold(
                  body: Center(
                    child: ChooseButtons(
                      options: options,
                      onSelected: onSelected,
                      isShowAnimation: true,
                      isSingleSelect: isSingleSelect,
                      lockAfterSelect: lockAfterSelect,
                      settingShowingMode: 2,
                      optionWords: optionWords,
                      onOptionLongPress: onOptionLongPress,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 释义行目标文本：阿语选项揭示中文释义，中文选项揭示阿语原文。
  List<String> expectedSubtitles() => <String>[
        words[0].chinese, // 'كتاب' -> '书'
        words[1].chinese, // 'قلم' -> '笔'
        words[2].arabic, // '门' -> 'مندى'
        words[3].arabic, // '火' -> 'نار'
      ];

  Future<void> tapOption(WidgetTester tester, int index) async {
    await tester.tap(find.byType(ChooseButtonBox).at(index));
    await tester.pump();
  }

  testWidgets('长按选项：onOptionLongPress 收到对应词条，且不影响正常点击作答', (WidgetTester tester) async {
    final List<WordItem> pressed = <WordItem>[];
    final List<int> selected = <int>[];
    await pumpChoose(
      tester,
      onSelected: (int index) {
        selected.add(index);
        return true;
      },
      optionWords: words,
      onOptionLongPress: (WordItem word) => pressed.add(word),
    );

    await tester.longPress(find.byType(ChooseButtonBox).at(2));
    await tester.pumpAndSettle();
    expect(pressed, <WordItem>[words[2]]);

    // 正常点击仍然作答，不受长按手势包装影响。
    await tapOption(tester, 1);
    await tester.pumpAndSettle();
    expect(selected, <int>[1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未提供 onOptionLongPress 时不响应长按', (WidgetTester tester) async {
    final List<WordItem> pressed = <WordItem>[];
    await pumpChoose(
      tester,
      onSelected: (int index) => true,
      optionWords: words,
      // 显式不传 onOptionLongPress。
    );
    await tester.longPress(find.byType(ChooseButtonBox).at(0));
    await tester.pumpAndSettle();
    expect(pressed, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('作答前：不渲染任何释义行', (WidgetTester tester) async {
    await pumpChoose(tester, onSelected: (int index) => true, optionWords: words);
    for(final String subtitle in expectedSubtitles()) {
      expect(find.text(subtitle), findsNothing);
    }
    await tester.pumpAndSettle();
    for(final String subtitle in expectedSubtitles()) {
      expect(find.text(subtitle), findsNothing);
    }
  });

  testWidgets('多选答对：全部选项释义行揭示（阿语选项显示中文，中文选项显示阿语）', (WidgetTester tester) async {
    await pumpChoose(tester, onSelected: (int index) => index == 0, optionWords: words);

    // 答错（index 1 返回 false）不揭示。
    await tapOption(tester, 1);
    await tester.pumpAndSettle();
    expect(find.text(words[1].chinese), findsNothing);

    // 答对（index 0 返回 true）后全部揭示。
    await tapOption(tester, 0);
    await tester.pumpAndSettle();
    expect(find.text(words[0].chinese), findsOneWidget);
    expect(find.text(words[1].chinese), findsOneWidget);
    expect(find.text(words[2].arabic), findsOneWidget);
    expect(find.text(words[3].arabic), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('答对后释义行高度平滑增长：存在过渡而非瞬间撑开', (WidgetTester tester) async {
    await pumpChoose(tester, onSelected: (int index) => index == 0, optionWords: words);
    await tester.pumpAndSettle();

    final Finder surface = find.byKey(const ValueKey<String>('chooseButtonBoxSurface-3'));
    final double before = tester.getSize(surface).height;

    await tester.tap(find.byType(ChooseButtonBox).at(0));
    await tester.pump();
    final double start = tester.getSize(surface).height;
    await tester.pump(const Duration(milliseconds: 90));
    final double mid = tester.getSize(surface).height;
    await tester.pumpAndSettle();
    final double settled = tester.getSize(surface).height;

    expect(settled, greaterThan(before), reason: '揭示后容器应增高容纳释义行');
    expect(start, lessThan(settled), reason: '揭示首帧不应直接到达终态');
    expect(mid, greaterThan(start), reason: '高度应在动画过程中持续增长');
    expect(mid, lessThan(settled), reason: '90ms 时应仍处于过渡中');
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('单选锁定：首次作答即使答错也揭示全部释义行', (WidgetTester tester) async {
    final List<int> locked = <int>[];
    await pumpChoose(
      tester,
      onSelected: (int index) => false,
      isSingleSelect: true,
      lockAfterSelect: true,
      optionWords: words,
    );

    await tapOption(tester, 0);
    await tester.pumpAndSettle();
    for(final String subtitle in expectedSubtitles()) {
      expect(find.text(subtitle), findsOneWidget);
    }

    // 锁定后点击其余选项只触发 onLockedTap（由旧测试覆盖），这里验证锁定回调仍可用。
    await tapOption(tester, 1);
    await tester.pumpAndSettle();
    // 锁定行为不因释义行改变：无异常即通过。
    expect(tester.takeException(), isNull);
    expect(locked, isEmpty); // 未传 onLockedTap，仅确认无异常。
  });

  testWidgets('optionWords 为 null：判定后不揭示释义行，且保持旧的聚焦淡化行为', (WidgetTester tester) async {
    await pumpChoose(
      tester,
      onSelected: (int index) => true,
      isSingleSelect: true,
      lockAfterSelect: true,
    );
    await tapOption(tester, 0);
    await tester.pumpAndSettle();

    for(final String subtitle in expectedSubtitles()) {
      expect(find.text(subtitle), findsNothing);
    }
    // 未提供词条数据时保持旧行为：其余选项聚焦淡化 0.4。
    final AnimatedOpacity dim = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('chooseButtonBoxSurface-1')),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(dim.opacity, 0.4);
  });

  testWidgets('单选锁定 + optionWords：揭示期间不淡化其余选项，保证释义可读', (WidgetTester tester) async {
    await pumpChoose(
      tester,
      onSelected: (int index) => true,
      isSingleSelect: true,
      lockAfterSelect: true,
      optionWords: words,
    );
    await tapOption(tester, 0);
    await tester.pumpAndSettle();

    for(int i = 1; i < options.length; i++) {
      final AnimatedOpacity dim = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(ValueKey<String>('chooseButtonBoxSurface-$i')),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(dim.opacity, 1.0, reason: '释义揭示期间选项 $i 不应被淡化');
      expect(find.text(expectedSubtitles()[i]), findsOneWidget);
    }
  });

  testWidgets('减弱动态效果：判定后释义行直接呈现，无动画残留', (WidgetTester tester) async {
    await pumpChoose(
      tester,
      onSelected: (int index) => true,
      optionWords: words,
      disableAnimations: true,
    );
    await tapOption(tester, 0);
    // 不做 pumpAndSettle：单帧后即应呈现终态。
    await tester.pump();
    for(final String subtitle in expectedSubtitles()) {
      expect(find.text(subtitle), findsOneWidget);
    }
    expect(tester.hasRunningAnimations, isFalse);
  });
}
