import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/voice_assets.dart';
import 'package:shiori/adapters/voicevox_engine.dart';
import 'package:voicevox_block/voicevox_block.dart';

VoiceEdition edition({
  String variant = 'voicevox-0.17.1-n0vvm-style10003',
  int styleId = 10003,
}) => VoiceEdition(
  variant: variant,
  builtOn: '2026-11-11',
  coreVersion: '0.17.1',
  modelFile: 'n0.vvm',
  dictionaryDir: 'dic',
  styleId: styleId,
  credit: 'VOICEVOX Nemo',
  files: const [],
);

void main() {
  test('sounds are said at the engine default speed', () {
    expect(speechSpeedScale, 1.0);
  });

  test('the cache name holds the edition, the style and the speed', () {
    final id = speechVoiceId(edition());

    expect(id, contains('voicevox-0.17.1-n0vvm-style10003'));
    expect(id, contains('style-10003'));
    expect(id, contains('speed-1.0'));
  });

  test('another edition, style or speed gives another cache name', () {
    final now = speechVoiceId(edition());

    expect(
      speechVoiceId(edition(variant: 'voicevox-0.17.1-0vvm-style2')),
      isNot(now),
    );
    expect(speechVoiceId(edition(styleId: 2)), isNot(now));
    expect(speechVoiceId(edition(), speed: 0.85), isNot(now));
  });
}
