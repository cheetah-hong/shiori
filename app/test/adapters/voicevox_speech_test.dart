import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/audio_playback.dart';
import 'package:shiori/adapters/voice_assets.dart';
import 'package:shiori/adapters/voicevox_speech.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/voicevox_block.dart';

const _chopsticks = WordSpeech(headword: '箸', reading: 'はし', accents: [1]);

Uint8List _wav() {
  final b = ByteData(48);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  b.setUint32(4, 40, Endian.little);
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
  b.setUint32(40, 4, Endian.little);
  return b.buffer.asUint8List();
}

AccentPhrase _phrase(List<String> morae, int accent) => AccentPhrase.fromJson({
  'moras': [
    for (final m in morae) {'text': m, 'vowel': 'a', 'pitch': 5.5},
  ],
  'accent': accent,
});

final class _Ops implements VoicevoxOps {
  int synth = 0;
  Object? fail;

  @override
  String get voiceId => 'test';

  @override
  Future<List<AccentPhrase>> phrasesFromKana(String kana) async => [
    _phrase(['ハ', 'シ'], 1),
  ];

  @override
  Future<List<AccentPhrase>> phrasesFromText(String text) async => [
    _phrase(['ハ', 'シ', 'ガ'], 1),
  ];

  @override
  Future<List<AccentPhrase>> replaceMoraPitch(List<AccentPhrase> p) async => p;

  @override
  Future<Uint8List> synthesize(List<AccentPhrase> phrases) async {
    synth++;
    final f = fail;
    if (f != null) throw f;
    return _wav();
  }
}

final class _Playback implements AudioPlayback {
  final events = <String>[];
  Object? fail;

  @override
  Future<void> play(File file) async {
    final f = fail;
    if (f != null) throw f;
    events.add('play ${file.path.split('/').last}');
  }

  @override
  Future<void> stop() async => events.add('stop');
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('voicevox_speech_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  VoiceAssetsReady ready() => VoiceAssetsReady(
    dir: dir,
    edition: VoiceEdition.fromJson({
      'variant': 'v',
      'built_on': '2026-11-06',
      'core_version': '0.17.1',
      'model_file': 'model.vvm',
      'dictionary_dir': 'dic',
      'style_id': 2,
      'credit': 'VOICEVOX:四国めたん',
      'files': [
        {
          'path': 'model.vvm',
          'gzip': 'a.gz',
          'gzip_bytes': 1,
          'bytes': 1,
          'sha256': '0' * 64,
        },
        {
          'path': 'dic/sys.dic',
          'gzip': 'b.gz',
          'gzip_bytes': 1,
          'bytes': 1,
          'sha256': '0' * 64,
        },
      ],
    }),
  );

  ({VoicevoxSpeech speech, _Ops ops, _Playback playback, List<String> opened})
  make({VoiceAssetsResult? assets, Object? engineError}) {
    final ops = _Ops();
    final playback = _Playback();
    final opened = <String>[];
    final speech = VoicevoxSpeech(
      isAvailable: true,
      prepareAssets: () async => assets ?? ready(),
      openEngine: (a) async {
        opened.add(a.modelPath);
        final e = engineError;
        if (e != null) throw e;
        return ops;
      },
      cache: () async =>
          SpeechCache(dir: Directory('${dir.path}/cache'), maxBytes: 1 << 20),
      playback: playback,
    );
    return (speech: speech, ops: ops, playback: playback, opened: opened);
  }

  test(
    'makes the sound once, plays it, and plays the cached file next',
    () async {
      final m = make();
      await m.speech.speak(_chopsticks);
      await m.speech.speak(_chopsticks);
      expect(m.ops.synth, 1);
      expect(m.opened, hasLength(1));
      expect(
        m.playback.events.where((e) => e.startsWith('play')),
        hasLength(2),
      );
    },
  );

  test(
    'speaking again stops what plays and starts from the beginning',
    () async {
      final m = make();
      await m.speech.speak(_chopsticks);
      await m.speech.speak(_chopsticks);
      expect(m.playback.events, [
        'stop',
        startsWith('play'),
        'stop',
        startsWith('play'),
      ]);
    },
  );

  test('stop stops the playback', () async {
    final m = make();
    await m.speech.stop();
    expect(m.playback.events, ['stop']);
  });

  test(
    'damaged voice data: the engine is not opened, the learner is told',
    () async {
      final m = make(
        assets: const VoiceAssetsUnavailable(
          'sha256 differs',
          kind: VoiceAssetsProblem.damaged,
        ),
      );
      await expectLater(
        m.speech.speak(_chopsticks),
        throwsA(
          isA<SpeechFailure>().having(
            (f) => f.message,
            'message',
            contains('손상'),
          ),
        ),
      );
      expect(m.opened, isEmpty);
      expect(m.ops.synth, 0);
    },
  );

  test('no voice data in this build: says so, engine not opened', () async {
    final m = make(
      assets: const VoiceAssetsUnavailable(
        'no edition',
        kind: VoiceAssetsProblem.missing,
      ),
    );
    await expectLater(
      m.speech.speak(_chopsticks),
      throwsA(isA<SpeechFailure>()),
    );
    expect(m.opened, isEmpty);
  });

  test(
    'an engine that does not open is a SpeechFailure, tried again later',
    () async {
      final m = make(engineError: StateError('no library'));
      await expectLater(
        m.speech.speak(_chopsticks),
        throwsA(isA<SpeechFailure>()),
      );
      await expectLater(
        m.speech.speak(_chopsticks),
        throwsA(isA<SpeechFailure>()),
      );
      expect(m.opened, hasLength(2));
    },
  );

  test('a synthesis or playback failure is a SpeechFailure', () async {
    final a = make();
    a.ops.fail = StateError('engine down');
    await expectLater(
      a.speech.speak(_chopsticks),
      throwsA(isA<SpeechFailure>()),
    );
    final b = make();
    b.playback.fail = StateError('no audio');
    await expectLater(
      b.speech.speak(_chopsticks),
      throwsA(isA<SpeechFailure>()),
    );
  });

  test('estimateAccent asks the engine; null when it cannot', () async {
    final m = make();
    expect(
      await m.speech.estimateAccent(
        const WordSpeech(headword: '箸', reading: 'はし'),
      ),
      1,
    );
    final broken = make(engineError: StateError('no library'));
    expect(
      await broken.speech.estimateAccent(
        const WordSpeech(headword: '箸', reading: 'はし'),
      ),
      isNull,
    );
  });

  test('two requests at once open the engine once', () async {
    final m = make();
    await Future.wait([
      m.speech.speak(_chopsticks),
      m.speech.speak(const SentenceSpeech(text: '箸で食べます。', word: _chopsticks)),
    ]);
    expect(m.opened, hasLength(1));
  });
}
