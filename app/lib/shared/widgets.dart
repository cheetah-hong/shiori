import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/shared/keep_words.dart';
import 'package:shiori_core/shiori_core.dart';

/// A section heading on the page, as 홈's 「재생목록」: bold ink, more room
/// above it than below. [trailing] is a quiet action or a count.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.xs),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: KeepWordsText(
                text,
                style: TextStyle(
                  color: t.text,
                  fontSize: TypeScale.title,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A rounded pill label (badges such as `새 단어`, `개발용`).
class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: foreground),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: TypeScale.caption,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The textbook's square POS badge: `[명]`.
class PosBadge extends StatelessWidget {
  const PosBadge(this.pos, {super.key, this.missing = false});

  final PartOfSpeech? pos;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Missing: a cell to check (the check color), not a wrong one.
    final color = missing ? t.warn : t.text2;
    return Semantics(
      label: pos?.label ?? '품사 없음',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.2),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            pos?.badge ?? '?',
            style: TextStyle(
              color: color,
              fontSize: TypeScale.caption,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}

/// Four-step memory meter: square cells, ink for each level reached and an
/// outline for the rest (all outlines = new word); the accent's green once
/// in long-term memory.
class MemoryMeter extends StatelessWidget {
  const MemoryMeter({super.key, required this.level, this.max = 4});

  final int level;
  final int max;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: level == 0
          ? '새 단어'
          : '기억 $level단계${level >= max ? ', 장기 기억' : ''}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= max; i++)
            Container(
              width: _cellWidth,
              height: _cellHeight,
              margin: const EdgeInsets.only(left: _cellGap),
              decoration: BoxDecoration(
                color: i <= level
                    ? (level >= max ? t.ok : t.text)
                    : Colors.transparent,
                border: i <= level
                    ? null
                    : Border.all(color: t.outline, width: _cellEdge),
              ),
            ),
        ],
      ),
    );
  }
}

const double _cellWidth = 7;
const double _cellHeight = 14;
const double _cellGap = 2;
const double _cellEdge = 1.2;

/// Shrinks slightly while pressed: a press state that moves only `transform`.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (widget.enabled && v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: Motion.of(context, Motion.press),
        curve: Motion.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A Japanese sentence with [focus] marked by the highlighter, like a learner's
/// own textbook. Conjugated forms are matched by the kanji stem
/// (`揺れる` → `揺`).
class HighlightedSentence extends StatelessWidget {
  const HighlightedSentence({
    super.key,
    required this.sentence,
    required this.focus,
    required this.style,
    this.textAlign = TextAlign.center,
  });

  final String sentence;
  final String focus;
  final TextStyle style;
  final TextAlign textAlign;

  /// The kanji stem of a conjugating word (`揺れる` → `揺`). Kana-only words
  /// are returned whole: cutting them would mark any matching kana.
  static String stemOf(String headword) {
    final runes = headword.runes.toList();
    if (!runes.any(_isKanji)) return headword;
    var end = runes.length;
    while (end > 1 && _isKana(runes[end - 1])) {
      end--;
    }
    return String.fromCharCodes(runes.take(end));
  }

  static bool _isKana(int c) => c >= 0x3040 && c <= 0x30FF;
  static bool _isKanji(int c) => (c >= 0x4E00 && c <= 0x9FFF) || c == 0x3005;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    var key = focus.isEmpty
        ? ''
        : (sentence.contains(focus) ? focus : stemOf(focus));
    if (key.isNotEmpty && !sentence.contains(key)) key = '';
    if (key.isEmpty) {
      return JpText(sentence, style: style, textAlign: textAlign);
    }

    final start = sentence.indexOf(key);
    final mark = style.copyWith(
      background: Paint()..color = t.accentTint,
      color: t.text,
      fontWeight: FontWeight.w600,
    );
    return Text.rich(
      TextSpan(
        style: style,
        locale: JpType.locale,
        children: [
          TextSpan(text: sentence.substring(0, start)),
          TextSpan(text: key, style: mark),
          TextSpan(text: sentence.substring(start + key.length)),
        ],
      ),
      textAlign: textAlign,
    );
  }
}

/// Book spine used as a textbook "cover" in lists.
class BookSpine extends StatelessWidget {
  const BookSpine({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 38,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.accentTint,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(3),
          right: Radius.circular(6),
        ),
      ),
      child: JpText(
        label,
        style: JpType.headword(
          TypeScale.body2,
          t.accentText,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Japanese text: [JpType] styles carry the `ja` locale for glyph forms,
/// and this puts it on the text itself so VoiceOver reads it in Japanese.
class JpText extends StatelessWidget {
  const JpText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(text: data, locale: JpType.locale),
    style: style,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
  );
}
