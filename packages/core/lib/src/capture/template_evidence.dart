/// Evidence for the entries the row template read (docs/extraction.md, 4.4):
/// where each cell came from, how sure its pairing with the headword is, and
/// where it sits on the page. The template put each cell in its row, so the
/// cell's place is one signal; the content signals are the general
/// extractor's (the dictionary has the headword with that reading; the
/// Korean readings of the kanji or the gloss lookup name the meaning).
///
/// Only evidence is added: every value and flag stays as the template and
/// its correctors made it.
library;

import 'package:shiori_core/src/extract/confidence.dart';
import 'package:shiori_core/src/extract/deconjugator.dart';
import 'package:shiori_core/src/extract/general_extractor.dart';
import 'package:shiori_core/src/extract/script_runs.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/evidence.dart';
import 'package:shiori_core/src/models/ocr.dart';
import 'package:shiori_core/src/ports/lexicon.dart';

/// [entries] (in row order) with their evidence. [lexicon] and [glosses] are
/// the general extractor's; [page] (the scan the template read) gives the
/// photo boxes. A lexicon that fails gives no content signals.
Future<List<CapturedEntry>> withTemplateEvidence(
  List<CapturedEntry> entries, {
  required Lexicon lexicon,
  KoreanGlossLookup? glosses,
  OcrScan? page,
}) async {
  final readings = await _dictionaryReadings(
    lexicon,
    {for (final e in entries) e.headword.trim()}..remove(''),
  );
  final boxes = _PageBoxes(page);
  return [
    for (final (i, e) in entries.indexed)
      e.copyWith(
        evidence: EntryEvidence(
          origin: WordOrigin.wordList,
          fields: await _fields(
            e,
            [
              if (i > 0) entries[i - 1],
              if (i + 1 < entries.length) entries[i + 1],
            ],
            readings,
            glosses,
            boxes,
          ),
        ),
      ),
  ];
}

Future<Map<EntryField, FieldEvidence>> _fields(
  CapturedEntry e,
  List<CapturedEntry> neighbours,
  Map<String, _Readings> dictionary,
  KoreanGlossLookup? glosses,
  _PageBoxes boxes,
) async {
  final head = boxes.of(e.headword, no: e.no);
  final meaning = e.meaning.trim();
  final fields = {
    EntryField.headword: FieldEvidence(
      source: FieldSource.photo,
      boxes: [?head],
    ),
    if (e.readings.isNotEmpty)
      EntryField.readings: _reading(e, neighbours, dictionary, boxes, head),
    if (meaning.isNotEmpty)
      EntryField.meaning: await _meaning(
        e,
        neighbours,
        glosses,
        dictionary,
        boxes,
        head,
      ),
    if (e.example != null)
      EntryField.example: const FieldEvidence(source: FieldSource.photo),
  };
  // A cell the learner must look at (an unread example, a doubtful
  // headword, a missing badge): the entry is not one to approve unseen.
  if (!e.needsReview) return fields;
  return {
    for (final MapEntry(:key, :value) in fields.entries)
      key: value.confidence == PairConfidence.high
          ? value.copyWith(
              confidence: PairConfidence.medium,
              note: '확인 필요 칸이 있음',
            )
          : value,
  };
}

bool _flagged(CapturedEntry e, EntryField field) =>
    e.issues.any((i) => i.field == field);

bool _has(CapturedEntry e, EntryField field, IssueKind kind) =>
    e.issues.any((i) => i.field == field && i.kind == kind);

FieldEvidence _reading(
  CapturedEntry e,
  List<CapturedEntry> neighbours,
  Map<String, _Readings> dictionary,
  _PageBoxes boxes,
  PhotoBox? head,
) {
  final text = e.readings.join('/');
  if (_has(e, EntryField.readings, IssueKind.inferred)) {
    return const FieldEvidence(
      source: FieldSource.dictionary,
      confidence: PairConfidence.medium,
    );
  }
  final known = dictionary[e.headword.trim()];
  final box = boxes.near(e.readings.first, head);
  FieldEvidence photo(PairConfidence c, [String? note]) => FieldEvidence(
    source: FieldSource.photo,
    confidence: c,
    boxes: [?box],
    note: note,
  );
  if (known == null) return photo(PairConfidence.medium);
  if (!known.accepts(text)) {
    return photo(PairConfidence.low, '사전에는 다른 읽기');
  }
  if (_flagged(e, EntryField.readings)) return photo(PairConfidence.medium);
  final rival = neighbours.any(
    (n) =>
        n.headword.trim() != e.headword.trim() &&
        (dictionary[n.headword.trim()]?.accepts(text) ?? false),
  );
  if (rival) {
    return photo(PairConfidence.medium, '이웃 표제어도 같은 읽기');
  }
  return photo(PairConfidence.high);
}

Future<FieldEvidence> _meaning(
  CapturedEntry e,
  List<CapturedEntry> neighbours,
  KoreanGlossLookup? glosses,
  Map<String, _Readings> dictionary,
  _PageBoxes boxes,
  PhotoBox? head,
) async {
  if (_has(e, EntryField.meaning, IssueKind.inferred)) {
    return const FieldEvidence(
      source: FieldSource.dictionary,
      confidence: PairConfidence.medium,
      note: '사전 뜻',
    );
  }
  final box = boxes.near(e.meaning.trim(), head, korean: true);
  FieldEvidence photo(PairConfidence c, [String? note]) => FieldEvidence(
    source: FieldSource.photo,
    confidence: c,
    boxes: [?box],
    note: note,
  );
  final kinds = {
    for (final i in e.issues)
      if (i.field == EntryField.meaning) i.kind,
  };
  if (kinds.any((k) => k != IssueKind.corrected && k != IssueKind.picked)) {
    return photo(PairConfidence.low);
  }
  if (kinds.isNotEmpty) return photo(PairConfidence.medium);
  final headword = e.headword.trim();
  if (headword.isEmpty) return photo(PairConfidence.medium);
  final named =
      hanjaNamesMeaning(headword, e.meaning) ||
      glossNames(
        await _glossWords(headword, e.readings, dictionary, glosses),
        e.meaning,
      );
  if (!named) return photo(PairConfidence.medium);
  if (!plainMeaning(e.meaning)) {
    return photo(PairConfidence.medium, '뜻에 한글이 아닌 글자');
  }
  if (e.readings.isEmpty && headword.runes.any(isKanji)) {
    return photo(PairConfidence.medium, '읽기 없음');
  }
  final bare = _bare(e.meaning);
  if (bare.isNotEmpty && neighbours.any((n) => _bare(n.meaning) == bare)) {
    return photo(PairConfidence.medium, '이웃에 같은 뜻');
  }
  return photo(PairConfidence.high);
}

Future<List<String>> _glossWords(
  String headword,
  List<String> readings,
  Map<String, _Readings> dictionary,
  KoreanGlossLookup? glosses,
) async {
  if (glosses == null) return const [];
  final forms = {headword, ...?dictionary[headword]?.bases};
  return [for (final f in forms) ...await glosses(f, readings)];
}

String _bare(String s) => s.replaceAll(RegExp(r'\([^)]*\)|[^가-힣]'), '');

/// What the dictionary reads a headword as (with its printed ending, as
/// `丈夫だ` → `じょうぶだ`), and its dictionary forms.
final class _Readings {
  const _Readings(this.readings, this.bases);

  final Set<String> readings;
  final Set<String> bases;

  /// Every reading [text] prints is one the dictionary gives.
  bool accepts(String text) {
    final parts = readingParts(text);
    return parts.isNotEmpty &&
        parts.every((r) => readings.contains(_hiragana(r)));
  }
}

/// Dictionary readings of [headwords], one lexicon call; headwords the
/// lexicon does not know are left out. A failing lexicon knows none.
Future<Map<String, _Readings>> _dictionaryReadings(
  Lexicon lexicon,
  Set<String> headwords,
) async {
  final deconjugator = Deconjugator.standard;
  final candidates = {
    for (final h in headwords)
      h: [
        for (final d in deconjugator.deconjugate(h))
          // A word list prints dictionary forms (and な-adjectives with だ).
          if (d.tag == null || d.tag == 'adj-na' && d.steps.length == 1) d,
      ],
  };
  Map<String, List<LexiconEntry>> found;
  try {
    found = await lexicon.lookup({
      for (final ds in candidates.values)
        for (final d in ds) d.base,
    });
  } on Exception {
    return const {};
  }
  final out = <String, _Readings>{};
  for (final MapEntry(key: h, value: ds) in candidates.entries) {
    final lemmas = rankLemmas(ds, found);
    if (lemmas.isEmpty) continue;
    out[h] = _Readings(
      {
        for (final l in lemmas)
          for (final r in l.entry.readings)
            _hiragana(r) +
                _hiragana(
                  h.startsWith(l.base) ? h.substring(l.base.length) : '',
                ),
      },
      {for (final l in lemmas) l.base},
    );
  }
  return out;
}

String _hiragana(String s) => String.fromCharCodes(
  s.runes.map((r) => r >= 0x30A1 && r <= 0x30F6 ? r - 0x60 : r),
);

/// Where a cell's text sits on the page: the part of an OCR line that holds
/// it (width shared out by character count, as the symbol clean-up does).
final class _PageBoxes {
  _PageBoxes(OcrScan? page)
    : ja = page?.japanese.lines ?? const [],
      ko = page?.korean.lines ?? const [];

  final List<OcrLine> ja;
  final List<OcrLine> ko;

  /// The headword's box: on the line of its word number when the page shows
  /// one, else the first line that holds it.
  PhotoBox? of(String headword, {String? no}) {
    final text = headword.trim();
    if (text.isEmpty) return null;
    final row = no == null
        ? null
        : ja.where((l) => l.text.trim().startsWith(no)).firstOrNull;
    return _closest(ja, text, row?.cy, row?.x);
  }

  /// [text]'s box on the line closest to [head] (the headword's box).
  PhotoBox? near(String text, PhotoBox? head, {bool korean = false}) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final lines = korean ? [...ko, ...ja] : ja;
    return _closest(
      lines,
      t,
      head == null ? null : head.y + head.height / 2,
      head?.x,
    );
  }

  PhotoBox? _closest(List<OcrLine> lines, String text, double? cy, double? x) {
    PhotoBox? best;
    var bestDistance = double.infinity;
    for (final box in _spans(lines, text)) {
      final mid = box.y + box.height / 2;
      final d = cy == null
          ? 0.0
          : (mid - cy).abs() * 4 + (x == null ? 0 : (box.x - x).abs());
      if (d < bestDistance) {
        best = box;
        bestDistance = d;
      }
    }
    return best;
  }

  /// Boxes holding [text]: the part of a line, or a few lines of one row
  /// that OCR split it into (`天気` + `予報`).
  Iterable<PhotoBox> _spans(List<OcrLine> lines, String text) sync* {
    for (final l in lines) {
      final at = l.text.indexOf(text);
      if (at < 0) continue;
      final share = l.width / l.text.runes.length;
      final box = PhotoBox(
        x: l.x + l.text.substring(0, at).runes.length * share,
        y: l.y,
        width: text.runes.length * share,
        height: l.height,
      ).clamped();
      if (!box.isEmpty) yield box;
    }
    final pieces = [
      for (final l in lines)
        if (l.text.trim().isNotEmpty &&
            l.text.trim() != text &&
            text.contains(l.text.trim()))
          l,
    ]..sort((a, b) => a.x.compareTo(b.x));
    for (final (i, first) in pieces.indexed) {
      if (!text.startsWith(first.text.trim())) continue;
      var joined = first.text.trim();
      var box = _boxOf(first);
      for (final next in pieces.skip(i + 1)) {
        if ((next.cy - first.cy).abs() > first.height) continue;
        final more = joined + next.text.trim();
        if (!text.startsWith(more)) continue;
        joined = more;
        box = box.union(_boxOf(next));
        if (joined == text) break;
      }
      if (joined == text && !box.clamped().isEmpty) yield box.clamped();
    }
  }
}

PhotoBox _boxOf(OcrLine l) =>
    PhotoBox(x: l.x, y: l.y, width: l.width, height: l.height);
