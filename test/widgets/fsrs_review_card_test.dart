import 'dart:math';

import 'package:arabic_learning/models/dict.dart' show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/screens/learning/fsrs_screens.dart' show FSRSReviewCardPage;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS, FSRSConfig;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/search.dart' show BKSearch;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

/// FSRSReviewCardPage 回归测试。
///
/// 锁定 `_FSRSReviewCardPage` 的两个历史崩溃：
/// 1. `correct` 曾以 `late final` 声明、只在首次 build（`options == null`
///    分支）赋值；作答触发 setState 重建后，新闭包读取它会抛
///    LateInitializationError（修复后每次 build 重新计算）。
/// 2. `end` 曾是 `late final DateTime`，作答赋值一次、点击详解再赋值一次，
///    第二次抛 `Field 'end' has already been initialized`（修复后改为可空、
///    可重复赋值的 `DateTime?`）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 单课程 6 词、释义互不相同：保证选择题干扰项充足，
  /// 且不会触发 `getRandomWords` 的词库过小兜底。
  List<WordItem> buildWords() => const <WordItem>[
        WordItem(arabic: 'لقاء', chinese: '相会', explanation: '见面', className: '第一课', id: 0, root: 'ل ق ي'),
        WordItem(arabic: 'كتاب', chinese: '书', explanation: '书籍', className: '第一课', id: 1, root: 'ك ت ب'),
        WordItem(arabic: 'قلم', chinese: '笔', explanation: '书写工具', className: '第一课', id: 2, root: 'ق ل م'),
        WordItem(arabic: 'مدرسة', chinese: '学校', explanation: '教育机构', className: '第一课', id: 3, root: 'د ر س'),
        WordItem(arabic: 'طالب', chinese: '学生', explanation: '学习者', className: '第一课', id: 4, root: 'ط ل ب'),
        WordItem(arabic: 'بيت', chinese: '房子', explanation: '住所', className: '第一课', id: 5, root: 'ب ي ت'),
      ];

  DictData buildDict() => DictData(
        words: buildWords(),
        classes: const <SourceItem>[
          SourceItem(
            sourceJsonFileName: 'test.json',
            displayName: '测试词库',
            subClasses: <ClassItem>[
              ClassItem(className: '第一课', wordIndexs: <int>[0, 1, 2, 3, 4, 5]),
            ],
          ),
        ],
      );

  /// 捕获父级 [StatefulBuilder] 的 setState，用于在不作答的情况下强制页面重建
  /// （`_FSRSReviewCardPageState.build` 再次执行），单独隔离 `correct` 回归。
  late StateSetter rebuildPage;

  /// 泵起非自我评级的复习卡片页。
  Future<void> pumpReviewCard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final PageController pageController = PageController();
    addTearDown(pageController.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<Global>(
        create: (BuildContext context) => Global(),
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                rebuildPage = setState;
                return FSRSReviewCardPage(
                  wordID: 0,
                  fsrs: FSRS(),
                  rnd: Random(1),
                  controller: pageController,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  setUpAll(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    // AppData 为单例：初始化一次（storage/basePath），随后每个用例重置词库与 FSRS。
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
  });

  setUp(() {
    AppData().wordData = buildDict();
    BKSearch.rebuild(AppData().wordData.words);
    // 非自我评级模式；重置 FSRS 单例，避免用例间卡片与配置串扰。
    FSRS().config = FSRSConfig(preferSimilar: false);
  });

  testWidgets('作答重建后点击详解：不抛异常且详解弹层打开', (WidgetTester tester) async {
    await pumpReviewCard(tester);

    // 作答正确项（选项包含目标词释义），触发页面 setState 重建。
    await tester.tap(find.text('相会'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '作答重建本身不应抛异常');
    expect(find.textContaining('用时:'), findsOneWidget);

    // 重建后「详解」按钮已揭示；修复前 onTipClicked 会读取未初始化的 correct
    // 或对 late final end 二次赋值。
    expect(find.text('详解'), findsOneWidget);
    await tester.tap(find.text('详解'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('我知道了'), findsOneWidget);
  });

  testWidgets('重建后作答：correct 重新计算，不抛 LateInitializationError', (WidgetTester tester) async {
    await pumpReviewCard(tester);

    // 强制 build 再次执行（等价于作答后的重建）：修复前 onSelected 闭包中的
    // correct 保持未初始化。
    rebuildPage(() {});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '重建本身不应抛异常');

    await tester.tap(find.text('相会'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('用时:'), findsOneWidget);
  });
}
