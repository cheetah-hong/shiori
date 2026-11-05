// What the learner does on the review screen: picking a dictionary candidate
// and pressing 고치기. Made-up words only.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

CapturedEntry _entry(
  String no,
  String headword, {
  List<String> readings = const ['よみ'],
  PartOfSpeech? pos = PartOfSpeech.noun,
  String meaning = '뜻',
  bool important = false,
  Example? example,
  List<EntryIssue> issues = const [],
  List<String> candidates = const [],
}) => CapturedEntry(
  no: no,
  headword: headword,
  readings: readings,
  pos: pos,
  meaning: meaning,
  important: important,
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
      important: e.important,
      example: e.example,
      checksExample: checksExample,
    );

List<String> _codes(CapturedEntry e) => [for (final i in e.issues) i.code];

void main() {
  group('a picked candidate is the learner\'s, not an automatic fix', () {
    final fixed = _entry(
      '0001',
      '一日',
      issues: const [
        EntryIssue.corrected(EntryField.headword, note: 'ー日 → 一日'),
      ],
    );
    final unread = _entry(
      '0002',
      '',
      readings: const ['ひ'],
      issues: const [EntryIssue.missing(EntryField.headword)],
      candidates: const ['日', '火'],
    );
    final draft = CaptureDraft(
      templateId: 'vocab.list',
      meta: const PageMeta(day: 1, title: '자연', page: 10),
      entries: [fixed, unread],
    );

    test('the automatic count stays the same', () {
      expect(draft.correctedCount, 1);
      final picked = draft.replaceEntry(1, pickHeadword(unread, '日'));
      expect(picked.correctedCount, 1);
      expect(picked.entries[1].wasCorrected, isFalse);
      expect(picked.entries[0].wasCorrected, isTrue);
    });

    test('the picked headword no longer needs review and reads as fixed', () {
      final e = pickHeadword(unread, '日');
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
      final tb = await service.createTextbook('JLPT 단어장');
      final result = await service.saveDraft(
        draft.replaceEntry(1, pickHeadword(unread, '日')),
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
        '0005',
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

    test('"not in the dictionary" clears; a guessed POS stays', () {
      final e = _entry(
        '0003',
        '雨傘具',
        issues: const [
          EntryIssue.unverified(EntryField.headword),
          EntryIssue.inferred(EntryField.pos, note: '품사 추정: 명'),
        ],
      );
      expect(_codes(_saveUnchanged(e)), ['pos:inferred']);
    });

    test('an automatic fix stays when its value is unchanged', () {
      final e = _entry(
        '0004',
        '一日',
        issues: const [
          EntryIssue.corrected(EntryField.headword, note: 'ー日 → 一日'),
          EntryIssue.unverified(EntryField.headword),
        ],
      );
      expect(_codes(_saveUnchanged(e)), ['headword:corrected']);
    });

    test('a changed value clears every flag on that cell', () {
      final e = _entry(
        '0004',
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
        important: e.important,
      );
      expect(out.headword, '二日');
      expect(_codes(out), ['pos:inferred']);
    });

    test('an entry without flags is left as it is', () {
      final e = _entry('0006', '切符', meaning: '표, 티켓');
      expect(_saveUnchanged(e), e);
    });

    test('an empty meaning is flagged missing again', () {
      final e = _entry(
        '0007',
        '川',
        meaning: '',
        issues: const [EntryIssue.missing(EntryField.meaning)],
      );
      expect(_codes(_saveUnchanged(e)), ['meaning:missing']);
      final cleared = applyLearnerEdits(
        _entry('0008', '山', meaning: '산'),
        headword: '山',
        readings: const ['よみ'],
        pos: PartOfSpeech.noun,
        meaning: '',
        important: false,
      );
      expect(_codes(cleared), ['meaning:missing']);
    });

    test('a checked example clears its missing flag, even left empty', () {
      final e = _entry(
        '0009',
        '空',
        issues: const [EntryIssue.missing(EntryField.example)],
      );
      expect(_codes(_saveUnchanged(e, checksExample: true)), isEmpty);
      expect(_codes(_saveUnchanged(e)), ['example:missing']);
    });

    test('a guessed star stays when the learner leaves it on', () {
      final e = _entry(
        '0010',
        '海',
        important: true,
        issues: const [EntryIssue.inferred(EntryField.important)],
      );
      expect(_codes(_saveUnchanged(e)), ['important:inferred']);
      final off = applyLearnerEdits(
        e,
        headword: e.headword,
        readings: e.readings,
        pos: e.pos,
        meaning: e.meaning,
        important: false,
      );
      expect(off.important, isFalse);
      expect(off.issues, isEmpty);
    });
  });
}
