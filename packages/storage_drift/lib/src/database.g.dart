// GENERATED CODE - DO NOT MODIFY BY HAND

// coverage:ignore-file

part of 'database.dart';

// ignore_for_file: type=lint
class $TextbooksTable extends Textbooks
    with TableInfo<$TextbooksTable, TextbookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TextbooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
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
      ).withConverter<DateTime>($TextbooksTable.$convertercreatedAt);
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, createdAt, templateId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'textbooks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TextbookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TextbookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TextbookRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: $TextbooksTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      ),
    );
  }

  @override
  $TextbooksTable createAlias(String alias) {
    return $TextbooksTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const UtcMicrosConverter();
}

class TextbookRow extends DataClass implements Insertable<TextbookRow> {
  final String id;
  final String title;
  final DateTime createdAt;
  final String? templateId;
  const TextbookRow({
    required this.id,
    required this.title,
    required this.createdAt,
    this.templateId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    {
      map['created_at'] = Variable<int>(
        $TextbooksTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    if (!nullToAbsent || templateId != null) {
      map['template_id'] = Variable<String>(templateId);
    }
    return map;
  }

  TextbooksCompanion toCompanion(bool nullToAbsent) {
    return TextbooksCompanion(
      id: Value(id),
      title: Value(title),
      createdAt: Value(createdAt),
      templateId: templateId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateId),
    );
  }

  factory TextbookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TextbookRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      templateId: serializer.fromJson<String?>(json['templateId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'templateId': serializer.toJson<String?>(templateId),
    };
  }

  TextbookRow copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    Value<String?> templateId = const Value.absent(),
  }) => TextbookRow(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    templateId: templateId.present ? templateId.value : this.templateId,
  );
  TextbookRow copyWithCompanion(TextbooksCompanion data) {
    return TextbookRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TextbookRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('templateId: $templateId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, createdAt, templateId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TextbookRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.templateId == this.templateId);
}

class TextbooksCompanion extends UpdateCompanion<TextbookRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<String?> templateId;
  final Value<int> rowid;
  const TextbooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.templateId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TextbooksCompanion.insert({
    required String id,
    required String title,
    required DateTime createdAt,
    this.templateId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt);
  static Insertable<TextbookRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? createdAt,
    Expression<String>? templateId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (templateId != null) 'template_id': templateId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TextbooksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<DateTime>? createdAt,
    Value<String?>? templateId,
    Value<int>? rowid,
  }) {
    return TextbooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      templateId: templateId ?? this.templateId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $TextbooksTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TextbooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('templateId: $templateId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TextbookDaysTable extends TextbookDays
    with TableInfo<$TextbookDaysTable, DayRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TextbookDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _textbookIdMeta = const VerificationMeta(
    'textbookId',
  );
  @override
  late final GeneratedColumn<String> textbookId = GeneratedColumn<String>(
    'textbook_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES textbooks (id)',
    ),
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [textbookId, number, title];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'textbook_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('textbook_id')) {
      context.handle(
        _textbookIdMeta,
        textbookId.isAcceptableOrUnknown(data['textbook_id']!, _textbookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_textbookIdMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {textbookId, number};
  @override
  DayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayRow(
      textbookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}textbook_id'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
    );
  }

  @override
  $TextbookDaysTable createAlias(String alias) {
    return $TextbookDaysTable(attachedDatabase, alias);
  }
}

class DayRow extends DataClass implements Insertable<DayRow> {
  final String textbookId;
  final int number;
  final String title;
  const DayRow({
    required this.textbookId,
    required this.number,
    required this.title,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['textbook_id'] = Variable<String>(textbookId);
    map['number'] = Variable<int>(number);
    map['title'] = Variable<String>(title);
    return map;
  }

  TextbookDaysCompanion toCompanion(bool nullToAbsent) {
    return TextbookDaysCompanion(
      textbookId: Value(textbookId),
      number: Value(number),
      title: Value(title),
    );
  }

  factory DayRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayRow(
      textbookId: serializer.fromJson<String>(json['textbookId']),
      number: serializer.fromJson<int>(json['number']),
      title: serializer.fromJson<String>(json['title']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'textbookId': serializer.toJson<String>(textbookId),
      'number': serializer.toJson<int>(number),
      'title': serializer.toJson<String>(title),
    };
  }

  DayRow copyWith({String? textbookId, int? number, String? title}) => DayRow(
    textbookId: textbookId ?? this.textbookId,
    number: number ?? this.number,
    title: title ?? this.title,
  );
  DayRow copyWithCompanion(TextbookDaysCompanion data) {
    return DayRow(
      textbookId: data.textbookId.present
          ? data.textbookId.value
          : this.textbookId,
      number: data.number.present ? data.number.value : this.number,
      title: data.title.present ? data.title.value : this.title,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayRow(')
          ..write('textbookId: $textbookId, ')
          ..write('number: $number, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(textbookId, number, title);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayRow &&
          other.textbookId == this.textbookId &&
          other.number == this.number &&
          other.title == this.title);
}

class TextbookDaysCompanion extends UpdateCompanion<DayRow> {
  final Value<String> textbookId;
  final Value<int> number;
  final Value<String> title;
  final Value<int> rowid;
  const TextbookDaysCompanion({
    this.textbookId = const Value.absent(),
    this.number = const Value.absent(),
    this.title = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TextbookDaysCompanion.insert({
    required String textbookId,
    required int number,
    required String title,
    this.rowid = const Value.absent(),
  }) : textbookId = Value(textbookId),
       number = Value(number),
       title = Value(title);
  static Insertable<DayRow> custom({
    Expression<String>? textbookId,
    Expression<int>? number,
    Expression<String>? title,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (textbookId != null) 'textbook_id': textbookId,
      if (number != null) 'number': number,
      if (title != null) 'title': title,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TextbookDaysCompanion copyWith({
    Value<String>? textbookId,
    Value<int>? number,
    Value<String>? title,
    Value<int>? rowid,
  }) {
    return TextbookDaysCompanion(
      textbookId: textbookId ?? this.textbookId,
      number: number ?? this.number,
      title: title ?? this.title,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (textbookId.present) {
      map['textbook_id'] = Variable<String>(textbookId.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TextbookDaysCompanion(')
          ..write('textbookId: $textbookId, ')
          ..write('number: $number, ')
          ..write('title: $title, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

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
  static const VerificationMeta _textbookIdMeta = const VerificationMeta(
    'textbookId',
  );
  @override
  late final GeneratedColumn<String> textbookId = GeneratedColumn<String>(
    'textbook_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES textbooks (id)',
    ),
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
    'day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noMeta = const VerificationMeta('no');
  @override
  late final GeneratedColumn<String> no = GeneratedColumn<String>(
    'no',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _pageMeta = const VerificationMeta('page');
  @override
  late final GeneratedColumn<int> page = GeneratedColumn<int>(
    'page',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    textbookId,
    day,
    no,
    headword,
    readings,
    pos,
    meaning,
    exampleJa,
    exampleKo,
    page,
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
    if (data.containsKey('textbook_id')) {
      context.handle(
        _textbookIdMeta,
        textbookId.isAcceptableOrUnknown(data['textbook_id']!, _textbookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_textbookIdMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    }
    if (data.containsKey('no')) {
      context.handle(_noMeta, no.isAcceptableOrUnknown(data['no']!, _noMeta));
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
    if (data.containsKey('page')) {
      context.handle(
        _pageMeta,
        page.isAcceptableOrUnknown(data['page']!, _pageMeta),
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
      textbookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}textbook_id'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day'],
      ),
      no: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}no'],
      ),
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
      page: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page'],
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
  final String textbookId;
  final int? day;
  final String? no;
  final String headword;

  /// JSON array: always read and written with the word, never queried alone.
  final List<String> readings;
  final PartOfSpeech? pos;
  final String meaning;

  /// The example sentence and its translation come as a pair or not at all.
  final String? exampleJa;
  final String? exampleKo;
  final int? page;
  final DateTime createdAt;

  /// When the learner hid the word (이미 알아요); null while it is shown (v3).
  /// Not content: saving the word again keeps it.
  final DateTime? hiddenAt;
  const WordRow({
    required this.id,
    required this.textbookId,
    this.day,
    this.no,
    required this.headword,
    required this.readings,
    this.pos,
    required this.meaning,
    this.exampleJa,
    this.exampleKo,
    this.page,
    required this.createdAt,
    this.hiddenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['textbook_id'] = Variable<String>(textbookId);
    if (!nullToAbsent || day != null) {
      map['day'] = Variable<int>(day);
    }
    if (!nullToAbsent || no != null) {
      map['no'] = Variable<String>(no);
    }
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
    if (!nullToAbsent || page != null) {
      map['page'] = Variable<int>(page);
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
      textbookId: Value(textbookId),
      day: day == null && nullToAbsent ? const Value.absent() : Value(day),
      no: no == null && nullToAbsent ? const Value.absent() : Value(no),
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
      page: page == null && nullToAbsent ? const Value.absent() : Value(page),
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
      textbookId: serializer.fromJson<String>(json['textbookId']),
      day: serializer.fromJson<int?>(json['day']),
      no: serializer.fromJson<String?>(json['no']),
      headword: serializer.fromJson<String>(json['headword']),
      readings: serializer.fromJson<List<String>>(json['readings']),
      pos: $WordsTable.$converterposn.fromJson(
        serializer.fromJson<String?>(json['pos']),
      ),
      meaning: serializer.fromJson<String>(json['meaning']),
      exampleJa: serializer.fromJson<String?>(json['exampleJa']),
      exampleKo: serializer.fromJson<String?>(json['exampleKo']),
      page: serializer.fromJson<int?>(json['page']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      hiddenAt: serializer.fromJson<DateTime?>(json['hiddenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'textbookId': serializer.toJson<String>(textbookId),
      'day': serializer.toJson<int?>(day),
      'no': serializer.toJson<String?>(no),
      'headword': serializer.toJson<String>(headword),
      'readings': serializer.toJson<List<String>>(readings),
      'pos': serializer.toJson<String?>($WordsTable.$converterposn.toJson(pos)),
      'meaning': serializer.toJson<String>(meaning),
      'exampleJa': serializer.toJson<String?>(exampleJa),
      'exampleKo': serializer.toJson<String?>(exampleKo),
      'page': serializer.toJson<int?>(page),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'hiddenAt': serializer.toJson<DateTime?>(hiddenAt),
    };
  }

  WordRow copyWith({
    String? id,
    String? textbookId,
    Value<int?> day = const Value.absent(),
    Value<String?> no = const Value.absent(),
    String? headword,
    List<String>? readings,
    Value<PartOfSpeech?> pos = const Value.absent(),
    String? meaning,
    Value<String?> exampleJa = const Value.absent(),
    Value<String?> exampleKo = const Value.absent(),
    Value<int?> page = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> hiddenAt = const Value.absent(),
  }) => WordRow(
    id: id ?? this.id,
    textbookId: textbookId ?? this.textbookId,
    day: day.present ? day.value : this.day,
    no: no.present ? no.value : this.no,
    headword: headword ?? this.headword,
    readings: readings ?? this.readings,
    pos: pos.present ? pos.value : this.pos,
    meaning: meaning ?? this.meaning,
    exampleJa: exampleJa.present ? exampleJa.value : this.exampleJa,
    exampleKo: exampleKo.present ? exampleKo.value : this.exampleKo,
    page: page.present ? page.value : this.page,
    createdAt: createdAt ?? this.createdAt,
    hiddenAt: hiddenAt.present ? hiddenAt.value : this.hiddenAt,
  );
  WordRow copyWithCompanion(WordsCompanion data) {
    return WordRow(
      id: data.id.present ? data.id.value : this.id,
      textbookId: data.textbookId.present
          ? data.textbookId.value
          : this.textbookId,
      day: data.day.present ? data.day.value : this.day,
      no: data.no.present ? data.no.value : this.no,
      headword: data.headword.present ? data.headword.value : this.headword,
      readings: data.readings.present ? data.readings.value : this.readings,
      pos: data.pos.present ? data.pos.value : this.pos,
      meaning: data.meaning.present ? data.meaning.value : this.meaning,
      exampleJa: data.exampleJa.present ? data.exampleJa.value : this.exampleJa,
      exampleKo: data.exampleKo.present ? data.exampleKo.value : this.exampleKo,
      page: data.page.present ? data.page.value : this.page,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      hiddenAt: data.hiddenAt.present ? data.hiddenAt.value : this.hiddenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordRow(')
          ..write('id: $id, ')
          ..write('textbookId: $textbookId, ')
          ..write('day: $day, ')
          ..write('no: $no, ')
          ..write('headword: $headword, ')
          ..write('readings: $readings, ')
          ..write('pos: $pos, ')
          ..write('meaning: $meaning, ')
          ..write('exampleJa: $exampleJa, ')
          ..write('exampleKo: $exampleKo, ')
          ..write('page: $page, ')
          ..write('createdAt: $createdAt, ')
          ..write('hiddenAt: $hiddenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    textbookId,
    day,
    no,
    headword,
    readings,
    pos,
    meaning,
    exampleJa,
    exampleKo,
    page,
    createdAt,
    hiddenAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordRow &&
          other.id == this.id &&
          other.textbookId == this.textbookId &&
          other.day == this.day &&
          other.no == this.no &&
          other.headword == this.headword &&
          other.readings == this.readings &&
          other.pos == this.pos &&
          other.meaning == this.meaning &&
          other.exampleJa == this.exampleJa &&
          other.exampleKo == this.exampleKo &&
          other.page == this.page &&
          other.createdAt == this.createdAt &&
          other.hiddenAt == this.hiddenAt);
}

class WordsCompanion extends UpdateCompanion<WordRow> {
  final Value<String> id;
  final Value<String> textbookId;
  final Value<int?> day;
  final Value<String?> no;
  final Value<String> headword;
  final Value<List<String>> readings;
  final Value<PartOfSpeech?> pos;
  final Value<String> meaning;
  final Value<String?> exampleJa;
  final Value<String?> exampleKo;
  final Value<int?> page;
  final Value<DateTime> createdAt;
  final Value<DateTime?> hiddenAt;
  final Value<int> rowid;
  const WordsCompanion({
    this.id = const Value.absent(),
    this.textbookId = const Value.absent(),
    this.day = const Value.absent(),
    this.no = const Value.absent(),
    this.headword = const Value.absent(),
    this.readings = const Value.absent(),
    this.pos = const Value.absent(),
    this.meaning = const Value.absent(),
    this.exampleJa = const Value.absent(),
    this.exampleKo = const Value.absent(),
    this.page = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.hiddenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordsCompanion.insert({
    required String id,
    required String textbookId,
    this.day = const Value.absent(),
    this.no = const Value.absent(),
    required String headword,
    required List<String> readings,
    this.pos = const Value.absent(),
    required String meaning,
    this.exampleJa = const Value.absent(),
    this.exampleKo = const Value.absent(),
    this.page = const Value.absent(),
    required DateTime createdAt,
    this.hiddenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       textbookId = Value(textbookId),
       headword = Value(headword),
       readings = Value(readings),
       meaning = Value(meaning),
       createdAt = Value(createdAt);
  static Insertable<WordRow> custom({
    Expression<String>? id,
    Expression<String>? textbookId,
    Expression<int>? day,
    Expression<String>? no,
    Expression<String>? headword,
    Expression<String>? readings,
    Expression<String>? pos,
    Expression<String>? meaning,
    Expression<String>? exampleJa,
    Expression<String>? exampleKo,
    Expression<int>? page,
    Expression<int>? createdAt,
    Expression<int>? hiddenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (textbookId != null) 'textbook_id': textbookId,
      if (day != null) 'day': day,
      if (no != null) 'no': no,
      if (headword != null) 'headword': headword,
      if (readings != null) 'readings': readings,
      if (pos != null) 'pos': pos,
      if (meaning != null) 'meaning': meaning,
      if (exampleJa != null) 'example_ja': exampleJa,
      if (exampleKo != null) 'example_ko': exampleKo,
      if (page != null) 'page': page,
      if (createdAt != null) 'created_at': createdAt,
      if (hiddenAt != null) 'hidden_at': hiddenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordsCompanion copyWith({
    Value<String>? id,
    Value<String>? textbookId,
    Value<int?>? day,
    Value<String?>? no,
    Value<String>? headword,
    Value<List<String>>? readings,
    Value<PartOfSpeech?>? pos,
    Value<String>? meaning,
    Value<String?>? exampleJa,
    Value<String?>? exampleKo,
    Value<int?>? page,
    Value<DateTime>? createdAt,
    Value<DateTime?>? hiddenAt,
    Value<int>? rowid,
  }) {
    return WordsCompanion(
      id: id ?? this.id,
      textbookId: textbookId ?? this.textbookId,
      day: day ?? this.day,
      no: no ?? this.no,
      headword: headword ?? this.headword,
      readings: readings ?? this.readings,
      pos: pos ?? this.pos,
      meaning: meaning ?? this.meaning,
      exampleJa: exampleJa ?? this.exampleJa,
      exampleKo: exampleKo ?? this.exampleKo,
      page: page ?? this.page,
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
    if (textbookId.present) {
      map['textbook_id'] = Variable<String>(textbookId.value);
    }
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    if (no.present) {
      map['no'] = Variable<String>(no.value);
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
    if (page.present) {
      map['page'] = Variable<int>(page.value);
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
          ..write('textbookId: $textbookId, ')
          ..write('day: $day, ')
          ..write('no: $no, ')
          ..write('headword: $headword, ')
          ..write('readings: $readings, ')
          ..write('pos: $pos, ')
          ..write('meaning: $meaning, ')
          ..write('exampleJa: $exampleJa, ')
          ..write('exampleKo: $exampleKo, ')
          ..write('page: $page, ')
          ..write('createdAt: $createdAt, ')
          ..write('hiddenAt: $hiddenAt, ')
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
  static const VerificationMeta _wordIdMeta = const VerificationMeta('wordId');
  @override
  late final GeneratedColumn<String> wordId = GeneratedColumn<String>(
    'word_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  Set<GeneratedColumn> get $primaryKey => {wordId};
  @override
  CardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardRow(
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

  static TypeConverter<DateTime, int> $converterdueAt =
      const UtcMicrosConverter();
  static TypeConverter<DateTime, int> $converterlastReviewedAt =
      const UtcMicrosConverter();
}

class CardRow extends DataClass implements Insertable<CardRow> {
  final String wordId;
  final int level;
  final DateTime dueAt;
  final DateTime lastReviewedAt;
  final int reviewCount;
  final int lapseCount;
  const CardRow({
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
      'wordId': serializer.toJson<String>(wordId),
      'level': serializer.toJson<int>(level),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'lastReviewedAt': serializer.toJson<DateTime>(lastReviewedAt),
      'reviewCount': serializer.toJson<int>(reviewCount),
      'lapseCount': serializer.toJson<int>(lapseCount),
    };
  }

  CardRow copyWith({
    String? wordId,
    int? level,
    DateTime? dueAt,
    DateTime? lastReviewedAt,
    int? reviewCount,
    int? lapseCount,
  }) => CardRow(
    wordId: wordId ?? this.wordId,
    level: level ?? this.level,
    dueAt: dueAt ?? this.dueAt,
    lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    reviewCount: reviewCount ?? this.reviewCount,
    lapseCount: lapseCount ?? this.lapseCount,
  );
  CardRow copyWithCompanion(ReviewCardsCompanion data) {
    return CardRow(
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
          other.wordId == this.wordId &&
          other.level == this.level &&
          other.dueAt == this.dueAt &&
          other.lastReviewedAt == this.lastReviewedAt &&
          other.reviewCount == this.reviewCount &&
          other.lapseCount == this.lapseCount);
}

class ReviewCardsCompanion extends UpdateCompanion<CardRow> {
  final Value<String> wordId;
  final Value<int> level;
  final Value<DateTime> dueAt;
  final Value<DateTime> lastReviewedAt;
  final Value<int> reviewCount;
  final Value<int> lapseCount;
  final Value<int> rowid;
  const ReviewCardsCompanion({
    this.wordId = const Value.absent(),
    this.level = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    this.reviewCount = const Value.absent(),
    this.lapseCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewCardsCompanion.insert({
    required String wordId,
    required int level,
    required DateTime dueAt,
    required DateTime lastReviewedAt,
    required int reviewCount,
    required int lapseCount,
    this.rowid = const Value.absent(),
  }) : wordId = Value(wordId),
       level = Value(level),
       dueAt = Value(dueAt),
       lastReviewedAt = Value(lastReviewedAt),
       reviewCount = Value(reviewCount),
       lapseCount = Value(lapseCount);
  static Insertable<CardRow> custom({
    Expression<String>? wordId,
    Expression<int>? level,
    Expression<int>? dueAt,
    Expression<int>? lastReviewedAt,
    Expression<int>? reviewCount,
    Expression<int>? lapseCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
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
    Value<String>? wordId,
    Value<int>? level,
    Value<DateTime>? dueAt,
    Value<DateTime>? lastReviewedAt,
    Value<int>? reviewCount,
    Value<int>? lapseCount,
    Value<int>? rowid,
  }) {
    return ReviewCardsCompanion(
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

  static JsonTypeConverter2<Answer, String, String> $converteranswer =
      const EnumNameConverter<Answer>(Answer.values);
  static TypeConverter<DateTime, int> $converterat = const UtcMicrosConverter();
}

class LogRow extends DataClass implements Insertable<LogRow> {
  final int id;
  final String wordId;
  final Answer answer;
  final DateTime at;
  final int levelBefore;
  final int levelAfter;
  final int retriesInSession;
  const LogRow({
    required this.id,
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
    String? wordId,
    Answer? answer,
    DateTime? at,
    int? levelBefore,
    int? levelAfter,
    int? retriesInSession,
  }) => LogRow(
    id: id ?? this.id,
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
          other.wordId == this.wordId &&
          other.answer == this.answer &&
          other.at == this.at &&
          other.levelBefore == this.levelBefore &&
          other.levelAfter == this.levelAfter &&
          other.retriesInSession == this.retriesInSession);
}

class ReviewLogsCompanion extends UpdateCompanion<LogRow> {
  final Value<int> id;
  final Value<String> wordId;
  final Value<Answer> answer;
  final Value<DateTime> at;
  final Value<int> levelBefore;
  final Value<int> levelAfter;
  final Value<int> retriesInSession;
  const ReviewLogsCompanion({
    this.id = const Value.absent(),
    this.wordId = const Value.absent(),
    this.answer = const Value.absent(),
    this.at = const Value.absent(),
    this.levelBefore = const Value.absent(),
    this.levelAfter = const Value.absent(),
    this.retriesInSession = const Value.absent(),
  });
  ReviewLogsCompanion.insert({
    this.id = const Value.absent(),
    required String wordId,
    required Answer answer,
    required DateTime at,
    required int levelBefore,
    required int levelAfter,
    required int retriesInSession,
  }) : wordId = Value(wordId),
       answer = Value(answer),
       at = Value(at),
       levelBefore = Value(levelBefore),
       levelAfter = Value(levelAfter),
       retriesInSession = Value(retriesInSession);
  static Insertable<LogRow> custom({
    Expression<int>? id,
    Expression<String>? wordId,
    Expression<String>? answer,
    Expression<int>? at,
    Expression<int>? levelBefore,
    Expression<int>? levelAfter,
    Expression<int>? retriesInSession,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
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
    Value<String>? wordId,
    Value<Answer>? answer,
    Value<DateTime>? at,
    Value<int>? levelBefore,
    Value<int>? levelAfter,
    Value<int>? retriesInSession,
  }) {
    return ReviewLogsCompanion(
      id: id ?? this.id,
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

abstract class _$ShioriDatabase extends GeneratedDatabase {
  _$ShioriDatabase(QueryExecutor e) : super(e);
  $ShioriDatabaseManager get managers => $ShioriDatabaseManager(this);
  late final $TextbooksTable textbooks = $TextbooksTable(this);
  late final $TextbookDaysTable textbookDays = $TextbookDaysTable(this);
  late final $WordsTable words = $WordsTable(this);
  late final $ReviewCardsTable reviewCards = $ReviewCardsTable(this);
  late final $ReviewLogsTable reviewLogs = $ReviewLogsTable(this);
  late final Index wordsByPlace = Index(
    'words_by_place',
    'CREATE INDEX words_by_place ON words (textbook_id, day, "no")',
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
    textbooks,
    textbookDays,
    words,
    reviewCards,
    reviewLogs,
    wordsByPlace,
    reviewLogsByTime,
  ];
}

typedef $$TextbooksTableCreateCompanionBuilder =
    TextbooksCompanion Function({
      required String id,
      required String title,
      required DateTime createdAt,
      Value<String?> templateId,
      Value<int> rowid,
    });
typedef $$TextbooksTableUpdateCompanionBuilder =
    TextbooksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<DateTime> createdAt,
      Value<String?> templateId,
      Value<int> rowid,
    });

final class $$TextbooksTableReferences
    extends BaseReferences<_$ShioriDatabase, $TextbooksTable, TextbookRow> {
  $$TextbooksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TextbookDaysTable, List<DayRow>>
  _textbookDaysRefsTable(_$ShioriDatabase db) => MultiTypedResultKey.fromTable(
    db.textbookDays,
    aliasName: 'textbooks__id__textbook_days__textbook_id',
  );

  $$TextbookDaysTableProcessedTableManager get textbookDaysRefs {
    final manager = $$TextbookDaysTableTableManager(
      $_db,
      $_db.textbookDays,
    ).filter((f) => f.textbookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_textbookDaysRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WordsTable, List<WordRow>> _wordsRefsTable(
    _$ShioriDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.words,
    aliasName: 'textbooks__id__words__textbook_id',
  );

  $$WordsTableProcessedTableManager get wordsRefs {
    final manager = $$WordsTableTableManager(
      $_db,
      $_db.words,
    ).filter((f) => f.textbookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_wordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TextbooksTableFilterComposer
    extends Composer<_$ShioriDatabase, $TextbooksTable> {
  $$TextbooksTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> textbookDaysRefs(
    Expression<bool> Function($$TextbookDaysTableFilterComposer f) f,
  ) {
    final $$TextbookDaysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.textbookDays,
      getReferencedColumn: (t) => t.textbookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextbookDaysTableFilterComposer(
            $db: $db,
            $table: $db.textbookDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> wordsRefs(
    Expression<bool> Function($$WordsTableFilterComposer f) f,
  ) {
    final $$WordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.textbookId,
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
    return f(composer);
  }
}

class $$TextbooksTableOrderingComposer
    extends Composer<_$ShioriDatabase, $TextbooksTable> {
  $$TextbooksTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TextbooksTableAnnotationComposer
    extends Composer<_$ShioriDatabase, $TextbooksTable> {
  $$TextbooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => column,
  );

  Expression<T> textbookDaysRefs<T extends Object>(
    Expression<T> Function($$TextbookDaysTableAnnotationComposer a) f,
  ) {
    final $$TextbookDaysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.textbookDays,
      getReferencedColumn: (t) => t.textbookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextbookDaysTableAnnotationComposer(
            $db: $db,
            $table: $db.textbookDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> wordsRefs<T extends Object>(
    Expression<T> Function($$WordsTableAnnotationComposer a) f,
  ) {
    final $$WordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.textbookId,
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
    return f(composer);
  }
}

class $$TextbooksTableTableManager
    extends
        RootTableManager<
          _$ShioriDatabase,
          $TextbooksTable,
          TextbookRow,
          $$TextbooksTableFilterComposer,
          $$TextbooksTableOrderingComposer,
          $$TextbooksTableAnnotationComposer,
          $$TextbooksTableCreateCompanionBuilder,
          $$TextbooksTableUpdateCompanionBuilder,
          (TextbookRow, $$TextbooksTableReferences),
          TextbookRow,
          PrefetchHooks Function({bool textbookDaysRefs, bool wordsRefs})
        > {
  $$TextbooksTableTableManager(_$ShioriDatabase db, $TextbooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TextbooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TextbooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TextbooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> templateId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TextbooksCompanion(
                id: id,
                title: title,
                createdAt: createdAt,
                templateId: templateId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required DateTime createdAt,
                Value<String?> templateId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TextbooksCompanion.insert(
                id: id,
                title: title,
                createdAt: createdAt,
                templateId: templateId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TextbooksTable, TextbookRow>(table),
                  $$TextbooksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({textbookDaysRefs = false, wordsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (textbookDaysRefs) db.textbookDays,
                    if (wordsRefs) db.words,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (textbookDaysRefs)
                        await $_getPrefetchedDataByColumns<
                          TextbookRow,
                          $TextbooksTable,
                          DayRow,
                          $TextbookDaysTable
                        >(
                          currentTable: table,
                          referencedTable: $$TextbooksTableReferences
                              ._textbookDaysRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TextbooksTableReferences(
                                db,
                                table,
                                p0,
                              ).textbookDaysRefs,
                          currentColumn: 'id',
                          referencedColumn: 'textbook_id',
                          typedResults: items,
                        ),
                      if (wordsRefs)
                        await $_getPrefetchedDataByColumns<
                          TextbookRow,
                          $TextbooksTable,
                          WordRow,
                          $WordsTable
                        >(
                          currentTable: table,
                          referencedTable: $$TextbooksTableReferences
                              ._wordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TextbooksTableReferences(
                                db,
                                table,
                                p0,
                              ).wordsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'textbook_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TextbooksTableProcessedTableManager =
    ProcessedTableManager<
      _$ShioriDatabase,
      $TextbooksTable,
      TextbookRow,
      $$TextbooksTableFilterComposer,
      $$TextbooksTableOrderingComposer,
      $$TextbooksTableAnnotationComposer,
      $$TextbooksTableCreateCompanionBuilder,
      $$TextbooksTableUpdateCompanionBuilder,
      (TextbookRow, $$TextbooksTableReferences),
      TextbookRow,
      PrefetchHooks Function({bool textbookDaysRefs, bool wordsRefs})
    >;
typedef $$TextbookDaysTableCreateCompanionBuilder =
    TextbookDaysCompanion Function({
      required String textbookId,
      required int number,
      required String title,
      Value<int> rowid,
    });
typedef $$TextbookDaysTableUpdateCompanionBuilder =
    TextbookDaysCompanion Function({
      Value<String> textbookId,
      Value<int> number,
      Value<String> title,
      Value<int> rowid,
    });

final class $$TextbookDaysTableReferences
    extends BaseReferences<_$ShioriDatabase, $TextbookDaysTable, DayRow> {
  $$TextbookDaysTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TextbooksTable _textbookIdTable(_$ShioriDatabase db) =>
      db.textbooks.createAlias('textbook_days__textbook_id__textbooks__id');

  $$TextbooksTableProcessedTableManager get textbookId {
    final $_column = $_itemColumn<String>('textbook_id')!;

    final manager = $$TextbooksTableTableManager(
      $_db,
      $_db.textbooks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_textbookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TextbookDaysTableFilterComposer
    extends Composer<_$ShioriDatabase, $TextbookDaysTable> {
  $$TextbookDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  $$TextbooksTableFilterComposer get textbookId {
    final $$TextbooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.textbookId,
      referencedTable: $db.textbooks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextbooksTableFilterComposer(
            $db: $db,
            $table: $db.textbooks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TextbookDaysTableOrderingComposer
    extends Composer<_$ShioriDatabase, $TextbookDaysTable> {
  $$TextbookDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  $$TextbooksTableOrderingComposer get textbookId {
    final $$TextbooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.textbookId,
      referencedTable: $db.textbooks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextbooksTableOrderingComposer(
            $db: $db,
            $table: $db.textbooks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TextbookDaysTableAnnotationComposer
    extends Composer<_$ShioriDatabase, $TextbookDaysTable> {
  $$TextbookDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  $$TextbooksTableAnnotationComposer get textbookId {
    final $$TextbooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.textbookId,
      referencedTable: $db.textbooks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextbooksTableAnnotationComposer(
            $db: $db,
            $table: $db.textbooks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TextbookDaysTableTableManager
    extends
        RootTableManager<
          _$ShioriDatabase,
          $TextbookDaysTable,
          DayRow,
          $$TextbookDaysTableFilterComposer,
          $$TextbookDaysTableOrderingComposer,
          $$TextbookDaysTableAnnotationComposer,
          $$TextbookDaysTableCreateCompanionBuilder,
          $$TextbookDaysTableUpdateCompanionBuilder,
          (DayRow, $$TextbookDaysTableReferences),
          DayRow,
          PrefetchHooks Function({bool textbookId})
        > {
  $$TextbookDaysTableTableManager(_$ShioriDatabase db, $TextbookDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TextbookDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TextbookDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TextbookDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> textbookId = const Value.absent(),
                Value<int> number = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TextbookDaysCompanion(
                textbookId: textbookId,
                number: number,
                title: title,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String textbookId,
                required int number,
                required String title,
                Value<int> rowid = const Value.absent(),
              }) => TextbookDaysCompanion.insert(
                textbookId: textbookId,
                number: number,
                title: title,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TextbookDaysTable, DayRow>(table),
                  $$TextbookDaysTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({textbookId = false}) {
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
                    if (textbookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.textbookId,
                                referencedTable: $$TextbookDaysTableReferences
                                    ._textbookIdTable(db),
                                referencedColumn: $$TextbookDaysTableReferences
                                    ._textbookIdTable(db)
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

typedef $$TextbookDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$ShioriDatabase,
      $TextbookDaysTable,
      DayRow,
      $$TextbookDaysTableFilterComposer,
      $$TextbookDaysTableOrderingComposer,
      $$TextbookDaysTableAnnotationComposer,
      $$TextbookDaysTableCreateCompanionBuilder,
      $$TextbookDaysTableUpdateCompanionBuilder,
      (DayRow, $$TextbookDaysTableReferences),
      DayRow,
      PrefetchHooks Function({bool textbookId})
    >;
typedef $$WordsTableCreateCompanionBuilder =
    WordsCompanion Function({
      required String id,
      required String textbookId,
      Value<int?> day,
      Value<String?> no,
      required String headword,
      required List<String> readings,
      Value<PartOfSpeech?> pos,
      required String meaning,
      Value<String?> exampleJa,
      Value<String?> exampleKo,
      Value<int?> page,
      required DateTime createdAt,
      Value<DateTime?> hiddenAt,
      Value<int> rowid,
    });
typedef $$WordsTableUpdateCompanionBuilder =
    WordsCompanion Function({
      Value<String> id,
      Value<String> textbookId,
      Value<int?> day,
      Value<String?> no,
      Value<String> headword,
      Value<List<String>> readings,
      Value<PartOfSpeech?> pos,
      Value<String> meaning,
      Value<String?> exampleJa,
      Value<String?> exampleKo,
      Value<int?> page,
      Value<DateTime> createdAt,
      Value<DateTime?> hiddenAt,
      Value<int> rowid,
    });

final class $$WordsTableReferences
    extends BaseReferences<_$ShioriDatabase, $WordsTable, WordRow> {
  $$WordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TextbooksTable _textbookIdTable(_$ShioriDatabase db) =>
      db.textbooks.createAlias('words__textbook_id__textbooks__id');

  $$TextbooksTableProcessedTableManager get textbookId {
    final $_column = $_itemColumn<String>('textbook_id')!;

    final manager = $$TextbooksTableTableManager(
      $_db,
      $_db.textbooks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_textbookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
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

  ColumnFilters<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get no => $composableBuilder(
    column: $table.no,
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

  ColumnFilters<int> get page => $composableBuilder(
    column: $table.page,
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

  $$TextbooksTableFilterComposer get textbookId {
    final $$TextbooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.textbookId,
      referencedTable: $db.textbooks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextbooksTableFilterComposer(
            $db: $db,
            $table: $db.textbooks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
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

  ColumnOrderings<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get no => $composableBuilder(
    column: $table.no,
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

  ColumnOrderings<int> get page => $composableBuilder(
    column: $table.page,
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

  $$TextbooksTableOrderingComposer get textbookId {
    final $$TextbooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.textbookId,
      referencedTable: $db.textbooks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextbooksTableOrderingComposer(
            $db: $db,
            $table: $db.textbooks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  GeneratedColumn<int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get no =>
      $composableBuilder(column: $table.no, builder: (column) => column);

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

  GeneratedColumn<int> get page =>
      $composableBuilder(column: $table.page, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get hiddenAt =>
      $composableBuilder(column: $table.hiddenAt, builder: (column) => column);

  $$TextbooksTableAnnotationComposer get textbookId {
    final $$TextbooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.textbookId,
      referencedTable: $db.textbooks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextbooksTableAnnotationComposer(
            $db: $db,
            $table: $db.textbooks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
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
          PrefetchHooks Function({bool textbookId})
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
                Value<String> textbookId = const Value.absent(),
                Value<int?> day = const Value.absent(),
                Value<String?> no = const Value.absent(),
                Value<String> headword = const Value.absent(),
                Value<List<String>> readings = const Value.absent(),
                Value<PartOfSpeech?> pos = const Value.absent(),
                Value<String> meaning = const Value.absent(),
                Value<String?> exampleJa = const Value.absent(),
                Value<String?> exampleKo = const Value.absent(),
                Value<int?> page = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> hiddenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordsCompanion(
                id: id,
                textbookId: textbookId,
                day: day,
                no: no,
                headword: headword,
                readings: readings,
                pos: pos,
                meaning: meaning,
                exampleJa: exampleJa,
                exampleKo: exampleKo,
                page: page,
                createdAt: createdAt,
                hiddenAt: hiddenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String textbookId,
                Value<int?> day = const Value.absent(),
                Value<String?> no = const Value.absent(),
                required String headword,
                required List<String> readings,
                Value<PartOfSpeech?> pos = const Value.absent(),
                required String meaning,
                Value<String?> exampleJa = const Value.absent(),
                Value<String?> exampleKo = const Value.absent(),
                Value<int?> page = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> hiddenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordsCompanion.insert(
                id: id,
                textbookId: textbookId,
                day: day,
                no: no,
                headword: headword,
                readings: readings,
                pos: pos,
                meaning: meaning,
                exampleJa: exampleJa,
                exampleKo: exampleKo,
                page: page,
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
          prefetchHooksCallback: ({textbookId = false}) {
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
                    if (textbookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.textbookId,
                                referencedTable: $$WordsTableReferences
                                    ._textbookIdTable(db),
                                referencedColumn: $$WordsTableReferences
                                    ._textbookIdTable(db)
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
      PrefetchHooks Function({bool textbookId})
    >;
typedef $$ReviewCardsTableCreateCompanionBuilder =
    ReviewCardsCompanion Function({
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
      Value<String> wordId,
      Value<int> level,
      Value<DateTime> dueAt,
      Value<DateTime> lastReviewedAt,
      Value<int> reviewCount,
      Value<int> lapseCount,
      Value<int> rowid,
    });

class $$ReviewCardsTableFilterComposer
    extends Composer<_$ShioriDatabase, $ReviewCardsTable> {
  $$ReviewCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get wordId => $composableBuilder(
    column: $table.wordId,
    builder: (column) => ColumnFilters(column),
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
  ColumnOrderings<String> get wordId => $composableBuilder(
    column: $table.wordId,
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
  GeneratedColumn<String> get wordId =>
      $composableBuilder(column: $table.wordId, builder: (column) => column);

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
          (
            CardRow,
            BaseReferences<_$ShioriDatabase, $ReviewCardsTable, CardRow>,
          ),
          CardRow,
          PrefetchHooks Function()
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
                Value<String> wordId = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<DateTime> lastReviewedAt = const Value.absent(),
                Value<int> reviewCount = const Value.absent(),
                Value<int> lapseCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewCardsCompanion(
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
                required String wordId,
                required int level,
                required DateTime dueAt,
                required DateTime lastReviewedAt,
                required int reviewCount,
                required int lapseCount,
                Value<int> rowid = const Value.absent(),
              }) => ReviewCardsCompanion.insert(
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
                  BaseReferences<_$ShioriDatabase, $ReviewCardsTable, CardRow>(
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
      (CardRow, BaseReferences<_$ShioriDatabase, $ReviewCardsTable, CardRow>),
      CardRow,
      PrefetchHooks Function()
    >;
typedef $$ReviewLogsTableCreateCompanionBuilder =
    ReviewLogsCompanion Function({
      Value<int> id,
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
                Value<String> wordId = const Value.absent(),
                Value<Answer> answer = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<int> levelBefore = const Value.absent(),
                Value<int> levelAfter = const Value.absent(),
                Value<int> retriesInSession = const Value.absent(),
              }) => ReviewLogsCompanion(
                id: id,
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
                required String wordId,
                required Answer answer,
                required DateTime at,
                required int levelBefore,
                required int levelAfter,
                required int retriesInSession,
              }) => ReviewLogsCompanion.insert(
                id: id,
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

class $ShioriDatabaseManager {
  final _$ShioriDatabase _db;
  $ShioriDatabaseManager(this._db);
  $$TextbooksTableTableManager get textbooks =>
      $$TextbooksTableTableManager(_db, _db.textbooks);
  $$TextbookDaysTableTableManager get textbookDays =>
      $$TextbookDaysTableTableManager(_db, _db.textbookDays);
  $$WordsTableTableManager get words =>
      $$WordsTableTableManager(_db, _db.words);
  $$ReviewCardsTableTableManager get reviewCards =>
      $$ReviewCardsTableTableManager(_db, _db.reviewCards);
  $$ReviewLogsTableTableManager get reviewLogs =>
      $$ReviewLogsTableTableManager(_db, _db.reviewLogs);
}
