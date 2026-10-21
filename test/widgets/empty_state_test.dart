// 空态回归测试：词库为空 / 检索无结果 / 课程选择为空。
//
// - 词库为空时进入单词总览页，应弹出明确的引导对话框（含「去导入词库」主按钮），
//   而不是只留一面空白或一闪而过的 snackbar。
// - 检索无结果时应有明确的「没有找到」空态文案。
// - 课程选择页在课程列表为空时应显示可理解的空态与操作入口。
import 'package:arabic_learning/models/dict.dart' show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/screens/learning/learning_pages_build.dart'
    show WordCardOverViewPage;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS, FSRSConfig;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/search.dart' show BKSearch;
import 'package:arabic_learning/widgets/class_select.dart' show ClassSelectPage;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
    FSRS().init();
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<Global>(
        create: (BuildContext context) => Global(),
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('词库为空的引导弹窗', () {
    testWidgets('进入单词总览页弹出对话框且主按钮存在', (WidgetTester tester) async {
      AppData().wordData = const DictData(words: [], classes: []);
      FSRS().config = FSRSConfig();
      BKSearch.rebuild(AppData().wordData.words);

      await pumpPage(tester, const WordCardOverViewPage());

      expect(find.text('还没有词库'), findsOneWidget);
      expect(find.text('去导入词库'), findsOneWidget,
          reason: '空态对话框应提供跳转词库导入的主按钮');
      expect(find.text('稍后'), findsOneWidget);
      expect(find.text('单词总览'), findsOneWidget,
          reason: '对话框之下应仍是总览页本体，而非空白页');
    });

    testWidgets('点击「稍后」关闭对话框且不再重复弹出', (WidgetTester tester) async {
      AppData().wordData = const DictData(words: [], classes: []);
      FSRS().config = FSRSConfig();
      BKSearch.rebuild(AppData().wordData.words);

      await pumpPage(tester, const WordCardOverViewPage());
      await tester.tap(find.text('稍后'));
      await tester.pumpAndSettle();

      expect(find.text('还没有词库'), findsNothing);
      expect(find.text('单词总览'), findsOneWidget);
    });
  });

  group('检索无结果空态', () {
    testWidgets('检索无命中时显示「没有找到」文案与建议', (WidgetTester tester) async {
      AppData().wordData = const DictData(
        words: <WordItem>[
          WordItem(arabic: 'كتاب', chinese: '书', explanation: '', className: '第一课', id: 0),
        ],
        classes: <SourceItem>[
          SourceItem(
            sourceJsonFileName: 'a.json',
            displayName: '词库A',
            subClasses: <ClassItem>[ClassItem(className: '第一课', wordIndexs: <int>[0])],
          ),
        ],
      );
      FSRS().config = FSRSConfig();
      BKSearch.rebuild(AppData().wordData.words);

      await pumpPage(tester, const WordCardOverViewPage());

      // 进入检索并提交一个不存在的词。
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '不存在的词');
      await tester.tap(find.text('查找'));
      await tester.pumpAndSettle();

      expect(find.textContaining('没有找到'), findsOneWidget,
          reason: '检索无命中时应有明确的空态文案而非空白列表');
      expect(find.text('可以换一个关键词，或调整筛选条件后重试'), findsOneWidget);
    });
  });

  group('课程选择空态', () {
    testWidgets('课程列表为空时显示空态文案（无跳转回调时不给按钮）', (WidgetTester tester) async {
      AppData().wordData = const DictData(words: [], classes: []);
      FSRS().config = FSRSConfig();
      BKSearch.rebuild(AppData().wordData.words);

      await pumpPage(tester, const ClassSelectPage(withReviewChoose: false));

      expect(find.text('还没有可选择的课程，请先导入词库'), findsOneWidget,
          reason: '课程列表为空时应给出可理解的空态文案');
      // 跳转由调用方通过 onImportDict 注入；未注入时不渲染无效按钮。
      expect(find.text('去导入词库'), findsNothing);
    });

    testWidgets('传入 onImportDict 时渲染「去导入词库」入口', (WidgetTester tester) async {
      AppData().wordData = const DictData(words: [], classes: []);
      FSRS().config = FSRSConfig();
      BKSearch.rebuild(AppData().wordData.words);

      await pumpPage(
        tester,
        ClassSelectPage(withReviewChoose: false, onImportDict: () {}),
      );

      expect(find.text('还没有可选择的课程，请先导入词库'), findsOneWidget);
      expect(find.text('去导入词库'), findsOneWidget,
          reason: '空态应提供跳转词库导入的操作入口');
    });
  });
}
