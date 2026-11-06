import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/src/morae.dart';
import 'package:voicevox_block/src/pronunciation.dart';

/// How a [SpeechRequest] is turned into engine input.
sealed class SpeechPlan {
  const SpeechPlan();

  /// What decides the sound (part of the cache key).
  String get key;
}

/// A word with accent data: VOICEVOX kana with the accent marked.
final class KanaPlan extends SpeechPlan {
  const KanaPlan(this.kana);

  final String kana;

  @override
  String get key => 'kana\n$kana';
}

/// A word without accent data: the engine reads [texts] in order and the
/// first one it says as [expectedMorae] is used (the written form first, then
/// the reading); when none matches, the last one.
final class EstimatePlan extends SpeechPlan {
  const EstimatePlan({required this.texts, required this.expectedMorae});

  final List<String> texts;
  final List<String> expectedMorae;

  @override
  String get key => 'estimate\n${texts.join('\n')}\n${expectedMorae.join()}';
}

/// An example sentence. When [fixMorae] is set, the first accent phrase that
/// starts with those morae gets accent [fixAccent] (the card's word).
final class SentencePlan extends SpeechPlan {
  const SentencePlan({required this.text, this.fixMorae, this.fixAccent});

  final String text;
  final List<String>? fixMorae;
  final int? fixAccent;

  @override
  String get key =>
      'sentence\n$text\n${fixMorae?.join() ?? ''}\n${fixAccent ?? ''}';
}

/// - A word with accents: [KanaPlan] of its pronunciation and first accent.
/// - A word without (or with a reading that is not kana): [EstimatePlan].
/// - A sentence: [SentencePlan], fixing the word only when it has accents and
///   the sentence has the written form followed by kana, punctuation or the
///   end (not inside a longer kanji or katakana word).
SpeechPlan planSpeech(SpeechRequest request) => switch (request) {
  WordSpeech() => _planWord(request),
  SentenceSpeech(:final text, :final word) => _planSentence(text, word),
};

SpeechPlan _planWord(WordSpeech word) {
  final morae = pronunciationMorae(word.reading, pos: word.pos);
  if (morae == null) {
    return EstimatePlan(texts: [word.headword], expectedMorae: const []);
  }
  if (word.accents.isNotEmpty && word.accents.first <= morae.length) {
    return KanaPlan(aquesTalkKana(morae, word.accents.first));
  }
  final reading = toHiragana(word.reading);
  return EstimatePlan(
    texts: [word.headword, if (reading != word.headword) reading],
    expectedMorae: morae,
  );
}

SentencePlan _planSentence(String text, WordSpeech word) {
  final morae = pronunciationMorae(word.reading, pos: word.pos);
  final accent = word.accents.firstOrNull;
  if (morae == null ||
      accent == null ||
      accent > morae.length ||
      !_standsAlone(text, word.headword)) {
    return SentencePlan(text: text);
  }
  return SentencePlan(text: text, fixMorae: morae, fixAccent: accent);
}

/// [text] has [word] not glued to the start or end of a longer kanji or
/// katakana word.
bool _standsAlone(String text, String word) {
  if (word.isEmpty) return false;
  for (var at = text.indexOf(word); at >= 0; at = text.indexOf(word, at + 1)) {
    final end = at + word.length;
    final before = at == 0 ? null : text.codeUnitAt(at - 1);
    final after = end >= text.length ? null : text.codeUnitAt(end);
    if (!_joins(before) && !_joins(after)) return true;
  }
  return false;
}

/// A kanji or katakana character: it would make the word part of a longer one.
bool _joins(int? c) =>
    c != null &&
    ((c >= 0x4E00 && c <= 0x9FFF) ||
        (c >= 0x3400 && c <= 0x4DBF) ||
        c == 0x3005 ||
        (c >= 0x30A1 && c <= 0x30FA) ||
        c == 0x30FC);
