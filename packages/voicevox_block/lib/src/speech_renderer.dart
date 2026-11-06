import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/src/accent_phrase.dart';
import 'package:voicevox_block/src/pronunciation.dart';
import 'package:voicevox_block/src/speech_cache.dart';
import 'package:voicevox_block/src/speech_plan.dart';
import 'package:voicevox_block/src/voicevox_ops.dart';

/// Makes the sound of a request with [ops], or takes it from [cache].
final class SpeechRenderer {
  SpeechRenderer({required this.ops, required this.cache});

  final VoicevoxOps ops;
  final SpeechCache cache;

  /// Sounds being made, by cache key: a second request for the same sound
  /// waits for the first instead of making it again.
  final _making = <String, Future<File>>{};

  /// The cache key of [request]: sha256 of the voice and the plan.
  String keyOf(SpeechRequest request) => sha256
      .convert(utf8.encode('${ops.voiceId}\n${planSpeech(request).key}'))
      .toString();

  /// The WAV file of [request]: from the cache, or made ([planSpeech]) and
  /// stored. Throws what the engine or the cache throws.
  Future<File> render(SpeechRequest request) {
    final key = keyOf(request);
    // The callback must not return the removed future: whenComplete would
    // wait for it, and it is this very future.
    return _making[key] ??= _render(key, request).whenComplete(() {
      _making.remove(key);
    });
  }

  Future<File> _render(String key, SpeechRequest request) async {
    final cached = await cache.lookup(key);
    if (cached != null) return cached;
    final phrases = await _phrasesOf(planSpeech(request));
    return cache.store(key, await ops.synthesize(phrases));
  }

  /// The accent the engine gives [word] (0 = flat). The word is read with
  /// が after it, so that a flat word and one falling after its last mora
  /// differ: the written form first, then the reading when the form is read
  /// with other sounds. Null when neither has the expected sounds, or they
  /// come in more than one phrase.
  Future<int?> estimateAccent(WordSpeech word) async {
    final morae = pronunciationMorae(word.reading, pos: word.pos);
    if (morae == null) return null;
    final expected = [...morae, 'ガ'].join();
    final plain = WordSpeech(headword: word.headword, reading: word.reading);
    final plan = planSpeech(plain);
    final texts = plan is EstimatePlan ? plan.texts : [word.headword];
    for (final text in texts) {
      final phrases = await ops.phrasesFromText('$textが');
      // Read otherwise (another reading): try the next text.
      if (phrases.expand((p) => p.moraTexts).join() != expected) continue;
      // Read as expected but in more than one phrase: no single accent.
      if (phrases.length != 1) return null;
      final p = phrases.single;
      return p.accent >= p.moraTexts.length ? 0 : p.accent;
    }
    return null;
  }

  Future<List<AccentPhrase>> _phrasesOf(SpeechPlan plan) async {
    switch (plan) {
      case KanaPlan(:final kana):
        return ops.phrasesFromKana(kana);
      case EstimatePlan(:final texts, :final expectedMorae):
        List<AccentPhrase>? last;
        for (final text in texts) {
          last = await ops.phrasesFromText(text);
          final said = last.expand((p) => p.moraTexts).join();
          if (said == expectedMorae.join()) return last;
        }
        return last ?? const [];
      case SentencePlan(:final text, :final fixMorae, :final fixAccent):
        final phrases = await ops.phrasesFromText(text);
        if (fixMorae == null || fixAccent == null) return phrases;
        final at = phrases.indexWhere(
          (p) => _startsWith(p.moraTexts, fixMorae),
        );
        if (at < 0) return phrases;
        final p = phrases[at];
        final accent = fixAccent == 0 ? p.moraTexts.length : fixAccent;
        return ops.replaceMoraPitch([
          for (final (i, q) in phrases.indexed)
            i == at ? p.withAccent(accent) : q,
        ]);
    }
  }

  static bool _startsWith(List<String> morae, List<String> prefix) {
    if (morae.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (morae[i] != prefix[i]) return false;
    }
    return true;
  }
}
