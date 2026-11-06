/// Meanings as the Android channel reads them, set right before pairing:
/// a POS badge glued to the meaning (`명사진`) and a full stop after a short
/// meaning (`기다리다.`) that makes it look like a sentence.
library;

import 'package:shiori_core/src/capture/text/word_list_marks.dart';
import 'package:shiori_core/src/extract/fragment.dart';

/// [fragments] with every glued badge syllable settled: [named] tells
/// whether some headword near the Korean fragment has a content signal
/// (Korean reading of its kanji, the Korean gloss) for a text. The badge
/// goes when the content names the rest and not the whole text (`명사진` →
/// `사진`); else the text stays as printed (`명함`, `동전`).
List<Fragment> settleGluedBadges(
  List<Fragment> fragments, {
  required bool Function(Fragment korean, String text) named,
}) => [
  for (final f in fragments)
    if (f.gluedBadge case final badge?)
      _dropsBadge(f, badge, named)
          ? f.copyWith(
              text: f.text.substring(badge.length),
              posBadge: posBadges[badge],
              gluedBadge: null,
              corrected: true,
            )
          : f.copyWith(gluedBadge: null)
    else
      f,
];

bool _dropsBadge(
  Fragment f,
  String badge,
  bool Function(Fragment korean, String text) named,
) {
  final rest = f.text.substring(badge.length);
  return rest.isNotEmpty && named(f, rest) && !named(f, f.text);
}

/// [text] (a Korean "sentence" by its full stop) is short dictionary-form
/// predicates between full stops or commas (`기다리다.`, `잠자코 있다. 말을
/// 하지 않다.`): each part three words at most, ending in 다, not polite
/// (`…니다`), past or future (ㅆ before 다, but 있다), or the plain present
/// (ㄴ before 다: `간다`, `먹는다`).
bool isShortPredicate(String text) {
  final t = text.trim();
  if (!t.endsWith('.') || t.contains(RegExp('[?!？！]'))) return false;
  final parts = [
    for (final p in t.split(RegExp('[.,，]')))
      if (p.trim().isNotEmpty) p.trim(),
  ];
  return parts.isNotEmpty && parts.every(_predicate);
}

final RegExp _shortKorean = RegExp(r'^[가-힣]+(?: [가-힣]+){0,2}$');

bool _predicate(String part) {
  if (!_shortKorean.hasMatch(part) || !part.endsWith('다')) return false;
  final runes = part.runes.toList();
  if (runes.length < 2) return false;
  final before = runes[runes.length - 2];
  if (before == 0xB2C8) return false; // 니
  if (before == 0xC788) return true; // 있
  final coda = (before - 0xAC00) % 28;
  return coda != _ssang && coda != _nieun;
}

/// Final consonant indexes of Hangul syllables: ㄴ, ㅆ.
const int _nieun = 4;
const int _ssang = 20;

/// The meaning of a short predicate "sentence": its full stops become
/// commas, the last one goes (`일어나다. 잠이 깨다.` → `일어나다, 잠이 깨다`).
String predicateMeaning(String text) => text
    .trim()
    .replaceAll(RegExp(r'\.+$'), '')
    .replaceAll(RegExp(r'\s*\.\s*'), ', ');
