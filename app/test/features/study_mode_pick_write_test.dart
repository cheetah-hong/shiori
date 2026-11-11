// A multiple-choice pick and its write: 다음 waits until the answer is
// stored, and a pick that failed to be stored is not shown again once the
// session starts over. Made-up words.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/voicevox_block.dart';

import '../support/harness.dart';
import '../support/study_modes.dart';

/// The test blocks' review store, with the press log held back ([gate]) or
/// failing ([fail]) on demand.
final class _HeldLog implements ReviewRepository {
  _HeldLog(this._inner);

  final ReviewRepository _inner;
  Completer<void>? gate;
  bool fail = false;

  @override
  Future<void> addLog(ReviewLog log) async {
    await gate?.future;
    if (fail) throw StateError('disk full');
    await _inner.addLog(log);
  }

  @override
  Future<ReviewCard?> card(
    String wordId, {
    CardScope scope = CardScope.shared,
    StudyMode mode = StudyMode.meaning,
  }) => _inner.card(wordId, scope: scope, mode: mode);

  @override
  Future<Map<String, ReviewCard>> cards({
    Iterable<String>? wordIds,
    CardScope scope = CardScope.shared,
    StudyMode mode = StudyMode.meaning,
  }) => _inner.cards(wordIds: wordIds, scope: scope, mode: mode);

  @override
  Future<void> saveCard(ReviewCard card) => _inner.saveCard(card);

  @override
  Future<List<ReviewCard>> deleteCards(
    Iterable<String> wordIds, {
    CardScope scope = CardScope.shared,
    StudyMode mode = StudyMode.meaning,
  }) => _inner.deleteCards(wordIds, scope: scope, mode: mode);

  @override
  Future<int> deleteAllCards({CardScope? scope, StudyMode? mode}) =>
      _inner.deleteAllCards(scope: scope, mode: mode);

  @override
  Future<List<ReviewLog>> logs({
    DateTime? since,
    CardScope? scope,
    StudyMode? mode,
  }) => _inner.logs(since: since, scope: scope, mode: mode);

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _inner.transaction(action);
}

void main() {
  /// Today's 객관식 study over [held].
  Future<List<Word>> open(
    WidgetTester tester,
    _HeldLog Function(TestBlocks) held,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final words = await seedModeWords(blocks);
    await blocks.preferences.save(
      const StudyPreferences(mode: StudyMode.choice),
    );
    final reviews = held(blocks);
    // The test blocks' own review store is the third override; it is
    // replaced by the held one.
    final overrides = [
      for (final (i, o) in blocks.overrides.indexed)
        if (i != 2) o,
      reviewRepositoryProvider.overrideWithValue(reviews),
      speechProvider.overrideWithValue(RecordingSpeech()),
      accentTableProvider.overrideWith((ref) async => AccentTable.empty),
    ];
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const ShioriApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('오늘 학습 시작'));
    await tester.pumpAndSettle();
    return words;
  }

  FilledButton next(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(of: find.text('다음'), matching: find.byType(FilledButton)),
  );

  testWidgets('다음 is off until the pick is stored', (tester) async {
    late _HeldLog held;
    final words = await open(
      tester,
      (b) => held = _HeldLog(b.reviews)..gate = Completer<void>(),
    );

    await tester.tap(find.byKey(ValueKey('option-${words[0].id}')));
    await tester.pump();
    expect(find.text('맞았어요'), findsOneWidget);
    expect(next(tester).onPressed, isNull);

    held.gate!.complete();
    await tester.pumpAndSettle();
    expect(next(tester).onPressed, isNotNull);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('語二'), findsOneWidget);
  });

  testWidgets('a pick not stored is gone after 다시 시작', (tester) async {
    late _HeldLog held;
    final words = await open(
      tester,
      (b) => held = _HeldLog(b.reviews)..fail = true,
    );

    await tester.tap(find.byKey(ValueKey('option-${words[0].id}')));
    await tester.pumpAndSettle();
    expect(find.text('학습을 이어 가지 못했어요'), findsOneWidget);

    held.fail = false;
    await tester.tap(find.text('다시 시작'));
    await tester.pumpAndSettle();
    expect(find.text('맞았어요'), findsNothing);
    expect(find.text('語一'), findsOneWidget);
    expect(find.byKey(ValueKey('option-${words[0].id}')), findsOneWidget);
  });
}
