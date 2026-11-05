/// Textbook spellings that differ from the dictionary's headword.
library;

import 'package:dict_jmdict/src/kana.dart';

/// Whether [a] and [b] are the same word with different okurigana
/// (締切 ~ 締め切り, 終る ~ 終わる), given that both are spellings of the
/// same reading. On its own the shape test also accepts different words
/// (見る ~ 見せる), so callers must compare readings first, as
/// `JmdictDictionary.checkPair` does.
///
/// Both must have the same kanji in the same order and the same leading kana
/// (お, ご belong to the word). After each kanji, the shorter kana run must be
/// the end of the longer one, and the extra kana must be hiragana. A changed
/// kana (待ち合わせろ vs 待ち合わせる) is not a variant.
bool isOkuriganaVariant(String a, String b) {
  if (a == b) return false;
  final x = _split(a);
  final y = _split(b);
  if (x.kanji.isEmpty || x.kanji != y.kanji || x.kana.first != y.kana.first) {
    return false;
  }
  for (var i = 1; i < x.kana.length; i++) {
    final (short, long) = x.kana[i].length <= y.kana[i].length
        ? (x.kana[i], y.kana[i])
        : (y.kana[i], x.kana[i]);
    if (!long.endsWith(short)) return false;
    final extra = long.substring(0, long.length - short.length);
    if (!extra.runes.every(isHiragana)) return false;
  }
  return true;
}

/// Kanji in order, and the kana runs around them (`kana.length == kanji.length + 1`).
({String kanji, List<String> kana}) _split(String s) {
  final kanji = StringBuffer();
  final kana = <String>[];
  var run = StringBuffer();
  for (final r in s.runes) {
    if (isKanji(r)) {
      kanji.writeCharCode(r);
      kana.add(run.toString());
      run = StringBuffer();
    } else {
      run.writeCharCode(r);
    }
  }
  kana.add(run.toString());
  return (kanji: kanji.toString(), kana: kana);
}

final _tilde = RegExp('[〜～~]');
final _optional = RegExp(r'[（(][^）)]*[）)]');
const _endings = ['する', 'な', 'だ'];

/// The だ printed after a な-adjective (静かだ) ends a word only after kanji:
/// kana words such as ただ and まだ end in だ themselves.
const _kanjiOnlyEndings = {'だ'};

enum _Ending { none, written, optional }

/// How [s] ends in [ending]: written out (勉強する), in parentheses
/// (勉強(する)), or not at all.
_Ending _endingOf(String s, String ending) {
  if (s.endsWith('($ending)') || s.endsWith('（$ending）')) {
    return _Ending.optional;
  }
  return s.length > ending.length && s.endsWith(ending)
      ? _Ending.written
      : _Ending.none;
}

String _cut(String s, String ending, _Ending how) => switch (how) {
  _Ending.none => s,
  _Ending.written => s.substring(0, s.length - ending.length),
  _Ending.optional => s.substring(0, s.length - ending.length - 2),
};

/// The pair without 〜 marks, parenthesised parts and a する / な / だ ending
/// (勉強する【べんきょうする】 → 勉強【べんきょう】, 静か(な)【しずかな】 →
/// 静か【しずか】, 静かだ【しずかだ】 → 静か【しずか】), or null when nothing
/// was removed. An empty [reading] stays empty (kana words).
///
/// The ending is removed when the headword has it and the reading has it
/// too (written or in parentheses), the reading is empty, or the headword
/// marks it optional. Endings are checked before other parentheses are
/// dropped, so 静か(な) still counts as ending in な. だ is removed only
/// from a headword with kanji.
(String, String)? stripAffixes(String headword, String reading) {
  var h = headword.replaceAll(_tilde, '').trim();
  var r = reading.replaceAll(_tilde, '').trim();
  for (final ending in _endings) {
    if (_kanjiOnlyEndings.contains(ending) && !hasKanji(h)) continue;
    final inHead = _endingOf(h, ending);
    final inReading = _endingOf(r, ending);
    final strip = switch (inHead) {
      _Ending.none => false,
      _Ending.optional => true,
      _Ending.written => r.isEmpty || inReading != _Ending.none,
    };
    if (strip) {
      h = _cut(h, ending, inHead);
      r = _cut(r, ending, inReading);
      break;
    }
  }
  h = h.replaceAll(_optional, '').trim();
  r = r.replaceAll(_optional, '').trim();
  if (h.isEmpty || (h == headword && r == reading)) return null;
  return (h, r);
}
