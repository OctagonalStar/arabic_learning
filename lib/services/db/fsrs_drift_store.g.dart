// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fsrs_drift_store.dart';

// ignore_for_file: type=lint
class $FsrsCardsTable extends FsrsCards
    with TableInfo<$FsrsCardsTable, FsrsCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FsrsCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cardJsonMeta = const VerificationMeta(
    'cardJson',
  );
  @override
  late final GeneratedColumn<String> cardJson = GeneratedColumn<String>(
    'card_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _logJsonMeta = const VerificationMeta(
    'logJson',
  );
  @override
  late final GeneratedColumn<String> logJson = GeneratedColumn<String>(
    'log_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [cardId, cardJson, logJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fsrs_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<FsrsCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    }
    if (data.containsKey('card_json')) {
      context.handle(
        _cardJsonMeta,
        cardJson.isAcceptableOrUnknown(data['card_json']!, _cardJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_cardJsonMeta);
    }
    if (data.containsKey('log_json')) {
      context.handle(
        _logJsonMeta,
        logJson.isAcceptableOrUnknown(data['log_json']!, _logJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_logJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardId};
  @override
  FsrsCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FsrsCard(
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      cardJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_json'],
      )!,
      logJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}log_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FsrsCardsTable createAlias(String alias) {
    return $FsrsCardsTable(attachedDatabase, alias);
  }
}

class FsrsCard extends DataClass implements Insertable<FsrsCard> {
  final int cardId;

  /// `Card.toMap()` 的 JSON 文本。
  final String cardJson;

  /// `ReviewLog.toMap()` 的 JSON 文本。
  final String logJson;

  /// 写入时间戳（毫秒），仅用于排障。
  final int updatedAt;
  const FsrsCard({
    required this.cardId,
    required this.cardJson,
    required this.logJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_id'] = Variable<int>(cardId);
    map['card_json'] = Variable<String>(cardJson);
    map['log_json'] = Variable<String>(logJson);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  FsrsCardsCompanion toCompanion(bool nullToAbsent) {
    return FsrsCardsCompanion(
      cardId: Value(cardId),
      cardJson: Value(cardJson),
      logJson: Value(logJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory FsrsCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FsrsCard(
      cardId: serializer.fromJson<int>(json['cardId']),
      cardJson: serializer.fromJson<String>(json['cardJson']),
      logJson: serializer.fromJson<String>(json['logJson']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardId': serializer.toJson<int>(cardId),
      'cardJson': serializer.toJson<String>(cardJson),
      'logJson': serializer.toJson<String>(logJson),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  FsrsCard copyWith({
    int? cardId,
    String? cardJson,
    String? logJson,
    int? updatedAt,
  }) => FsrsCard(
    cardId: cardId ?? this.cardId,
    cardJson: cardJson ?? this.cardJson,
    logJson: logJson ?? this.logJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FsrsCard copyWithCompanion(FsrsCardsCompanion data) {
    return FsrsCard(
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      cardJson: data.cardJson.present ? data.cardJson.value : this.cardJson,
      logJson: data.logJson.present ? data.logJson.value : this.logJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FsrsCard(')
          ..write('cardId: $cardId, ')
          ..write('cardJson: $cardJson, ')
          ..write('logJson: $logJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cardId, cardJson, logJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FsrsCard &&
          other.cardId == this.cardId &&
          other.cardJson == this.cardJson &&
          other.logJson == this.logJson &&
          other.updatedAt == this.updatedAt);
}

class FsrsCardsCompanion extends UpdateCompanion<FsrsCard> {
  final Value<int> cardId;
  final Value<String> cardJson;
  final Value<String> logJson;
  final Value<int> updatedAt;
  const FsrsCardsCompanion({
    this.cardId = const Value.absent(),
    this.cardJson = const Value.absent(),
    this.logJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  FsrsCardsCompanion.insert({
    this.cardId = const Value.absent(),
    required String cardJson,
    required String logJson,
    required int updatedAt,
  }) : cardJson = Value(cardJson),
       logJson = Value(logJson),
       updatedAt = Value(updatedAt);
  static Insertable<FsrsCard> custom({
    Expression<int>? cardId,
    Expression<String>? cardJson,
    Expression<String>? logJson,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (cardId != null) 'card_id': cardId,
      if (cardJson != null) 'card_json': cardJson,
      if (logJson != null) 'log_json': logJson,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  FsrsCardsCompanion copyWith({
    Value<int>? cardId,
    Value<String>? cardJson,
    Value<String>? logJson,
    Value<int>? updatedAt,
  }) {
    return FsrsCardsCompanion(
      cardId: cardId ?? this.cardId,
      cardJson: cardJson ?? this.cardJson,
      logJson: logJson ?? this.logJson,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (cardJson.present) {
      map['card_json'] = Variable<String>(cardJson.value);
    }
    if (logJson.present) {
      map['log_json'] = Variable<String>(logJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FsrsCardsCompanion(')
          ..write('cardId: $cardId, ')
          ..write('cardJson: $cardJson, ')
          ..write('logJson: $logJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $HotKvTable extends HotKv with TableInfo<$HotKvTable, HotKvData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HotKvTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hot_kv';
  @override
  VerificationContext validateIntegrity(
    Insertable<HotKvData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  HotKvData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HotKvData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $HotKvTable createAlias(String alias) {
    return $HotKvTable(attachedDatabase, alias);
  }
}

class HotKvData extends DataClass implements Insertable<HotKvData> {
  final String key;
  final String value;
  final int updatedAt;
  const HotKvData({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  HotKvCompanion toCompanion(bool nullToAbsent) {
    return HotKvCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory HotKvData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HotKvData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  HotKvData copyWith({String? key, String? value, int? updatedAt}) => HotKvData(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  HotKvData copyWithCompanion(HotKvCompanion data) {
    return HotKvData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HotKvData(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HotKvData &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class HotKvCompanion extends UpdateCompanion<HotKvData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const HotKvCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HotKvCompanion.insert({
    required String key,
    required String value,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<HotKvData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HotKvCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return HotKvCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HotKvCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaTableTable extends MetaTable
    with TableInfo<$MetaTableTable, MetaTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaTableData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaTableTable createAlias(String alias) {
    return $MetaTableTable(attachedDatabase, alias);
  }
}

class MetaTableData extends DataClass implements Insertable<MetaTableData> {
  final String key;
  final String value;
  const MetaTableData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaTableCompanion toCompanion(bool nullToAbsent) {
    return MetaTableCompanion(key: Value(key), value: Value(value));
  }

  factory MetaTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaTableData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaTableData copyWith({String? key, String? value}) =>
      MetaTableData(key: key ?? this.key, value: value ?? this.value);
  MetaTableData copyWithCompanion(MetaTableCompanion data) {
    return MetaTableData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaTableData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaTableData &&
          other.key == this.key &&
          other.value == this.value);
}

class MetaTableCompanion extends UpdateCompanion<MetaTableData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaTableCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaTableData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaTableCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$FsrsDatabase extends GeneratedDatabase {
  _$FsrsDatabase(QueryExecutor e) : super(e);
  $FsrsDatabaseManager get managers => $FsrsDatabaseManager(this);
  late final $FsrsCardsTable fsrsCards = $FsrsCardsTable(this);
  late final $HotKvTable hotKv = $HotKvTable(this);
  late final $MetaTableTable metaTable = $MetaTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    fsrsCards,
    hotKv,
    metaTable,
  ];
}

typedef $$FsrsCardsTableCreateCompanionBuilder =
    FsrsCardsCompanion Function({
      Value<int> cardId,
      required String cardJson,
      required String logJson,
      required int updatedAt,
    });
typedef $$FsrsCardsTableUpdateCompanionBuilder =
    FsrsCardsCompanion Function({
      Value<int> cardId,
      Value<String> cardJson,
      Value<String> logJson,
      Value<int> updatedAt,
    });

class $$FsrsCardsTableFilterComposer
    extends Composer<_$FsrsDatabase, $FsrsCardsTable> {
  $$FsrsCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardJson => $composableBuilder(
    column: $table.cardJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logJson => $composableBuilder(
    column: $table.logJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FsrsCardsTableOrderingComposer
    extends Composer<_$FsrsDatabase, $FsrsCardsTable> {
  $$FsrsCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardJson => $composableBuilder(
    column: $table.cardJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logJson => $composableBuilder(
    column: $table.logJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FsrsCardsTableAnnotationComposer
    extends Composer<_$FsrsDatabase, $FsrsCardsTable> {
  $$FsrsCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get cardId =>
      $composableBuilder(column: $table.cardId, builder: (column) => column);

  GeneratedColumn<String> get cardJson =>
      $composableBuilder(column: $table.cardJson, builder: (column) => column);

  GeneratedColumn<String> get logJson =>
      $composableBuilder(column: $table.logJson, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FsrsCardsTableTableManager
    extends
        RootTableManager<
          _$FsrsDatabase,
          $FsrsCardsTable,
          FsrsCard,
          $$FsrsCardsTableFilterComposer,
          $$FsrsCardsTableOrderingComposer,
          $$FsrsCardsTableAnnotationComposer,
          $$FsrsCardsTableCreateCompanionBuilder,
          $$FsrsCardsTableUpdateCompanionBuilder,
          (FsrsCard, BaseReferences<_$FsrsDatabase, $FsrsCardsTable, FsrsCard>),
          FsrsCard,
          PrefetchHooks Function()
        > {
  $$FsrsCardsTableTableManager(_$FsrsDatabase db, $FsrsCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FsrsCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FsrsCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FsrsCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> cardId = const Value.absent(),
                Value<String> cardJson = const Value.absent(),
                Value<String> logJson = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => FsrsCardsCompanion(
                cardId: cardId,
                cardJson: cardJson,
                logJson: logJson,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> cardId = const Value.absent(),
                required String cardJson,
                required String logJson,
                required int updatedAt,
              }) => FsrsCardsCompanion.insert(
                cardId: cardId,
                cardJson: cardJson,
                logJson: logJson,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FsrsCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$FsrsDatabase,
      $FsrsCardsTable,
      FsrsCard,
      $$FsrsCardsTableFilterComposer,
      $$FsrsCardsTableOrderingComposer,
      $$FsrsCardsTableAnnotationComposer,
      $$FsrsCardsTableCreateCompanionBuilder,
      $$FsrsCardsTableUpdateCompanionBuilder,
      (FsrsCard, BaseReferences<_$FsrsDatabase, $FsrsCardsTable, FsrsCard>),
      FsrsCard,
      PrefetchHooks Function()
    >;
typedef $$HotKvTableCreateCompanionBuilder =
    HotKvCompanion Function({
      required String key,
      required String value,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$HotKvTableUpdateCompanionBuilder =
    HotKvCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$HotKvTableFilterComposer extends Composer<_$FsrsDatabase, $HotKvTable> {
  $$HotKvTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HotKvTableOrderingComposer
    extends Composer<_$FsrsDatabase, $HotKvTable> {
  $$HotKvTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HotKvTableAnnotationComposer
    extends Composer<_$FsrsDatabase, $HotKvTable> {
  $$HotKvTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$HotKvTableTableManager
    extends
        RootTableManager<
          _$FsrsDatabase,
          $HotKvTable,
          HotKvData,
          $$HotKvTableFilterComposer,
          $$HotKvTableOrderingComposer,
          $$HotKvTableAnnotationComposer,
          $$HotKvTableCreateCompanionBuilder,
          $$HotKvTableUpdateCompanionBuilder,
          (HotKvData, BaseReferences<_$FsrsDatabase, $HotKvTable, HotKvData>),
          HotKvData,
          PrefetchHooks Function()
        > {
  $$HotKvTableTableManager(_$FsrsDatabase db, $HotKvTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HotKvTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HotKvTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HotKvTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HotKvCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => HotKvCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HotKvTableProcessedTableManager =
    ProcessedTableManager<
      _$FsrsDatabase,
      $HotKvTable,
      HotKvData,
      $$HotKvTableFilterComposer,
      $$HotKvTableOrderingComposer,
      $$HotKvTableAnnotationComposer,
      $$HotKvTableCreateCompanionBuilder,
      $$HotKvTableUpdateCompanionBuilder,
      (HotKvData, BaseReferences<_$FsrsDatabase, $HotKvTable, HotKvData>),
      HotKvData,
      PrefetchHooks Function()
    >;
typedef $$MetaTableTableCreateCompanionBuilder =
    MetaTableCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$MetaTableTableUpdateCompanionBuilder =
    MetaTableCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$MetaTableTableFilterComposer
    extends Composer<_$FsrsDatabase, $MetaTableTable> {
  $$MetaTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaTableTableOrderingComposer
    extends Composer<_$FsrsDatabase, $MetaTableTable> {
  $$MetaTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaTableTableAnnotationComposer
    extends Composer<_$FsrsDatabase, $MetaTableTable> {
  $$MetaTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaTableTableTableManager
    extends
        RootTableManager<
          _$FsrsDatabase,
          $MetaTableTable,
          MetaTableData,
          $$MetaTableTableFilterComposer,
          $$MetaTableTableOrderingComposer,
          $$MetaTableTableAnnotationComposer,
          $$MetaTableTableCreateCompanionBuilder,
          $$MetaTableTableUpdateCompanionBuilder,
          (
            MetaTableData,
            BaseReferences<_$FsrsDatabase, $MetaTableTable, MetaTableData>,
          ),
          MetaTableData,
          PrefetchHooks Function()
        > {
  $$MetaTableTableTableManager(_$FsrsDatabase db, $MetaTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaTableCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => MetaTableCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableTableProcessedTableManager =
    ProcessedTableManager<
      _$FsrsDatabase,
      $MetaTableTable,
      MetaTableData,
      $$MetaTableTableFilterComposer,
      $$MetaTableTableOrderingComposer,
      $$MetaTableTableAnnotationComposer,
      $$MetaTableTableCreateCompanionBuilder,
      $$MetaTableTableUpdateCompanionBuilder,
      (
        MetaTableData,
        BaseReferences<_$FsrsDatabase, $MetaTableTable, MetaTableData>,
      ),
      MetaTableData,
      PrefetchHooks Function()
    >;

class $FsrsDatabaseManager {
  final _$FsrsDatabase _db;
  $FsrsDatabaseManager(this._db);
  $$FsrsCardsTableTableManager get fsrsCards =>
      $$FsrsCardsTableTableManager(_db, _db.fsrsCards);
  $$HotKvTableTableManager get hotKv =>
      $$HotKvTableTableManager(_db, _db.hotKv);
  $$MetaTableTableTableManager get metaTable =>
      $$MetaTableTableTableManager(_db, _db.metaTable);
}
