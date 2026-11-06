import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime(2026, 11, 5);

  group('value equality', () {
    test('Word', () {
      Word w({String meaning = '강, 개천'}) => Word(
        id: 'tb:0015',
        textbookId: 'tb',
        day: 1,
        no: '0015',
        headword: '川',
        readings: const ['かわ'],
        pos: PartOfSpeech.noun,
        meaning: meaning,
        example: const Example(ja: '川で泳ぐ。', ko: '강에서 헤엄치다.'),
        page: 11,
        createdAt: t0,
      );
      expect(w(), w());
      expect(w().hashCode, w().hashCode);
      expect(w(), isNot(w(meaning: '강')));
      expect(w().toString(), contains('川'));
    });

    test('Textbook, TextbookDay, PageMeta, PageImage, EntryIssue, Example', () {
      expect(
        Textbook(id: 'a', title: 'A', createdAt: t0),
        Textbook(id: 'a', title: 'A', createdAt: t0),
      );
      expect(
        Textbook(id: 'a', title: 'A', createdAt: t0).copyWith(title: 'B').title,
        'B',
      );
      expect(
        const TextbookDay(textbookId: 'a', number: 1, title: 'x').hashCode,
        const TextbookDay(textbookId: 'a', number: 1, title: 'x').hashCode,
      );
      expect(
        const PageImage('s010', label: '10쪽'),
        const PageImage('s010', label: '10쪽'),
      );
      expect(
        const PageImage('s010').hashCode,
        const PageImage('s010').hashCode,
      );
      expect(const PageImage('s010').toString(), contains('s010'));
      expect(
        const EntryIssue.corrected(
          EntryField.headword,
          note: 'ー → 一',
        ).toString(),
        'headword:corrected(ー → 一)',
      );
      expect(
        const EntryIssue.missing(EntryField.meaning).hashCode,
        const EntryIssue.missing(EntryField.meaning).hashCode,
      );
      expect(const Example(ja: 'a', ko: 'b').toString(), contains('a'));
      expect(
        const Example(ja: 'a', ko: 'b').hashCode,
        const Example(ja: 'a', ko: 'b').hashCode,
      );
    });

    test('CapturedEntry and CaptureDraft', () {
      CapturedEntry e() => const CapturedEntry(
        headword: '口',
        readings: ['くち'],
        pos: PartOfSpeech.noun,
        meaning: '입',
        issues: [EntryIssue.corrected(EntryField.headword, note: 'ロ → 口')],
      );
      expect(e(), e());
      expect(e().hashCode, e().hashCode);
      expect(e(), isNot(e().copyWith(readings: ['こう'])));
      CaptureDraft d() => CaptureDraft(entries: [e()]);
      expect(d(), d());
      expect(d().hashCode, d().hashCode);
      expect(d(), isNot(d().replaceEntry(0, e().copyWith(included: false))));
    });

    test('TextbookStats', () {
      final book = Textbook(id: 'a', title: 'A', createdAt: t0);
      TextbookStats s({int count = 2, List<int> days = const [1]}) =>
          TextbookStats(textbook: book, wordCount: count, days: days);
      expect(s(), s());
      expect(s().hashCode, s().hashCode);
      expect(s(), isNot(s(days: const [2])));
      expect(s(), isNot(s(count: 3)));
      expect(s().toString(), contains('2'));
    });

    test('ReviewCard', () {
      final c = ReviewCard(
        wordId: 'w',
        level: 2,
        dueAt: t0,
        lastReviewedAt: t0,
      );
      expect(c.copyWith(), c);
      expect(c.copyWith(level: 3), isNot(c));
      expect(c.hashCode, c.copyWith().hashCode);
      expect(c.isDue(t0), isTrue);
      expect(c.isDue(t0.subtract(const Duration(seconds: 1))), isFalse);
      expect(c.toString(), contains('L2'));
    });

    test('PartOfSpeech from badge', () {
      expect(PartOfSpeech.fromBadge('い형'), PartOfSpeech.iAdjective);
      expect(PartOfSpeech.fromBadge('?'), isNull);
      expect(PartOfSpeech.fromBadge(null), isNull);
    });

    test('OcrLine toString', () {
      expect(
        const OcrLine(text: '川', x: 0, y: 0, width: 1, height: 1).toString(),
        contains('川'),
      );
    });
  });

  group('first port blocks', () {
    test(
      'SystemClock is close to now; FixedClock moves only when advanced',
      () {
        final before = DateTime.now();
        expect(const SystemClock().now().isBefore(before), isFalse);
        final fixed = FixedClock(t0);
        expect(fixed.now(), t0);
        expect(
          fixed.advance(const Duration(days: 3)).now(),
          t0.add(const Duration(days: 3)),
        );
        expect(fixed.now(), t0);
      },
    );

    test('SilentSpeech is unavailable and silent', () async {
      const speech = SilentSpeech();
      expect(speech.isAvailable, isFalse);
      await speech.speak('川');
    });

    test('TextRecognitionException explains itself', () {
      expect(
        const TextRecognitionException('실패', cause: 'io').toString(),
        contains('실패 (io)'),
      );
      expect(const TextRecognitionException('실패').toString(), endsWith('실패'));
    });
  });
}
