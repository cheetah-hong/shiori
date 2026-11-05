/// Block slot (optional): reads Japanese aloud.
///
/// First block: [SilentSpeech] (the card hides the speaker button).
/// Next: flutter_tts, then cloud voices with a cache.
abstract interface class Speech {
  bool get isAvailable;

  Future<void> speak(String text, {String language = 'ja-JP'});
}

final class SilentSpeech implements Speech {
  const SilentSpeech();

  @override
  bool get isAvailable => false;

  @override
  Future<void> speak(String text, {String language = 'ja-JP'}) async {}
}
