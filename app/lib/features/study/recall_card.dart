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

  void _toggle() => setState(() => _shown = !_shown);

  @override
  Widget build(BuildContext context) {
    final w = widget.item.word;
    final playWord = widget.onSpeakWord;
    return CardFrame(
      item: widget.item,
      children: [
        // The question heads the sheet, where 홈 has the day's number.
        CardBody(
          top: _questionTop,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (w.pos != null) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PosBadge(w.pos),
                ),
                const SizedBox(height: Space.sm),
              ],
              _Question(meaning: w.meaning),
              const SizedBox(height: Space.lg),
              if (!_shown)
                HiddenPart(label: '일본어', onReveal: _toggle)
              else
                _Answer(word: w, pitch: widget.pitch),
              if (w.example case final example?) _example(example, w.headword),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: RevealButton(label: '일본어', on: _shown, onTap: _toggle),
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

  /// The example: its translation always, the Japanese once shown.
  Widget _example(Example example, String headword) {
    final t = context.tokens;
    final play = widget.onSpeakExample;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.xl),
        if (_shown)
          Row(
            children: [
              Flexible(
                child: ExampleSentence(
                  sentence: example.ja,
                  focus: headword,
                  style: JpType.body(TypeScale.body2, t.text2, height: 1.75),
                  textAlign: TextAlign.start,
                  onSpeak: play == null || _exampleLoading
                      ? null
                      : () => speakWith(play, (on) => _exampleLoading = on),
                ),
              ),
              if (play != null) ...[
                const SizedBox(width: Space.xs),
                SpeakButton(
                  tooltip: '예문 듣기',
                  loading: _exampleLoading,
                  small: true,
                  onPressed: () =>
                      speakWith(play, (on) => _exampleLoading = on),
                ),
              ],
            ],
          ),
        const SizedBox(height: Space.xs),
        Text(example.ko, style: context.text.bodySmall?.copyWith(height: 1.5)),
      ],
    );
  }
}

/// Where the question starts, as a share of the sheet's height: in its
/// top third.
const double _questionTop = 0.08;

/// The meaning to recall the word from, big and heavy at the sheet's head.
/// It grows with the text size only so far (it is large already).
class _Question extends StatelessWidget {
  const _Question({required this.meaning});

  final String meaning;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _questionMaxScale,
      child: Text(
        meaning,
        style: TextStyle(
          color: t.text,
          fontSize: meaning.runes.length <= _shortQuestion ? 48 : 40,
          height: 1.15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

const double _questionMaxScale = 1.4;
const int _shortQuestion = 6;

/// The word once shown: reading, pitch and the printed headword.
class _Answer extends StatelessWidget {
  const _Answer({required this.word, this.pitch});

  final Word word;
  final PitchInfo? pitch;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JpText(
          readingsLabel(word.readings),
          style: JpType.body(TypeScale.body, t.text3, height: 1.3),
        ),
        if (pitch case final p?) ...[
          const SizedBox(height: Space.xs),
          PitchLine(info: p),
        ],
        CardHeadword(word.headword, textAlign: TextAlign.start),
      ],
    );
  }
}
