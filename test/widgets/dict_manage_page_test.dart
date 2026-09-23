import 'package:arabic_learning/models/dict.dart' show ClassItem, DictData, SourceItem, WordItem;
import 'package:arabic_learning/screens/setting/dict_manage_page.dart' show DictManagePage;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/fsrs.dart' show FSRS, FSRSConfig;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/services/memberships.dart' show WordMembershipIndex;
import 'package:arabic_learning/services/search.dart' show BKSearch;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/test_env.dart';

/// 词库管理页回归测试：列表展示、删除（仅解绑）确认流程。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DictData buildDict() {
    return const DictData(
      words: <WordItem>[
        WordItem(arabic: 'كتاب', chinese: '书', explanation: '', className: '第一课', id: 0),
        WordItem(arabic: 'قلم', chinese: '笔', explanation: '', className: '第一课', id: 1),
      ],
      classes: <SourceItem>[
        SourceItem(
          sourceJsonFileName: 'a.json',
          displayName: '词库A',
          subClasses: <ClassItem>[
            ClassItem(className: '第一课', wordIndexs: <int>[0, 1]),
          ],
        ),
      ],
    );
  }

  setUpAll(() async {
    mockPathProvider();
    mockStorage(<String, Object>{});
    await AppData().init();
    if (AppData().isFirstStart) {
      await AppData().initStorageValue();
    }
    FSRS().init();
  });

  setUp(() {
    AppData().wordData = buildDict();
    FSRS().config = FSRSConfig();
    BKSearch.rebuild(AppData().wordData.words);
    WordMembershipIndex.instance.rebuild(AppData().wordData.classes);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<Global>(
        create: (BuildContext context) => Global(),
        child: const MaterialApp(home: DictManagePage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('展示已安装词库及词条/课程数量', (WidgetTester tester) async {
    await pumpPage(tester);

    expect(find.text('词库管理'), findsOneWidget);
    expect(find.text('词库A'), findsOneWidget);
    expect(find.text('词条 2 · 课程 1'), findsOneWidget);
    expect(find.text('线上下载'), findsOneWidget);
    expect(find.text('文件导入'), findsOneWidget);
    expect(find.text('修复/重建索引'), findsOneWidget);
    expect(find.text('清理未归属词条'), findsOneWidget);
    expect(find.text('重置词库（保留复习进度）'), findsOneWidget);
  });

  testWidgets('删除词库需确认，确认后解除归属并保留词条', (WidgetTester tester) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('删除词库'));
    await tester.pumpAndSettle();
    expect(find.text('删除词库「词库A」？'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(AppData().wordData.classes, isEmpty);
    expect(AppData().wordData.words.length, 2, reason: '仅解绑，词条本体保留');
    expect(find.text('暂无词库，请在下方导入'), findsOneWidget);
  });
}
