// The dictionary slot and the correctors that use it. A fake dictionary
// stands in for JMdict; the words are synthetic examples.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

CapturedEntry entry(
  String headword, {
  List<String> readings = const ['いちにち'],
  PartOfSpeech? pos = PartOfSpeech.noun,
  String? ocrHeadword,
  List<EntryIssue> issues = const [],
}) => CapturedEntry(
  no: '0001',
  headword: headword,
  readings: readings,
  pos: pos,
  meaning: '뜻',
  issues: issues,
  ocrHeadword: ocrHeadword ?? headword,
);

/// Answers from fixed tables and records every call.
final class _FakeDictionary implements Dictionary {
  _FakeDictionary({
    this.pairs = const {},
    this.fixes = const {},
    this.byKana = const {},
  });

  /// Headword → status; anything else is notFound.
  final Map<String, PairStatus> pairs;

  /// OCR headword → look-alike fixes.
  final Map<String, List<String>> fixes;
  final Map<String, List<String>> byKana;

  final List<(String, List<String>)> pairCalls = [];
  final List<(String, String, PartOfSpeech?)> fixCalls = [];
  final List<(String, PartOfSpeech?)> readingCalls = [];

  @override
  Future<List<DictionaryEntry>> byReading(
    String reading, {
    int limit = 5,
    PartOfSpeech? pos,
  }) async {
    readingCalls.add((reading, pos));
    return [
      for (final h in (byKana[reading] ?? const <String>[]).take(limit))
        DictionaryEntry(headword: h, readings: [reading]),
    ];
  }

  @override
  Future<List<DictionaryEntry>> byHeadword(
    String headword, {
    int limit = 5,
  }) async => const [];

  @override
  Future<PairStatus> checkPair(String headword, List<String> readings) async {
    pairCalls.add((headword, readings));
    return pairs[headword] ?? PairStatus.notFound;
  }

  @override
  Future<List<String>> fixHeadword(
    String ocrHeadword,
    String reading, {
    PartOfSpeech? pos,
    int limit = 3,
  }) async {
    fixCalls.add((ocrHeadword, reading, pos));
    return (fixes[ocrHeadword] ?? const <String>[]).take(limit).toList();
  }
}

List<EntryIssue> headwordIssues(CapturedEntry e) => [
  for (final i in e.issues)
    if (i.field == EntryField.headword) i,
];

void main() {
  group('EmptyDictionary', () {
    const d = EmptyDictionary();

    test('cannot check pairs and fixes nothing', () async {
      expect(await d.checkPair('日', ['ひ']), PairStatus.unavailable);
      expect(await d.checkPair('もう', const []), PairStatus.unavailable);
      expect(await d.fixHeadword('ー日', 'いちにち'), isEmpty);
      expect(
        await d.fixHeadword('ー日', 'いちにち', pos: PartOfSpeech.noun),
        isEmpty,
      );
    });

    test('knows no words, with or without a POS hint', () async {
      expect(await d.byReading('ひ', pos: PartOfSpeech.noun), isEmpty);
      expect(await d.byReading('ひ'), isEmpty);
      expect(await d.byHeadword('日'), isEmpty);
    });
  });

  group('DictionaryPairCorrector', () {
    test('a known pair is left as it is', () async {
      final d = _FakeDictionary(pairs: {'一日': PairStatus.known});
      final e = entry('一日');
      expect(await DictionaryPairCorrector(d).correct(e), same(e));
      expect(d.pairCalls.single.$1, '一日');
      expect(d.pairCalls.single.$2, ['いちにち']);
    });

    test('without a dictionary nothing changes', () async {
      final e = entry('一日');
      expect(
        await const DictionaryPairCorrector(EmptyDictionary()).correct(e),
        same(e),
      );
    });

    test('an empty headword is left to the candidate corrector', () async {
      final d = _FakeDictionary();
      final e = entry('', readings: const ['ひ']);
      expect(await DictionaryPairCorrector(d).correct(e), same(e));
      expect(d.pairCalls, isEmpty);
      expect(d.fixCalls, isEmpty);
    });

    test(
      'a rule that broke a real word is undone when OCR read a known word',
      () async {
        final d = _FakeDictionary(pairs: {'タ行': PairStatus.known});
        final ruled = entry(
          '夕行',
          readings: const ['たぎょう'],
          ocrHeadword: 'タ行',
          issues: const [
            EntryIssue.corrected(EntryField.headword, note: 'タ行 → 夕行'),
          ],
        );
        final out = await DictionaryPairCorrector(d).correct(ruled);
        expect(out.headword, 'タ行');
        expect(out.ocrHeadword, 'タ行');
        final issues = headwordIssues(out);
        expect(issues, hasLength(1));
        expect(issues.single.kind, IssueKind.corrected);
        expect(issues.single.note, contains('(사전)'));
        expect(out.statusOf(EntryField.headword), FieldStatus.corrected);
        expect(out.needsReview, isFalse);
      },
    );

    test('a compound-only match is kept (weak, but nothing better)', () async {
      final d = _FakeDictionary(
        pairs: {'二短調': PairStatus.compoundOnly},
        fixes: {
          '二短調': ['二短調'],
        },
      );
      final e = entry('二短調', readings: const ['にたんちょう']);
      expect(await DictionaryPairCorrector(d).correct(e), same(e));
      expect(d.fixCalls, isEmpty);
    });

    test('look-alike glyphs that explain the text are fixed', () async {
      final d = _FakeDictionary(
        fixes: {
          'ー日': ['一日', '一'],
        },
      );
      final out = await DictionaryPairCorrector(d).correct(entry('ー日'));
      expect(out.headword, '一日');
      expect(out.headwordCandidates, ['一日', '一']);
      expect(out.statusOf(EntryField.headword), FieldStatus.corrected);
      expect(headwordIssues(out).single.note, contains('(사전)'));
      expect(d.fixCalls.single, ('ー日', 'いちにち', PartOfSpeech.noun));
    });

    test('a word the dictionary does not have is marked unverified', () async {
      final d = _FakeDictionary();
      final e = entry('雨傘具', readings: const ['あまがさぐ']);
      final out = await DictionaryPairCorrector(d).correct(e);
      expect(out.headword, '雨傘具');
      expect(headwordIssues(out).single.kind, IssueKind.unverified);
      expect(out.statusOf(EntryField.headword), FieldStatus.unverified);
      expect(out.needsReview, isTrue);
      expect(out.isFlagged, isTrue);
    });

    test('a kana word without a reading is checked with no readings', () async {
      final d = _FakeDictionary(pairs: {'のんびり': PairStatus.known});
      final e = entry('のんびり', readings: const [], pos: PartOfSpeech.adverb);
      expect(await DictionaryPairCorrector(d).correct(e), same(e));
      expect(d.pairCalls.single.$1, 'のんびり');
      expect(d.pairCalls.single.$2, isEmpty);
    });
  });

  group('DictionaryCandidateCorrector', () {
    test('passes the POS badge as a hint and only offers words', () async {
      final d = _FakeDictionary(
        byKana: {
          'そら': ['空', '虚'],
        },
      );
      final out = await DictionaryCandidateCorrector(
        d,
      ).correct(entry('', readings: const ['そら']));
      expect(d.readingCalls.single, ('そら', PartOfSpeech.noun));
      expect(out.headwordCandidates, ['空', '虚']);
      expect(out.headword, isEmpty, reason: 'the learner picks');
    });
  });

  test('the dictionary pair check runs after the rules, before the flags', () {
    final ids = standardCorrectors(
      const EmptyDictionary(),
    ).map((c) => c.id).toList();
    final pair = ids.indexOf('dictionary-pair');
    expect(pair, greaterThan(ids.indexOf('confusable-glyphs')));
    expect(pair, greaterThan(ids.indexOf('kana-okurigana')));
    expect(pair, greaterThan(ids.indexOf('reading-lookalikes')));
    expect(pair, greaterThan(ids.indexOf('dictionary-candidates')));
    expect(pair, ids.indexOf('missing-fields') - 1);
  });

  group('ocrHeadword', () {
    final raw = CapturePipeline(
      templates: TemplateRegistry(const [
        ListPageTemplate(),
        EntryPageTemplate(),
      ]),
      correctors: const [],
    );

    test('both templates record the headword they read', () async {
      for (final page in ['s011', 's140']) {
        final draft = await raw.fromScan(await loadScan(page));
        expect(draft.entries, isNotEmpty);
        for (final e in draft.entries) {
          expect(e.ocrHeadword, e.headword, reason: '$page ${e.no}');
        }
      }
    });

    test('correctors change the headword, never what OCR read', () async {
      final pipeline = standardPipeline();
      final list = await pipeline.fromScan(await loadScan('s011'));
      final sunset = list.entries.singleWhere((e) => e.no == '0016');
      expect((sunset.headword, sunset.ocrHeadword), ('夕日', 'タ日'));
      final entries = await pipeline.fromScan(await loadScan('s140'));
      final first = entries.entries.singleWhere((e) => e.no == '1211');
      expect(first.ocrHeadword, '乗り換える');
    });
  });
}
