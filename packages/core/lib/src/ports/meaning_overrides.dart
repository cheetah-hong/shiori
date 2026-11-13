import 'dart:convert';

import 'package:shiori_core/src/models/part_of_speech.dart';
import 'package:shiori_core/src/ports/korean_glossary.dart';
import 'package:shiori_core/src/study/card_example.dart' show toHiraganaReading;

/// The `format` of a meaning overrides file
/// (tools/dict/build_meaning_overrides.py).
const String meaningOverridesFormat = 'shiori-meaning-overrides';

/// The newest meaning overrides file version this build reads.
const int meaningOverridesVersion = 1;

/// A meaning this app wrote for a word whose dictionary meaning is off: the
/// word's spellings ([forms]) read [reading] mean [meaning].
final class MeaningOverride {
  const MeaningOverride({
    required this.forms,
    required this.reading,
    required this.meaning,
  });

  /// The spellings it is for: the word as listed, and the kanji spellings of
  /// its dictionary entry.
  final List<String> forms;

  /// The reading in kana (the word itself for a word written in kana).
  final String reading;

  /// Korean words, `, ` between them.
  final String meaning;
}

/// The meaning overrides (시오리 보정), looked up by spelling and reading.
final class MeaningOverrides {
  /// Throws [FormatException] when a spelling and reading come twice.
  MeaningOverrides(Iterable<MeaningOverride> rows, {this.edition = ''}) {
    for (final row in rows) {
      final reading = toHiraganaReading(row.reading);
      for (final form in row.forms) {
        final byReading = _byForm.putIfAbsent(form, () => {});
        if (byReading.containsKey(reading)) {
          throw FormatException('meaning overrides: $form $reading twice');
        }
        byReading[reading] = row.meaning;
      }
      _length++;
    }
  }

  static final MeaningOverrides empty = MeaningOverrides(const []);

  /// The day the file was made.
  final String edition;

  /// Spelling → reading (hiragana) → meaning, in the file's order.
  final Map<String, Map<String, String>> _byForm = {};
  int _length = 0;

  /// Rows in the file.
  int get length => _length;

  /// The meaning of [form] read as one of [readings] (katakana and hiragana
  /// alike); without readings, the spelling's first meaning.
  String? meaningOf(String form, {List<String> readings = const []}) {
    final byReading = _byForm[form.trim()];
    if (byReading == null) return null;
    if (readings.isEmpty) return byReading.values.firstOrNull;
    for (final r in readings) {
      final meaning = byReading[toHiraganaReading(r.trim())];
      if (meaning != null) return meaning;
    }
    return null;
  }
}

/// Reads a meaning overrides file. Throws [FormatException] when it is not
/// one this build reads, or a row is incomplete or has an unknown key.
MeaningOverrides parseMeaningOverrides(String text) {
  final Object? top;
  try {
    top = jsonDecode(text);
  } on FormatException catch (e) {
    throw FormatException('meaning overrides are not JSON: ${e.message}');
  }
  if (top is! Map<String, Object?>) {
    throw const FormatException('meaning overrides: not a JSON object');
  }
  if (top['format'] != meaningOverridesFormat) {
    throw FormatException('not a meaning overrides file', top['format']);
  }
  if (top['version'] != meaningOverridesVersion) {
    throw FormatException(
      'meaning overrides version this app cannot read',
      top['version'],
    );
  }
  final rows = top['rows'];
  if (rows is! List<Object?>) {
    throw const FormatException('meaning overrides: no rows');
  }
  return MeaningOverrides([
    for (final row in rows) _row(row),
  ], edition: top['edition'] is String ? top['edition']! as String : '');
}

const Set<String> _rowKeys = {'f', 'r', 'm'};

MeaningOverride _row(Object? row) {
  if (row is! Map<String, Object?>) {
    throw const FormatException('meaning overrides: a row is not an object');
  }
  final unknown = row.keys.where((k) => !_rowKeys.contains(k));
  if (unknown.isNotEmpty) {
    throw FormatException('meaning overrides: unknown key', unknown.first);
  }
  final forms = switch (row['f']) {
    final List<Object?> list when list.isNotEmpty => [
      for (final f in list)
        switch (f) {
          final String s when s.trim().isNotEmpty => s.trim(),
          _ => throw const FormatException('meaning overrides: empty form'),
        },
    ],
    _ => throw const FormatException('meaning overrides: a row has no forms'),
  };
  String text(String key) => switch (row[key]) {
    final String s when s.trim().isNotEmpty => s.trim(),
    _ => throw FormatException('meaning overrides: a row has no $key'),
  };
  return MeaningOverride(
    forms: List.unmodifiable(forms),
    reading: text('r'),
    meaning: text('m'),
  );
}

/// [primary] with the meaning overrides' meaning as the first sense of the
/// words they are for (source [GlossarySource.shiori]); [primary]'s senses
/// follow without one of the same text. Every other word is [primary]'s
/// answer as it is. Read backwards and sources are [primary]'s.
final class OverriddenKoreanGlossary
    implements KoreanGlossary, KoreanReverseGlossary {
  OverriddenKoreanGlossary(this.primary, this.overrides);

  final KoreanGlossary primary;
  final MeaningOverrides overrides;

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async {
    final found = await primary.lookup(
      headword,
      readings: readings,
      limit: limit,
      pos: pos,
    );
    final meaning = overrides.meaningOf(headword, readings: readings);
    if (meaning == null) return found;
    final own = KoreanSense(
      words: [
        for (final w in meaning.split(','))
          if (w.trim().isNotEmpty) w.trim(),
      ],
      source: GlossarySource.shiori,
    );
    return List.unmodifiable(
      [
        own,
        for (final s in found)
          if (s.text != own.text) s,
      ].take(limit),
    );
  }

  @override
  Future<List<GlossedSpelling>> reverseLookup(Iterable<String> readings) =>
      switch (primary) {
        final KoreanReverseGlossary backwards => backwards.reverseLookup(
          readings,
        ),
        _ => Future.value(const <GlossedSpelling>[]),
      };

  @override
  List<GlossarySourceInfo> get sources => primary.sources;
}
