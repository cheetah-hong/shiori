import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime(2026, 11, 5);

  group('value equality', () {
    test('Word', () {
      Word w({String meaning = '강, 개천'}) => Word(
        id: 'w1',
        headword: '川',
        readings: const ['かわ'],
        pos: PartOfSpeech.noun,
        meaning: meaning,
        example: const Example(ja: '川で泳ぐ。', ko: '강에서 헤엄치다.'),
        createdAt: t0,
      );
      expect(w(), w());
      expect(w().hashCode, w().hashCode);
      expect(w(), isNot(w(meaning: '강')));
      expect(w().toString(), contains('川'));
      expect(w().key, '川');
    });

    test('wordKey: the headword alone, without spaces, width or だ', () {
      expect(wordKey(' 食べる '), '食べる');
      expect(wordKey('食 べる'), '食べる');
      expect(wordKey('丈夫だ'), '丈夫');
      expect(wordKey('だ'), 'だ', reason: 'a lone だ is a word');
      expect(wordKey('まだ'), 'まだ', reason: 'no kanji: not a な-adjective');
      expect(wordKey('ﾃｽﾄ'), 'テスト');
      expect(
        Word(
          id: 'a',
          headword: '丈夫だ',
          readings: const [],
          meaning: '',
          createdAt: t0,
        ).key,
        '丈夫',
      );
    });

    test('Playlist, PlaylistEntry, playlistNameKey', () {
      final p = Playlist(id: 'p', name: 'A', createdAt: t0, position: 0);
      expect(p, Playlist(id: 'p', name: 'A', createdAt: t0, position: 0));
      expect(p.hashCode, p.copyWith().hashCode);
      expect(p.copyWith(name: 'B').name, 'B');
      expect(p.copyWith(position: 2).position, 2);
      expect(p.copyWith(name: 'B'), isNot(p));
      expect(p.toString(), contains('A'));
      final e = PlaylistEntry(
        playlistId: 'p',
        wordId: 'w',
        position: 3,
        addedAt: t0,
      );
      expect(
        e,
        PlaylistEntry(playlistId: 'p', wordId: 'w', position: 3, addedAt: t0),
      );
      expect(e.hashCode, isNot(0));
      expect(e.toString(), contains('w'));
      expect(playlistNameKey(' JLPT Ｎ５ '), 'jlpt n5');
    });

    test('CardScope', () {
      expect(CardScope.shared.key, '');
      expect(CardScope.shared.isShared, isTrue);
      expect(CardScope.shared.playlistId, isNull);
      final p = CardScope.playlist('pl-1');
      expect((p.key, p.isShared, p.playlistId), ('p:pl-1', false, 'pl-1'));
      expect(CardScope.fromKey('p:pl-1'), p);
      expect(CardScope.fromKey(''), CardScope.shared);
      expect(p.hashCode, CardScope.playlist('pl-1').hashCode);
      expect(() => CardScope.fromKey('x'), throwsFormatException);
      expect(() => CardScope.fromKey('p:'), throwsFormatException);
      expect(() => CardScope.playlist(''), throwsArgumentError);
      expect(CardScope.shared.toString(), contains('shared'));
      expect(p.toString(), contains('p:pl-1'));
    });

    test('StudyPreferences and stored values', () {
      const p = StudyPreferences();
      expect(
        (p.recordMode, p.scopeMode),
        (RecordMode.shared, StudyScopeMode.allOrPlaylist),
      );
      expect(p, const StudyPreferences());
      expect(p.hashCode, const StudyPreferences().hashCode);
      final per = p.copyWith(recordMode: RecordMode.perPlaylist);
      expect(per, isNot(p));
      expect(per.copyWith(), per);
      expect(
        p.copyWith(scopeMode: StudyScopeMode.playlistOnly).scopeMode,
        StudyScopeMode.playlistOnly,
      );
      expect(per.toString(), contains('perPlaylist'));
      for (final m in RecordMode.values) {
        expect(RecordMode.fromStored(m.storedAs), m);
      }
      for (final m in StudyScopeMode.values) {
        expect(StudyScopeMode.fromStored(m.storedAs), m);
      }
      expect(RecordMode.fromStored('later'), isNull);
      expect(StudyScopeMode.fromStored(''), isNull);
      expect(
        [for (final m in RecordMode.values) m.storedAs],
        ['shared', 'per_playlist'],
      );
      expect(
        [for (final m in StudyScopeMode.values) m.storedAs],
        ['all_or_playlist', 'playlist_only'],
      );
    });

    test('PageImage, EntryIssue, Example', () {
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
      expect(c.scope, CardScope.shared);
      final other = ReviewCard(
        wordId: 'w',
        level: 2,
        dueAt: t0,
        lastReviewedAt: t0,
        scope: CardScope.playlist('p'),
      );
      expect(other, isNot(c));
      expect(other.copyWith(level: 3).scope, CardScope.playlist('p'));
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
      await speech.speak(const WordSpeech(headword: '川', reading: 'かわ'));
      await speech.stop();
    });

    test('a word without accent data is estimated', () {
      const plain = WordSpeech(headword: '波', reading: 'なみ');
      const known = WordSpeech(headword: '波', reading: 'なみ', accents: [2]);
      expect(plain.isEstimated, isTrue);
      expect(known.isEstimated, isFalse);
      expect(
        known,
        const WordSpeech(headword: '波', reading: 'なみ', accents: [2]),
      );
      expect(
        const SentenceSpeech(text: '波が高い。', word: known),
        const SentenceSpeech(text: '波が高い。', word: known),
      );
      expect(
        const SpeechFailure('소리를 만들지 못했어요').toString(),
        contains('소리를 만들지 못했어요'),
      );
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
