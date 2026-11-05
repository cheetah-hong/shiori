/// Many forms at once, with what a word extractor needs to rank them.
library;

import 'dart:convert';

import 'package:dict_jmdict/src/priority.dart';

/// A JMdict entry seen from one spelling of it.
final class FormEntry {
  const FormEntry({
    required this.form,
    required this.entryId,
    required this.readings,
    required this.kanjiForms,
    required this.partsOfSpeech,
    required this.priority,
    this.usuallyKana = false,
    this.irregular = false,
  });

  /// The spelling looked up (a kanji form, or a reading).
  final String form;
  final int entryId;

  /// Readings that go with [form], in JMdict order (a reading: itself).
  final List<String> readings;

  /// Every kanji form of the entry except search-only ones.
  final List<String> kanjiForms;
  final List<String> partsOfSpeech;

  /// Priority of [form] itself.
  final Priority priority;

  /// misc `uk`: usually written in kana.
  final bool usuallyKana;

  /// [form] is a rare, irregular or outdated spelling (rK, iK, oK, ...).
  final bool irregular;

  bool get isKanaForm => !kanjiForms.contains(form);

  @override
  String toString() => '$form【${readings.join('/')}】#$entryId $priority';
}

typedef _Reading = ({String text, bool noKanji, String restr});

/// Runs one prepared query (the dictionary's statement cache).
typedef SelectRows =
    Iterable<List<Object?>> Function(String sql, List<Object?> args);

const _kanjiFormsSql = '''
SELECT k.text, k.entry_id, k.pri, k.nf, k.inf, e.pos, e.misc
FROM kanji k JOIN entry e ON e.id = k.entry_id
WHERE k.text IN (SELECT value FROM json_each(?1))
ORDER BY k.entry_id, k.ord''';

const _readingFormsSql = '''
SELECT r.text, r.entry_id, r.pri, r.nf, r.inf, e.pos, e.misc
FROM reading r JOIN entry e ON e.id = r.entry_id
WHERE r.text IN (SELECT value FROM json_each(?1))
ORDER BY r.entry_id, r.ord''';

const _entryReadingsSql = '''
SELECT entry_id, text, nokanji, restr, inf FROM reading
WHERE entry_id IN (SELECT value FROM json_each(?1))
ORDER BY entry_id, ord''';

const _entryKanjiSql = '''
SELECT entry_id, text, inf FROM kanji
WHERE entry_id IN (SELECT value FROM json_each(?1))
ORDER BY entry_id, ord''';

const Set<String> _searchOnly = {'sK', 'sk'};
const Set<String> _irregular = {'rK', 'iK', 'oK', 'io', 'rk', 'ik', 'ok'};

List<String> _codes(Object? v) {
  final s = v as String? ?? '';
  return s.isEmpty ? const [] : s.split(' ');
}

bool _isKanaForm(String s) =>
    s.isNotEmpty &&
    s.runes.every((r) => (r >= 0x3041 && r <= 0x30FF) || r == 0x30FC);

String _hira(String s) => String.fromCharCodes(
  s.runes.map((r) => r >= 0x30A1 && r <= 0x30F6 ? r - 0x60 : r),
);

String _kata(String s) => String.fromCharCodes(
  s.runes.map((r) => r >= 0x3041 && r <= 0x3096 ? r + 0x60 : r),
);

/// [JmdictDictionary.lookupForms] over [select].
Map<String, List<FormEntry>> lookupForms(
  Iterable<String> forms,
  SelectRows select,
) {
  final wanted = {
    for (final f in forms)
      if (f.trim().isNotEmpty) f.trim(),
  };
  if (wanted.isEmpty) return const {};
  final kana = wanted.where(_isKanaForm).toSet();
  final kanji = wanted.difference(kana);
  // Kana forms match in either script: spelling → the forms asked for.
  final spellingOf = <String, Set<String>>{};
  for (final f in kana) {
    for (final s in {f, _hira(f), _kata(f)}) {
      (spellingOf[s] ??= {}).add(f);
    }
  }
  final hits =
      <
        ({
          String form,
          int id,
          int pri,
          int? nf,
          List<String> inf,
          List<String> pos,
          List<String> misc,
          bool kanaHit,
        })
      >[];
  if (kanji.isNotEmpty) {
    for (final row in select(_kanjiFormsSql, [jsonEncode(kanji.toList())])) {
      hits.add((
        form: row[0]! as String,
        id: row[1]! as int,
        pri: row[2]! as int,
        nf: row[3] as int?,
        inf: _codes(row[4]),
        pos: _codes(row[5]),
        misc: _codes(row[6]),
        kanaHit: false,
      ));
    }
  }
  if (kana.isNotEmpty) {
    for (final row in select(_readingFormsSql, [
      jsonEncode(spellingOf.keys.toList()),
    ])) {
      for (final asked in spellingOf[row[0]! as String] ?? const <String>{}) {
        hits.add((
          form: asked,
          id: row[1]! as int,
          pri: row[2]! as int,
          nf: row[3] as int?,
          inf: _codes(row[4]),
          pos: _codes(row[5]),
          misc: _codes(row[6]),
          kanaHit: true,
        ));
      }
    }
  }
  final usable = [
    for (final h in hits)
      if (!h.inf.any(_searchOnly.contains)) h,
  ];
  if (usable.isEmpty) return const {};
  final ids = jsonEncode({for (final h in usable) h.id}.toList());
  final readings = <int, List<_Reading>>{};
  for (final row in select(_entryReadingsSql, [ids])) {
    if (_codes(row[4]).any(_searchOnly.contains)) continue;
    (readings[row[0]! as int] ??= []).add((
      text: row[1]! as String,
      noKanji: row[2] == 1,
      restr: row[3]! as String,
    ));
  }
  final kanjiForms = <int, List<String>>{};
  for (final row in select(_entryKanjiSql, [ids])) {
    if (_codes(row[2]).any(_searchOnly.contains)) continue;
    (kanjiForms[row[0]! as int] ??= []).add(row[1]! as String);
  }
  final out = <String, Map<int, FormEntry>>{};
  for (final h in usable) {
    final entryKanji = List<String>.unmodifiable(kanjiForms[h.id] ?? const []);
    final formReadings = h.kanaHit
        ? [h.form]
        : [
            for (final r in readings[h.id] ?? const <_Reading>[])
              if (!r.noKanji &&
                  (r.restr.isEmpty || r.restr.split('\t').contains(h.form)))
                r.text,
          ];
    final entry = FormEntry(
      form: h.form,
      entryId: h.id,
      readings: List.unmodifiable(formReadings),
      kanjiForms: entryKanji,
      partsOfSpeech: List.unmodifiable(h.pos),
      priority: Priority(h.pri, h.nf),
      usuallyKana: h.misc.contains('uk'),
      irregular: h.inf.any(_irregular.contains),
    );
    final byEntry = out[h.form] ??= {};
    final kept = byEntry[h.id];
    // A kana form spelled both ways keeps its better-ranked spelling.
    if (kept == null || entry.priority.compareTo(kept.priority) < 0) {
      byEntry[h.id] = entry;
    }
  }
  return {
    for (final MapEntry(:key, :value) in out.entries)
      key: List.unmodifiable(value.values),
  };
}
