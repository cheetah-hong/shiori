import 'dart:convert';
import 'dart:typed_data';

import 'package:voicevox_block/voicevox_block.dart';

/// A whole WAV file of [samples] 16-bit samples (44-byte header).
Uint8List wavOf(int samples, {int fill = 0}) {
  final data = samples * 2;
  final b = ByteData(44 + data);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  b.setUint32(4, 36 + data, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, 24000, Endian.little);
  b.setUint32(28, 48000, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  b.setUint32(40, data, Endian.little);
  for (var i = 0; i < data; i++) {
    b.setUint8(44 + i, fill & 0xff);
  }
  return b.buffer.asUint8List();
}

/// An accent phrase as the engine writes it.
AccentPhrase phrase(List<String> morae, int accent) => AccentPhrase.fromJson({
  'moras': [
    for (final m in morae)
      {
        'text': m,
        'consonant': null,
        'consonant_length': null,
        'vowel': 'a',
        'vowel_length': 0.1,
        'pitch': 5.5,
      },
  ],
  'accent': accent,
  'pause_mora': null,
  'is_interrogative': false,
});

/// Records every call; answers from the maps it is given.
final class FakeOps implements VoicevoxOps {
  FakeOps({this.kana = const {}, this.text = const {}});

  /// VOICEVOX kana → phrases.
  final Map<String, List<AccentPhrase>> kana;

  /// Text → phrases.
  final Map<String, List<AccentPhrase>> text;

  final calls = <String>[];
  Object? failSynthesis;

  @override
  String get voiceId => 'fake-engine/style-2';

  @override
  Future<List<AccentPhrase>> phrasesFromKana(String k) async {
    calls.add('kana $k');
    final p = kana[k];
    if (p == null) throw StateError('unknown kana $k');
    return p;
  }

  @override
  Future<List<AccentPhrase>> phrasesFromText(String t) async {
    calls.add('text $t');
    final p = text[t];
    if (p == null) throw StateError('unknown text $t');
    return p;
  }

  @override
  Future<List<AccentPhrase>> replaceMoraPitch(List<AccentPhrase> p) async {
    calls.add('pitch ${describe(p)}');
    return p;
  }

  @override
  Future<Uint8List> synthesize(List<AccentPhrase> p) async {
    calls.add('synth ${describe(p)}');
    final fail = failSynthesis;
    if (fail != null) throw fail;
    return wavOf(8, fill: utf8.encode(describe(p)).length);
  }

  static String describe(List<AccentPhrase> p) =>
      p.map((x) => '${x.moraTexts.join()}:${x.accent}').join(' ');
}
