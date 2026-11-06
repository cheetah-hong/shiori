import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/pitch_line.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// The study card: headword and the textbook's own example up front;
/// meaning and reading stay covered until the learner opens them.
class WordCard extends StatefulWidget {
  const WordCard({
    super.key,
    required this.item,
    required this.maxLevel,
    this.onSpeakWord,
    this.onSpeakExample,
    this.pitch,
    this.estimatePitch,
  });

  final SessionItem item;
  final int maxLevel;

  /// Plays the word; null hides the button. Throws [SpeechFailure] (or
  /// anything else) when it cannot, which the card shows.
  final Future<void> Function()? onSpeakWord;

  /// Plays the example sentence; null (or no example) hides the button.
  final Future<void> Function()? onSpeakExample;

  /// The pitch line shown with the reading; null shows none.
  final PitchInfo? pitch;

  /// Asked once, when the reading is first opened, for an estimated [pitch]
  /// without an accent yet.
  final Future<int?> Function()? estimatePitch;

  @override
  State<WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> {
  bool _showMeaning = false;
  bool _showReading = false;
  bool _wordLoading = false;
  bool _exampleLoading = false;

  /// The engine's guess for an estimated pitch, once asked.
  int? _estimated;
  bool _askedEstimate = false;

  /// Runs a speaker button: loading while the sound is made, a message when
  /// it cannot be played (the card itself keeps working).
  Future<void> _speak(
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

  void _toggleReading() {
    setState(() => _showReading = !_showReading);
    final estimate = widget.estimatePitch;
    final pitch = widget.pitch;
    if (!_showReading || _askedEstimate || estimate == null) return;
    if (pitch == null || !pitch.estimated || pitch.accent != null) return;
    _askedEstimate = true;
    estimate().then((accent) {
      if (mounted) setState(() => _estimated = accent);
    }, onError: (Object _) {});
  }

  PitchInfo? get _pitch => switch (widget.pitch) {
    final PitchInfo p when p.accent == null && _estimated != null =>
      p.withAccent(_estimated),
    final p => p,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final item = widget.item;
    final w = item.word;

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
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Covered(
                      visible: _showReading,
                      label: '읽기',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            readingsLabel(w.readings),
                            style: JpType.gothic(17, t.ink3, height: 1.3),
                          ),
                          if (_pitch case final pitch?) ...[
                            const SizedBox(height: Space.xs),
                            PitchLine(info: pitch),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Semantics(
                      label: w.headword,
                      child: Text(
                        w.headword,
                        style: JpType.print(
                          _headSize(w.headword),
                          t.ink,
                          weight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    _Covered(
                      visible: _showMeaning,
                      label: '뜻',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (w.pos != null) ...[
                            PosBadge(w.pos),
                            const SizedBox(width: Space.sm),
                          ],
                          Flexible(
                            child: Text(
                              w.meaning,
                              style: context.text.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (w.example case final ex?) ...[
                      const SizedBox(height: Space.xl),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: HighlightedSentence(
                              sentence: ex.ja,
                              focus: w.headword,
                              style: JpType.gothic(15, t.ink2, height: 1.75),
                            ),
                          ),
                          if (widget.onSpeakExample case final play?) ...[
                            const SizedBox(width: Space.xs),
                            _SpeakButton(
                              tooltip: '예문 듣기',
                              loading: _exampleLoading,
                              small: true,
                              onPressed: () =>
                                  _speak(play, (on) => _exampleLoading = on),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      _Covered(
                        visible: _showMeaning,
                        label: '번역',
                        child: Text(
                          ex.ko,
                          style: context.text.bodySmall?.copyWith(height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _RevealButton(
                  label: '뜻',
                  on: _showMeaning,
                  onTap: () => setState(() => _showMeaning = !_showMeaning),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _RevealButton(
                  label: '읽기',
                  on: _showReading,
                  onTap: _toggleReading,
                ),
              ),
              if (widget.onSpeakWord case final play?) ...[
                const SizedBox(width: Space.sm),
                _SpeakButton(
                  tooltip: '발음 듣기',
                  loading: _wordLoading,
                  onPressed: () => _speak(play, (on) => _wordLoading = on),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static double _headSize(String headword) {
    final n = headword.runes.length;
    if (n <= 3) return 60;
    if (n <= 5) return 48;
    return 36;
  }
}

/// Keeps the space while hidden (no layout jump) and fades the content in.
class _Covered extends StatelessWidget {
  const _Covered({
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

class _RevealButton extends StatelessWidget {
  const _RevealButton({
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
class _SpeakButton extends StatelessWidget {
  const _SpeakButton({
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
