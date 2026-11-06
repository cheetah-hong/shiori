// Review fix (drop-template review, MAJOR 1): picking a kanji spelling for
// a headword left as kana (the dictionary had several spellings of its kana
// and meaning) keeps the kana as the reading. Made-up rows only.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

/// A kana word read back with two spellings, as the extractor leaves it.
CapturedEntry _kanaWithCandidates() => const ExtractedWord(
  origin: WordOrigin.wordList,
  headword: 'はし',
  readings: [],
  meaning: '다리',
  headwordCandidates: ['橋', '箸'],
).toCapturedEntry();

void main() {
  test('the kana becomes the reading of the picked kanji spelling', () {
    final e = _kanaWithCandidates();
    expect(e.readings, isEmpty);

    final picked = pickCandidate(e, EntryField.headword, '橋');

    expect(picked.headword, '橋');
    expect(picked.readings, ['はし']);
    expect(
      picked.statusOf(EntryField.readings),
      isNot(FieldStatus.needsReview),
    );
  });

  test('picking the kana back keeps the reading the pick gave', () {
    final picked = pickCandidate(
      _kanaWithCandidates(),
      EntryField.headword,
      '橋',
    );
    final back = pickCandidate(picked, EntryField.headword, 'はし');

    expect(back.headword, 'はし');
    // The reading stays: the learner may clear it by hand.
    expect(back.readings, ['はし']);
  });

  test('a kanji headword picked with no reading at all is flagged', () {
    final e = const ExtractedWord(
      origin: WordOrigin.wordList,
      headword: '',
      readings: [],
      meaning: '다리',
      headwordCandidates: ['橋', '箸'],
    ).toCapturedEntry();

    final picked = pickCandidate(e, EntryField.headword, '橋');

    expect(picked.readings, isEmpty);
    expect(picked.statusOf(EntryField.readings), FieldStatus.needsReview);
  });

  test('a headword that had a reading keeps it', () {
    final e = const ExtractedWord(
      origin: WordOrigin.wordList,
      headword: '端',
      readings: ['はし'],
      meaning: '끝',
      headwordCandidates: ['橋'],
    ).toCapturedEntry();

    expect(pickCandidate(e, EntryField.headword, '橋').readings, ['はし']);
  });

  test('picking a candidate flags no other cell (a word without a POS)', () {
    final e = _kanaWithCandidates();
    expect(e.pos, isNull);

    final headword = pickCandidate(e, EntryField.headword, '橋');
    final meaning = pickCandidate(e, EntryField.meaning, '교량');

    for (final picked in [headword, meaning]) {
      expect(picked.issues.map((i) => i.code), isNot(contains('pos:missing')));
    }
  });
}
