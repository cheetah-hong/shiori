import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/eval/extract_truth.dart';
import 'package:shiori_core/src/extract/extracted_word.dart';
import 'package:shiori_core/src/extract/general_extractor.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/ocr.dart';

/// What the scorer needs of a returned word, from the word extractor or a
/// review entry.
final class ScoredWord {
  const ScoredWord({
    required this.headword,
    this.readings = const [],
    this.meaning,
    this.confidence,
    this.origin = WordOrigin.wordList,
  });

  factory ScoredWord.fromExtracted(ExtractedWord w) => ScoredWord(
    headword: w.headword,
    readings: w.readings,
    meaning: w.meaning,
    confidence: w.pairConfidence,
    origin: w.origin,
  );

  /// A review entry: its evidence carries the pairing confidence and the
  /// origin (an entry made by hand has none).
  factory ScoredWord.fromCaptured(CapturedEntry e) => ScoredWord(
    headword: e.headword,
    readings: e.readings,
    meaning: e.meaning.trim().isEmpty ? null : e.meaning,
    confidence: e.evidence?.confidence,
    origin: e.evidence?.origin ?? WordOrigin.wordList,
  );

  final String headword;
  final List<String> readings;
  final String? meaning;

  /// Null for an entry without evidence.
  final PairConfidence? confidence;
  final WordOrigin origin;
}

typedef Ratio = ({int ok, int of});

final class PageExtractScore {
  const PageExtractScore({
    required this.page,
    required this.vocab,
    required this.found,
    required this.readingsOk,
    required this.meanings,
    required this.sentenceWords,
    required this.sentencePredicted,
    required this.extras,
    required this.duplicates,
    required this.highWrong,
    required this.high,
    required this.returned,
    this.extraHigh = 0,
    required this.mistakes,
    this.elapsed = Duration.zero,
  });

  final String page;

  /// Printed words in the answers, and how many came back by headword.
  final int vocab;
  final int found;

  /// Of the found words.
  final int readingsOk;

  /// Of the found words whose answer has a meaning.
  final Ratio meanings;

  /// Answer sentence words that came back (recall).
  final Ratio sentenceWords;

  /// Sentence-origin words returned that are answers (precision); ignored
  /// headwords are not counted.
  final Ratio sentencePredicted;

  /// Returned headwords that are in no answer list and not ignored.
  final int extras;

  /// Headwords returned more than once (each repeat counts one).
  final int duplicates;

  /// Words with high pairing confidence whose reading or meaning is wrong.
  final int highWrong;

  /// Words with high pairing confidence that the answers score.
  final int high;

  /// Extras at high pairing confidence: a headword no answer has (a kana
  /// left where OCR lost the kanji, a stray word) that would be approved
  /// unseen.
  final int extraHigh;
  final int returned;
  final List<String> mistakes;
  final Duration elapsed;
}

final class ExtractScore {
  const ExtractScore(this.pages);

  final List<PageExtractScore> pages;

  int get vocab => pages.fold(0, (s, p) => s + p.vocab);
  int get found => pages.fold(0, (s, p) => s + p.found);
  int get readingsOk => pages.fold(0, (s, p) => s + p.readingsOk);
  Ratio get meanings => _sum((p) => p.meanings);
  Ratio get sentenceWords => _sum((p) => p.sentenceWords);
  Ratio get sentencePredicted => _sum((p) => p.sentencePredicted);
  int get extras => pages.fold(0, (s, p) => s + p.extras);
  int get duplicates => pages.fold(0, (s, p) => s + p.duplicates);
  int get highWrong => pages.fold(0, (s, p) => s + p.highWrong);
  int get high => pages.fold(0, (s, p) => s + p.high);
  int get extraHigh => pages.fold(0, (s, p) => s + p.extraHigh);

  Ratio _sum(Ratio Function(PageExtractScore) f) => pages.fold((
    ok: 0,
    of: 0,
  ), (s, p) => (ok: s.ok + f(p).ok, of: s.of + f(p).of));

  /// Fixed-width table, one row per page and a total. [verbose] adds one
  /// line per mistake (they quote the page: keep them out of commits for
  /// real pages).
  String table({bool verbose = false}) {
    final b = StringBuffer();
    if (verbose) {
      for (final p in pages) {
        for (final m in p.mistakes) {
          b.writeln('  ${p.page} $m');
        }
      }
    }
    b.writeln(
      'page        n found read mean   sentR   sentP extra dup high hiWrong    ms exHigh',
    );
    for (final p in pages) {
      b.writeln(
        '${p.page.padRight(9)}${_r(p.vocab, 4)} ${_r(p.found, 5)} '
        '${_r(p.readingsOk, 4)} ${_r(p.meanings.ok, 4)} '
        '${_r(_ratio(p.sentenceWords), 7)} ${_r(_ratio(p.sentencePredicted), 7)} '
        '${_r(p.extras, 5)} ${_r(p.duplicates, 3)} ${_r(p.high, 4)} '
        '${_r(p.highWrong, 7)} ${_r(p.elapsed.inMicroseconds / 1000, 5, 1)} '
        '${_r(p.extraHigh, 6)}',
      );
    }
    b.writeln();
    final total = pages.fold(Duration.zero, (s, p) => s + p.elapsed);
    b.write(
      'TOTAL found=$found/$vocab reading=$readingsOk/$found '
      'meaning=${meanings.ok}/${meanings.of} '
      'sentence_recall=${sentenceWords.ok}/${sentenceWords.of} '
      'sentence_precision=${sentencePredicted.ok}/${sentencePredicted.of} '
      'extras=$extras duplicates=$duplicates high=$high high_wrong=$highWrong '
      'extra_high=$extraHigh '
      'ms_per_page=${pages.isEmpty ? 0 : (total.inMicroseconds / 1000 / pages.length).toStringAsFixed(1)}',
    );
    return b.toString();
  }
}

String _ratio(Ratio r) => '${r.ok}/${r.of}';

String _r(Object v, int width, [int? digits]) =>
    (v is double && digits != null ? v.toStringAsFixed(digits) : '$v').padLeft(
      width,
    );

/// Headword key: NFKC without spaces; a な-adjective's printed だ does not
/// count (`丈夫だ` and `丈夫` are one word).
String _key(String headword) {
  final h = nfkc(headword).replaceAll(_spaces, '');
  if (h.endsWith('だ') && h.length > 1 && h.runes.any(_isKanji)) {
    return h.substring(0, h.length - 1);
  }
  return h;
}

bool _isKanji(int c) => (c >= 0x4E00 && c <= 0x9FFF) || c == 0x3005;

final RegExp _spaces = RegExp(r'\s+');
final RegExp _notes = RegExp(r'\([^()]*\)|（[^（）]*）');

String _hira(String s) => String.fromCharCodes(
  nfkc(s)
      .replaceAll(_spaces, '')
      .runes
      .map((r) => r >= 0x30A1 && r <= 0x30F6 ? r - 0x60 : r),
);

/// A reading key: hiragana, no spaces, a printed だ dropped as for [_key].
String _readingKey(String reading, String headword) {
  final r = _hira(reading);
  return nfkc(headword).endsWith('だ') && r.endsWith('だ')
      ? r.substring(0, r.length - 1)
      : r;
}

bool _readingsOk(TruthWord truth, ScoredWord word) {
  final want = {for (final r in truth.readings) _readingKey(r, truth.headword)};
  final got = {
    for (final r in word.readings)
      if (r.trim().isNotEmpty) _readingKey(r, word.headword),
  };
  if (want.isEmpty) {
    // A kana word: no reading, or the kana itself from a dictionary.
    return got.isEmpty || got.every((r) => r == _hira(truth.headword));
  }
  return got.isNotEmpty && want.containsAll(got);
}

/// Scores [words] returned for [page].
PageExtractScore scoreExtractPage(
  ExtractTruthPage page,
  List<ScoredWord> words, {
  Duration elapsed = Duration.zero,
}) {
  final first = <String, ScoredWord>{};
  final counts = <String, int>{};
  for (final w in words) {
    if (!page.scoresSentences && w.origin == WordOrigin.sentence) continue;
    final k = _key(w.headword);
    first.putIfAbsent(k, () => w);
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final vocabKeys = {for (final v in page.vocab) _key(v.headword)};
  final sentenceKeys = {for (final s in page.sentenceWords) _key(s)};
  final ignore = {for (final i in page.ignore) _key(i)};
  final mistakes = <String>[];
  var found = 0, readingsOk = 0, meaningsOk = 0, meaningsOf = 0;
  var high = 0, highWrong = 0;
  for (final v in page.vocab) {
    final w = first[_key(v.headword)];
    if (w == null) {
      mistakes.add('MISS ${v.headword}');
      continue;
    }
    found++;
    final readingOk = _readingsOk(v, w);
    if (readingOk) {
      readingsOk++;
    } else {
      mistakes.add(
        'READ ${v.headword} got=${w.readings.join('/')} want=${v.readings.join('/')}',
      );
    }
    var meaningOk = true;
    if (v.meaning != null) {
      meaningsOf++;
      meaningOk =
          normalizeMeaning(w.meaning ?? '') == normalizeMeaning(v.meaning!);
      if (meaningOk) {
        meaningsOk++;
      } else {
        mistakes.add('MEAN ${v.headword} got=${w.meaning} want=${v.meaning}');
      }
    }
    if (w.confidence == PairConfidence.high) {
      high++;
      if (!readingOk || !meaningOk) {
        highWrong++;
        mistakes.add('HIGH-WRONG ${v.headword}');
      }
    }
  }
  final returnedKeys = first.keys.toSet();
  final sentenceFound = sentenceKeys.where(returnedKeys.contains).length;
  final fromSentences = [
    for (final MapEntry(key: k, value: w) in first.entries)
      if (w.origin == WordOrigin.sentence && !ignore.contains(k)) k,
  ];
  final sentenceRight = fromSentences
      .where((k) => sentenceKeys.contains(k) || vocabKeys.contains(k))
      .length;
  final extras = [
    for (final k in returnedKeys)
      if (!vocabKeys.contains(k) &&
          !sentenceKeys.contains(k) &&
          !ignore.contains(k))
        k,
  ];
  var extraHigh = 0;
  for (final k in extras) {
    mistakes.add('EXTRA ${first[k]!.headword}');
    if (first[k]!.confidence == PairConfidence.high) {
      extraHigh++;
      mistakes.add('EXTRA-HIGH ${first[k]!.headword}');
    }
  }
  var duplicates = 0;
  for (final MapEntry(key: k, value: n) in counts.entries) {
    if (n > 1) {
      duplicates += n - 1;
      mistakes.add('DUP ${first[k]!.headword} x$n');
    }
  }
  for (final s in page.sentenceWords) {
    if (!returnedKeys.contains(_key(s))) mistakes.add('MISS-SENTENCE $s');
  }
  return PageExtractScore(
    page: page.page,
    vocab: page.vocab.length,
    found: found,
    readingsOk: readingsOk,
    meanings: (ok: meaningsOk, of: meaningsOf),
    sentenceWords: (ok: sentenceFound, of: sentenceKeys.length),
    sentencePredicted: (ok: sentenceRight, of: fromSentences.length),
    extras: extras.length,
    duplicates: duplicates,
    highWrong: highWrong,
    high: high,
    extraHigh: extraHigh,
    returned: words.length,
    mistakes: List.unmodifiable(mistakes),
    elapsed: elapsed,
  );
}

final RegExp _trailingPunctuation = RegExp(r'[.。,，\s]+$');

/// Normalized meaning for comparison: NFKC, no spaces, no `(…)` notes,
/// commas and periods between Korean words alike.
String normalizeMeaning(String s) => fixKoreanPeriods(nfkc(s))
    .replaceAll(_notes, '')
    .replaceAll('，', ',')
    .replaceAll(_trailingPunctuation, '')
    .replaceAll(_spaces, '');

/// Runs [run] on every page of [truth] and scores it; the time per page is
/// the extraction only (OCR passes are loaded, not recognized).
Future<ExtractScore> scoreExtractor({
  required ExtractTruth truth,
  required Future<OcrScan> Function(String fixture) loadScan,
  required Future<List<ScoredWord>> Function(OcrScan scan) run,
  bool warmUp = false,
}) async {
  // The first page read pays for the VM's warm-up and the dictionary
  // files' first reads; with [warmUp] it is read once before the timing.
  if (warmUp && truth.pages.isNotEmpty) {
    await run(await loadScan(truth.pages.first.fixture));
  }
  final pages = <PageExtractScore>[];
  for (final page in truth.pages) {
    final scan = await loadScan(page.fixture);
    final watch = Stopwatch()..start();
    final words = await run(scan);
    watch.stop();
    pages.add(scoreExtractPage(page, words, elapsed: watch.elapsed));
  }
  return ExtractScore(List.unmodifiable(pages));
}

/// [scoreExtractor]'s `run` for the word extractor.
Future<List<ScoredWord>> Function(OcrScan) generalRun(GeneralExtractor e) =>
    (scan) async => [
      for (final w in (await e.extract(scan)).words)
        ScoredWord.fromExtracted(w),
    ];
