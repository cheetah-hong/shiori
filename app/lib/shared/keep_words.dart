import 'package:flutter/widgets.dart';

/// [text] with a word joiner (U+2060) between the letters of each word, so a
/// line breaks only at a space or a line break. Korean otherwise breaks
/// between any two syllables (「한국어 뜻 사\n전」). The joiner goes between
/// whole characters as the reader sees them (grapheme clusters), never
/// inside one: an emoji with its variation selector or a ZWJ family stays
/// whole.
String keepWords(String text) {
  final letters = text.characters.toList();
  final out = StringBuffer();
  for (var i = 0; i < letters.length; i++) {
    out.write(letters[i]);
    if (i + 1 < letters.length &&
        !_isBreak(letters[i]) &&
        !_isBreak(letters[i + 1])) {
      out.write(_wordJoiner);
    }
  }
  return out.toString();
}

const String _wordJoiner = '\u2060';

bool _isBreak(String letter) => letter == ' ' || letter == '\n';

/// A heading that wraps between words only. It is found, copied and read
/// aloud as [data] (the joiners are only in what is laid out).
class KeepWordsText extends StatelessWidget {
  const KeepWordsText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => Text.rich(
    _KeepWordsSpan(data),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
  );
}

class _KeepWordsSpan extends TextSpan {
  _KeepWordsSpan(this.plain)
    : super(text: keepWords(plain), semanticsLabel: plain);

  final String plain;

  @override
  String toPlainText({
    bool includeSemanticsLabels = true,
    bool includePlaceholders = true,
  }) => plain;
}
