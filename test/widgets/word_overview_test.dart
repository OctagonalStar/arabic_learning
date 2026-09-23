import 'package:arabic_learning/models/dict.dart' show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/screens/learning/learning_pages_build.dart' show WordCardOverViewPage;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS, FSRSConfig;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/search.dart' show BKSearch;
import 'package:arabic_learning/widgets/flip_word_card.dart' show FlipWordCard;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

/// 词汇总览页回归测试。
///
/// - #1：设置弹层曾嵌套 `BottomSheet`，叠加主题的 `showDragHandle` 后出现两条
///   拖拽横条；修复后只应存在一条（modal 自身）。
/// - #2：展开靠后的课程曾因固定像素 `animateTo` + 预留空白，把展开行顶出屏幕；
///   修复后展开内容应保持在视口内。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const int sourceCount = 12;
  const int wordsPerClass = 6;

  DictData buildDict() {
    final List<WordItem> words = <WordItem>[];
    final List<SourceItem> sources = <SourceItem>[];
    for (int s = 0; s < sourceCount; s++) {
      final List<int> idx = <int>[];
      for (int w = 0; w < wordsPerClass; w++) {
        final int id = s * wordsPerClass + w;
        idx.add(id);
        words.add(WordItem(
          arabic: 'كلمة$id',
          chinese: '词$id',
          explanation: '解释$id',
          className: '课程$s',
          id: id,
        ));
      }
      sources.add(SourceItem(
        sourceJsonFileName: 'src$s.json',
        displayName: '词库$s',
        subClasses: <ClassItem>[ClassItem(className: '课程$s', wordIndexs: idx)],
      ));
    }
    return DictData(words: words, classes: sources);
  }

  setUpAll(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
  });

  setUp(() {
    AppData().wordData = buildDict();
    FSRS().config = FSRSConfig();
    BKSearch.rebuild(AppData().wordData.words);
  });

  Future<void> pumpOverview(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<Global>(
        create: (BuildContext context) => Global(),
        child: const MaterialApp(home: WordCardOverViewPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('设置弹层只有一条拖拽横条（单个 BottomSheet）', (WidgetTester tester) async {
    await pumpOverview(tester);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsOneWidget,
        reason: '不应嵌套第二个 BottomSheet（会多出一条拖拽横条）');
    expect(find.text('设置固定列数'), findsOneWidget);
  });

  testWidgets('展开靠后的课程后，展开内容不会跑到屏幕上方之外', (WidgetTester tester) async {
    await pumpOverview(tester);

    // 滚到底部，确保最后一个词库行完整可见后再展开。
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
    await tester.pumpAndSettle();

    final Finder lastSource = find.text('词库${sourceCount - 1}');
    await tester.ensureVisible(lastSource);
    await tester.pumpAndSettle();
    await tester.tap(lastSource);
    await tester.pumpAndSettle();

    // 回归：旧实现 animateTo 固定像素会把展开行顶到屏幕上方之外（top < 0）。
    final Finder classTile = find.text('课程${sourceCount - 1}');
    final Rect classRect = tester.getRect(classTile);
    expect(classRect.top, greaterThanOrEqualTo(0.0),
        reason: '展开的课程行不应位于屏幕上方之外');

    // 滚动到班级行再展开，网格内容应正常渲染且无溢出异常。
    await tester.ensureVisible(classTile);
    await tester.pumpAndSettle();
    await tester.tap(classTile);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(FlipWordCard), findsWidgets);
  });
}
