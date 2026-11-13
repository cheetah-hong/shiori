import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/card_parts.dart';
import 'package:shiori/features/study/pitch_line.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/large_text.dart';
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
    this.filledExample,
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

  /// A sentence of the word's dictionary entry, shown in the example's place
  /// when the page printed no example (the page example always wins).
  final CardExample? filledExample;

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

  /// The page example, else the filled one.
  CardExample? _example(Word w) => switch (w.example) {
    final Example e => CardExample.fromPage(e),
    null => widget.filledExample,
  };

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

  /// A tap on a covered line opens it, as 뜻 보기 does.
  void _openMeaning() => setState(() => _showMeaning = true);

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

    return CardFrame(
      item: item,
      children: [
        CardBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoveredPart(
                visible: _showReading,
                label: '읽기',
                onReveal: _toggleReading,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    JpText(
                      readingsLabel(w.readings),
                      style: JpType.body(TypeScale.body, t.text3, height: 1.3),
                    ),
                    if (_pitch case final pitch?) ...[
                      const SizedBox(height: Space.xs),
                      PitchLine(info: pitch),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Space.xs),
              CardHeadword(w.headword),
              const SizedBox(height: Space.md),
              CoveredPart(
                visible: _showMeaning,
                label: '뜻',
                onReveal: _openMeaning,
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
              if (_example(w) case final ex?) ...[
                const SizedBox(height: Space.xl),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ExampleSentence(
                        sentence: ex.ja,
                        focus: ex.surface ?? w.headword,
                        style: JpType.body(
                          TypeScale.body2,
                          t.text2,
                          height: 1.75,
                        ),
                        onSpeak: _exampleLoading
                            ? null
                            : switch (widget.onSpeakExample) {
                                final play? => () => _speak(
                                  play,
                                  (on) => _exampleLoading = on,
                                ),
                                null => null,
                              },
                      ),
                    ),
                    if (widget.onSpeakExample case final play?) ...[
                      const SizedBox(width: Space.xs),
                      SpeakButton(
                        tooltip: '예문 듣기',
                        loading: _exampleLoading,
                        small: true,
                        onPressed: () =>
                            _speak(play, (on) => _exampleLoading = on),
                      ),
                    ],
                  ],
                ),
                if (ex.ko ?? ex.en case final translation?) ...[
                  const SizedBox(height: Space.xs),
                  CoveredPart(
                    visible: _showMeaning,
                    label: '번역',
                    onReveal: _openMeaning,
                    child: Text(
                      translation,
                      style: context.text.bodySmall?.copyWith(
                        height: 1.5,
                        fontStyle: ex.ko == null ? FontStyle.italic : null,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                if (ex.isFilled) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    ex.ko == null && ex.en != null
                        ? '예문: Tatoeba · 영어 번역'
                        : '예문: Tatoeba',
                    style: context.text.labelSmall?.copyWith(color: t.text3),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ],
          ),
        ),
        _RevealRow(
          meaning: RevealButton(
            label: '뜻',
            on: _showMeaning,
            onTap: () => setState(() => _showMeaning = !_showMeaning),
          ),
          reading: RevealButton(
            label: '읽기',
            on: _showReading,
            onTap: _toggleReading,
          ),
          speak: switch (widget.onSpeakWord) {
            final play? => SpeakButton(
              tooltip: '발음 듣기',
              loading: _wordLoading,
              onPressed: () => _speak(play, (on) => _wordLoading = on),
            ),
            null => null,
          },
        ),
      ],
    );
  }
}

/// 뜻 보기 and 읽기 보기 side by side with the speaker; at large text sizes
/// one above the other, so neither label breaks inside a word.
class _RevealRow extends StatelessWidget {
  const _RevealRow({required this.meaning, required this.reading, this.speak});

  final Widget meaning;
  final Widget reading;
  final Widget? speak;

  @override
  Widget build(BuildContext context) {
    final sound = speak;
    if (isLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          meaning,
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(child: reading),
              if (sound != null) ...[const SizedBox(width: Space.sm), sound],
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: meaning),
        const SizedBox(width: Space.sm),
        Expanded(child: reading),
        if (sound != null) ...[const SizedBox(width: Space.sm), sound],
      ],
    );
  }
}
