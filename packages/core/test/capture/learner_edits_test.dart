// What the learner does on the review screen: picking a headword candidate
// and pressing 고치기. Made-up words only.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

CapturedEntry _entry(
  String headword, {
  List<String> readings = const ['よみ'],
  PartOfSpeech? pos = PartOfSpeech.noun,
  String meaning = '뜻',
  Example? example,
  List<EntryIssue> issues = const [],
  List<String> candidates = const [],
}) => CapturedEntry(
  headword: headword,
  readings: readings,
  pos: pos,
  meaning: meaning,
  example: example,
  issues: issues,
  headwordCandidates: candidates,
);

/// 고치기 pressed without changing anything.
CapturedEntry _saveUnchanged(CapturedEntry e, {bool checksExample = false}) =>
    applyLearnerEdits(
      e,
      headword: e.headword,
      readings: e.readings,
      pos: e.pos,
      meaning: e.meaning,
      example: e.example,
      checksExample: checksExample,
    );

List<String> _codes(CapturedEntry e) => [for (final i in e.issues) i.code];

void main() {
  group('a picked candidate is the learner\'s, not an automatic fix', () {
    final fixed = _entry(
      '一日',
      issues: const [
        EntryIssue.corrected(EntryField.headword, note: 'ー日 → 一日'),
      ],
    );
    final unread = _entry(
      '',
      readings: const ['ひ'],
      issues: const [EntryIssue.missing(EntryField.headword)],
      candidates: const ['日', '火'],
    );
    final draft = CaptureDraft(entries: [fixed, unread]);
    CapturedEntry pick(CapturedEntry e, String headword) =>
        pickCandidate(e, EntryField.headword, headword);

    test('the automatic count stays the same', () {
      expect(draft.correctedCount, 1);
      final picked = draft.replaceEntry(1, pick(unread, '日'));
      expect(picked.correctedCount, 1);
      expect(picked.entries[1].wasCorrected, isFalse);
      expect(picked.entries[0].wasCorrected, isTrue);
    });

    test('the picked headword no longer needs review and reads as fixed', () {
      final e = pick(unread, '日');
      expect(e.headword, '日');
      expect(e.statusOf(EntryField.headword), isNot(FieldStatus.needsReview));
      expect(e.statusOf(EntryField.headword), FieldStatus.corrected);
      expect(e.needsReview, isFalse);
      expect(_codes(e), ['headword:picked']);
      expect(e.issues.single.kind, IssueKind.picked);
      expect(e.issues.single.note, contains('日'));
    });

    test('saving the draft stores the picked headword', () async {
      final repo = InMemoryLibraryRepository();
      final service = LibraryService(
        library: repo,
        clock: FixedClock(DateTime(2026, 11, 5, 21)),
      );
      final tb = await service.createTextbook('내 단어장');
      final result = await service.saveDraft(
        draft.replaceEntry(1, pick(unread, '日')),
        textbookId: tb.id,
      );
      expect(result.saved, 2);
      final words = await repo.words(textbookId: tb.id);
      expect(words.map((w) => w.headword), ['一日', '日']);
    });
  });

  group('고치기 confirms the entry', () {
    test('a suspect meaning clears even when the value is unchanged', () {
      final e = _entry(
        '到着',
        meaning: '도착,',
        issues: const [
          EntryIssue.suspect(EntryField.meaning, note: '뜻 끝이 잘렸을 수 있음'),
        ],
      );
      final out = _saveUnchanged(e);
      expect(out.issues, isEmpty);
      expect(out.meaning, '도착,');
      expect(out.needsReview, isFalse);
    });

    test('a suspect headword clears; a guessed POS stays', () {
      final e = _entry(
        '雨傘具',
        issues: const [
          EntryIssue.suspect(EntryField.headword),
          EntryIssue.inferred(EntryField.pos, note: '품사 추정: 명'),
        ],
      );
      expect(_codes(_saveUnchanged(e)), ['pos:inferred']);
    });

    test('an automatic fix stays when its value is unchanged', () {
      final e = _entry(
        '一日',
        issues: const [
          EntryIssue.corrected(EntryField.headword, note: 'ー日 → 一日'),
          EntryIssue.suspect(EntryField.headword),
        ],
      );
      expect(_codes(_saveUnchanged(e)), ['headword:corrected']);
    });

    test('a changed value clears every flag on that cell', () {
      final e = _entry(
        '一日',
        issues: const [
          EntryIssue.corrected(EntryField.headword, note: 'ー日 → 一日'),
          EntryIssue.inferred(EntryField.pos),
        ],
      );
      final out = applyLearnerEdits(
        e,
        headword: '二日',
        readings: e.readings,
        pos: e.pos,
        meaning: e.meaning,
      );
      expect(out.headword, '二日');
      expect(_codes(out), ['pos:inferred']);
    });

    test('an entry without flags is left as it is', () {
      final e = _entry('切符', meaning: '표, 티켓');
      expect(_saveUnchanged(e), e);
    });

    test('an empty meaning is flagged missing again', () {
      final e = _entry(
        '川',
        meaning: '',
        issues: const [EntryIssue.missing(EntryField.meaning)],
      );
      expect(_codes(_saveUnchanged(e)), ['meaning:missing']);
      final cleared = applyLearnerEdits(
        _entry('山', meaning: '산'),
        headword: '山',
        readings: const ['よみ'],
        pos: PartOfSpeech.noun,
        meaning: '',
      );
      expect(_codes(cleared), ['meaning:missing']);
    });

    test('a checked example clears its missing flag, even left empty', () {
      final e = _entry(
        '空',
        issues: const [EntryIssue.missing(EntryField.example)],
      );
      expect(_codes(_saveUnchanged(e, checksExample: true)), isEmpty);
      expect(_codes(_saveUnchanged(e)), ['example:missing']);
    });
  });

  group('missing cells', () {
    test('every empty core cell is flagged', () {
      final out = flagMissingFields(
        _entry('', readings: const [], pos: null, meaning: ''),
      );
      expect(_codes(out), [
        'headword:missing',
        'meaning:missing',
        'pos:missing',
      ]);
      expect(out.needsReview, isTrue);
    });

    test('a kanji word needs a reading; a kana word does not', () {
      expect(_codes(flagMissingFields(_entry('天気予報', readings: const []))), [
        'readings:missing',
      ]);
      expect(_codes(flagMissingFields(_entry('もう', readings: const []))), []);
    });

    test('a cell the learner cleared is flagged once', () {
      final cleared = _entry('川').edit(meaning: '');
      final flagged = flagMissingFields(cleared);
      expect(_codes(flagged), ['meaning:missing']);
      expect(flagMissingFields(flagged).issues.length, 1);
      expect(missingFieldsOf(_entry('川')), isEmpty);
    });
  });
}
