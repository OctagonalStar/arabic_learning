// 「计划学习」持久化单例（"planData" 键，位于 usedKeys 白名单，随备份同步）。
//
// 只保存计划配置与当日进度快照，不保存任何 word id：范围由「词库文件名 +
// 课程名」表达（见 models/plan.dart）。未 init 时 [state] 返回
// [PlanState.empty]，不会抛异常，便于连胜门禁等早期调用点安全读取。
//
// 写盘策略与 FSRS 一致：显式配置变更（[setPlan] / [clear] / [setToday]）
// 立即落盘；逐题累加的 [recordProgress] 走 400ms 防抖，避免每答一题就把整份
// `planData` 序列化写一次。防抖窗口内的内容由 [flush]（备份导出钩子、
// 退后台/隐藏/销毁的生命周期节点）兜底写入。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:logging/logging.dart';

import 'package:arabic_learning/models/plan.dart';
import 'package:arabic_learning/package_replacement/storage.dart';
import 'package:arabic_learning/services/app_data.dart';

class PlanStore {
  // 作为单例
  static final PlanStore _instance = PlanStore._internal();
  factory PlanStore() => _instance;
  PlanStore._internal();

  final Logger logger = Logger("Plan");

  /// 存储键；新增顶级键必须登记进 `SharedPreferences.usedKeys`，否则备份会丢失。
  static const String storageKey = "planData";

  /// 进度写入的防抖窗口（与 [FSRS.save] 保持一致）。
  static const Duration saveDebounce = Duration(milliseconds: 400);

  PlanState _state = PlanState.empty;
  bool _inited = false;

  /// 防抖写盘计时器：连续 [recordProgress] 只重置计时，最后一次统一落盘。
  Timer? _saveTimer;

  /// 生命周期落盘守卫（退后台/隐藏/销毁前立即写盘），只注册一次。
  AppLifecycleListener? _lifecycleListener;

  /// 是否已完成首次加载。
  bool get inited => _inited;

  /// 当前状态；未 init 时返回空状态（不抛异常）。
  PlanState get state => _inited ? _state : PlanState.empty;

  /// 是否有防抖中的写入（诊断 / 测试用）。
  bool get hasPendingWrite => _saveTimer != null;

  /// 实际写盘次数（诊断用；生产代码不应依赖它）。
  ///
  /// 测试用它断言「连续多次 [recordProgress] 只落盘一次」，
  /// 从而避免用墙钟时间做性能/合并断言。
  @visibleForTesting
  int debugWriteCount = 0;

  /// 默认空数据（供首次启动 / [clear] 写入）。
  static Map<String, dynamic> defaultData() => PlanState.empty.toMap();

  /// 从存储加载。无 `"planData"` 键时写入默认空数据。
  Future<void> init() async {
    _ensureHooks();
    final AppData appData = AppData();
    if (!appData.storage.containsKey(storageKey)) {
      logger.info("未发现计划学习数据，写入默认值");
      _state = PlanState.empty;
      _inited = true;
      await save();
      return;
    }
    // 重读前先丢弃防抖中的旧快照，否则它会在重读后把恢复出来的数据覆盖回去。
    _cancelPendingWrite();
    _loadFromStorage();
    _inited = true;
    logger.info("计划学习数据加载完成");
  }

  /// 从存储重读（备份恢复后调用），等价于 [init]。
  Future<void> reload() => init();

  /// 将当前状态写入存储。
  ///
  /// 默认立即落盘（显式配置变更必须立刻可见）；`immediate: false` 时按
  /// [saveDebounce] 合并写入，供逐题累加的 [recordProgress] 使用。
  Future<void> save({bool immediate = true}) async {
    if (!immediate) {
      _scheduleSave();
      return;
    }
    await flush();
  }

  /// 立即把内存状态写入存储（跳过防抖）。
  ///
  /// 由备份导出钩子、生命周期节点与测试调用；可等待真正落盘。
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _write();
  }

  /// 设置新计划，并清空当日快照（下次评估时按新计划重算）。
  Future<void> setPlan(StudyPlan plan) async {
    _state = PlanState(plan: plan, today: null);
    await save();
    logger.info("已保存计划学习配置: ${plan.id}");
  }

  /// 清空计划与当日快照（写默认空 JSON）。
  Future<void> clear() async {
    _state = PlanState.empty;
    await save();
    logger.info("已清空计划学习数据");
  }

  /// 累加当日完成量；`learnedDelta` 取 `max(0, delta)`，无当日快照时忽略。
  ///
  /// 每答一题都会调用，因此走防抖写入：内存立即可见，落盘合并到 400ms 后
  /// （或由 [flush] / 生命周期节点强制落盘）。
  Future<void> recordProgress(int learnedDelta) async {
    final PlanDayProgress? today = _state.today;
    if (today == null) return;
    final int delta = learnedDelta > 0 ? learnedDelta : 0;
    if (delta == 0) return;
    _state = PlanState(
      plan: _state.plan,
      today: today.copyWith(doneWords: today.doneWords + delta),
    );
    _scheduleSave();
  }

  /// 写入当日进度快照（调度层跨日重建快照 / 手动修正时使用）。
  Future<void> setToday(PlanDayProgress? today) async {
    _state = PlanState(plan: _state.plan, today: today);
    await save();
  }

  /// 登记一个 [saveDebounce] 后执行的写入（重复调用只保留最后一次）。
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDebounce, () {
      _saveTimer = null;
      unawaited(_write());
    });
  }

  void _cancelPendingWrite() {
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  /// 真正写盘。`jsonEncode` 与存储层的缓存更新都是同步完成的，
  /// 因此导出钩子（同步 API）在调用后即可读到最新值。
  ///
  /// 未 init 时不写：此时内存里只有 [PlanState.empty]，落盘会把存储中已有的
  /// `planData` 覆盖成空（早期调用点如连胜门禁可能在任何加载之前跑）。
  Future<void> _write() async {
    if (!_inited) return;
    debugWriteCount++;
    await AppData().storage.setString(storageKey, jsonEncode(_state.toMap()));
  }

  /// 注册存储层钩子：备份/导出前强制落盘（与 FSRS 共用同一份钩子列表）。
  void _ensureHooks() {
    _ensureLifecycleListener();
    SharedPreferences.addFlushHook(_flushForExport);
  }

  /// 导出钩子是同步 API：取消防抖并立即写入（底层缓存同步更新）。
  ///
  /// 未 init 时直接跳过：此时内存里只有 [PlanState.empty]，写出去会把存储中
  /// 已有的 `planData` 覆盖成空（与 FSRS 的「未加载不落盘」保持一致的防御）。
  void _flushForExport() {
    if (!_inited) return;
    _cancelPendingWrite();
    unawaited(_write());
  }

  /// 注册生命周期落盘守卫：暂停/隐藏/分离前立即写盘，避免防抖窗口内丢数据。
  /// 纯 Dart 测试环境没有初始化 WidgetsBinding，此时直接跳过（不抛异常）。
  void _ensureLifecycleListener() {
    if (_lifecycleListener != null) return;
    try {
      // 未初始化绑定时 AppLifecycleListener 的构造会抛错，纯 Dart 环境据此跳过。
      _lifecycleListener = AppLifecycleListener(
        onPause: () => unawaited(flush()),
        onHide: () => unawaited(flush()),
        onDetach: () => unawaited(flush()),
      );
    } catch (e) {
      logger.fine("非 Flutter 环境，跳过生命周期落盘守卫: $e");
    }
  }

  /// 读取并按需解码存储内容，失败时回退为空状态。
  void _loadFromStorage() {
    _state = PlanState.empty;
    try {
      final String? raw = AppData().storage.getString(storageKey);
      if (raw == null || raw.isEmpty) return;
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _state = PlanState.fromMap(Map<String, dynamic>.from(decoded));
    } catch (e) {
      logger.severe("计划学习数据解析失败: $e");
      _state = PlanState.empty;
    }
  }
}
