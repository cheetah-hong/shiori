// K11: the corrector that fills an empty meaning from the Korean glossary.
// A fake glossary stands in for the Basic Korean Dictionary; the words are
// synthetic examples.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

CapturedEntry entry(
  String headword, {
  List<String> readings = const ['はな'],
  String meaning = '',
  List<EntryIssue> issues = const [],
}) => CapturedEntry(
  no: '0001',
  headword: headword,
  readings: readings,
  pos: PartOfSpeech.noun,
  meaning: meaning,
  issues: issues,
  ocrHeadword: headword,
);

/// Answers from a fixed table keyed by headword; records every call.
final class _FakeGlossary implements KoreanGlossary {
  _FakeGlossary(this.table);

  final Map<String, List<KoreanSense>> table;
  final List<(String, List<String>, int)> calls = [];

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
  }) async {
    calls.add((headword, readings, limit));
    return (table[headword] ?? const []).take(limit).toList();
  }

  @override
  List<GlossarySourceInfo> get sources => const [];
}

/// Knows nothing: every pair is notFound, no glyph fixes.
final class _RejectingDictionary implements Dictionary {
  const _RejectingDictionary();

  @override
  Future<List<DictionaryEntry>> byReading(
    String reading, {
    int limit = 5,
    PartOfSpeech? pos,
  }) async => const [];

  @override
  Future<List<DictionaryEntry>> byHeadword(
    String headword, {
    int limit = 5,
  }) async => const [];

  @override
  Future<PairStatus> checkPair(String headword, List<String> readings) async =>
      PairStatus.notFound;

  @override
  Future<List<String>> fixHeadword(
    String ocrHeadword,
    String reading, {
    PartOfSpeech? pos,
    int limit = 3,
  }) async => const [];
}

const _nose = KoreanSense(
  words: ['코'],
  source: GlossarySource.krdict,
  level: GlossaryLevel.beginner,
  senseNo: 1,
);
const _onlyJust = KoreanSense(
  words: ['다만', '단지'],
  source: GlossarySource.krdict,
  senseNo: 1,
);
const _merely = KoreanSense(words: ['그저'], source: GlossarySource.krdict);

void main() {
  late _FakeGlossary glossary;
  late KoreanMeaningFiller filler;

  setUp(() {
    glossary = _FakeGlossary({
      '鼻': [_nose],
      'ただ': [_onlyJust, _merely],
    });
    filler = KoreanMeaningFiller(glossary);
  });

  test('an empty meaning gets the first meaning, marked as a guess', () async {
    final e = await filler.correct(entry('鼻'));
    expect(e.meaning, '코');
    expect(e.issues, [
      const EntryIssue.inferred(EntryField.meaning, note: '사전 뜻: 한국어기초사전'),
    ]);
    expect(e.statusOf(EntryField.meaning), FieldStatus.inferred);
    expect(e.needsReview, isFalse);
    expect(glossary.calls.single.$1, '鼻');
    expect(glossary.calls.single.$2, ['はな'], reason: 'readings are passed on');
  });

  test('a meaning with several words is written like the page', () async {
    final e = await filler.correct(entry('ただ', readings: const []));
    expect(e.meaning, '다만, 단지');
  });

  test('a meaning of blanks counts as empty', () async {
    expect((await filler.correct(entry('鼻', meaning: '  '))).meaning, '코');
  });

  test('a meaning read from the page is never changed', () async {
    final read = entry('鼻', meaning: '콧등');
    expect(await filler.correct(read), read);
    expect(glossary.calls, isEmpty);
  });

  test('a meaning flagged as cut is still the page\'s', () async {
    final cut = entry(
      '鼻',
      meaning: '코,',
      issues: const [EntryIssue.suspect(EntryField.meaning)],
    );
    expect(await filler.correct(cut), cut);
  });

  test('no glossary data: nothing changes', () async {
    final e = entry('鼻');
    expect(
      await const KoreanMeaningFiller(EmptyKoreanGlossary()).correct(e),
      e,
    );
  });

  test('a word the glossary does not know: nothing changes', () async {
    final e = entry('耳', readings: const ['みみ']);
    expect(await filler.correct(e), e);
  });

  test('a headword the dictionary does not have is not filled', () async {
    final e = entry(
      '鼻',
      issues: const [EntryIssue.unverified(EntryField.headword)],
    );
    expect(await filler.correct(e), e);
    expect(glossary.calls, isEmpty);
  });

  test('an unread headword is not filled', () async {
    final e = entry(
      '',
      issues: const [EntryIssue.missing(EntryField.headword)],
    );
    expect(await filler.correct(e), e);
    expect((await filler.correct(entry(''))).meaning, isEmpty);
    expect(glossary.calls, isEmpty);
  });

  group('in the standard chain', () {
    test('runs after the dictionary check and before the flags', () {
      final ids = [
        for (final c in standardCorrectors(
          const EmptyDictionary(),
          glossary: glossary,
        ))
          c.id,
      ];
      expect(ids.sublist(ids.length - 3), [
        'dictionary-pair',
        'korean-meaning',
        'missing-fields',
      ]);
    });

    Future<CapturedEntry> run(CapturedEntry e, Dictionary dictionary) async {
      var out = e;
      for (final c in standardCorrectors(dictionary, glossary: glossary)) {
        out = await c.correct(out);
      }
      return out;
    }

    test('a filled meaning is not flagged as missing', () async {
      final e = await run(entry('鼻'), const EmptyDictionary());
      expect(e.meaning, '코');
      expect([for (final i in e.issues) i.code], ['meaning:inferred']);
    });

    test('"사전에 없음" from the dictionary check stops the fill', () async {
      final e = await run(entry('鼻'), const _RejectingDictionary());
      expect(e.meaning, isEmpty);
      expect(
        [for (final i in e.issues) i.code],
        ['headword:unverified', 'meaning:missing'],
      );
    });

    test('without a glossary the chain is as before', () async {
      var e = entry('鼻');
      for (final c in standardCorrectors(const EmptyDictionary())) {
        e = await c.correct(e);
      }
      expect([for (final i in e.issues) i.code], ['meaning:missing']);
    });
  });
}
