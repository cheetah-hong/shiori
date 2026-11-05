import 'dart:convert';

import 'package:dict_jmdict/src/confusables.dart';
import 'package:dict_jmdict/src/form_lookup.dart' as forms;
import 'package:dict_jmdict/src/kana.dart';
import 'package:dict_jmdict/src/models.dart';
import 'package:dict_jmdict/src/priority.dart';
import 'package:dict_jmdict/src/spelling.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' show OpenMode, sqlite3;

/// Schema version written by tools/dict/build_jmdict_db.py (`PRAGMA user_version`).
const int jmdictSchemaVersion = 1;

/// The file is not a JMdict database this package can read.
final class JmdictFormatException implements Exception {
  const JmdictFormatException(this.message);

  final String message;

  @override
  String toString() => 'JmdictFormatException: $message';
}

/// A dictionary word looked up by its headword.
final class DictionaryWord {
  const DictionaryWord({
    required this.entryId,
    required this.headword,
    required this.readings,
    required this.priority,
    this.partsOfSpeech = const [],
    this.glosses = const [],
  });

  final int entryId;
  final String headword;

  /// Readings that go with this headword, in JMdict order.
  final List<String> readings;

  /// Best priority among this headword's pairs.
  final Priority priority;
  final List<String> partsOfSpeech;
  final List<String> glosses;

  @override
  String toString() => '$headword【${readings.join('/')}】#$entryId $priority';
}

/// Read-only lookups over the JMdict SQLite file.
///
/// Calls are synchronous. Each one runs a few indexed queries; on the full
/// dictionary that takes well under a millisecond.
final class JmdictDictionary {
  JmdictDictionary._(this._db, this.info);

  /// Opens the database at [path] read-only.
  ///
  /// Throws [JmdictFormatException] when the file was not built by
  /// build_jmdict_db.py with schema [jmdictSchemaVersion].
  factory JmdictDictionary.open(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    var opened = false;
    try {
      final dict = JmdictDictionary.fromDatabase(db);
      opened = true;
      return dict;
    } finally {
      if (!opened) db.close();
    }
  }

  /// Uses an already open database (tests load the SQL fixture in memory).
  factory JmdictDictionary.fromDatabase(CommonDatabase db) {
    final int version;
    final Map<String, String> meta;
    try {
      version = db.select('PRAGMA user_version').first.columnAt(0) as int;
      meta = {
        for (final row in db.select('SELECT key, value FROM meta'))
          row.columnAt(0) as String: row.columnAt(1) as String,
      };
    } on SqliteException catch (e) {
      throw JmdictFormatException('not a JMdict database: ${e.message}');
    }
    if (version != jmdictSchemaVersion) {
      throw JmdictFormatException(
        'schema $version, expected $jmdictSchemaVersion; rebuild the file',
      );
    }
    return JmdictDictionary._(db, DictionaryInfo(Map.unmodifiable(meta)));
  }

  final CommonDatabase _db;
  final Map<String, CommonPreparedStatement> _statements = {};
  bool _closed = false;

  /// Source, version and licence of the data.
  final DictionaryInfo info;

  /// Headwords printed with [kana], best first.
  ///
  /// Order: words of a [prefer]red class first (the textbook's POS badge),
  /// normal forms before rare or irregular ones, then [Priority] (common, nf
  /// band, any tag), an entry's main spelling before its untagged variants,
  /// then JMdict order. Each candidate carries its
  /// [HeadwordCandidate.rankReason]. Search-only forms are left out. With
  /// [requireKanji], words written in kana alone are left out too.
  List<HeadwordCandidate> lookupByReading(
    String kana, {
    int limit = 10,
    bool requireKanji = false,
    Set<WordClass> prefer = const {},
  }) {
    _ensureOpen();
    final reading = kana.trim();
    if (reading.isEmpty || limit <= 0) return const [];
    return List.unmodifiable(
      _candidates(reading, prefer: prefer)
          .where(
            (c) => !c.isSearchOnly && (!requireKanji || hasKanji(c.headword)),
          )
          .take(limit),
    );
  }

  /// Dictionary words written as [headword], best first. A kana headword
  /// also matches its other script (ごみ finds ゴミ) and returns each entry
  /// once; any other headword is looked up among the kanji forms (which also
  /// hold full-width digits and letters such as ２).
  List<DictionaryWord> lookupByHeadword(String headword, {int limit = 10}) {
    _ensureOpen();
    final h = headword.trim();
    if (h.isEmpty || limit <= 0) return const [];
    final words = isKanaOnly(h) ? _wordsByKana(h) : _wordsByKanji(h);
    final ordered = [for (var i = 0; i < words.length; i++) (i, words[i])]
      ..sort((a, b) {
        final byPriority = a.$2.priority.compareTo(b.$2.priority);
        return byPriority != 0 ? byPriority : a.$1.compareTo(b.$1);
      });
    return List.unmodifiable(ordered.take(limit).map((w) => w.$2));
  }

  /// Entries spelled as each of [forms], in one query per kind of form.
  ///
  /// A kanji form matches the entry's kanji forms; a kana form matches its
  /// readings in either script. Search-only spellings (sK, sk) never match.
  /// Forms with no entry are left out.
  Map<String, List<forms.FormEntry>> lookupForms(Iterable<String> spellings) {
    _ensureOpen();
    return forms.lookupForms(
      spellings,
      (sql, args) => [for (final row in _select(sql, args)) row.values],
    );
  }

  /// Whether the dictionary has [headword] read as [reading], exactly.
  ///
  /// With an empty or null [reading], whether [headword] is a dictionary
  /// form at all (kana words are printed without a reading).
  bool hasPair(String headword, String? reading) {
    _ensureOpen();
    return _exactPair(headword.trim(), (reading ?? '').trim()) != null;
  }

  /// Like [hasPair], but allows the ways a textbook spelling can differ from
  /// the dictionary headword ([PairMatch]). Only [PairMatch.none] should be
  /// shown to the learner as "확인 필요".
  PairCheck checkPair(String headword, String? reading) {
    _ensureOpen();
    final h = headword.trim();
    if (h.isEmpty) return PairCheck.notFound;
    return _check(h, (reading ?? '').trim(), allowStrip: true);
  }

  /// Dictionary headwords that [ocrText] could be, for a row whose reading
  /// was read as [reading], best first.
  ///
  /// Each OCR glyph may stay, become a look-alike from the confusable table
  /// (either direction: タ ↔ 夕, ー ↔ 一, ...), or switch kana script
  /// (ベ ↔ べ). Only forms the dictionary has with [reading] are returned,
  /// fewest changes first, then by rank ([prefer] as in [lookupByReading]).
  /// A first result with no edits means the OCR text is already right
  /// ([HeadwordSuggestion.confirmsOcr]).
  ///
  /// A printed reading means the headword is not just that kana, so the bare
  /// reading (in either script) comes after every other match: OCR text ニ
  /// read as に suggests 二 before the katakana word ニ.
  ///
  /// Empty [ocrText]: the headword was not read, so every headword printed
  /// with [reading] is a candidate except the bare reading itself.
  /// Empty [reading]: kana words and kanji forms spelled like [ocrText].
  /// Search-only forms are never suggested.
  List<HeadwordSuggestion> suggestHeadword(
    String ocrText,
    String? reading, {
    int limit = 5,
    Set<WordClass> prefer = const {},
  }) {
    _ensureOpen();
    final text = ocrText.replaceAll(RegExp(r'\s'), '');
    final r = (reading ?? '').trim();
    if (limit <= 0 || (text.isEmpty && r.isEmpty)) return const [];
    if (r.isEmpty) return _suggestWithoutReading(text, limit, prefer);
    final pool = _candidates(r, prefer: prefer);
    bool bare(HeadwordCandidate c) => _isBareReading(c.headword, r);
    if (text.isEmpty) {
      return List.unmodifiable(
        pool
            .where((c) => !c.isSearchOnly && !bare(c))
            .take(limit)
            .map((c) => HeadwordSuggestion(c, SuggestionBasis.readingOnly)),
      );
    }
    final matched = <(int, int, HeadwordSuggestion)>[];
    for (var i = 0; i < pool.length; i++) {
      if (pool[i].isSearchOnly) continue;
      final edits = glyphEdits(text, pool[i].headword);
      if (edits == null) continue;
      final penalty = bare(pool[i]) ? 1 << 16 : 0;
      matched.add((
        penalty + edits.length,
        i,
        HeadwordSuggestion(pool[i], SuggestionBasis.glyphs, edits),
      ));
    }
    matched.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    return List.unmodifiable(matched.take(limit).map((m) => m.$3));
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final s in _statements.values) {
      s.close();
    }
    _statements.clear();
    _db.close();
  }

  // ------------------------------------------------------------ queries

  void _ensureOpen() {
    if (_closed) throw StateError('JmdictDictionary is closed');
  }

  ResultSet _select(String sql, List<Object?> args) {
    _ensureOpen();
    return (_statements[sql] ??= _db.prepare(sql)).select(args);
  }

  static const _byReadingSql = '''
SELECT r.entry_id, r.ord, r.text, r.pri, r.nf, r.inf, r.nokanji, r.restr,
       k.ord, k.text, k.pri, k.nf, k.inf, e.pos, e.misc,
       (SELECT s.gloss FROM sense s WHERE s.entry_id = r.entry_id AND s.ord = 0)
FROM reading r
JOIN entry e ON e.id = r.entry_id
LEFT JOIN kanji k ON k.entry_id = r.entry_id
WHERE r.text IN (?1, ?2, ?3)
ORDER BY r.entry_id, r.ord, k.ord''';

  /// Every headword printed with [reading] (search-only forms last), ranked
  /// and without duplicate headwords.
  List<HeadwordCandidate> _candidates(
    String reading, {
    Set<WordClass> prefer = const {},
  }) {
    final spellings = _three(kanaSpellings(reading));
    final ranked = <(_Rank, HeadwordCandidate)>[];
    final kanaDone = <String>{};
    for (final row in _select(_byReadingSql, spellings)) {
      final entryId = row.columnAt(0) as int;
      final rText = row.columnAt(2) as String;
      final rPri = Priority(row.columnAt(3) as int, row.columnAt(4) as int?);
      final rInf = _codes(row.columnAt(5));
      final noKanji = row.columnAt(6) == 1;
      final restr = row.columnAt(7) as String;
      final kText = row.columnAt(9) as String?;
      final pos = _codes(row.columnAt(13));
      final misc = _codes(row.columnAt(14));
      final glosses = _glosses(row.columnAt(15));
      if (kText != null && _applies(noKanji, restr, kText)) {
        final kOrd = row.columnAt(8) as int;
        final kPri = Priority(
          row.columnAt(10) as int,
          row.columnAt(11) as int?,
        );
        final c = HeadwordCandidate(
          headword: kText,
          reading: rText,
          entryId: entryId,
          priority: Priority.pair(kPri, rPri),
          formInfo: [..._codes(row.columnAt(12)), ...rInf],
          partsOfSpeech: pos,
          glosses: glosses,
        );
        ranked.add((_Rank(c, entryId, kOrd, prefer), c));
      }
      // The kana itself is a headword when the word has no kanji form for
      // this reading, or is usually written in kana (uk).
      final kanaHeadword = kText == null || noKanji || misc.contains('uk');
      if (kanaHeadword && kanaDone.add('$entryId/$rText')) {
        final c = HeadwordCandidate(
          headword: rText,
          reading: rText,
          entryId: entryId,
          priority: rPri,
          formInfo: rInf,
          partsOfSpeech: pos,
          glosses: glosses,
        );
        ranked.add((_Rank(c, entryId, _Rank.kanaForm, prefer), c));
      }
    }
    ranked.sort((a, b) => a.$1.compareTo(b.$1));
    final seen = <String>{};
    return [
      for (final (_, c) in ranked)
        if (seen.add(c.headword)) c,
    ];
  }

  static const _pairSql = '''
SELECT r.entry_id, r.nokanji, r.restr
FROM kanji k JOIN reading r ON r.entry_id = k.entry_id
WHERE k.text = ?1 AND r.text = ?2''';

  /// Entry id of the exact pair, or null.
  int? _exactPair(String h, String r) {
    if (h.isEmpty) return null;
    if (r.isEmpty || r == h) {
      final asKana = _select(
        'SELECT entry_id FROM reading WHERE text = ?1 LIMIT 1',
        [h],
      );
      if (asKana.isNotEmpty) return asKana.first.columnAt(0) as int;
      if (r.isNotEmpty) return null;
      final asKanji = _select(
        'SELECT entry_id FROM kanji WHERE text = ?1 LIMIT 1',
        [h],
      );
      return asKanji.isEmpty ? null : asKanji.first.columnAt(0) as int;
    }
    for (final row in _select(_pairSql, [h, r])) {
      if (_applies(row.columnAt(1) == 1, row.columnAt(2) as String, h)) {
        return row.columnAt(0) as int;
      }
    }
    return null;
  }

  PairCheck _check(String h, String r, {required bool allowStrip}) {
    final exact = _exactPair(h, r);
    if (exact != null) return PairCheck(PairMatch.exact, entryId: exact);
    // A printed reading means the headword is not that kana in the other
    // script: ニ read as に is a misread 二, not the katakana word ニ.
    if (_isBareReading(h, r)) return PairCheck.notFound;
    for (final hs in kanaSpellings(h)) {
      for (final rs in r.isEmpty ? const {''} : kanaSpellings(r)) {
        if (hs == h && rs == r) continue;
        final id = _exactPair(hs, rs);
        if (id != null) {
          return PairCheck(
            PairMatch.kanaScript,
            dictionaryForm: hs == h ? null : hs,
            entryId: id,
          );
        }
      }
    }
    if (r.isNotEmpty && hasKanji(h)) {
      for (final c in _candidates(r)) {
        if (isOkuriganaVariant(h, c.headword)) {
          return PairCheck(
            PairMatch.spellingVariant,
            dictionaryForm: c.headword,
            entryId: c.entryId,
          );
        }
      }
    }
    if (allowStrip) {
      final stripped = stripAffixes(h, r);
      if (stripped != null) {
        final inner = _check(stripped.$1, stripped.$2, allowStrip: false);
        if (inner.isKnown) {
          final form = inner.dictionaryForm ?? stripped.$1;
          return PairCheck(
            PairMatch.affixStripped,
            dictionaryForm: form == h ? null : form,
            entryId: inner.entryId,
            parts: inner.parts,
          );
        }
      }
    }
    return r.isEmpty
        ? PairCheck.notFound
        : _compound(h, r) ?? PairCheck.notFound;
  }

  /// [h] as two dictionary words whose readings make up [r]; the second
  /// word may start voiced (rendaku: 両 + 側 = りょう + がわ). Readings are
  /// compared in hiragana.
  PairCheck? _compound(String h, String reading) {
    final r = toHiragana(reading);
    final runes = h.runes.toList();
    for (var i = 1; i < runes.length; i++) {
      final first = String.fromCharCodes(runes.sublist(0, i));
      final second = String.fromCharCodes(runes.sublist(i));
      if (!hasKanji(first) || !hasKanji(second)) continue;
      final firstReadings = _readingsOfKanji(first);
      if (firstReadings.isEmpty) continue;
      final secondReadings = _readingsOfKanji(second);
      for (final MapEntry(key: rFirst, value: entryId)
          in firstReadings.entries) {
        if (!r.startsWith(rFirst) || rFirst.length == r.length) continue;
        final rest = r.substring(rFirst.length);
        if (secondReadings.containsKey(rest) ||
            secondReadings.containsKey(withoutRendaku(rest))) {
          return PairCheck(
            PairMatch.compound,
            entryId: entryId,
            parts: List.unmodifiable([first, second]),
          );
        }
      }
    }
    return null;
  }

  static const _readingsOfKanjiSql = '''
SELECT r.text, r.nokanji, r.restr, r.entry_id
FROM kanji k JOIN reading r ON r.entry_id = k.entry_id
WHERE k.text = ?1
ORDER BY r.entry_id, r.ord''';

  /// Readings (in hiragana) of kanji form [form] → entry id.
  Map<String, int> _readingsOfKanji(String form) => {
    for (final row in _select(_readingsOfKanjiSql, [form]))
      if (_applies(row.columnAt(1) == 1, row.columnAt(2) as String, form))
        toHiragana(row.columnAt(0) as String): row.columnAt(3) as int,
  };

  /// Kana forms (order -1) and kanji forms (their k.ord) spelled like one of
  /// the JSON-encoded variants in ?1.
  static const _formsSql = '''
SELECT r.entry_id, r.text, r.text, r.pri, r.nf, r.inf, e.pos,
       (SELECT s.gloss FROM sense s WHERE s.entry_id = r.entry_id AND s.ord = 0),
       -1
FROM reading r JOIN entry e ON e.id = r.entry_id
WHERE r.text IN (SELECT value FROM json_each(?1))
UNION ALL
SELECT k.entry_id, k.text,
       (SELECT r.text FROM reading r WHERE r.entry_id = k.entry_id AND r.nokanji = 0
          AND (r.restr = '' OR instr(char(9) || r.restr || char(9), char(9) || k.text || char(9)))
        ORDER BY r.ord LIMIT 1),
       k.pri, k.nf, k.inf, e.pos,
       (SELECT s.gloss FROM sense s WHERE s.entry_id = k.entry_id AND s.ord = 0),
       k.ord
FROM kanji k JOIN entry e ON e.id = k.entry_id
WHERE k.text IN (SELECT value FROM json_each(?1))''';

  List<HeadwordSuggestion> _suggestWithoutReading(
    String text,
    int limit,
    Set<WordClass> prefer,
  ) {
    final variants = glyphVariants(text);
    final found = <(int, _Rank, HeadwordSuggestion)>[];
    for (final row in _select(_formsSql, [jsonEncode(variants)])) {
      final form = row.columnAt(1) as String;
      final edits = glyphEdits(text, form);
      if (edits == null) continue;
      final order = row.columnAt(8) as int;
      final c = HeadwordCandidate(
        headword: form,
        reading: row.columnAt(2) as String? ?? '',
        entryId: row.columnAt(0) as int,
        priority: Priority(row.columnAt(3) as int, row.columnAt(4) as int?),
        formInfo: _codes(row.columnAt(5)),
        partsOfSpeech: _codes(row.columnAt(6)),
        glosses: _glosses(row.columnAt(7)),
      );
      if (c.isSearchOnly) continue;
      found.add((
        edits.length,
        _Rank(c, c.entryId, order < 0 ? _Rank.kanaForm : order, prefer),
        HeadwordSuggestion(c, SuggestionBasis.glyphs, edits),
      ));
    }
    found.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2.compareTo(b.$2));
    final seen = <String>{};
    return List.unmodifiable(
      found.where((f) => seen.add(f.$3.headword)).take(limit).map((f) => f.$3),
    );
  }

  static const _wordsByKanjiSql = '''
SELECT k.entry_id, k.pri, k.nf, r.text, r.pri, r.nf, r.nokanji, r.restr, e.pos,
       (SELECT s.gloss FROM sense s WHERE s.entry_id = k.entry_id AND s.ord = 0), r.inf
FROM kanji k
JOIN entry e ON e.id = k.entry_id
JOIN reading r ON r.entry_id = k.entry_id
WHERE k.text = ?1
ORDER BY k.entry_id, r.ord''';

  List<DictionaryWord> _wordsByKanji(String h) {
    final byEntry = <int, _WordBuilder>{};
    for (final row in _select(_wordsByKanjiSql, [h])) {
      final applies = _applies(
        row.columnAt(6) == 1,
        row.columnAt(7) as String,
        h,
      );
      final searchOnly = _codes(
        row.columnAt(10),
      ).any(searchOnlyFormCodes.contains);
      if (!applies || searchOnly) continue;
      final entryId = row.columnAt(0) as int;
      final pair = Priority.pair(
        Priority(row.columnAt(1) as int, row.columnAt(2) as int?),
        Priority(row.columnAt(4) as int, row.columnAt(5) as int?),
      );
      (byEntry[entryId] ??= _WordBuilder(
        entryId,
        h,
        _codes(row.columnAt(8)),
        _glosses(row.columnAt(9)),
      )).add(row.columnAt(3) as String, pair);
    }
    return [for (final b in byEntry.values) b.build()];
  }

  static const _wordsByKanaSql = '''
SELECT r.entry_id, r.text, r.pri, r.nf, e.pos,
       (SELECT s.gloss FROM sense s WHERE s.entry_id = r.entry_id AND s.ord = 0),
       r.inf
FROM reading r JOIN entry e ON e.id = r.entry_id
WHERE r.text IN (?1, ?2, ?3)
ORDER BY r.entry_id, r.ord''';

  /// One word per entry; its readings are the matched spellings (ごみ, ゴミ).
  List<DictionaryWord> _wordsByKana(String h) {
    final byEntry = <int, _WordBuilder>{};
    for (final row in _select(_wordsByKanaSql, _three(kanaSpellings(h)))) {
      if (_codes(row.columnAt(6)).any(searchOnlyFormCodes.contains)) continue;
      final entryId = row.columnAt(0) as int;
      final text = row.columnAt(1) as String;
      (byEntry[entryId] ??= _WordBuilder(
        entryId,
        text,
        _codes(row.columnAt(4)),
        _glosses(row.columnAt(5)),
      )).add(text, Priority(row.columnAt(2) as int, row.columnAt(3) as int?));
    }
    return [for (final b in byEntry.values) b.build()];
  }
}

/// [headword] is just [reading] (in either script), with a reading given.
bool _isBareReading(String headword, String reading) =>
    reading.isNotEmpty &&
    isKanaOnly(headword) &&
    toHiragana(headword) == toHiragana(reading);

/// Whether a reading applies to kanji form [kanji] (re_nokanji, re_restr).
bool _applies(bool noKanji, String restr, String kanji) =>
    !noKanji && (restr.isEmpty || restr.split('\t').contains(kanji));

List<String> _codes(Object? spaceSeparated) {
  final s = spaceSeparated as String? ?? '';
  return s.isEmpty ? const [] : List.unmodifiable(s.split(' '));
}

List<String> _glosses(Object? joined) {
  final s = joined as String? ?? '';
  return s.isEmpty ? const [] : List.unmodifiable(s.split('; '));
}

/// Exactly three query parameters (the set has one to three spellings).
List<String> _three(Set<String> spellings) {
  final list = spellings.toList();
  return [for (var i = 0; i < 3; i++) list[i < list.length ? i : 0]];
}

/// Sort key for candidates: search-only last, preferred word class first,
/// irregular after normal, then priority, then an entry's main spelling
/// before its untagged variants (二 before ２), then JMdict order.
final class _Rank implements Comparable<_Rank> {
  _Rank(this.candidate, this.entryId, this.formOrder, Set<WordClass> prefer)
    : preferred =
          prefer.isEmpty ||
          wordClassesOf(candidate.partsOfSpeech).any(prefer.contains);

  /// Order given to the kana headword of an entry (after its kanji forms).
  static const kanaForm = 1 << 20;

  final HeadwordCandidate candidate;
  final int entryId;
  final int formOrder;
  final bool preferred;

  bool get _variant => formOrder > 0 && formOrder != kanaForm;

  @override
  int compareTo(_Rank o) {
    final a = candidate, b = o.candidate;
    if (a.isSearchOnly != b.isSearchOnly) return a.isSearchOnly ? 1 : -1;
    if (preferred != o.preferred) return preferred ? -1 : 1;
    if (a.isIrregular != b.isIrregular) return a.isIrregular ? 1 : -1;
    final byPriority = a.priority.compareTo(b.priority);
    if (byPriority != 0) return byPriority;
    if (_variant != o._variant) return _variant ? 1 : -1;
    final byEntry = entryId.compareTo(o.entryId);
    return byEntry != 0 ? byEntry : formOrder.compareTo(o.formOrder);
  }
}

final class _WordBuilder {
  _WordBuilder(this.entryId, this.headword, this.pos, this.glosses);

  final int entryId;
  final String headword;
  final List<String> pos;
  final List<String> glosses;
  final List<String> _readings = [];
  Priority _best = Priority.none;

  void add(String reading, Priority pair) {
    if (!_readings.contains(reading)) _readings.add(reading);
    if (pair.compareTo(_best) < 0) _best = pair;
  }

  DictionaryWord build() => DictionaryWord(
    entryId: entryId,
    headword: headword,
    readings: List.unmodifiable(_readings),
    priority: _best,
    partsOfSpeech: pos,
    glosses: glosses,
  );
}
