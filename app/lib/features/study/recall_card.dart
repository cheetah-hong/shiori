import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/card_parts.dart';
import 'package:shiori/features/study/pitch_line.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// 일본어 떠올리기: the meaning (and the example's translation) up front; the
/// word, its reading and the Japanese example stay out of the card until
/// 일본어 보기, since each of them gives the answer away.
class RecallCard extends StatefulWidget {
  const RecallCard({
    super.key,
    required this.item,
    this.onSpeakWord,
    this.onSpeakExample,
    this.pitch,
  });

  final SessionItem item;

  /// Plays the word; null hides the button. Shown once the word is.
  final Future<void> Function()? onSpeakWord;

  /// Plays the example; null: no button, the text takes no taps.
  final Future<void> Function()? onSpeakExample;

  final PitchInfo? pitch;

  @override
  State<RecallCard> createState() => _RecallCardState();
}

class _RecallCardState extends State<RecallCard> with CardSpeech {
  bool _shown = false;
  bool _wordLoading = false;
  bool _exampleLoading = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = widget.item.word;
    final example = w.example;
    final playExample = widget.onSpeakExample;
    final playWord = widget.onSpeakWord;
    return CardFrame(
      item: widget.item,
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (w.pos != null) ...[
                        PosBadge(w.pos),
                        const SizedBox(width: Space.sm),
                      ],
                      Flexible(
                        child: Text(
                          w.meaning,
                          style: context.text.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  if (!_shown)
                    const HiddenPart(label: '일본어')
                  else ...[
                    Text(
                      readingsLabel(w.readings),
                      style: JpType.gothic(17, t.ink3, height: 1.3),
                    ),
                    if (widget.pitch case final pitch?) ...[
                      const SizedBox(height: Space.xs),
                      PitchLine(info: pitch),
                    ],
                    Text(
                      w.headword,
                      style: JpType.print(
                        headwordSize(w.headword),
                        t.ink,
                        weight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (example != null) ...[
                    const SizedBox(height: Space.xl),
                    if (_shown)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: ExampleSentence(
                              sentence: example.ja,
                              focus: w.headword,
                              style: JpType.gothic(15, t.ink2, height: 1.75),
                              onSpeak: playExample == null || _exampleLoading
                                  ? null
                                  : () => speakWith(
                                      playExample,
                                      (on) => _exampleLoading = on,
                                    ),
                            ),
                          ),
                          if (playExample != null) ...[
                            const SizedBox(width: Space.xs),
                            SpeakButton(
                              tooltip: '예문 듣기',
                              loading: _exampleLoading,
                              small: true,
                              onPressed: () => speakWith(
                                playExample,
                                (on) => _exampleLoading = on,
                              ),
                            ),
                          ],
                        ],
                      ),
                    const SizedBox(height: Space.xs),
                    Text(
                      example.ko,
                      style: context.text.bodySmall?.copyWith(height: 1.5),
                      textAlign: TextAlign.center,
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
              child: RevealButton(
                label: '일본어',
                on: _shown,
                onTap: () => setState(() => _shown = !_shown),
              ),
            ),
            if (_shown && playWord != null) ...[
              const SizedBox(width: Space.sm),
              SpeakButton(
                tooltip: '발음 듣기',
                loading: _wordLoading,
                onPressed: () => speakWith(playWord, (on) => _wordLoading = on),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
