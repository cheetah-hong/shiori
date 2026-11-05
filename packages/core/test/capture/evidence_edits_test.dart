// E8 (core side): what the review screen does with the evidence — pick a
// candidate, place an unpaired fragment, make an entry from one, approve
// every high entry.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

const _box = PhotoBox(x: 0.1, y: 0.2, width: 0.1, height: 0.02);

CapturedEntry _entry({
  String headword = '走る',
  String meaning = '달리다',
  PairConfidence meaningConfidence = PairConfidence.medium,
  List<String> candidates = const ['뛰다'],
}) => CapturedEntry(
  no: null,
  headword: headword,
  readings: const ['はしる'],
  pos: PartOfSpeech.verb,
  meaning: meaning,
  issues: [
    if (meaningConfidence != PairConfidence.high)
      const EntryIssue.suspect(EntryField.meaning, note: 'pair medium'),
  ],
  evidence: EntryEvidence(
    origin: WordOrigin.wordList,
    fields: {
      EntryField.headword: const FieldEvidence(
        source: FieldSource.photo,
        boxes: [_box],
      ),
      EntryField.readings: const FieldEvidence(
        source: FieldSource.photo,
        confidence: PairConfidence.high,
        boxes: [_box],
      ),
      EntryField.meaning: FieldEvidence(
        source: FieldSource.photo,
        confidence: meaningConfidence,
        boxes: const [_box],
        candidates: candidates,
      ),
    },
  ),
);

Fragment _fragment(String text, FragmentKind kind) => Fragment(
  id: 7,
  text: text,
  kind: kind,
  x: 0.5,
  y: 0.6,
  width: 0.1,
  height: 0.02,
  pass: kind == FragmentKind.hangul ? OcrPass.korean : OcrPass.japanese,
);

void main() {
  test('the evidence confidence is the weakest paired field', () {
    expect(_entry().evidence!.confidence, PairConfidence.medium);
    expect(
      _entry(meaningConfidence: PairConfidence.high).evidence!.isHigh,
      isTrue,
    );
  });

  test('a picked candidate replaces the meaning, is marked as the learner\'s '
      'choice and clears the doubt', () {
    final e = pickCandidate(_entry(), EntryField.meaning, '뛰다');

    expect(e.meaning, '뛰다');
    expect(e.needsReview, isFalse);
    expect(e.statusOf(EntryField.meaning), FieldStatus.corrected);
    expect(e.evidence!.of(EntryField.meaning)!.checked, isTrue);
    // The value it replaced becomes a candidate, so the pick can be undone.
    expect(e.evidence!.of(EntryField.meaning)!.candidates, contains('달리다'));
  });

  test('a reading candidate is split like typed readings', () {
    final e = pickCandidate(_entry(), EntryField.readings, 'あした/あす');

    expect(e.readings, ['あした', 'あす']);
  });

  test('an unpaired Korean fragment placed on the meaning', () {
    final e = attachFragment(
      _entry(meaning: ''),
      EntryField.meaning,
      _fragment('뛰어가다', FragmentKind.hangul),
    );

    expect(e.meaning, '뛰어가다');
    final field = e.evidence!.of(EntryField.meaning)!;
    expect(field.source, FieldSource.photo);
    expect(field.boxes.single.x, 0.5);
    expect(field.checked, isTrue);
  });

  test('a new entry from an unpaired fragment: Japanese → headword, '
      'Korean → meaning', () {
    final ja = entryFromFragment(_fragment('散歩', FragmentKind.kanjiWord));
    expect(ja.headword, '散歩');
    expect(ja.meaning, '');
    expect(ja.no, isNull);
    expect(ja.statusOf(EntryField.meaning), FieldStatus.needsReview);
    expect(ja.evidence!.of(EntryField.headword)!.boxes, hasLength(1));

    final ko = entryFromFragment(_fragment('산책', FragmentKind.hangul));
    expect(ko.headword, '');
    expect(ko.meaning, '산책');
    expect(ko.statusOf(EntryField.headword), FieldStatus.needsReview);
  });

  test('approving every high entry confirms only those', () {
    final draft = CaptureDraft(
      templateId: generalTemplateId,
      meta: PageMeta.empty,
      entries: [
        _entry(meaningConfidence: PairConfidence.high),
        _entry(headword: '食べる'),
        const CapturedEntry(
          no: '0001',
          headword: '本',
          readings: ['ほん'],
          pos: null,
          meaning: '책',
        ),
      ],
    );

    final approved = approveHighConfidence(draft);

    expect(approved.entries[0].evidence!.confirmed, isTrue);
    expect(approved.entries[1].evidence!.confirmed, isFalse);
    expect(approved.entries[2], draft.entries[2]);
    expect(highConfidenceCount(draft), 1);
  });

  test('editing a cell marks its evidence as checked by the learner', () {
    final e = _entry().edit(meaning: '달려가다');

    expect(e.evidence!.of(EntryField.meaning)!.checked, isTrue);
    expect(e.evidence!.of(EntryField.readings)!.checked, isFalse);
  });

  test('boxes outside the photo are clamped to it', () {
    const box = PhotoBox(x: -0.2, y: 0.95, width: 0.5, height: 0.2);
    final c = box.clamped();

    expect(c.x, 0);
    expect(c.y, 0.95);
    expect(c.width, closeTo(0.3, 1e-9));
    expect(c.height, closeTo(0.05, 1e-9));
    expect(
      const PhotoBox(x: 2, y: 2, width: 1, height: 1).clamped().isEmpty,
      isTrue,
    );
    expect(
      const PhotoBox(
        x: double.nan,
        y: 0,
        width: 1,
        height: 1,
      ).clamped().isEmpty,
      isTrue,
    );
  });
}
