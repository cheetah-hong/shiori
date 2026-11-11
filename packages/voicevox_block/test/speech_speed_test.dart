import 'dart:convert';

import 'package:test/test.dart';
import 'package:voicevox_block/voicevox_block.dart';

void main() {
  // The shape of the engine's audio query JSON (VOICEVOX ENGINE names:
  // accent_phrases in snake case, the scales in camel case).
  String query({Object? speed = 1.0}) => jsonEncode({
    'accent_phrases': [
      {
        'moras': [
          {'text': 'ア', 'vowel': 'a', 'vowel_length': 0.1, 'pitch': 5.5},
        ],
        'accent': 1,
        'pause_mora': null,
        'is_interrogative': false,
      },
    ],
    'speedScale': ?speed,
    'pitchScale': 0.0,
    'intonationScale': 1.0,
    'volumeScale': 1.0,
    'prePhonemeLength': 0.1,
    'postPhonemeLength': 0.1,
    'outputSamplingRate': 24000,
    'outputStereo': false,
    'kana': "ア'",
  });

  test('sounds are said at the engine default speed', () {
    expect(speechSpeedScale, 1.0);
  });

  test('withSpeedScale sets only the speed of the audio query', () {
    final before = jsonDecode(query()) as Map<String, Object?>;

    final after =
        jsonDecode(withSpeedScale(query(), 0.85)) as Map<String, Object?>;

    expect(after['speedScale'], 0.85);
    expect({...after}..remove('speedScale'), {...before}..remove('speedScale'));
  });

  test('withSpeedScale fails when the query has no speed to set', () {
    expect(
      () => withSpeedScale(query(speed: null), 0.85),
      throwsFormatException,
    );
    expect(() => withSpeedScale('[]', 0.85), throwsFormatException);
    expect(() => withSpeedScale('not json', 0.85), throwsFormatException);
  });
}
