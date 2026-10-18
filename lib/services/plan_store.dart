// 「计划学习」持久化单例（"planData" 键，位于 usedKeys 白名单，随备份同步）。
//
// 只保存计划配置与当日进度快照，不保存任何 word id：范围由「词库文件名 +
// 课程名」表达（见 models/plan.dart）。未 init 时 [state] 返回
// [PlanState.empty]，不会抛异常，便于连胜门禁等早期调用点安全读取。

import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:arabic_learning/models/plan.dart';
import 'package:arabic_learning/services/app_data.dart';

class PlanStore {
  // 作为单例
  static final PlanStore _instance = PlanStore._internal();
  factory PlanStore() => _instance;
  PlanStore._internal();

  final Logger logger = Logger("Plan");

  /// 存储键；新增顶级键必须登记进 `SharedPreferences.usedKeys`，否则备份会丢失。
  static const String storageKey = "planData";

  PlanState _state = PlanState.empty;
  bool _inited = false;

  /// 是否已完成首次加载。
  bool get inited => _inited;

  /// 当前状态；未 init 时返回空状态（不抛异常）。
  PlanState get state => _inited ? _state : PlanState.empty;

  /// 默认空数据（供首次启动 / [clear] 写入）。
  static Map<String, dynamic> defaultData() => PlanState.empty.toMap();

  /// 从存储加载。无 `"planData"` 键时写入默认空数据。
  Future<void> init() async {
    final AppData appData = AppData();
    if (!appData.storage.containsKey(storageKey)) {
      logger.info("未发现计划学习数据，写入默认值");
      _state = PlanState.empty;
      _inited = true;
      await save();
      return;
    }
    _loadFromStorage();
    _inited = true;
    logger.info("计划学习数据加载完成");
  }

  /// 从存储重读（备份恢复后调用），等价于 [init]。
  Future<void> reload() => init();

  /// 将当前状态写入存储。
  Future<void> save() async {
    await AppData().storage.setString(storageKey, jsonEncode(_state.toMap()));
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
  Future<void> recordProgress(int learnedDelta) async {
    final PlanDayProgress? today = _state.today;
    if (today == null) return;
    final int delta = learnedDelta > 0 ? learnedDelta : 0;
    if (delta == 0) return;
    _state = PlanState(
      plan: _state.plan,
      today: today.copyWith(doneWords: today.doneWords + delta),
    );
    await save();
  }

  /// 写入当日进度快照（调度层跨日重建快照 / 手动修正时使用）。
  Future<void> setToday(PlanDayProgress? today) async {
    _state = PlanState(plan: _state.plan, today: today);
    await save();
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
