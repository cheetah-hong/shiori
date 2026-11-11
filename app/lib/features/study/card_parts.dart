import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
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
  });

  final String sentence;
  final String focus;
  final TextStyle style;

  /// Reads the sentence; null: the text takes no taps.
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final text = HighlightedSentence(
      sentence: sentence,
      focus: focus,
      style: style,
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
class CoveredPart extends StatelessWidget {
  const CoveredPart({
    super.key,
    required this.visible,
    required this.label,
    required this.child,
  });

  final bool visible;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Motion.of(context, Motion.ui),
          child: ExcludeSemantics(excluding: !visible, child: child),
        ),
        if (!visible)
          ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: t.paper2,
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
              child: Text(
                '$label 가림',
                style: TextStyle(
                  color: t.ink3,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
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
      toggled: on,
      label: on ? '$label 가리기' : '$label 보기',
      child: ExcludeSemantics(
        child: Material(
          color: on ? t.paper3 : t.paper,
          borderRadius: BorderRadius.circular(Radii.chip),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.chip),
            onTap: onTap,
            child: SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    on
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: t.ink2,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    on ? '$label 가리기' : '$label 보기',
                    style: TextStyle(color: t.ink, fontWeight: FontWeight.w700),
                  ),
                ],
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

/// The sheet every study card sits on, with the card's badge (새 단어,
/// 복습 · n단계, 다시 n) at the top.
class CardFrame extends StatelessWidget {
  const CardFrame({super.key, required this.item, required this.children});

  final SessionItem item;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (badge, badgeBg, badgeFg) = switch (item) {
      SessionItem(retries: > 0) => ('다시 ${item.retries}', t.paper3, t.ink),
      SessionItem(isNew: true) => ('새 단어', t.marker, t.markerInk),
      _ => ('복습 · ${item.before?.level ?? 0}단계', t.paper2, t.ink),
    };
    return Container(
      decoration: BoxDecoration(
        color: t.sheet,
        borderRadius: BorderRadius.circular(Radii.wordCard),
        boxShadow: [
          BoxShadow(
            color: t.ink.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.lg,
        Space.lg,
        Space.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Pill(badge, background: badgeBg, foreground: badgeFg),
              const Spacer(),
            ],
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
  const HiddenPart({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => CoveredPart(
    visible: false,
    label: label,
    child: const SizedBox(height: 24, width: 96),
  );
}

/// Headword size by length, as on the 뜻 맞히기 card.
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
