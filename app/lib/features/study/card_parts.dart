import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/shared/sheet.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

// Parts shared by the study cards of every mode.

/// The example sentence; when [onSpeak] is given, tapping its text reads it
/// aloud (as its speaker button does).
class ExampleSentence extends StatelessWidget {
  const ExampleSentence({
    super.key = const ValueKey('example-ja'),
    required this.sentence,
    required this.focus,
    required this.style,
    this.onSpeak,
    this.textAlign = TextAlign.center,
  });

  final String sentence;
  final String focus;
  final TextStyle style;
  final TextAlign textAlign;

  /// Reads the sentence; null: the text takes no taps.
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final text = HighlightedSentence(
      sentence: sentence,
      focus: focus,
      style: style,
      textAlign: textAlign,
    );
    final speak = onSpeak;
    if (speak == null) return text;
    return Semantics(
      button: true,
      hint: '예문 듣기',
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.chip),
        onTap: speak,
        child: text,
      ),
    );
  }
}

/// Keeps the space while hidden (no layout jump) and fades the content in.
/// Hidden, the space is an empty ruled line with a small 「[label] 가림」, a
/// blank in a notebook; tapping it does what the reveal button does (which
/// alone is read and counted as a button, so the line is not).
class CoveredPart extends StatelessWidget {
  const CoveredPart({
    super.key,
    required this.visible,
    required this.label,
    required this.child,
    this.onReveal,
  });

  final bool visible;
  final String label;
  final Widget child;

  /// The reveal button's action; null: the line takes no taps.
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // The line runs across the sheet, open or not, so nothing moves.
      constraints: const BoxConstraints(minWidth: double.infinity),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: Motion.of(context, Motion.ui),
            child: ExcludeSemantics(
              excluding: !visible,
              // Opened by a reveal button: VoiceOver reads what appeared.
              child: Semantics(liveRegion: visible, child: child),
            ),
          ),
          if (!visible)
            Positioned.fill(
              child: _BlankLine(label: label, onTap: onReveal),
            ),
        ],
      ),
    );
  }
}

/// The hairline-ruled blank of a covered part, its label small at the left.
class _BlankLine extends StatelessWidget {
  const _BlankLine({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.line)),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '$label 가림',
                style: TextStyle(
                  color: t.text3,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RevealButton extends StatelessWidget {
  const RevealButton({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: on ? '$label 가리기' : '$label 보기',
      child: ExcludeSemantics(
        child: Material(
          // A light fill: the sheet under it is bg.
          color: on ? t.surfaceStrong : t.surface,
          borderRadius: BorderRadius.circular(Radii.button),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.button),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.sm,
                  vertical: Space.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      on
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: t.text2,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        on ? '$label 가리기' : '$label 보기',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: t.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A speaker button; while the sound is being made it shows progress, says
/// 「불러오는 중」 and takes no taps.
class SpeakButton extends StatelessWidget {
  const SpeakButton({
    super.key,
    required this.tooltip,
    required this.loading,
    required this.onPressed,
    this.small = false,
  });

  final String tooltip;
  final bool loading;
  final VoidCallback onPressed;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final icon = loading
        ? SizedBox.square(
            dimension: small ? 16 : 20,
            child: const CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(Icons.volume_up_outlined, size: small ? 20 : null);
    final pressed = loading ? null : onPressed;
    final label = loading ? '불러오는 중' : tooltip;
    return small
        ? IconButton(tooltip: label, onPressed: pressed, icon: icon)
        : IconButton.filledTonal(
            tooltip: label,
            onPressed: pressed,
            icon: icon,
          );
  }
}

/// The sheet every study card sits on: a page of the tear-off calendar, as
/// on 홈 ([SheetFrame]), with the card's tag (새 단어, 복습 · n단계, 다시 n)
/// as a small line under the binding strip.
class CardFrame extends StatelessWidget {
  const CardFrame({super.key, required this.item, required this.children});

  final SessionItem item;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (tag, tagColor) = switch (item) {
      SessionItem(retries: > 0) => ('다시 ${item.retries}', t.text),
      SessionItem(isNew: true) => ('새 단어', t.accentText),
      _ => ('복습 · ${item.before?.level ?? 0}단계', t.text2),
    };
    return SheetFrame(
      fill: true,
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.sm,
        Space.lg,
        Space.md,
      ),
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              tag,
              style: TextStyle(
                color: tagColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// A space that holds [label] 가림 until the learner opens it (the content
/// is not built at all, so nothing of it can be read early).
class HiddenPart extends StatelessWidget {
  const HiddenPart({super.key, required this.label, this.onReveal});

  final String label;

  /// The reveal button's action, for a tap on the blank line.
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) => CoveredPart(
    visible: false,
    label: label,
    onReveal: onReveal,
    child: const SizedBox(height: _blankHeight),
  );
}

const double _blankHeight = 28;

/// Headword size by length: one size for the printed word in every mode.
double headwordSize(String headword) {
  final n = headword.runes.length;
  if (n <= 3) return 60;
  if (n <= 5) return 48;
  return 36;
}

/// Runs a card's speaker: loading while the sound is made, a message when it
/// cannot be played (the card itself keeps working).
mixin CardSpeech<T extends StatefulWidget> on State<T> {
  Future<void> speakWith(
    Future<void> Function() play,
    void Function(bool loading) setLoading,
  ) async {
    setState(() => setLoading(true));
    try {
      await play();
    } on SpeechFailure catch (failure) {
      _tell(failure.message);
    } on Object {
      _tell('소리를 재생하지 못했어요');
    } finally {
      if (mounted) setState(() => setLoading(false));
    }
  }

  void _tell(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
