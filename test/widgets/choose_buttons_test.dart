import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/theme/tokens.dart' show AppSemanticColors;
import 'package:arabic_learning/widgets/kit.dart' show ChooseButtonBox, ChooseButtons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// 选择题判定反馈（A 徽章 / D 正误差异化 / E 选中聚焦 / F 触觉）行为测试：
/// 正确 / 错误徽章与最终落色、isAnimated=false 立即落色、ans==null 恢复初始色、
/// 单选聚焦淡化、多选 / 无动画不淡化、减弱动态效果直接落色、
/// 触觉反馈静默容错、动画有限可 pumpAndSettle、防重复作答。
void main() {
  const List<String> options = <String>['ا', 'ب', 'ت', 'ث'];

  /// 泵起一组选项按钮；[disableAnimations] 模拟系统“减弱动态效果”。
  Future<void> pumpChoose(
    WidgetTester tester, {
    required bool? Function(int index) onSelected,
    bool isShowAnimation = true,
    bool isSingleSelect = false,
    bool disableAnimations = false,
    bool lockAfterSelect = false,
    void Function(int index)? onLockedTap,
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
                      isShowAnimation: isShowAnimation,
                      isSingleSelect: isSingleSelect,
                      lockAfterSelect: lockAfterSelect,
                      onLockedTap: onLockedTap,
                      settingShowingMode: 2,
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

  ColorScheme schemeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(ChooseButtons))).colorScheme;

  /// 期望的低饱和落定色（与实现同一套语义 token 公式）。
  Color expectedJudgeColor(WidgetTester tester, {required bool correct}) {
    final ColorScheme scheme = schemeOf(tester);
    final AppSemanticColors semantic = AppSemanticColors.of(scheme);
    return Color.alphaBlend(
      (correct ? semantic.success : semantic.error).withValues(alpha: 0.20),
      scheme.surfaceContainerHighest,
    );
  }

  /// 读取某个选项容器的当前装饰色。
  Color surfaceColor(WidgetTester tester, int index) {
    final Container container = tester.widget<Container>(
      find.byKey(ValueKey<String>('chooseButtonBoxSurface-$index')),
    );
    return (container.decoration! as BoxDecoration).color!;
  }

  /// 读取选中聚焦包装层（位于按钮容器之外，避免命中 Button 内部的按压动画）。
  AnimatedOpacity dimOpacityWidget(WidgetTester tester, int index) => tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(ValueKey<String>('chooseButtonBoxSurface-$index')),
          matching: find.byType(AnimatedOpacity),
        ),
      );

  double dimOpacityOf(WidgetTester tester, int index) => dimOpacityWidget(tester, index).opacity;

  double dimScaleOf(WidgetTester tester, int index) => tester
      .widget<AnimatedScale>(
        find.ancestor(
          of: find.byKey(ValueKey<String>('chooseButtonBoxSurface-$index')),
          matching: find.byType(AnimatedScale),
        ),
      )
      .scale;

  /// 判定按钮是否处于脉冲放大 / 水平抖动中（Transform 不参与布局）。
  /// 仅当缩放大于 1（脉冲）时才计为脉冲，避免把徽章入场（0→1）误判为脉冲。
  bool hasVisiblePulse(WidgetTester tester) => tester
      .widgetList<Transform>(
        find.descendant(
          of: find.byType(ChooseButtonBox),
          matching: find.byType(Transform),
        ),
      )
      .any((Transform t) => t.transform.storage[0] > 1.001);

  bool hasHorizontalShake(WidgetTester tester) => tester
      .widgetList<Transform>(
        find.descendant(
          of: find.byType(ChooseButtonBox),
          matching: find.byType(Transform),
        ),
      )
      .any((Transform t) => t.transform.getTranslation().x.abs() > 0.001);

  Future<void> tapOption(WidgetTester tester, int index) async {
    await tester.tap(find.byType(ChooseButtonBox).at(index));
    await tester.pump();
  }

  testWidgets('正确判定：预判保持初始色，随后揭示成功色并弹入 ✓ 徽章', (WidgetTester tester) async {
    await pumpChoose(tester, onSelected: (int index) => true);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    await tapOption(tester, 0);
    // 预判阶段（<~176ms）仍保持初始色（不整块高饱和变色），且未开始脉冲。
    await tester.pump(const Duration(milliseconds: 80));
    expect(surfaceColor(tester, 0), schemeOf(tester).primaryContainer);
    expect(hasVisiblePulse(tester), isFalse);

    // 差异化阶段：正确发生轻微脉冲（不影响布局）。
    await tester.pump(const Duration(milliseconds: 560));
    expect(hasVisiblePulse(tester), isTrue);

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(surfaceColor(tester, 0), expectedJudgeColor(tester, correct: true));
    expect(hasVisiblePulse(tester), isFalse);
    expect(hasHorizontalShake(tester), isFalse);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('错误判定：揭示错误色并弹入 ✗ 徽章，水平抖动后归位', (WidgetTester tester) async {
    await pumpChoose(tester, onSelected: (int index) => false);
    await tapOption(tester, 0);

    // 差异化阶段：错误发生水平抖动，且位移不进入布局。
    await tester.pump(const Duration(milliseconds: 480));
    expect(hasHorizontalShake(tester), isTrue);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(surfaceColor(tester, 0), expectedJudgeColor(tester, correct: false));
    expect(hasHorizontalShake(tester), isFalse);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('isAnimated=false：立即落色且无徽章 / 抖动 / 淡化', (WidgetTester tester) async {
    await pumpChoose(
      tester,
      onSelected: (int index) => true,
      isShowAnimation: false,
      isSingleSelect: true,
    );
    await tapOption(tester, 0);

    // 单帧后即已落定旧语义（高饱和）正误色，不等待任何动画。
    final AppSemanticColors semantic = AppSemanticColors.of(schemeOf(tester));
    expect(surfaceColor(tester, 0), semantic.success);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(hasVisiblePulse(tester), isFalse);

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(surfaceColor(tester, 0), semantic.success);
    expect(dimOpacityOf(tester, 0), 1.0);
    expect(dimOpacityOf(tester, 1), 1.0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('ans==null：恢复初始色且不触发判定动画与聚焦', (WidgetTester tester) async {
    await pumpChoose(tester, onSelected: (int index) => null, isSingleSelect: true);
    await tapOption(tester, 0);

    expect(surfaceColor(tester, 0), schemeOf(tester).primaryContainer);
    await tester.pumpAndSettle();
    expect(surfaceColor(tester, 0), schemeOf(tester).primaryContainer);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(hasVisiblePulse(tester), isFalse);
    expect(hasHorizontalShake(tester), isFalse);
    expect(dimOpacityOf(tester, 0), 1.0);
    expect(dimOpacityOf(tester, 1), 1.0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('单选判定后：选中项保持，其余选项淡化并轻微缩小', (WidgetTester tester) async {
    await pumpChoose(tester, onSelected: (int index) => true, isSingleSelect: true);
    await tapOption(tester, 0);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(dimOpacityOf(tester, 0), 1.0);
    expect(dimScaleOf(tester, 0), 1.0);
    for(int i = 1; i < options.length; i++) {
      expect(dimOpacityOf(tester, i), 0.4);
      expect(dimScaleOf(tester, i), 0.975);
    }
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('多选：判定后不淡化，其余选项仍可继续作答且单次点击只判定一次', (WidgetTester tester) async {
    final List<int> callLog = <int>[];
    await pumpChoose(
      tester,
      onSelected: (int index) {
        callLog.add(index);
        return true;
      },
      isSingleSelect: false,
    );
    await tapOption(tester, 0);
    await tester.pumpAndSettle();
    expect(callLog, <int>[0]);

    // 已选过的按钮防重入，不再触发判定。
    await tapOption(tester, 0);
    await tester.pumpAndSettle();
    expect(callLog, <int>[0]);

    // 其余选项可继续选择，且不淡化。
    await tapOption(tester, 1);
    await tester.pumpAndSettle();
    expect(callLog, <int>[0, 1]);
    for(int i = 0; i < options.length; i++) {
      expect(dimOpacityOf(tester, i), 1.0);
    }
  });

  testWidgets('isShowAnimation=false：即使单选也不淡化', (WidgetTester tester) async {
    await pumpChoose(
      tester,
      onSelected: (int index) => false,
      isShowAnimation: false,
      isSingleSelect: true,
    );
    await tapOption(tester, 0);
    await tester.pumpAndSettle();

    for(int i = 0; i < options.length; i++) {
      expect(dimOpacityOf(tester, i), 1.0);
      expect(dimScaleOf(tester, i), 1.0);
    }
  });

  testWidgets('减弱动态效果：跳过预判 / 徽章 / 脉冲 / 抖动，直接落定结果色', (WidgetTester tester) async {
    await pumpChoose(
      tester,
      onSelected: (int index) => false,
      disableAnimations: true,
    );
    await tapOption(tester, 0);

    expect(surfaceColor(tester, 0), expectedJudgeColor(tester, correct: false));
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(hasVisiblePulse(tester), isFalse);
    expect(hasHorizontalShake(tester), isFalse);

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(surfaceColor(tester, 0), expectedJudgeColor(tester, correct: false));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('触觉反馈：正确 lightImpact / 错误 mediumImpact，且不抛异常', (WidgetTester tester) async {
    final List<MethodCall> hapticCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if(call.method == 'HapticFeedback.vibrate') hapticCalls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await pumpChoose(tester, onSelected: (int index) => index == 0);

    await tapOption(tester, 0);
    await tester.pumpAndSettle();
    expect(hapticCalls, isNotEmpty);
    expect(hapticCalls.last.arguments, 'HapticFeedbackType.lightImpact');

    await tapOption(tester, 1);
    await tester.pumpAndSettle();
    expect(hapticCalls.last.arguments, 'HapticFeedbackType.mediumImpact');
  });

  testWidgets('lockAfterSelect：首次选择后锁定全部选项并触发 onLockedTap', (WidgetTester tester) async {
    final List<int> calls = <int>[];
    final List<int> locked = <int>[];
    await pumpChoose(
      tester,
      onSelected: (int index) { calls.add(index); return true; },
      isSingleSelect: true,
      lockAfterSelect: true,
      onLockedTap: (int index) => locked.add(index),
    );

    await tapOption(tester, 0);
    await tester.pumpAndSettle();
    expect(calls, <int>[0]);

    // 已锁定：点击其它选项不再作答，只回调 onLockedTap。
    await tapOption(tester, 1);
    await tester.pumpAndSettle();
    expect(calls, <int>[0], reason: '锁定后不应再触发 onSelected');
    expect(locked, <int>[1], reason: '锁定点击应回调 onLockedTap');
    expect(tester.takeException(), isNull);
  });
}
