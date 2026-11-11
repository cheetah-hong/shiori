import 'dart:convert';
import 'dart:math';

import 'package:shiori_core/src/models/library.dart';

/// One multiple-choice question: [answer]'s meaning among [options] (the
/// answer is one of them, at [answerIndex]).
final class MultipleChoice {
  const MultipleChoice({required this.answer, required this.options});

  final Word answer;

  /// Words whose meanings are shown, in the order shown.
  final List<Word> options;

  int get answerIndex => options.indexWhere((w) => w.id == answer.id);
}

/// Picks the wrong options of a multiple-choice question (객관식) out of the
/// learner's own words: never one whose meaning is the answer's or overlaps
/// it (or another option's), words of the answer's part of speech first,
/// shuffled by a seed so the same seed gives the same question.
final class ChoiceMaker {
  const ChoiceMaker();

  /// Options per question: the answer and three wrong ones.
  static const int optionCount = 4;

  /// A question for [answer], or null when the answer has no meaning or
  /// [pool] has fewer than three words that can be wrong options (a question
  /// always has [optionCount] options). [pool] may hold [answer]; its order
  /// does not matter.
  MultipleChoice? make({
    required Word answer,
    required List<Word> pool,
    required int seed,
  }) {
    final answerGlosses = meaningGlosses(answer.meaning);
    if (answerGlosses.isEmpty) return null;
    final random = Random(seed);
    final (same, other) = _candidates(answer, answerGlosses, pool);
    var wrong = _apart(
      [...List.of(same)..shuffle(random), ...List.of(other)..shuffle(random)],
      taken: answerGlosses,
      limit: optionCount - 1,
    );
    // A shuffled pick can block itself (one word overlapping two others);
    // the fixed order then decides, as [canAskFor] does.
    if (wrong.length < optionCount - 1) {
      wrong = _apart(
        [...same, ...other],
        taken: answerGlosses,
        limit: optionCount - 1,
      );
    }
    if (wrong.length < optionCount - 1) return null;
    return MultipleChoice(
      answer: answer,
      options: List.unmodifiable([answer, ...wrong]..shuffle(random)),
    );
  }

  /// Whether a question can be made for [answer] out of [pool], whatever
  /// the seed.
  bool canAskFor(Word answer, List<Word> pool) =>
      askable([answer], pool).isNotEmpty;

  /// The ids of [answers] a question can be made for out of [pool] (as
  /// [canAskFor], reading the pool once).
  Set<String> askable(List<Word> answers, List<Word> pool) {
    final prepared = _withGlosses(pool);
    return {
      for (final answer in answers)
        if (_canAsk(answer, prepared)) answer.id,
    };
  }

  static bool _canAsk(Word answer, List<_Candidate> prepared) {
    final answerGlosses = meaningGlosses(answer.meaning);
    if (answerGlosses.isEmpty) return false;
    final (same, other) = _split(answer, answerGlosses, prepared);
    final wrong = _apart(
      [...same, ...other],
      taken: answerGlosses,
      limit: optionCount - 1,
    );
    return wrong.length == optionCount - 1;
  }

  /// The words of [pool] that can be wrong options for [answer], in id
  /// order: those of the answer's part of speech, then the others.
  static (List<_Candidate>, List<_Candidate>) _candidates(
    Word answer,
    Set<String> answerGlosses,
    List<Word> pool,
  ) => _split(answer, answerGlosses, _withGlosses(pool));

  static (List<_Candidate>, List<_Candidate>) _split(
    Word answer,
    Set<String> answerGlosses,
    List<_Candidate> prepared,
  ) {
    final candidates = [
      for (final c in prepared)
        if (c.word.id != answer.id && c.glosses.every(_notIn(answerGlosses))) c,
    ];
    bool samePos(_Candidate c) =>
        answer.pos != null && c.word.pos == answer.pos;
    return (
      [
        for (final c in candidates)
          if (samePos(c)) c,
      ],
      [
        for (final c in candidates)
          if (!samePos(c)) c,
      ],
    );
  }

  /// Whether [pool] holds [optionCount] words whose meanings can stand side
  /// by side (none empty, none overlapping). Counted greedily in id order.
  bool canAsk(List<Word> pool) =>
      _apart(_withGlosses(pool), taken: const {}, limit: optionCount).length ==
      optionCount;

  /// [pool]'s words that have a meaning, once each, in id order.
  static List<_Candidate> _withGlosses(List<Word> pool) {
    final words = {for (final w in pool) w.id: w}.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return [
      for (final w in words)
        if (meaningGlosses(w.meaning) case final g when g.isNotEmpty)
          (word: w, glosses: g),
    ];
  }

  /// Up to [limit] words of [ordered], in order, whose meanings overlap
  /// neither [taken] nor each other.
  static List<Word> _apart(
    List<_Candidate> ordered, {
    required Set<String> taken,
    required int limit,
  }) {
    final used = {...taken};
    final picked = <Word>[];
    for (final c in ordered) {
      if (picked.length == limit) break;
      if (!c.glosses.every(_notIn(used))) continue;
      picked.add(c.word);
      used.addAll(c.glosses);
    }
    return picked;
  }

  static bool Function(String) _notIn(Set<String> glosses) =>
      (g) => !glosses.contains(g);
}

typedef _Candidate = ({Word word, Set<String> glosses});

/// Notes in brackets: (…), （…）, […].
final _notes = RegExp(r'\([^)]*\)|（[^）]*）|\[[^\]]*\]');

/// Marks between the meanings of a list.
final _separators = RegExp('[,，;；/／·・、]');

final _spaces = RegExp(r'\s+');

/// The parts of [meaning] that count as the same meaning: notes in brackets
/// left out, split at list marks (, ; / · 、), spaces collapsed. Two meanings
/// overlap when they share a part. Empty for an empty meaning.
Set<String> meaningGlosses(String meaning) => {
  for (final part in meaning.replaceAll(_notes, ' ').split(_separators))
    if (part.replaceAll(_spaces, ' ').trim() case final g when g.isNotEmpty) g,
};

/// A seed for one presentation of a card: FNV-1a (32 bit) of
/// `<session start in microseconds>|<word id>|<retries>` in UTF-8, so the
/// same session, word and retry count give the same seed on every run.
int choiceSeed({
  required DateTime sessionStart,
  required String wordId,
  required int retries,
}) {
  const offset = 0x811c9dc5;
  const mask = 0xffffffff;
  var hash = offset;
  final text = '${sessionStart.microsecondsSinceEpoch}|$wordId|$retries';
  for (final byte in utf8.encode(text)) {
    hash ^= byte;
    // hash * 16777619 (2^24 + 403), kept to 32 bits.
    hash = (hash * 403 + ((hash << 24) & mask)) & mask;
  }
  return hash;
}
