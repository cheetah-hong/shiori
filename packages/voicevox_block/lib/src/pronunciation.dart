import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/src/morae.dart';

const _oRow = 'オコゴソゾトドノホボポモヨョロヲォ';
const _eRow = 'エケゲセゼテデネヘベペメレェ';
const _vowelOf = {
  'a': 'アカガサザタダナハバパマヤャラワァ',
  'i': 'イキギシジチヂニヒビピミリィ',
  'u': 'ウクグスズツヅヌフブプムユュルゥヴ',
  'e': _eRow,
  'o': _oRow,
};
const _vowelKana = {'a': 'ア', 'i': 'イ', 'u': 'ウ', 'e': 'エ', 'o': 'オ'};

/// A reading (hiragana or katakana) as the katakana morae it is said with:
/// おう/こう… → オオ/コオ, えい/けい… → エエ/ケエ, ー → the vowel before it.
/// A verb keeps its final う (思う → オモウ). Returns null when the reading
/// has something that is not kana.
List<String>? pronunciationMorae(String reading, {PartOfSpeech? pos}) {
  final kata = toKatakana(reading);
  if (kata.isEmpty || !kata.runes.every(_isKatakana)) return null;
  final morae = splitMorae(kata);
  final out = <String>[];
  for (final (i, m) in morae.indexed) {
    final prev = out.isEmpty ? null : _vowel(out.last);
    final isLast = i == morae.length - 1;
    out.add(switch (m) {
      'ー' when prev != null => _vowelKana[prev]!,
      'ウ' when prev == 'o' && !(isLast && pos == PartOfSpeech.verb) => 'オ',
      'イ' when prev == 'e' => 'エ',
      _ => m,
    });
  }
  return List.unmodifiable(out);
}

/// VOICEVOX kana for one accent phrase: an apostrophe after the accented
/// mora; a flat word (0) puts it after the last mora.
String aquesTalkKana(List<String> morae, int accent) {
  if (morae.isEmpty) throw ArgumentError.value(morae, 'morae', 'is empty');
  if (accent < 0 || accent > morae.length) {
    throw ArgumentError.value(accent, 'accent', 'outside 0…${morae.length}');
  }
  final at = accent == 0 ? morae.length : accent;
  return "${morae.take(at).join()}'${morae.skip(at).join()}";
}

bool _isKatakana(int c) => (c >= 0x30A1 && c <= 0x30F6) || c == 0x30FC;

/// The vowel a mora ends in (`キョ` → o), null for ン, ッ and ー.
String? _vowel(String mora) {
  final last = mora.substring(mora.length - 1);
  for (final MapEntry(:key, :value) in _vowelOf.entries) {
    if (value.contains(last)) return key;
  }
  return null;
}
