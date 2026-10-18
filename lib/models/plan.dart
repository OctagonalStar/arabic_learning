// 「计划学习」数据模型：PlanScopeRef / PlanChain / StudyPlan / PlanDayProgress / PlanState
//
// 纯数据、不可变，且**不保存任何 word id**：学习范围以「词库文件名 + 课程名」
// （[PlanScopeRef]）表达，因此词库重排 / 合并后仍然有效，只会在课程失效时
// 由调度层判定 `invalidScope`。
//
// 本文件不依赖 Flutter，便于后台 isolate 复用。

/// 计划范围内的单个课程引用（`SourceItem.sourceJsonFileName` + `ClassItem.className`）。
class PlanScopeRef {
  /// 词库文件名（`SourceItem.sourceJsonFileName`）
  final String sourceFile;

  /// 课程名（`ClassItem.className`）
  final String className;

  const PlanScopeRef({required this.sourceFile, required this.className});

  factory PlanScopeRef.fromMap(Map<String, dynamic> map) {
    final dynamic source = map["sourceFile"];
    final dynamic name = map["className"];
    return PlanScopeRef(
      sourceFile: source is String ? source : "",
      className: name is String ? name : "",
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        "sourceFile": sourceFile,
        "className": className,
      };

  /// 去重键：用 NUL 分隔，避免文件名 / 课程名中恰好含分隔符时串键。
  String get key => "$sourceFile\u0000$className";

  @override
  bool operator ==(Object other) => other is PlanScopeRef && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => "$sourceFile/$className";
}

/// 学习链条：一次学习会话依次经过的题型，以及组内是否乱序。
///
/// 题型编号与项目既有约定一致：0 单词卡片、1 中译阿选择、2 阿译中选择、
/// 3 中译阿拼写、4 听力。
class PlanChain {
  /// 题型序列（0..4）
  final List<int> sections;

  /// 同一组内的单词是否乱序
  final bool shuffleWithinSection;

  const PlanChain({
    this.sections = const [0, 2],
    this.shuffleWithinSection = false,
  });

  /// 是否包含非卡片题型（1/2/3/4）。只有 `[0]` 的链条视为无效。
  bool get hasNonCardType =>
      sections.any((int type) => type >= 1 && type <= 4);

  /// 链条是否可用：非空、题型全部合法且至少含一个非卡片题型。
  bool get isValid =>
      sections.isNotEmpty &&
      sections.every((int type) => type >= 0 && type <= 4) &&
      hasNonCardType;

  PlanChain copyWith({List<int>? sections, bool? shuffleWithinSection}) {
    return PlanChain(
      sections: List<int>.unmodifiable(
        _normalizeSections(sections ?? this.sections),
      ),
      shuffleWithinSection: shuffleWithinSection ?? this.shuffleWithinSection,
    );
  }

  factory PlanChain.fromMap(Map<String, dynamic> map) {
    final dynamic raw = map["sections"];
    final List<int> parsed = raw is List ? raw.whereType<int>().toList(growable: false) : const <int>[];
    return PlanChain(
      sections: List<int>.unmodifiable(_normalizeSections(parsed)),
      shuffleWithinSection: map["shuffleWithinSection"] == true,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        "sections": List<int>.of(sections),
        "shuffleWithinSection": shuffleWithinSection,
      };

  /// 清洗题型：丢弃越界值；全部非法 / 为空时回退到默认 `[0, 2]`。
  static List<int> _normalizeSections(List<int> raw) {
    final List<int> filtered =
        raw.where((int type) => type >= 0 && type <= 4).toList(growable: false);
    return filtered.isEmpty ? const <int>[0, 2] : filtered;
  }
}

/// 一条「计划学习」配置。
class StudyPlan {
  /// 周期标识，创建时用毫秒时间戳字符串
  final String id;

  /// 截止日期（本地零点，不含当日）。最后学习日 = deadline 前一天。
  final DateTime deadline;

  /// 学习范围（课程引用，顺序即默认学习顺序）
  final List<PlanScopeRef> scope;

  /// 每组单词数（1..50）
  final int groupSize;

  /// 学习链条
  final PlanChain chain;

  /// 是否打乱课程顺序（每天按日期种子稳定）
  final bool shuffleClasses;

  /// 是否介入连胜（当日最低量未达标时不记录连胜）
  final bool streakGate;

  /// 创建当天的日期键（yyyyMMdd）
  final int configuredDayKey;

  StudyPlan({
    required this.id,
    required DateTime deadline,
    required List<PlanScopeRef> scope,
    int groupSize = 10,
    this.chain = const PlanChain(),
    this.shuffleClasses = false,
    this.streakGate = false,
    int configuredDayKey = 0,
  })  : deadline = DateTime(deadline.year, deadline.month, deadline.day),
        scope = _normalizeScope(scope),
        groupSize = _normalizeGroupSize(groupSize),
        configuredDayKey = configuredDayKey < 0 ? 0 : configuredDayKey;

  StudyPlan copyWith({
    String? id,
    DateTime? deadline,
    List<PlanScopeRef>? scope,
    int? groupSize,
    PlanChain? chain,
    bool? shuffleClasses,
    bool? streakGate,
    int? configuredDayKey,
  }) {
    return StudyPlan(
      id: id ?? this.id,
      deadline: deadline ?? this.deadline,
      scope: scope ?? this.scope,
      groupSize: groupSize ?? this.groupSize,
      chain: chain ?? this.chain,
      shuffleClasses: shuffleClasses ?? this.shuffleClasses,
      streakGate: streakGate ?? this.streakGate,
      configuredDayKey: configuredDayKey ?? this.configuredDayKey,
    );
  }

  factory StudyPlan.fromMap(Map<String, dynamic> map) {
    final dynamic rawId = map["id"];
    final DateTime? parsedDeadline = _parseDate(map["deadline"]);
    if (rawId is! String || rawId.isEmpty || parsedDeadline == null) {
      throw const FormatException("计划数据缺少必要字段");
    }

    final List<PlanScopeRef> scope = <PlanScopeRef>[];
    final dynamic rawScope = map["scope"];
    if (rawScope is List) {
      for (final dynamic item in rawScope) {
        if (item is Map) {
          scope.add(PlanScopeRef.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final dynamic rawChain = map["chain"];
    final dynamic rawGroupSize = map["groupSize"];
    final dynamic rawConfiguredDay = map["configuredDayKey"];
    return StudyPlan(
      id: rawId,
      deadline: parsedDeadline,
      scope: scope,
      groupSize: rawGroupSize is int ? rawGroupSize : 10,
      chain: rawChain is Map
          ? PlanChain.fromMap(Map<String, dynamic>.from(rawChain))
          : const PlanChain(),
      shuffleClasses: map["shuffleClasses"] == true,
      streakGate: map["streakGate"] == true,
      configuredDayKey: rawConfiguredDay is int ? rawConfiguredDay : 0,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        "id": id,
        "deadline": _formatDate(deadline),
        "scope": List<Map<String, dynamic>>.generate(
          scope.length,
          (int index) => scope[index].toMap(),
          growable: false,
        ),
        "groupSize": groupSize,
        "chain": chain.toMap(),
        "shuffleClasses": shuffleClasses,
        "streakGate": streakGate,
        "configuredDayKey": configuredDayKey,
      };

  /// 课程引用去重（保留首次出现顺序），并剔除完全为空的脏引用。
  static List<PlanScopeRef> _normalizeScope(List<PlanScopeRef> raw) {
    final List<PlanScopeRef> result = <PlanScopeRef>[];
    final Set<String> seen = <String>{};
    for (final PlanScopeRef ref in raw) {
      if (ref.sourceFile.isEmpty && ref.className.isEmpty) continue;
      if (seen.add(ref.key)) result.add(ref);
    }
    return List<PlanScopeRef>.unmodifiable(result);
  }

  /// 组大小限制在 1..50。
  static int _normalizeGroupSize(int value) {
    if (value < 1) return 1;
    if (value > 50) return 50;
    return value;
  }
}

/// 单日进度快照。
class PlanDayProgress {
  /// 日期键（yyyyMMdd）
  final int dayKey;

  /// 当日最低量快照（当天固定，不随剩余量变化）
  final int minWords;

  /// 当日已完成量（以 FSRS 新增卡片数计）
  final int doneWords;

  const PlanDayProgress({
    required this.dayKey,
    required this.minWords,
    required this.doneWords,
  });

  PlanDayProgress copyWith({int? minWords, int? doneWords}) {
    return PlanDayProgress(
      dayKey: dayKey,
      minWords: minWords ?? this.minWords,
      doneWords: doneWords ?? this.doneWords,
    );
  }

  factory PlanDayProgress.fromMap(Map<String, dynamic> map) {
    final dynamic day = map["dayKey"];
    final dynamic min = map["minWords"];
    final dynamic done = map["doneWords"];
    return PlanDayProgress(
      dayKey: day is int && day > 0 ? day : 0,
      minWords: min is int && min > 0 ? min : 0,
      doneWords: done is int && done > 0 ? done : 0,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        "dayKey": dayKey,
        "minWords": minWords,
        "doneWords": doneWords,
      };
}

/// 计划学习的持久化状态：计划本体 + 当日进度快照。
class PlanState {
  final StudyPlan? plan;
  final PlanDayProgress? today;

  const PlanState({this.plan, this.today});

  static const PlanState empty = PlanState();

  PlanState copyWith({StudyPlan? plan, PlanDayProgress? today}) {
    return PlanState(
      plan: plan ?? this.plan,
      today: today ?? this.today,
    );
  }

  /// 容错解析：任何字段缺失 / 类型异常 / 坏日期都回退为 [empty]。
  factory PlanState.fromMap(Map<String, dynamic> map) {
    try {
      StudyPlan? plan;
      final dynamic rawPlan = map["plan"];
      if (rawPlan is Map) {
        plan = StudyPlan.fromMap(Map<String, dynamic>.from(rawPlan));
      }

      PlanDayProgress? today;
      final dynamic rawToday = map["today"];
      if (rawToday is Map) {
        final PlanDayProgress parsed =
            PlanDayProgress.fromMap(Map<String, dynamic>.from(rawToday));
        if (parsed.dayKey > 0) today = parsed;
      }
      return PlanState(plan: plan, today: today);
    } catch (_) {
      return empty;
    }
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        "plan": plan?.toMap(),
        "today": today?.toMap(),
      };
}

/// 日期格式化为 `yyyy-MM-dd`（仅本地日期部分）。
String _formatDate(DateTime date) {
  final String year = date.year.toString().padLeft(4, '0');
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return "$year-$month-$day";
}

/// 解析 `yyyy-MM-dd` 为本地零点；格式错误或日期溢出（如 2/30）返回 null。
DateTime? _parseDate(dynamic raw) {
  if (raw is! String) return null;
  final List<String> parts = raw.split("-");
  if (parts.length != 3) return null;
  final int? year = int.tryParse(parts[0]);
  final int? month = int.tryParse(parts[1]);
  final int? day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final DateTime parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}
