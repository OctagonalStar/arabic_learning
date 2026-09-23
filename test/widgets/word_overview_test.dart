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

  testWidgets('搜索页 Scaffold 不随输入法收缩（resizeToAvoidBottomInset == false）', (WidgetTester tester) async {
    await pumpOverview(tester);

    // 回归：默认 true 时键盘弹出会压缩 body，网格 LayoutBuilder 按更矮的
    // 高度重算 cell 尺寸，导致搜索结果卡片整体缩小 / 重排。
    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.resizeToAvoidBottomInset, isFalse,
        reason: '键盘弹出不应改变页面可用高度（不得重排词卡网格）');
  });

  testWidgets('进入搜索聚焦输入框；打开词卡并关闭后输入框不再聚焦', (WidgetTester tester) async {
    await pumpOverview(tester);

    // 点击 FAB 进入搜索：输入框应获得焦点（等价于旧 autofocus 行为）。
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    final FocusNode? focusNode = field.focusNode;
    expect(focusNode, isNotNull, reason: '搜索输入框应由页面显式管理 FocusNode');
    expect(focusNode!.hasFocus, isTrue, reason: '进入搜索应自动聚焦输入框');

    // 触发检索，渲染出结果词卡。
    await tester.enterText(find.byType(TextField), 'كلمة0');
    await tester.pump();
    await tester.tap(find.text('查找'));
    await tester.pumpAndSettle();
    expect(find.byType(FlipWordCard), findsWidgets, reason: '检索应至少渲染一个结果词卡');

    // 打开词卡：应先收起输入法（清焦点）。
    await tester.tap(find.byType(FlipWordCard).first);
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse, reason: '打开词卡时应取消输入框焦点（收起 IME）');

    // 点击遮罩关闭展开层：焦点不应自动回到输入框，否则 IME 会重新弹出。
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse, reason: '关闭词卡后输入框不应重新获得焦点（IME 不重新弹出）');
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
