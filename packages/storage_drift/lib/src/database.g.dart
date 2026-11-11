// GENERATED CODE - DO NOT MODIFY BY HAND

// coverage:ignore-file

part of 'database.dart';

// ignore_for_file: type=lint
class $WordsTable extends Words with TableInfo<$WordsTable, WordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _headwordMeta = const VerificationMeta(
    'headword',
  );
  @override
  late final GeneratedColumn<String> headword = GeneratedColumn<String>(
    'headword',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> readings =
      GeneratedColumn<String>(
        'readings',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<String>>($WordsTable.$converterreadings);
  @override
  late final GeneratedColumnWithTypeConverter<PartOfSpeech?, String> pos =
      GeneratedColumn<String>(
        'pos',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<PartOfSpeech?>($WordsTable.$converterposn);
  static const VerificationMeta _meaningMeta = const VerificationMeta(
    'meaning',
  );
  @override
  late final GeneratedColumn<String> meaning = GeneratedColumn<String>(
    'meaning',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exampleJaMeta = const VerificationMeta(
    'exampleJa',
  );
  @override
  late final GeneratedColumn<String> exampleJa = GeneratedColumn<String>(
    'example_ja',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exampleKoMeta = const VerificationMeta(
    'exampleKo',
  );
  @override
  late final GeneratedColumn<String> exampleKo = GeneratedColumn<String>(
    'example_ko',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($WordsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> hiddenAt =
      GeneratedColumn<int>(
        'hidden_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($WordsTable.$converterhiddenAtn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    key,
    headword,
    readings,
    pos,
    meaning,
    exampleJa,
    exampleKo,
    createdAt,
    hiddenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'words';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('headword')) {
      context.handle(
        _headwordMeta,
        headword.isAcceptableOrUnknown(data['headword']!, _headwordMeta),
      );
    } else if (isInserting) {
      context.missing(_headwordMeta);
    }
    if (data.containsKey('meaning')) {
      context.handle(
        _meaningMeta,
        meaning.isAcceptableOrUnknown(data['meaning']!, _meaningMeta),
      );
    } else if (isInserting) {
      context.missing(_meaningMeta);
    }
    if (data.containsKey('example_ja')) {
      context.handle(
        _exampleJaMeta,
        exampleJa.isAcceptableOrUnknown(data['example_ja']!, _exampleJaMeta),
      );
    }
    if (data.containsKey('example_ko')) {
      context.handle(
        _exampleKoMeta,
        exampleKo.isAcceptableOrUnknown(data['example_ko']!, _exampleKoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      headword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headword'],
      )!,
      readings: $WordsTable.$converterreadings.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}readings'],
        )!,
      ),
      pos: $WordsTable.$converterposn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}pos'],
        ),
      ),
      meaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning'],
      )!,
      exampleJa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example_ja'],
      ),
      exampleKo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example_ko'],
      ),
      createdAt: $WordsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      hiddenAt: $WordsTable.$converterhiddenAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}hidden_at'],
        ),
      ),
    );
  }

  @override
  $WordsTable createAlias(String alias) {
    return $WordsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterreadings =
      const StringListConverter();
  static JsonTypeConverter2<PartOfSpeech, String, String> $converterpos =
      const EnumNameConverter<PartOfSpeech>(PartOfSpeech.values);
  static JsonTypeConverter2<PartOfSpeech?, String?, String?> $converterposn =
      JsonTypeConverter2.asNullable($converterpos);
  static TypeConverter<DateTime, int> $convertercreatedAt =
      const UtcMicrosConverter();
  static TypeConverter<DateTime, int> $converterhiddenAt =
      const UtcMicrosConverter();
  static TypeConverter<DateTime?, int?> $converterhiddenAtn =
      NullAwareTypeConverter.wrap($converterhiddenAt);
}

class WordRow extends DataClass implements Insertable<WordRow> {
  final String id;

  /// What makes two words the same word (`wordKey`). Unique.
  final String key;
  final String headword;

  /// JSON array: always read and written with the word, never queried alone.
  final List<String> readings;
  final PartOfSpeech? pos;
  final String meaning;

  /// The example sentence and its translation come as a pair or not at all.
  final String? exampleJa;
  final String? exampleKo;
  final DateTime createdAt;

  /// When the learner hid the word (이미 알아요); null while it is shown.
  /// Per word: hidden in every playlist that holds it.
  final DateTime? hiddenAt;
  const WordRow({
    required this.id,
    required this.key,
    required this.headword,
    required this.readings,
    this.pos,
    required this.meaning,
    this.exampleJa,
    this.exampleKo,
    required this.createdAt,
    this.hiddenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['key'] = Variable<String>(key);
    map['headword'] = Variable<String>(headword);
    {
      map['readings'] = Variable<String>(
        $WordsTable.$converterreadings.toSql(readings),
      );
    }
    if (!nullToAbsent || pos != null) {
      map['pos'] = Variable<String>($WordsTable.$converterposn.toSql(pos));
    }
    map['meaning'] = Variable<String>(meaning);
    if (!nullToAbsent || exampleJa != null) {
      map['example_ja'] = Variable<String>(exampleJa);
    }
    if (!nullToAbsent || exampleKo != null) {
      map['example_ko'] = Variable<String>(exampleKo);
    }
    {
      map['created_at'] = Variable<int>(
        $WordsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    if (!nullToAbsent || hiddenAt != null) {
      map['hidden_at'] = Variable<int>(
        $WordsTable.$converterhiddenAtn.toSql(hiddenAt),
      );
    }
    return map;
  }

  WordsCompanion toCompanion(bool nullToAbsent) {
    return WordsCompanion(
      id: Value(id),
      key: Value(key),
      headword: Value(headword),
      readings: Value(readings),
      pos: pos == null && nullToAbsent ? const Value.absent() : Value(pos),
      meaning: Value(meaning),
      exampleJa: exampleJa == null && nullToAbsent
          ? const Value.absent()
          : Value(exampleJa),
      exampleKo: exampleKo == null && nullToAbsent
          ? const Value.absent()
          : Value(exampleKo),
      createdAt: Value(createdAt),
      hiddenAt: hiddenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(hiddenAt),
    );
  }

  factory WordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordRow(
      id: serializer.fromJson<String>(json['id']),
      key: serializer.fromJson<String>(json['key']),
      headword: serializer.fromJson<String>(json['headword']),
      readings: serializer.fromJson<List<String>>(json['readings']),
      pos: $WordsTable.$converterposn.fromJson(
        serializer.fromJson<String?>(json['pos']),
      ),
      meaning: serializer.fromJson<String>(json['meaning']),
      exampleJa: serializer.fromJson<String?>(json['exampleJa']),
      exampleKo: serializer.fromJson<String?>(json['exampleKo']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      hiddenAt: serializer.fromJson<DateTime?>(json['hiddenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'key': serializer.toJson<String>(key),
      'headword': serializer.toJson<String>(headword),
      'readings': serializer.toJson<List<String>>(readings),
      'pos': serializer.toJson<String?>($WordsTable.$converterposn.toJson(pos)),
      'meaning': serializer.toJson<String>(meaning),
      'exampleJa': serializer.toJson<String?>(exampleJa),
      'exampleKo': serializer.toJson<String?>(exampleKo),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'hiddenAt': serializer.toJson<DateTime?>(hiddenAt),
    };
  }

  WordRow copyWith({
    String? id,
    String? key,
    String? headword,
    List<String>? readings,
    Value<PartOfSpeech?> pos = const Value.absent(),
    String? meaning,
    Value<String?> exampleJa = const Value.absent(),
    Value<String?> exampleKo = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> hiddenAt = const Value.absent(),
  }) => WordRow(
    id: id ?? this.id,
    key: key ?? this.key,
    headword: headword ?? this.headword,
    readings: readings ?? this.readings,
    pos: pos.present ? pos.value : this.pos,
    meaning: meaning ?? this.meaning,
    exampleJa: exampleJa.present ? exampleJa.value : this.exampleJa,
    exampleKo: exampleKo.present ? exampleKo.value : this.exampleKo,
    createdAt: createdAt ?? this.createdAt,
    hiddenAt: hiddenAt.present ? hiddenAt.value : this.hiddenAt,
  );
  WordRow copyWithCompanion(WordsCompanion data) {
    return WordRow(
      id: data.id.present ? data.id.value : this.id,
      key: data.key.present ? data.key.value : this.key,
      headword: data.headword.present ? data.headword.value : this.headword,
      readings: data.readings.present ? data.readings.value : this.readings,
      pos: data.pos.present ? data.pos.value : this.pos,
      meaning: data.meaning.present ? data.meaning.value : this.meaning,
      exampleJa: data.exampleJa.present ? data.exampleJa.value : this.exampleJa,
      exampleKo: data.exampleKo.present ? data.exampleKo.value : this.exampleKo,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      hiddenAt: data.hiddenAt.present ? data.hiddenAt.value : this.hiddenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordRow(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('headword: $headword, ')
          ..write('readings: $readings, ')
          ..write('pos: $pos, ')
          ..write('meaning: $meaning, ')
          ..write('exampleJa: $exampleJa, ')
          ..write('exampleKo: $exampleKo, ')
          ..write('createdAt: $createdAt, ')
          ..write('hiddenAt: $hiddenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    key,
    headword,
    readings,
    pos,
    meaning,
    exampleJa,
    exampleKo,
    createdAt,
    hiddenAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordRow &&
          other.id == this.id &&
          other.key == this.key &&
          other.headword == this.headword &&
          other.readings == this.readings &&
          other.pos == this.pos &&
          other.meaning == this.meaning &&
          other.exampleJa == this.exampleJa &&
          other.exampleKo == this.exampleKo &&
          other.createdAt == this.createdAt &&
          other.hiddenAt == this.hiddenAt);
}

class WordsCompanion extends UpdateCompanion<WordRow> {
  final Value<String> id;
  final Value<String> key;
  final Value<String> headword;
  final Value<List<String>> readings;
  final Value<PartOfSpeech?> pos;
  final Value<String> meaning;
  final Value<String?> exampleJa;
  final Value<String?> exampleKo;
  final Value<DateTime> createdAt;
  final Value<DateTime?> hiddenAt;
  final Value<int> rowid;
  const WordsCompanion({
    this.id = const Value.absent(),
    this.key = const Value.absent(),
    this.headword = const Value.absent(),
    this.readings = const Value.absent(),
    this.pos = const Value.absent(),
    this.meaning = const Value.absent(),
    this.exampleJa = const Value.absent(),
    this.exampleKo = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.hiddenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordsCompanion.insert({
    required String id,
    required String key,
    required String headword,
    required List<String> readings,
    this.pos = const Value.absent(),
    required String meaning,
    this.exampleJa = const Value.absent(),
    this.exampleKo = const Value.absent(),
    required DateTime createdAt,
    this.hiddenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       key = Value(key),
       headword = Value(headword),
       readings = Value(readings),
       meaning = Value(meaning),
       createdAt = Value(createdAt);
  static Insertable<WordRow> custom({
    Expression<String>? id,
    Expression<String>? key,
    Expression<String>? headword,
    Expression<String>? readings,
    Expression<String>? pos,
    Expression<String>? meaning,
    Expression<String>? exampleJa,
    Expression<String>? exampleKo,
    Expression<int>? createdAt,
    Expression<int>? hiddenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (key != null) 'key': key,
      if (headword != null) 'headword': headword,
      if (readings != null) 'readings': readings,
      if (pos != null) 'pos': pos,
      if (meaning != null) 'meaning': meaning,
      if (exampleJa != null) 'example_ja': exampleJa,
      if (exampleKo != null) 'example_ko': exampleKo,
      if (createdAt != null) 'created_at': createdAt,
      if (hiddenAt != null) 'hidden_at': hiddenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordsCompanion copyWith({
    Value<String>? id,
    Value<String>? key,
    Value<String>? headword,
    Value<List<String>>? readings,
    Value<PartOfSpeech?>? pos,
    Value<String>? meaning,
    Value<String?>? exampleJa,
    Value<String?>? exampleKo,
    Value<DateTime>? createdAt,
    Value<DateTime?>? hiddenAt,
    Value<int>? rowid,
  }) {
    return WordsCompanion(
      id: id ?? this.id,
      key: key ?? this.key,
      headword: headword ?? this.headword,
      readings: readings ?? this.readings,
      pos: pos ?? this.pos,
      meaning: meaning ?? this.meaning,
      exampleJa: exampleJa ?? this.exampleJa,
      exampleKo: exampleKo ?? this.exampleKo,
      createdAt: createdAt ?? this.createdAt,
      hiddenAt: hiddenAt ?? this.hiddenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (headword.present) {
      map['headword'] = Variable<String>(headword.value);
    }
    if (readings.present) {
      map['readings'] = Variable<String>(
        $WordsTable.$converterreadings.toSql(readings.value),
      );
    }
    if (pos.present) {
      map['pos'] = Variable<String>(
        $WordsTable.$converterposn.toSql(pos.value),
      );
    }
    if (meaning.present) {
      map['meaning'] = Variable<String>(meaning.value);
    }
    if (exampleJa.present) {
      map['example_ja'] = Variable<String>(exampleJa.value);
    }
    if (exampleKo.present) {
      map['example_ko'] = Variable<String>(exampleKo.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $WordsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (hiddenAt.present) {
      map['hidden_at'] = Variable<int>(
        $WordsTable.$converterhiddenAtn.toSql(hiddenAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordsCompanion(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('headword: $headword, ')
          ..write('readings: $readings, ')
          ..write('pos: $pos, ')
          ..write('meaning: $meaning, ')
          ..write('exampleJa: $exampleJa, ')
          ..write('exampleKo: $exampleKo, ')
          ..write('createdAt: $createdAt, ')
          ..write('hiddenAt: $hiddenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, PlaylistRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($PlaylistsTable.$convertercreatedAt);
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: $PlaylistsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const UtcMicrosConverter();
}

class PlaylistRow extends DataClass implements Insertable<PlaylistRow> {
  final String id;
  final String name;
  final DateTime createdAt;
  final int position;
  const PlaylistRow({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    {
      map['created_at'] = Variable<int>(
        $PlaylistsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    map['position'] = Variable<int>(position);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      position: Value(position),
    );
  }

  factory PlaylistRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'position': serializer.toJson<int>(position),
    };
  }

  PlaylistRow copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    int? position,
  }) => PlaylistRow(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    position: position ?? this.position,
  );
  PlaylistRow copyWithCompanion(PlaylistsCompanion data) {
    return PlaylistRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.position == this.position);
}

class PlaylistsCompanion extends UpdateCompanion<PlaylistRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<int> position;
  final Value<int> rowid;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    required String id,
    required String name,
    required DateTime createdAt,
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       position = Value(position);
  static Insertable<PlaylistRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? createdAt,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $PlaylistsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistWordsTable extends PlaylistWords
    with TableInfo<$PlaylistWordsTable, PlaylistWordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistWordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _wordIdMeta = const VerificationMeta('wordId');
  @override
  late final GeneratedColumn<String> wordId = GeneratedColumn<String>(
    'word_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES words (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> addedAt =
      GeneratedColumn<int>(
        'added_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($PlaylistWordsTable.$converteraddedAt);
  @override
  List<GeneratedColumn> get $columns => [playlistId, wordId, position, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_words';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistWordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('word_id')) {
      context.handle(
        _wordIdMeta,
        wordId.isAcceptableOrUnknown(data['word_id']!, _wordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_wordIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, wordId};
  @override
  PlaylistWordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistWordRow(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playlist_id'],
      )!,
      wordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      addedAt: $PlaylistWordsTable.$converteraddedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}added_at'],
        )!,
      ),
    );
  }

  @override
  $PlaylistWordsTable createAlias(String alias) {
    return $PlaylistWordsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converteraddedAt =
      const UtcMicrosConverter();
}

class PlaylistWordRow extends DataClass implements Insertable<PlaylistWordRow> {
  final String playlistId;
  final String wordId;
  final int position;
  final DateTime addedAt;
  const PlaylistWordRow({
    required this.playlistId,
    required this.wordId,
    required this.position,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<String>(playlistId);
    map['word_id'] = Variable<String>(wordId);
    map['position'] = Variable<int>(position);
    {
      map['added_at'] = Variable<int>(
        $PlaylistWordsTable.$converteraddedAt.toSql(addedAt),
      );
    }
    return map;
  }

  PlaylistWordsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistWordsCompanion(
      playlistId: Value(playlistId),
      wordId: Value(wordId),
      position: Value(position),
      addedAt: Value(addedAt),
    );
  }

  factory PlaylistWordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistWordRow(
      playlistId: serializer.fromJson<String>(json['playlistId']),
      wordId: serializer.fromJson<String>(json['wordId']),
      position: serializer.fromJson<int>(json['position']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<String>(playlistId),
      'wordId': serializer.toJson<String>(wordId),
      'position': serializer.toJson<int>(position),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  PlaylistWordRow copyWith({
    String? playlistId,
    String? wordId,
    int? position,
    DateTime? addedAt,
  }) => PlaylistWordRow(
    playlistId: playlistId ?? this.playlistId,
    wordId: wordId ?? this.wordId,
    position: position ?? this.position,
    addedAt: addedAt ?? this.addedAt,
  );
  PlaylistWordRow copyWithCompanion(PlaylistWordsCompanion data) {
    return PlaylistWordRow(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      wordId: data.wordId.present ? data.wordId.value : this.wordId,
      position: data.position.present ? data.position.value : this.position,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistWordRow(')
          ..write('playlistId: $playlistId, ')
          ..write('wordId: $wordId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, wordId, position, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistWordRow &&
          other.playlistId == this.playlistId &&
          other.wordId == this.wordId &&
          other.position == this.position &&
          other.addedAt == this.addedAt);
}

class PlaylistWordsCompanion extends UpdateCompanion<PlaylistWordRow> {
  final Value<String> playlistId;
  final Value<String> wordId;
  final Value<int> position;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const PlaylistWordsCompanion({
    this.playlistId = const Value.absent(),
    this.wordId = const Value.absent(),
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistWordsCompanion.insert({
    required String playlistId,
    required String wordId,
    required int position,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       wordId = Value(wordId),
       position = Value(position),
       addedAt = Value(addedAt);
  static Insertable<PlaylistWordRow> custom({
    Expression<String>? playlistId,
    Expression<String>? wordId,
    Expression<int>? position,
    Expression<int>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (wordId != null) 'word_id': wordId,
      if (position != null) 'position': position,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistWordsCompanion copyWith({
    Value<String>? playlistId,
    Value<String>? wordId,
    Value<int>? position,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return PlaylistWordsCompanion(
      playlistId: playlistId ?? this.playlistId,
      wordId: wordId ?? this.wordId,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (wordId.present) {
      map['word_id'] = Variable<String>(wordId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(
        $PlaylistWordsTable.$converteraddedAt.toSql(addedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistWordsCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('wordId: $wordId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewCardsTable extends ReviewCards
    with TableInfo<$ReviewCardsTable, CardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<StudyMode, String> mode =
      GeneratedColumn<String>(
        'mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('meaning'),
      ).withConverter<StudyMode>($ReviewCardsTable.$convertermode);
  static const VerificationMeta _wordIdMeta = const VerificationMeta('wordId');
  @override
  late final GeneratedColumn<String> wordId = GeneratedColumn<String>(
    'word_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES words (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> dueAt =
      GeneratedColumn<int>(
        'due_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ReviewCardsTable.$converterdueAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> lastReviewedAt =
      GeneratedColumn<int>(
        'last_reviewed_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ReviewCardsTable.$converterlastReviewedAt);
  static const VerificationMeta _reviewCountMeta = const VerificationMeta(
    'reviewCount',
  );
  @override
  late final GeneratedColumn<int> reviewCount = GeneratedColumn<int>(
    'review_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lapseCountMeta = const VerificationMeta(
    'lapseCount',
  );
  @override
  late final GeneratedColumn<int> lapseCount = GeneratedColumn<int>(
    'lapse_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scope,
    mode,
    wordId,
    level,
    dueAt,
    lastReviewedAt,
    reviewCount,
    lapseCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('word_id')) {
      context.handle(
        _wordIdMeta,
        wordId.isAcceptableOrUnknown(data['word_id']!, _wordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_wordIdMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('review_count')) {
      context.handle(
        _reviewCountMeta,
        reviewCount.isAcceptableOrUnknown(
          data['review_count']!,
          _reviewCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reviewCountMeta);
    }
    if (data.containsKey('lapse_count')) {
      context.handle(
        _lapseCountMeta,
        lapseCount.isAcceptableOrUnknown(data['lapse_count']!, _lapseCountMeta),
      );
    } else if (isInserting) {
      context.missing(_lapseCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, mode, wordId};
  @override
  CardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardRow(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      mode: $ReviewCardsTable.$convertermode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}mode'],
        )!,
      ),
      wordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_id'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      dueAt: $ReviewCardsTable.$converterdueAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}due_at'],
        )!,
      ),
      lastReviewedAt: $ReviewCardsTable.$converterlastReviewedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_reviewed_at'],
        )!,
      ),
      reviewCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}review_count'],
      )!,
      lapseCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapse_count'],
      )!,
    );
  }

  @override
  $ReviewCardsTable createAlias(String alias) {
    return $ReviewCardsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<StudyMode, String, String> $convertermode =
      const EnumNameConverter<StudyMode>(StudyMode.values);
  static TypeConverter<DateTime, int> $converterdueAt =
      const UtcMicrosConverter();
  static TypeConverter<DateTime, int> $converterlastReviewedAt =
      const UtcMicrosConverter();
}

class CardRow extends DataClass implements Insertable<CardRow> {
  final String scope;

  /// Cards written before modes existed (schema v4) were all 뜻 맞히기; the
  /// repository always names the mode.
  final StudyMode mode;
  final String wordId;
  final int level;
  final DateTime dueAt;
  final DateTime lastReviewedAt;
  final int reviewCount;
  final int lapseCount;
  const CardRow({
    required this.scope,
    required this.mode,
    required this.wordId,
    required this.level,
    required this.dueAt,
    required this.lastReviewedAt,
    required this.reviewCount,
    required this.lapseCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    {
      map['mode'] = Variable<String>(
        $ReviewCardsTable.$convertermode.toSql(mode),
      );
    }
    map['word_id'] = Variable<String>(wordId);
    map['level'] = Variable<int>(level);
    {
      map['due_at'] = Variable<int>(
        $ReviewCardsTable.$converterdueAt.toSql(dueAt),
      );
    }
    {
      map['last_reviewed_at'] = Variable<int>(
        $ReviewCardsTable.$converterlastReviewedAt.toSql(lastReviewedAt),
      );
    }
    map['review_count'] = Variable<int>(reviewCount);
    map['lapse_count'] = Variable<int>(lapseCount);
    return map;
  }

  ReviewCardsCompanion toCompanion(bool nullToAbsent) {
    return ReviewCardsCompanion(
      scope: Value(scope),
      mode: Value(mode),
      wordId: Value(wordId),
      level: Value(level),
      dueAt: Value(dueAt),
      lastReviewedAt: Value(lastReviewedAt),
      reviewCount: Value(reviewCount),
      lapseCount: Value(lapseCount),
    );
  }

  factory CardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardRow(
      scope: serializer.fromJson<String>(json['scope']),
      mode: $ReviewCardsTable.$convertermode.fromJson(
        serializer.fromJson<String>(json['mode']),
      ),
      wordId: serializer.fromJson<String>(json['wordId']),
      level: serializer.fromJson<int>(json['level']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      lastReviewedAt: serializer.fromJson<DateTime>(json['lastReviewedAt']),
      reviewCount: serializer.fromJson<int>(json['reviewCount']),
      lapseCount: serializer.fromJson<int>(json['lapseCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'mode': serializer.toJson<String>(
        $ReviewCardsTable.$convertermode.toJson(mode),
      ),
      'wordId': serializer.toJson<String>(wordId),
      'level': serializer.toJson<int>(level),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'lastReviewedAt': serializer.toJson<DateTime>(lastReviewedAt),
      'reviewCount': serializer.toJson<int>(reviewCount),
      'lapseCount': serializer.toJson<int>(lapseCount),
    };
  }

  CardRow copyWith({
    String? scope,
    StudyMode? mode,
    String? wordId,
    int? level,
    DateTime? dueAt,
    DateTime? lastReviewedAt,
    int? reviewCount,
    int? lapseCount,
  }) => CardRow(
    scope: scope ?? this.scope,
    mode: mode ?? this.mode,
    wordId: wordId ?? this.wordId,
    level: level ?? this.level,
    dueAt: dueAt ?? this.dueAt,
    lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    reviewCount: reviewCount ?? this.reviewCount,
    lapseCount: lapseCount ?? this.lapseCount,
  );
  CardRow copyWithCompanion(ReviewCardsCompanion data) {
    return CardRow(
      scope: data.scope.present ? data.scope.value : this.scope,
      mode: data.mode.present ? data.mode.value : this.mode,
      wordId: data.wordId.present ? data.wordId.value : this.wordId,
      level: data.level.present ? data.level.value : this.level,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      lastReviewedAt: data.lastReviewedAt.present
          ? data.lastReviewedAt.value
          : this.lastReviewedAt,
      reviewCount: data.reviewCount.present
          ? data.reviewCount.value
          : this.reviewCount,
      lapseCount: data.lapseCount.present
          ? data.lapseCount.value
          : this.lapseCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardRow(')
          ..write('scope: $scope, ')
          ..write('mode: $mode, ')
          ..write('wordId: $wordId, ')
          ..write('level: $level, ')
          ..write('dueAt: $dueAt, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('reviewCount: $reviewCount, ')
          ..write('lapseCount: $lapseCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scope,
    mode,
    wordId,
    level,
    dueAt,
    lastReviewedAt,
    reviewCount,
    lapseCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardRow &&
          other.scope == this.scope &&
          other.mode == this.mode &&
          other.wordId == this.wordId &&
          other.level == this.level &&
          other.dueAt == this.dueAt &&
          other.lastReviewedAt == this.lastReviewedAt &&
          other.reviewCount == this.reviewCount &&
          other.lapseCount == this.lapseCount);
}

class ReviewCardsCompanion extends UpdateCompanion<CardRow> {
  final Value<String> scope;
  final Value<StudyMode> mode;
  final Value<String> wordId;
  final Value<int> level;
  final Value<DateTime> dueAt;
  final Value<DateTime> lastReviewedAt;
  final Value<int> reviewCount;
  final Value<int> lapseCount;
  final Value<int> rowid;
  const ReviewCardsCompanion({
    this.scope = const Value.absent(),
    this.mode = const Value.absent(),
    this.wordId = const Value.absent(),
    this.level = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    this.reviewCount = const Value.absent(),
    this.lapseCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewCardsCompanion.insert({
    required String scope,
    this.mode = const Value.absent(),
    required String wordId,
    required int level,
    required DateTime dueAt,
    required DateTime lastReviewedAt,
    required int reviewCount,
    required int lapseCount,
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       wordId = Value(wordId),
       level = Value(level),
       dueAt = Value(dueAt),
       lastReviewedAt = Value(lastReviewedAt),
       reviewCount = Value(reviewCount),
       lapseCount = Value(lapseCount);
  static Insertable<CardRow> custom({
    Expression<String>? scope,
    Expression<String>? mode,
    Expression<String>? wordId,
    Expression<int>? level,
    Expression<int>? dueAt,
    Expression<int>? lastReviewedAt,
    Expression<int>? reviewCount,
    Expression<int>? lapseCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (mode != null) 'mode': mode,
      if (wordId != null) 'word_id': wordId,
      if (level != null) 'level': level,
      if (dueAt != null) 'due_at': dueAt,
      if (lastReviewedAt != null) 'last_reviewed_at': lastReviewedAt,
      if (reviewCount != null) 'review_count': reviewCount,
      if (lapseCount != null) 'lapse_count': lapseCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewCardsCompanion copyWith({
    Value<String>? scope,
    Value<StudyMode>? mode,
    Value<String>? wordId,
    Value<int>? level,
    Value<DateTime>? dueAt,
    Value<DateTime>? lastReviewedAt,
    Value<int>? reviewCount,
    Value<int>? lapseCount,
    Value<int>? rowid,
  }) {
    return ReviewCardsCompanion(
      scope: scope ?? this.scope,
      mode: mode ?? this.mode,
      wordId: wordId ?? this.wordId,
      level: level ?? this.level,
      dueAt: dueAt ?? this.dueAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      reviewCount: reviewCount ?? this.reviewCount,
      lapseCount: lapseCount ?? this.lapseCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(
        $ReviewCardsTable.$convertermode.toSql(mode.value),
      );
    }
    if (wordId.present) {
      map['word_id'] = Variable<String>(wordId.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<int>(
        $ReviewCardsTable.$converterdueAt.toSql(dueAt.value),
      );
    }
    if (lastReviewedAt.present) {
      map['last_reviewed_at'] = Variable<int>(
        $ReviewCardsTable.$converterlastReviewedAt.toSql(lastReviewedAt.value),
      );
    }
    if (reviewCount.present) {
      map['review_count'] = Variable<int>(reviewCount.value);
    }
    if (lapseCount.present) {
      map['lapse_count'] = Variable<int>(lapseCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewCardsCompanion(')
          ..write('scope: $scope, ')
          ..write('mode: $mode, ')
          ..write('wordId: $wordId, ')
          ..write('level: $level, ')
          ..write('dueAt: $dueAt, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('reviewCount: $reviewCount, ')
          ..write('lapseCount: $lapseCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewLogsTable extends ReviewLogs
    with TableInfo<$ReviewLogsTable, LogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<StudyMode, String> mode =
      GeneratedColumn<String>(
        'mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('meaning'),
      ).withConverter<StudyMode>($ReviewLogsTable.$convertermode);
  static const VerificationMeta _wordIdMeta = const VerificationMeta('wordId');
  @override
  late final GeneratedColumn<String> wordId = GeneratedColumn<String>(
    'word_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Answer, String> answer =
      GeneratedColumn<String>(
        'answer',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Answer>($ReviewLogsTable.$converteranswer);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> at =
      GeneratedColumn<int>(
        'at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ReviewLogsTable.$converterat);
  static const VerificationMeta _levelBeforeMeta = const VerificationMeta(
    'levelBefore',
  );
  @override
  late final GeneratedColumn<int> levelBefore = GeneratedColumn<int>(
    'level_before',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelAfterMeta = const VerificationMeta(
    'levelAfter',
  );
  @override
  late final GeneratedColumn<int> levelAfter = GeneratedColumn<int>(
    'level_after',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retriesInSessionMeta = const VerificationMeta(
    'retriesInSession',
  );
  @override
  late final GeneratedColumn<int> retriesInSession = GeneratedColumn<int>(
    'retries_in_session',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scope,
    mode,
    wordId,
    answer,
    at,
    levelBefore,
    levelAfter,
    retriesInSession,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('word_id')) {
      context.handle(
        _wordIdMeta,
        wordId.isAcceptableOrUnknown(data['word_id']!, _wordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_wordIdMeta);
    }
    if (data.containsKey('level_before')) {
      context.handle(
        _levelBeforeMeta,
        levelBefore.isAcceptableOrUnknown(
          data['level_before']!,
          _levelBeforeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_levelBeforeMeta);
    }
    if (data.containsKey('level_after')) {
      context.handle(
        _levelAfterMeta,
        levelAfter.isAcceptableOrUnknown(data['level_after']!, _levelAfterMeta),
      );
    } else if (isInserting) {
      context.missing(_levelAfterMeta);
    }
    if (data.containsKey('retries_in_session')) {
      context.handle(
        _retriesInSessionMeta,
        retriesInSession.isAcceptableOrUnknown(
          data['retries_in_session']!,
          _retriesInSessionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_retriesInSessionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      mode: $ReviewLogsTable.$convertermode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}mode'],
        )!,
      ),
      wordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_id'],
      )!,
      answer: $ReviewLogsTable.$converteranswer.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}answer'],
        )!,
      ),
      at: $ReviewLogsTable.$converterat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}at'],
        )!,
      ),
      levelBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level_before'],
      )!,
      levelAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level_after'],
      )!,
      retriesInSession: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retries_in_session'],
      )!,
    );
  }

  @override
  $ReviewLogsTable createAlias(String alias) {
    return $ReviewLogsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<StudyMode, String, String> $convertermode =
      const EnumNameConverter<StudyMode>(StudyMode.values);
  static JsonTypeConverter2<Answer, String, String> $converteranswer =
      const EnumNameConverter<Answer>(Answer.values);
  static TypeConverter<DateTime, int> $converterat = const UtcMicrosConverter();
}

class LogRow extends DataClass implements Insertable<LogRow> {
  final int id;
  final String scope;

  /// Presses logged before modes existed (schema v4) were all 뜻 맞히기.
  final StudyMode mode;
  final String wordId;
  final Answer answer;
  final DateTime at;
  final int levelBefore;
  final int levelAfter;
  final int retriesInSession;
  const LogRow({
    required this.id,
    required this.scope,
    required this.mode,
    required this.wordId,
    required this.answer,
    required this.at,
    required this.levelBefore,
    required this.levelAfter,
    required this.retriesInSession,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['scope'] = Variable<String>(scope);
    {
      map['mode'] = Variable<String>(
        $ReviewLogsTable.$convertermode.toSql(mode),
      );
    }
    map['word_id'] = Variable<String>(wordId);
    {
      map['answer'] = Variable<String>(
        $ReviewLogsTable.$converteranswer.toSql(answer),
      );
    }
    {
      map['at'] = Variable<int>($ReviewLogsTable.$converterat.toSql(at));
    }
    map['level_before'] = Variable<int>(levelBefore);
    map['level_after'] = Variable<int>(levelAfter);
    map['retries_in_session'] = Variable<int>(retriesInSession);
    return map;
  }

  ReviewLogsCompanion toCompanion(bool nullToAbsent) {
    return ReviewLogsCompanion(
      id: Value(id),
      scope: Value(scope),
      mode: Value(mode),
      wordId: Value(wordId),
      answer: Value(answer),
      at: Value(at),
      levelBefore: Value(levelBefore),
      levelAfter: Value(levelAfter),
      retriesInSession: Value(retriesInSession),
    );
  }

  factory LogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LogRow(
      id: serializer.fromJson<int>(json['id']),
      scope: serializer.fromJson<String>(json['scope']),
      mode: $ReviewLogsTable.$convertermode.fromJson(
        serializer.fromJson<String>(json['mode']),
      ),
      wordId: serializer.fromJson<String>(json['wordId']),
      answer: $ReviewLogsTable.$converteranswer.fromJson(
        serializer.fromJson<String>(json['answer']),
      ),
      at: serializer.fromJson<DateTime>(json['at']),
      levelBefore: serializer.fromJson<int>(json['levelBefore']),
      levelAfter: serializer.fromJson<int>(json['levelAfter']),
      retriesInSession: serializer.fromJson<int>(json['retriesInSession']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scope': serializer.toJson<String>(scope),
      'mode': serializer.toJson<String>(
        $ReviewLogsTable.$convertermode.toJson(mode),
      ),
      'wordId': serializer.toJson<String>(wordId),
      'answer': serializer.toJson<String>(
        $ReviewLogsTable.$converteranswer.toJson(answer),
      ),
      'at': serializer.toJson<DateTime>(at),
      'levelBefore': serializer.toJson<int>(levelBefore),
      'levelAfter': serializer.toJson<int>(levelAfter),
      'retriesInSession': serializer.toJson<int>(retriesInSession),
    };
  }

  LogRow copyWith({
    int? id,
    String? scope,
    StudyMode? mode,
    String? wordId,
    Answer? answer,
    DateTime? at,
    int? levelBefore,
    int? levelAfter,
    int? retriesInSession,
  }) => LogRow(
    id: id ?? this.id,
    scope: scope ?? this.scope,
    mode: mode ?? this.mode,
    wordId: wordId ?? this.wordId,
    answer: answer ?? this.answer,
    at: at ?? this.at,
    levelBefore: levelBefore ?? this.levelBefore,
    levelAfter: levelAfter ?? this.levelAfter,
    retriesInSession: retriesInSession ?? this.retriesInSession,
  );
  LogRow copyWithCompanion(ReviewLogsCompanion data) {
    return LogRow(
      id: data.id.present ? data.id.value : this.id,
      scope: data.scope.present ? data.scope.value : this.scope,
      mode: data.mode.present ? data.mode.value : this.mode,
      wordId: data.wordId.present ? data.wordId.value : this.wordId,
      answer: data.answer.present ? data.answer.value : this.answer,
      at: data.at.present ? data.at.value : this.at,
      levelBefore: data.levelBefore.present
          ? data.levelBefore.value
          : this.levelBefore,
      levelAfter: data.levelAfter.present
          ? data.levelAfter.value
          : this.levelAfter,
      retriesInSession: data.retriesInSession.present
          ? data.retriesInSession.value
          : this.retriesInSession,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LogRow(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('mode: $mode, ')
          ..write('wordId: $wordId, ')
          ..write('answer: $answer, ')
          ..write('at: $at, ')
          ..write('levelBefore: $levelBefore, ')
          ..write('levelAfter: $levelAfter, ')
          ..write('retriesInSession: $retriesInSession')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scope,
    mode,
    wordId,
    answer,
    at,
    levelBefore,
    levelAfter,
    retriesInSession,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LogRow &&
          other.id == this.id &&
          other.scope == this.scope &&
          other.mode == this.mode &&
          other.wordId == this.wordId &&
          other.answer == this.answer &&
          other.at == this.at &&
          other.levelBefore == this.levelBefore &&
          other.levelAfter == this.levelAfter &&
          other.retriesInSession == this.retriesInSession);
}

class ReviewLogsCompanion extends UpdateCompanion<LogRow> {
  final Value<int> id;
  final Value<String> scope;
  final Value<StudyMode> mode;
  final Value<String> wordId;
  final Value<Answer> answer;
  final Value<DateTime> at;
  final Value<int> levelBefore;
  final Value<int> levelAfter;
  final Value<int> retriesInSession;
  const ReviewLogsCompanion({
    this.id = const Value.absent(),
    this.scope = const Value.absent(),
    this.mode = const Value.absent(),
    this.wordId = const Value.absent(),
    this.answer = const Value.absent(),
    this.at = const Value.absent(),
    this.levelBefore = const Value.absent(),
    this.levelAfter = const Value.absent(),
    this.retriesInSession = const Value.absent(),
  });
  ReviewLogsCompanion.insert({
    this.id = const Value.absent(),
    required String scope,
    this.mode = const Value.absent(),
    required String wordId,
    required Answer answer,
    required DateTime at,
    required int levelBefore,
    required int levelAfter,
    required int retriesInSession,
  }) : scope = Value(scope),
       wordId = Value(wordId),
       answer = Value(answer),
       at = Value(at),
       levelBefore = Value(levelBefore),
       levelAfter = Value(levelAfter),
       retriesInSession = Value(retriesInSession);
  static Insertable<LogRow> custom({
    Expression<int>? id,
    Expression<String>? scope,
    Expression<String>? mode,
    Expression<String>? wordId,
    Expression<String>? answer,
    Expression<int>? at,
    Expression<int>? levelBefore,
    Expression<int>? levelAfter,
    Expression<int>? retriesInSession,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scope != null) 'scope': scope,
      if (mode != null) 'mode': mode,
      if (wordId != null) 'word_id': wordId,
      if (answer != null) 'answer': answer,
      if (at != null) 'at': at,
      if (levelBefore != null) 'level_before': levelBefore,
      if (levelAfter != null) 'level_after': levelAfter,
      if (retriesInSession != null) 'retries_in_session': retriesInSession,
    });
  }

  ReviewLogsCompanion copyWith({
    Value<int>? id,
    Value<String>? scope,
    Value<StudyMode>? mode,
    Value<String>? wordId,
    Value<Answer>? answer,
    Value<DateTime>? at,
    Value<int>? levelBefore,
    Value<int>? levelAfter,
    Value<int>? retriesInSession,
  }) {
    return ReviewLogsCompanion(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      mode: mode ?? this.mode,
      wordId: wordId ?? this.wordId,
      answer: answer ?? this.answer,
      at: at ?? this.at,
      levelBefore: levelBefore ?? this.levelBefore,
      levelAfter: levelAfter ?? this.levelAfter,
      retriesInSession: retriesInSession ?? this.retriesInSession,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(
        $ReviewLogsTable.$convertermode.toSql(mode.value),
      );
    }
    if (wordId.present) {
      map['word_id'] = Variable<String>(wordId.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(
        $ReviewLogsTable.$converteranswer.toSql(answer.value),
      );
    }
    if (at.present) {
      map['at'] = Variable<int>($ReviewLogsTable.$converterat.toSql(at.value));
    }
    if (levelBefore.present) {
      map['level_before'] = Variable<int>(levelBefore.value);
    }
    if (levelAfter.present) {
      map['level_after'] = Variable<int>(levelAfter.value);
    }
    if (retriesInSession.present) {
      map['retries_in_session'] = Variable<int>(retriesInSession.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogsCompanion(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('mode: $mode, ')
          ..write('wordId: $wordId, ')
          ..write('answer: $answer, ')
          ..write('at: $at, ')
          ..write('levelBefore: $levelBefore, ')
          ..write('levelAfter: $levelAfter, ')
          ..write('retriesInSession: $retriesInSession')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
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
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
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
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
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

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
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
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
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

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
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
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ShioriDatabase extends GeneratedDatabase {
  _$ShioriDatabase(QueryExecutor e) : super(e);
  $ShioriDatabaseManager get managers => $ShioriDatabaseManager(this);
  late final $WordsTable words = $WordsTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistWordsTable playlistWords = $PlaylistWordsTable(this);
  late final $ReviewCardsTable reviewCards = $ReviewCardsTable(this);
  late final $ReviewLogsTable reviewLogs = $ReviewLogsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index playlistWordsByWord = Index(
    'playlist_words_by_word',
    'CREATE INDEX playlist_words_by_word ON playlist_words (word_id)',
  );
  late final Index reviewLogsByTime = Index(
    'review_logs_by_time',
    'CREATE INDEX review_logs_by_time ON review_logs (at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    words,
    playlists,
    playlistWords,
    reviewCards,
    reviewLogs,
    settings,
    playlistWordsByWord,
    reviewLogsByTime,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_words', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'words',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_words', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'words',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('review_cards', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$WordsTableCreateCompanionBuilder =
    WordsCompanion Function({
      required String id,
      required String key,
      required String headword,
      required List<String> readings,
      Value<PartOfSpeech?> pos,
      required String meaning,
      Value<String?> exampleJa,
      Value<String?> exampleKo,
      required DateTime createdAt,
      Value<DateTime?> hiddenAt,
      Value<int> rowid,
    });
typedef $$WordsTableUpdateCompanionBuilder =
    WordsCompanion Function({
      Value<String> id,
      Value<String> key,
      Value<String> headword,
      Value<List<String>> readings,
      Value<PartOfSpeech?> pos,
      Value<String> meaning,
      Value<String?> exampleJa,
      Value<String?> exampleKo,
      Value<DateTime> createdAt,
      Value<DateTime?> hiddenAt,
      Value<int> rowid,
    });

final class $$WordsTableReferences
    extends BaseReferences<_$ShioriDatabase, $WordsTable, WordRow> {
  $$WordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistWordsTable, List<PlaylistWordRow>>
  _playlistWordsRefsTable(_$ShioriDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistWords,
    aliasName: 'words__id__playlist_words__word_id',
  );

  $$PlaylistWordsTableProcessedTableManager get playlistWordsRefs {
    final manager = $$PlaylistWordsTableTableManager(
      $_db,
      $_db.playlistWords,
    ).filter((f) => f.wordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistWordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReviewCardsTable, List<CardRow>>
  _reviewCardsRefsTable(_$ShioriDatabase db) => MultiTypedResultKey.fromTable(
    db.reviewCards,
    aliasName: 'words__id__review_cards__word_id',
  );

  $$ReviewCardsTableProcessedTableManager get reviewCardsRefs {
    final manager = $$ReviewCardsTableTableManager(
      $_db,
      $_db.reviewCards,
    ).filter((f) => f.wordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_reviewCardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WordsTableFilterComposer
    extends Composer<_$ShioriDatabase, $WordsTable> {
  $$WordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headword => $composableBuilder(
    column: $table.headword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get readings => $composableBuilder(
    column: $table.readings,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<PartOfSpeech?, PartOfSpeech, String> get pos =>
      $composableBuilder(
        column: $table.pos,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exampleJa => $composableBuilder(
    column: $table.exampleJa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exampleKo => $composableBuilder(
    column: $table.exampleKo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get hiddenAt =>
      $composableBuilder(
        column: $table.hiddenAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> playlistWordsRefs(
    Expression<bool> Function($$PlaylistWordsTableFilterComposer f) f,
  ) {
    final $$PlaylistWordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistWords,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistWordsTableFilterComposer(
            $db: $db,
            $table: $db.playlistWords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> reviewCardsRefs(
    Expression<bool> Function($$ReviewCardsTableFilterComposer f) f,
  ) {
    final $$ReviewCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewCards,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewCardsTableFilterComposer(
            $db: $db,
            $table: $db.reviewCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WordsTableOrderingComposer
    extends Composer<_$ShioriDatabase, $WordsTable> {
  $$WordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headword => $composableBuilder(
    column: $table.headword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readings => $composableBuilder(
    column: $table.readings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exampleJa => $composableBuilder(
    column: $table.exampleJa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exampleKo => $composableBuilder(
    column: $table.exampleKo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hiddenAt => $composableBuilder(
    column: $table.hiddenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordsTableAnnotationComposer
    extends Composer<_$ShioriDatabase, $WordsTable> {
  $$WordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get headword =>
      $composableBuilder(column: $table.headword, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get readings =>
      $composableBuilder(column: $table.readings, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PartOfSpeech?, String> get pos =>
      $composableBuilder(column: $table.pos, builder: (column) => column);

  GeneratedColumn<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => column);

  GeneratedColumn<String> get exampleJa =>
      $composableBuilder(column: $table.exampleJa, builder: (column) => column);

  GeneratedColumn<String> get exampleKo =>
      $composableBuilder(column: $table.exampleKo, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get hiddenAt =>
      $composableBuilder(column: $table.hiddenAt, builder: (column) => column);

  Expression<T> playlistWordsRefs<T extends Object>(
    Expression<T> Function($$PlaylistWordsTableAnnotationComposer a) f,
  ) {
    final $$PlaylistWordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistWords,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistWordsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistWords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> reviewCardsRefs<T extends Object>(
    Expression<T> Function($$ReviewCardsTableAnnotationComposer a) f,
  ) {
    final $$ReviewCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewCards,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.reviewCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WordsTableTableManager
    extends
        RootTableManager<
          _$ShioriDatabase,
          $WordsTable,
          WordRow,
          $$WordsTableFilterComposer,
          $$WordsTableOrderingComposer,
          $$WordsTableAnnotationComposer,
          $$WordsTableCreateCompanionBuilder,
          $$WordsTableUpdateCompanionBuilder,
          (WordRow, $$WordsTableReferences),
          WordRow,
          PrefetchHooks Function({bool playlistWordsRefs, bool reviewCardsRefs})
        > {
  $$WordsTableTableManager(_$ShioriDatabase db, $WordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> headword = const Value.absent(),
                Value<List<String>> readings = const Value.absent(),
                Value<PartOfSpeech?> pos = const Value.absent(),
                Value<String> meaning = const Value.absent(),
                Value<String?> exampleJa = const Value.absent(),
                Value<String?> exampleKo = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> hiddenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordsCompanion(
                id: id,
                key: key,
                headword: headword,
                readings: readings,
                pos: pos,
                meaning: meaning,
                exampleJa: exampleJa,
                exampleKo: exampleKo,
                createdAt: createdAt,
                hiddenAt: hiddenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String key,
                required String headword,
                required List<String> readings,
                Value<PartOfSpeech?> pos = const Value.absent(),
                required String meaning,
                Value<String?> exampleJa = const Value.absent(),
                Value<String?> exampleKo = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> hiddenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordsCompanion.insert(
                id: id,
                key: key,
                headword: headword,
                readings: readings,
                pos: pos,
                meaning: meaning,
                exampleJa: exampleJa,
                exampleKo: exampleKo,
                createdAt: createdAt,
                hiddenAt: hiddenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordsTable, WordRow>(table),
                  $$WordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({playlistWordsRefs = false, reviewCardsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playlistWordsRefs) db.playlistWords,
                    if (reviewCardsRefs) db.reviewCards,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playlistWordsRefs)
                        await $_getPrefetchedDataByColumns<
                          WordRow,
                          $WordsTable,
                          PlaylistWordRow,
                          $PlaylistWordsTable
                        >(
                          currentTable: table,
                          referencedTable: $$WordsTableReferences
                              ._playlistWordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WordsTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistWordsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'word_id',
                          typedResults: items,
                        ),
                      if (reviewCardsRefs)
                        await $_getPrefetchedDataByColumns<
                          WordRow,
                          $WordsTable,
                          CardRow,
                          $ReviewCardsTable
                        >(
                          currentTable: table,
                          referencedTable: $$WordsTableReferences
                              ._reviewCardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WordsTableReferences(
                                db,
                                table,
                                p0,
                              ).reviewCardsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'word_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ShioriDatabase,
      $WordsTable,
      WordRow,
      $$WordsTableFilterComposer,
      $$WordsTableOrderingComposer,
      $$WordsTableAnnotationComposer,
      $$WordsTableCreateCompanionBuilder,
      $$WordsTableUpdateCompanionBuilder,
      (WordRow, $$WordsTableReferences),
      WordRow,
      PrefetchHooks Function({bool playlistWordsRefs, bool reviewCardsRefs})
    >;
typedef $$PlaylistsTableCreateCompanionBuilder =
    PlaylistsCompanion Function({
      required String id,
      required String name,
      required DateTime createdAt,
      required int position,
      Value<int> rowid,
    });
typedef $$PlaylistsTableUpdateCompanionBuilder =
    PlaylistsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<int> position,
      Value<int> rowid,
    });

final class $$PlaylistsTableReferences
    extends BaseReferences<_$ShioriDatabase, $PlaylistsTable, PlaylistRow> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistWordsTable, List<PlaylistWordRow>>
  _playlistWordsRefsTable(_$ShioriDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistWords,
    aliasName: 'playlists__id__playlist_words__playlist_id',
  );

  $$PlaylistWordsTableProcessedTableManager get playlistWordsRefs {
    final manager = $$PlaylistWordsTableTableManager(
      $_db,
      $_db.playlistWords,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistWordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$ShioriDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistWordsRefs(
    Expression<bool> Function($$PlaylistWordsTableFilterComposer f) f,
  ) {
    final $$PlaylistWordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistWords,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistWordsTableFilterComposer(
            $db: $db,
            $table: $db.playlistWords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$ShioriDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$ShioriDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  Expression<T> playlistWordsRefs<T extends Object>(
    Expression<T> Function($$PlaylistWordsTableAnnotationComposer a) f,
  ) {
    final $$PlaylistWordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistWords,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistWordsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistWords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$ShioriDatabase,
          $PlaylistsTable,
          PlaylistRow,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (PlaylistRow, $$PlaylistsTableReferences),
          PlaylistRow,
          PrefetchHooks Function({bool playlistWordsRefs})
        > {
  $$PlaylistsTableTableManager(_$ShioriDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required DateTime createdAt,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, PlaylistRow>(table),
                  $$PlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistWordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistWordsRefs) db.playlistWords,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistWordsRefs)
                    await $_getPrefetchedDataByColumns<
                      PlaylistRow,
                      $PlaylistsTable,
                      PlaylistWordRow,
                      $PlaylistWordsTable
                    >(
                      currentTable: table,
                      referencedTable: $$PlaylistsTableReferences
                          ._playlistWordsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlaylistsTableReferences(
                            db,
                            table,
                            p0,
                          ).playlistWordsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'playlist_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$ShioriDatabase,
      $PlaylistsTable,
      PlaylistRow,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (PlaylistRow, $$PlaylistsTableReferences),
      PlaylistRow,
      PrefetchHooks Function({bool playlistWordsRefs})
    >;
typedef $$PlaylistWordsTableCreateCompanionBuilder =
    PlaylistWordsCompanion Function({
      required String playlistId,
      required String wordId,
      required int position,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$PlaylistWordsTableUpdateCompanionBuilder =
    PlaylistWordsCompanion Function({
      Value<String> playlistId,
      Value<String> wordId,
      Value<int> position,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

final class $$PlaylistWordsTableReferences
    extends
        BaseReferences<_$ShioriDatabase, $PlaylistWordsTable, PlaylistWordRow> {
  $$PlaylistWordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$ShioriDatabase db) =>
      db.playlists.createAlias('playlist_words__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<String>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WordsTable _wordIdTable(_$ShioriDatabase db) =>
      db.words.createAlias('playlist_words__word_id__words__id');

  $$WordsTableProcessedTableManager get wordId {
    final $_column = $_itemColumn<String>('word_id')!;

    final manager = $$WordsTableTableManager(
      $_db,
      $_db.words,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistWordsTableFilterComposer
    extends Composer<_$ShioriDatabase, $PlaylistWordsTable> {
  $$PlaylistWordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get addedAt =>
      $composableBuilder(
        column: $table.addedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WordsTableFilterComposer get wordId {
    final $$WordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableFilterComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistWordsTableOrderingComposer
    extends Composer<_$ShioriDatabase, $PlaylistWordsTable> {
  $$PlaylistWordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WordsTableOrderingComposer get wordId {
    final $$WordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableOrderingComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistWordsTableAnnotationComposer
    extends Composer<_$ShioriDatabase, $PlaylistWordsTable> {
  $$PlaylistWordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WordsTableAnnotationComposer get wordId {
    final $$WordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableAnnotationComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistWordsTableTableManager
    extends
        RootTableManager<
          _$ShioriDatabase,
          $PlaylistWordsTable,
          PlaylistWordRow,
          $$PlaylistWordsTableFilterComposer,
          $$PlaylistWordsTableOrderingComposer,
          $$PlaylistWordsTableAnnotationComposer,
          $$PlaylistWordsTableCreateCompanionBuilder,
          $$PlaylistWordsTableUpdateCompanionBuilder,
          (PlaylistWordRow, $$PlaylistWordsTableReferences),
          PlaylistWordRow,
          PrefetchHooks Function({bool playlistId, bool wordId})
        > {
  $$PlaylistWordsTableTableManager(
    _$ShioriDatabase db,
    $PlaylistWordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistWordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistWordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistWordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> playlistId = const Value.absent(),
                Value<String> wordId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistWordsCompanion(
                playlistId: playlistId,
                wordId: wordId,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playlistId,
                required String wordId,
                required int position,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlaylistWordsCompanion.insert(
                playlistId: playlistId,
                wordId: wordId,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistWordsTable, PlaylistWordRow>(table),
                  $$PlaylistWordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false, wordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.playlistId,
                                referencedTable: $$PlaylistWordsTableReferences
                                    ._playlistIdTable(db),
                                referencedColumn: $$PlaylistWordsTableReferences
                                    ._playlistIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (wordId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.wordId,
                                referencedTable: $$PlaylistWordsTableReferences
                                    ._wordIdTable(db),
                                referencedColumn: $$PlaylistWordsTableReferences
                                    ._wordIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistWordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ShioriDatabase,
      $PlaylistWordsTable,
      PlaylistWordRow,
      $$PlaylistWordsTableFilterComposer,
      $$PlaylistWordsTableOrderingComposer,
      $$PlaylistWordsTableAnnotationComposer,
      $$PlaylistWordsTableCreateCompanionBuilder,
      $$PlaylistWordsTableUpdateCompanionBuilder,
      (PlaylistWordRow, $$PlaylistWordsTableReferences),
      PlaylistWordRow,
      PrefetchHooks Function({bool playlistId, bool wordId})
    >;
typedef $$ReviewCardsTableCreateCompanionBuilder =
    ReviewCardsCompanion Function({
      required String scope,
      Value<StudyMode> mode,
      required String wordId,
      required int level,
      required DateTime dueAt,
      required DateTime lastReviewedAt,
      required int reviewCount,
      required int lapseCount,
      Value<int> rowid,
    });
typedef $$ReviewCardsTableUpdateCompanionBuilder =
    ReviewCardsCompanion Function({
      Value<String> scope,
      Value<StudyMode> mode,
      Value<String> wordId,
      Value<int> level,
      Value<DateTime> dueAt,
      Value<DateTime> lastReviewedAt,
      Value<int> reviewCount,
      Value<int> lapseCount,
      Value<int> rowid,
    });

final class $$ReviewCardsTableReferences
    extends BaseReferences<_$ShioriDatabase, $ReviewCardsTable, CardRow> {
  $$ReviewCardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WordsTable _wordIdTable(_$ShioriDatabase db) =>
      db.words.createAlias('review_cards__word_id__words__id');

  $$WordsTableProcessedTableManager get wordId {
    final $_column = $_itemColumn<String>('word_id')!;

    final manager = $$WordsTableTableManager(
      $_db,
      $_db.words,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReviewCardsTableFilterComposer
    extends Composer<_$ShioriDatabase, $ReviewCardsTable> {
  $$ReviewCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<StudyMode, StudyMode, String> get mode =>
      $composableBuilder(
        column: $table.mode,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get dueAt =>
      $composableBuilder(
        column: $table.dueAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get lastReviewedAt =>
      $composableBuilder(
        column: $table.lastReviewedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get reviewCount => $composableBuilder(
    column: $table.reviewCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapseCount => $composableBuilder(
    column: $table.lapseCount,
    builder: (column) => ColumnFilters(column),
  );

  $$WordsTableFilterComposer get wordId {
    final $$WordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableFilterComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewCardsTableOrderingComposer
    extends Composer<_$ShioriDatabase, $ReviewCardsTable> {
  $$ReviewCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reviewCount => $composableBuilder(
    column: $table.reviewCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapseCount => $composableBuilder(
    column: $table.lapseCount,
    builder: (column) => ColumnOrderings(column),
  );

  $$WordsTableOrderingComposer get wordId {
    final $$WordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableOrderingComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewCardsTableAnnotationComposer
    extends Composer<_$ShioriDatabase, $ReviewCardsTable> {
  $$ReviewCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumnWithTypeConverter<StudyMode, String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get lastReviewedAt =>
      $composableBuilder(
        column: $table.lastReviewedAt,
        builder: (column) => column,
      );

  GeneratedColumn<int> get reviewCount => $composableBuilder(
    column: $table.reviewCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lapseCount => $composableBuilder(
    column: $table.lapseCount,
    builder: (column) => column,
  );

  $$WordsTableAnnotationComposer get wordId {
    final $$WordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableAnnotationComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewCardsTableTableManager
    extends
        RootTableManager<
          _$ShioriDatabase,
          $ReviewCardsTable,
          CardRow,
          $$ReviewCardsTableFilterComposer,
          $$ReviewCardsTableOrderingComposer,
          $$ReviewCardsTableAnnotationComposer,
          $$ReviewCardsTableCreateCompanionBuilder,
          $$ReviewCardsTableUpdateCompanionBuilder,
          (CardRow, $$ReviewCardsTableReferences),
          CardRow,
          PrefetchHooks Function({bool wordId})
        > {
  $$ReviewCardsTableTableManager(_$ShioriDatabase db, $ReviewCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<StudyMode> mode = const Value.absent(),
                Value<String> wordId = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<DateTime> lastReviewedAt = const Value.absent(),
                Value<int> reviewCount = const Value.absent(),
                Value<int> lapseCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewCardsCompanion(
                scope: scope,
                mode: mode,
                wordId: wordId,
                level: level,
                dueAt: dueAt,
                lastReviewedAt: lastReviewedAt,
                reviewCount: reviewCount,
                lapseCount: lapseCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                Value<StudyMode> mode = const Value.absent(),
                required String wordId,
                required int level,
                required DateTime dueAt,
                required DateTime lastReviewedAt,
                required int reviewCount,
                required int lapseCount,
                Value<int> rowid = const Value.absent(),
              }) => ReviewCardsCompanion.insert(
                scope: scope,
                mode: mode,
                wordId: wordId,
                level: level,
                dueAt: dueAt,
                lastReviewedAt: lastReviewedAt,
                reviewCount: reviewCount,
                lapseCount: lapseCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReviewCardsTable, CardRow>(table),
                  $$ReviewCardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({wordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (wordId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.wordId,
                                referencedTable: $$ReviewCardsTableReferences
                                    ._wordIdTable(db),
                                referencedColumn: $$ReviewCardsTableReferences
                                    ._wordIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReviewCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$ShioriDatabase,
      $ReviewCardsTable,
      CardRow,
      $$ReviewCardsTableFilterComposer,
      $$ReviewCardsTableOrderingComposer,
      $$ReviewCardsTableAnnotationComposer,
      $$ReviewCardsTableCreateCompanionBuilder,
      $$ReviewCardsTableUpdateCompanionBuilder,
      (CardRow, $$ReviewCardsTableReferences),
      CardRow,
      PrefetchHooks Function({bool wordId})
    >;
typedef $$ReviewLogsTableCreateCompanionBuilder =
    ReviewLogsCompanion Function({
      Value<int> id,
      required String scope,
      Value<StudyMode> mode,
      required String wordId,
      required Answer answer,
      required DateTime at,
      required int levelBefore,
      required int levelAfter,
      required int retriesInSession,
    });
typedef $$ReviewLogsTableUpdateCompanionBuilder =
    ReviewLogsCompanion Function({
      Value<int> id,
      Value<String> scope,
      Value<StudyMode> mode,
      Value<String> wordId,
      Value<Answer> answer,
      Value<DateTime> at,
      Value<int> levelBefore,
      Value<int> levelAfter,
      Value<int> retriesInSession,
    });

class $$ReviewLogsTableFilterComposer
    extends Composer<_$ShioriDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<StudyMode, StudyMode, String> get mode =>
      $composableBuilder(
        column: $table.mode,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get wordId => $composableBuilder(
    column: $table.wordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Answer, Answer, String> get answer =>
      $composableBuilder(
        column: $table.answer,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get at =>
      $composableBuilder(
        column: $table.at,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get levelBefore => $composableBuilder(
    column: $table.levelBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get levelAfter => $composableBuilder(
    column: $table.levelAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retriesInSession => $composableBuilder(
    column: $table.retriesInSession,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReviewLogsTableOrderingComposer
    extends Composer<_$ShioriDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wordId => $composableBuilder(
    column: $table.wordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get levelBefore => $composableBuilder(
    column: $table.levelBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get levelAfter => $composableBuilder(
    column: $table.levelAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retriesInSession => $composableBuilder(
    column: $table.retriesInSession,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReviewLogsTableAnnotationComposer
    extends Composer<_$ShioriDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumnWithTypeConverter<StudyMode, String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get wordId =>
      $composableBuilder(column: $table.wordId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Answer, String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<int> get levelBefore => $composableBuilder(
    column: $table.levelBefore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get levelAfter => $composableBuilder(
    column: $table.levelAfter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retriesInSession => $composableBuilder(
    column: $table.retriesInSession,
    builder: (column) => column,
  );
}

class $$ReviewLogsTableTableManager
    extends
        RootTableManager<
          _$ShioriDatabase,
          $ReviewLogsTable,
          LogRow,
          $$ReviewLogsTableFilterComposer,
          $$ReviewLogsTableOrderingComposer,
          $$ReviewLogsTableAnnotationComposer,
          $$ReviewLogsTableCreateCompanionBuilder,
          $$ReviewLogsTableUpdateCompanionBuilder,
          (LogRow, BaseReferences<_$ShioriDatabase, $ReviewLogsTable, LogRow>),
          LogRow,
          PrefetchHooks Function()
        > {
  $$ReviewLogsTableTableManager(_$ShioriDatabase db, $ReviewLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<StudyMode> mode = const Value.absent(),
                Value<String> wordId = const Value.absent(),
                Value<Answer> answer = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<int> levelBefore = const Value.absent(),
                Value<int> levelAfter = const Value.absent(),
                Value<int> retriesInSession = const Value.absent(),
              }) => ReviewLogsCompanion(
                id: id,
                scope: scope,
                mode: mode,
                wordId: wordId,
                answer: answer,
                at: at,
                levelBefore: levelBefore,
                levelAfter: levelAfter,
                retriesInSession: retriesInSession,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String scope,
                Value<StudyMode> mode = const Value.absent(),
                required String wordId,
                required Answer answer,
                required DateTime at,
                required int levelBefore,
                required int levelAfter,
                required int retriesInSession,
              }) => ReviewLogsCompanion.insert(
                id: id,
                scope: scope,
                mode: mode,
                wordId: wordId,
                answer: answer,
                at: at,
                levelBefore: levelBefore,
                levelAfter: levelAfter,
                retriesInSession: retriesInSession,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReviewLogsTable, LogRow>(table),
                  BaseReferences<_$ShioriDatabase, $ReviewLogsTable, LogRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReviewLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$ShioriDatabase,
      $ReviewLogsTable,
      LogRow,
      $$ReviewLogsTableFilterComposer,
      $$ReviewLogsTableOrderingComposer,
      $$ReviewLogsTableAnnotationComposer,
      $$ReviewLogsTableCreateCompanionBuilder,
      $$ReviewLogsTableUpdateCompanionBuilder,
      (LogRow, BaseReferences<_$ShioriDatabase, $ReviewLogsTable, LogRow>),
      LogRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$ShioriDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
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

class $$SettingsTableOrderingComposer
    extends Composer<_$ShioriDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
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

class $$SettingsTableAnnotationComposer
    extends Composer<_$ShioriDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
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

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$ShioriDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$ShioriDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$ShioriDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$ShioriDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$ShioriDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$ShioriDatabase, $SettingsTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;

class $ShioriDatabaseManager {
  final _$ShioriDatabase _db;
  $ShioriDatabaseManager(this._db);
  $$WordsTableTableManager get words =>
      $$WordsTableTableManager(_db, _db.words);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistWordsTableTableManager get playlistWords =>
      $$PlaylistWordsTableTableManager(_db, _db.playlistWords);
  $$ReviewCardsTableTableManager get reviewCards =>
      $$ReviewCardsTableTableManager(_db, _db.reviewCards);
  $$ReviewLogsTableTableManager get reviewLogs =>
      $$ReviewLogsTableTableManager(_db, _db.reviewLogs);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
