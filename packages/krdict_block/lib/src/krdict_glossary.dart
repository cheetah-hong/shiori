import 'package:krdict_block/src/keys.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' show OpenMode, sqlite3;

/// Schema version written by tools/dict/build_ko_glossary.py (`PRAGMA user_version`).
const int krdictSchemaVersion = 1;

/// The file is not a Korean glossary database this package can read.
final class KrdictFormatException implements Exception {
  const KrdictFormatException(this.message);

  final String message;

  @override
  String toString() => 'KrdictFormatException: $message';
}

/// Korean meanings of Japanese words from the glossary SQLite file.
///
/// The file indexes every Japanese equivalent of the Basic Korean Dictionary
/// (한국어기초사전) back to the Korean sense it translates. Order of the
/// meanings for one Japanese word:
/// 1. how it matched: a kanji word with its reading (or a kana word written
///    in kana) before a kanji word found by spelling only (or a kana word
///    found as the reading of a kanji spelling),
/// 2. its place in the sense's list of equivalents (first is closest),
/// 3. the same ending as the headword (有名だ: ゆうめいだ【有名だ】 → 유명하다
///    before ゆうめい【有名】 → 유명),
/// 4. the Korean word's level: 초급, 중급, 고급, none,
/// 5. the sense number, then file order.
///
/// A kanji word with an honorific お or ご that the dictionary does not have
/// is looked up again without it (お皿 → 皿).
///
/// Calls are synchronous and take well under a millisecond.
final class KrdictGlossary implements KoreanGlossary, KoreanReverseGlossary {
  KrdictGlossary._(this._db, this.sources);

  /// Opens the database at [path] read-only.
  ///
  /// Throws [KrdictFormatException] when the file was not built by
  /// build_ko_glossary.py with schema [krdictSchemaVersion].
  factory KrdictGlossary.open(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    var opened = false;
    try {
      final glossary = KrdictGlossary.fromDatabase(db);
      opened = true;
      return glossary;
    } finally {
      if (!opened) db.close();
    }
  }

  /// Uses an already open database (tests load the SQL fixture in memory).
  factory KrdictGlossary.fromDatabase(CommonDatabase db) {
    final int version;
    final Map<String, String> meta;
    try {
      version = db.select('PRAGMA user_version').first.columnAt(0) as int;
      meta = {
        for (final row in db.select('SELECT key, value FROM meta'))
          row.columnAt(0) as String: row.columnAt(1) as String,
      };
      db
        ..select(
          'SELECT id, word, level, sense_no, source, synonyms '
          'FROM sense LIMIT 0',
        )
        ..select(
          'SELECT key, reading, kind, pos, ending, sense_id FROM ja LIMIT 0',
        );
    } on SqliteException catch (e) {
      throw KrdictFormatException('not a Korean glossary: ${e.message}');
    }
    if (version != krdictSchemaVersion) {
      throw KrdictFormatException(
        'schema $version, expected $krdictSchemaVersion; rebuild the file',
      );
    }
    return KrdictGlossary._(db, List.unmodifiable(_sourcesOf(meta)));
  }

  final CommonDatabase _db;
  final Map<String, CommonPreparedStatement> _statements = {};
  bool _closed = false;

  @override
  final List<GlossarySourceInfo> sources;

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
  }) async => lookupSync(headword, readings: readings, limit: limit);

  @override
  Future<List<GlossedSpelling>> reverseLookup(
    Iterable<String> readings,
  ) async => reverseLookupSync(readings);

  /// [reverseLookup] without the Future: every kanji word read as one of
  /// [readings] (katakana folded to hiragana) and every kana word written
  /// so, one result per sense, in file order. Both go through an index
  /// (`ja_reading`, `ja_key`).
  List<GlossedSpelling> reverseLookupSync(Iterable<String> readings) {
    _ensureOpen();
    final out = <GlossedSpelling>[];
    for (final reading in {for (final r in readings) toHiragana(r.trim())}) {
      if (reading.isEmpty) continue;
      for (final row in _select(_spellingsSql, [reading, reading])) {
        final key = row.columnAt(0) as String;
        final read = row.columnAt(1) as String;
        final word = row.columnAt(2) as String;
        final synonyms = row.columnAt(3) as String;
        out.add(
          GlossedSpelling(
            written: key,
            reading: read.isEmpty ? key : read,
            words: List.unmodifiable([
              word,
              if (synonyms.isNotEmpty)
                for (final s in synonyms.split('|'))
                  if (s != word) s,
            ]),
          ),
        );
      }
    }
    return out;
  }

  /// [lookup] without the Future.
  List<KoreanSense> lookupSync(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
  }) {
    _ensureOpen();
    if (limit <= 0) return const [];
    final found = _lookup(headword, readings, limit);
    if (found.isNotEmpty) return found;
    return switch (_withoutHonorific(headword, readings)) {
      (final h, final r) => _lookup(h, r, limit),
      null => const [],
    };
  }

  List<KoreanSense> _lookup(String headword, List<String> readings, int limit) {
    final (key, _, ending) = keysAndEnding(headword, '');
    if (key.isEmpty) return const [];
    final hits = hasKanji(key)
        ? _kanjiHits(
            key,
            ending,
            {for (final r in readings) pairKey(headword, r).$2}..remove(''),
          )
        : _kanaHits(key, ending);
    return List.unmodifiable(_meanings(hits, limit));
  }

  /// お皿 / おさら → 皿 / さら; null when [headword] has no such prefix.
  static (String, List<String>)? _withoutHonorific(
    String headword,
    List<String> readings,
  ) {
    final h = headword.trim();
    if (h.length < 2 ||
        !_honorifics.contains(h[0]) ||
        !hasKanji(h.substring(1))) {
      return null;
    }
    return (
      h.substring(1),
      [
        for (final r in readings)
          if (r.trim().length > 1 && 'おご'.contains(r.trim()[0]))
            r.trim().substring(1)
          else
            r,
      ],
    );
  }

  static const _honorifics = 'おご御';

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

  /// Rows found by spelling. With [readings], a pair must have one of them.
  Iterable<_Hit> _kanjiHits(
    String key,
    String ending,
    Set<String> readings,
  ) sync* {
    for (final row in _select(_byKeySql, [key])) {
      final kind = row.columnAt(0) as int;
      if (kind == _pair &&
          readings.isNotEmpty &&
          !readings.contains(row.columnAt(2) as String)) {
        continue;
      }
      yield _Hit.of(row, tier: kind == _pair ? 0 : 1, ending: ending);
    }
  }

  /// A kana word: written in kana first, then as a kanji word's reading.
  Iterable<_Hit> _kanaHits(String key, String ending) sync* {
    for (final row in _select(_byKeySql, [key])) {
      if (row.columnAt(0) as int == _kana) {
        yield _Hit.of(row, tier: 0, ending: ending);
      }
    }
    for (final row in _select(_byReadingSql, [key])) {
      yield _Hit.of(row, tier: 1, ending: ending);
    }
  }

  /// Best hit per sense, ordered, then grouped into meanings.
  static List<KoreanSense> _meanings(Iterable<_Hit> hits, int limit) {
    final best = <int, _Hit>{};
    for (final h in hits) {
      final seen = best[h.senseId];
      if (seen == null || h.compareTo(seen) < 0) best[h.senseId] = h;
    }
    final ordered = best.values.toList()..sort();
    final hitWords = {for (final h in ordered) h.word};
    final shown = <String>{};
    final out = <KoreanSense>[];
    for (final h in ordered) {
      if (out.length >= limit) break;
      if (shown.contains(h.word)) continue;
      final words = [
        h.word,
        for (final s in h.synonyms)
          if (s != h.word && hitWords.contains(s) && !shown.contains(s)) s,
      ];
      shown.addAll(words);
      out.add(
        KoreanSense(
          words: List.unmodifiable(words),
          source: h.source,
          level: h.level,
          senseNo: h.senseNo,
        ),
      );
    }
    return out;
  }

  void _ensureOpen() {
    if (_closed) throw StateError('KrdictGlossary is closed');
  }

  ResultSet _select(String sql, List<Object?> args) {
    _ensureOpen();
    return (_statements[sql] ??= _db.prepare(sql)).select(args);
  }

  static const _pair = 0;
  static const _kana = 2;

  /// Enough for the most ambiguous kana word (ただ has 14 senses).
  static const _rowLimit = 500;

  static const _columns =
      'j.kind, j.pos, j.reading, s.id, s.word, s.level, s.sense_no, '
      's.source, s.synonyms, j.ending '
      'FROM ja j JOIN sense s ON s.id = j.sense_id';

  static const _byKeySql = 'SELECT $_columns WHERE j.key = ? LIMIT $_rowLimit';

  /// Kanji words read as `?1`, then kana words written `?2`.
  static const _spellingsSql =
      'SELECT j.key, j.reading, s.word, s.synonyms '
      'FROM ja j JOIN sense s ON s.id = j.sense_id '
      'WHERE j.reading = ?1 AND j.kind = $_pair '
      'UNION ALL '
      'SELECT j.key, j.reading, s.word, s.synonyms '
      'FROM ja j JOIN sense s ON s.id = j.sense_id '
      'WHERE j.key = ?2 AND j.kind = $_kana '
      'LIMIT $_rowLimit';

  static const _byReadingSql =
      'SELECT $_columns WHERE j.reading = ? AND j.kind = $_pair '
      'LIMIT $_rowLimit';
}

final class _Hit implements Comparable<_Hit> {
  _Hit({
    required this.tier,
    required this.position,
    required this.sameEnding,
    required this.senseId,
    required this.word,
    required this.level,
    required this.senseNo,
    required this.source,
    required this.synonyms,
  });

  /// Columns as in [KrdictGlossary._columns].
  factory _Hit.of(Row row, {required int tier, required String ending}) => _Hit(
    tier: tier,
    position: row.columnAt(1) as int,
    sameEnding: row.columnAt(9) as String == ending,
    senseId: row.columnAt(3) as int,
    word: row.columnAt(4) as String,
    level: _levelOf(row.columnAt(5) as int?),
    senseNo: row.columnAt(6) as int,
    source: _sourceOf(row.columnAt(7) as int),
    synonyms: switch (row.columnAt(8) as String) {
      '' => const [],
      final s => s.split('|'),
    },
  );

  final int tier;
  final int position;

  /// The equivalent had the ending the headword had (both 有名だ, or neither).
  final bool sameEnding;
  final int senseId;
  final String word;
  final GlossaryLevel? level;
  final int senseNo;
  final GlossarySource source;
  final List<String> synonyms;

  @override
  int compareTo(_Hit other) {
    for (final (a, b) in [
      (tier, other.tier),
      (position, other.position),
      (sameEnding ? 0 : 1, other.sameEnding ? 0 : 1),
      (_levelRank(level), _levelRank(other.level)),
      (senseNo, other.senseNo),
      (senseId, other.senseId),
    ]) {
      if (a != b) return a - b;
    }
    return 0;
  }

  static int _levelRank(GlossaryLevel? level) =>
      level == null ? GlossaryLevel.values.length : level.index;
}

/// 1 초급, 2 중급, 3 고급 in the file; anything else is no level.
GlossaryLevel? _levelOf(int? stored) => switch (stored) {
  1 => GlossaryLevel.beginner,
  2 => GlossaryLevel.intermediate,
  3 => GlossaryLevel.advanced,
  _ => null,
};

GlossarySource _sourceOf(int stored) => switch (stored) {
  0 => GlossarySource.krdict,
  1 => GlossarySource.wiktionary,
  _ => throw KrdictFormatException('unknown source $stored'),
};

/// `sources` lists the dictionaries in the file; each has its `<name>.*` keys.
List<GlossarySourceInfo> _sourcesOf(Map<String, String> meta) {
  String field(String key) => switch (meta[key]) {
    final String v when v.isNotEmpty => v,
    _ => throw KrdictFormatException('meta has no $key'),
  };
  return [
    for (final name in field('sources').split(','))
      GlossarySourceInfo(
        source: GlossarySource.values.firstWhere(
          (s) => s.name == name,
          orElse: () => throw KrdictFormatException('unknown source $name'),
        ),
        publisher: field('$name.publisher'),
        license: field('$name.license'),
        licenseUrl: field('$name.license_url'),
        edition: field('$name.edition'),
      ),
  ];
}
