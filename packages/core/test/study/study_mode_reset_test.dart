// 처음부터 다시 학습 and 모든 단어 처음부터 take every mode's cards: a word
// made new is new in all four ways; 되돌리기 puts each mode's card back.
// Made-up words, a fixed clock.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/library_seed.dart';

void main() {
  final start = DateTime(2026, 11, 12, 9);
  late InMemoryLibraryRepository library;
  late InMemoryReviewRepository reviews;

  StudyService serviceAt(DateTime now) => StudyService(
    library: library,
    reviews: reviews,
    scheduler: const LeitnerFourStepScheduler(),
    clock: FixedClock(now),
  );

  ReviewCard card(String id, StudyMode mode, int level) => ReviewCard(
    wordId: id,
    level: level,
    dueAt: start.add(Duration(days: level)),
    lastReviewedAt: start.subtract(const Duration(days: 1)),
    reviewCount: level,
    mode: mode,
  );

  setUp(() async {
    library = InMemoryLibraryRepository();
    reviews = InMemoryReviewRepository();
    await seedPlaylist(library, 'tb', [
      seedWord('w1', '語一', at: start, meaning: '하나'),
      seedWord('w2', '語二', at: start, meaning: '둘'),
    ], at: start);
    for (final (i, mode) in StudyMode.values.indexed) {
      await reviews.saveCard(card('w1', mode, i + 1));
    }
    await reviews.saveCard(card('w2', StudyMode.choice, 3));
    await reviews.addLog(
      ReviewLog(
        wordId: 'w1',
        answer: Answer.known,
        at: start,
        levelBefore: 0,
        levelAfter: 4,
        retriesInSession: 0,
        mode: StudyMode.recall,
      ),
    );
  });

  test('resetWords takes the word\'s cards in every mode', () async {
    final removed = await serviceAt(start).resetWords(['w1']);

    expect(removed.toSet(), {
      for (final (i, mode) in StudyMode.values.indexed) card('w1', mode, i + 1),
    });
    for (final mode in StudyMode.values) {
      expect(await reviews.card('w1', mode: mode), isNull, reason: '$mode');
    }
    expect(
      await reviews.card('w2', mode: StudyMode.choice),
      card('w2', StudyMode.choice, 3),
    );
    expect(await reviews.logs(), hasLength(1), reason: 'presses stay');
  });

  test('restoreCards puts every mode back, except one studied '
      'meanwhile', () async {
    final service = serviceAt(start);
    final removed = await service.resetWords(['w1', 'w2']);
    final fresh = card('w1', StudyMode.listening, 1).copyWith(reviewCount: 9);
    await reviews.saveCard(fresh);

    await service.restoreCards(removed);

    expect(await reviews.card('w1'), card('w1', StudyMode.meaning, 1));
    expect(
      await reviews.card('w1', mode: StudyMode.recall),
      card('w1', StudyMode.recall, 2),
    );
    expect(await reviews.card('w1', mode: StudyMode.listening), fresh);
    expect(
      await reviews.card('w1', mode: StudyMode.choice),
      card('w1', StudyMode.choice, 4),
    );
    expect(
      await reviews.card('w2', mode: StudyMode.choice),
      card('w2', StudyMode.choice, 3),
    );
  });

  test('a reset word is new again (modes that need no options)', () async {
    final service = serviceAt(start.add(const Duration(days: 30)));
    await service.resetWords(['w1']);
    for (final mode in [StudyMode.meaning, StudyMode.recall]) {
      final s = await service.startSession(mode: mode);
      expect(s.queue.first.word.id, 'w1', reason: '$mode');
      expect(s.queue.first.isNew, isTrue, reason: '$mode');
    }
  });

  test('resetAll takes every mode and counts every card', () async {
    expect(await serviceAt(start).resetAll(), 5);
    for (final mode in StudyMode.values) {
      expect(await reviews.cards(mode: mode), isEmpty, reason: '$mode');
    }
    expect(await reviews.logs(), hasLength(1));
  });

  test('studied words: those with a card in any mode', () async {
    final service = serviceAt(start);
    final byMode = await service.cardsByMode();
    final studied = {for (final cards in byMode.values) ...cards.keys};
    expect(studied, {'w1', 'w2'});
    await service.resetWords(['w2']);
    final after = await service.cardsByMode();
    expect({for (final cards in after.values) ...cards.keys}, {'w1'});
  });
}
