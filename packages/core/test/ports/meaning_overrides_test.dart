// M1: short meanings of our own for words whose dictionary meaning is off
// (시오리 보정), read from the app's file and put in front of the glossary's
// senses for the spelling and reading they are for. Every other word is
// answered by the glossary as before. Made-up words only.
import 'dart:convert';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

final class _Glossary implements KoreanGlossary, KoreanReverseGlossary {
  _Glossary(this.senses);

  final Map<String, List<List<String>>> senses;
  final List<
    ({String headword, List<String> readings, int limit, PartOfSpeech? pos})
  >
  calls = [];

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async {
    calls.add((headword: headword, readings: readings, limit: limit, pos: pos));
    return [
      for (final (i, words)
          in (senses[headword] ?? const []).take(limit).indexed)
        KoreanSense(
          words: words,
          source: GlossarySource.krdict,
          senseNo: i + 1,
        ),
    ];
  }

  @override
  Future<List<GlossedSpelling>> reverseLookup(
    Iterable<String> readings,
  ) async => [
    for (final r in readings)
      GlossedSpelling(written: '試$r', reading: r, words: const ['되읽기']),
  ];

  @override
  List<GlossarySourceInfo> get sources => const [
    GlossarySourceInfo(
      source: GlossarySource.krdict,
      publisher: '국립국어원',
      license: 'CC BY-SA 2.0 KR',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/2.0/kr/',
      edition: '2026-10-19',
    ),
  ];
}

/// A glossary that cannot be read backwards.
final class _ForwardOnly implements KoreanGlossary {
  const _ForwardOnly();

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async => const [];

  @override
  List<GlossarySourceInfo> get sources => const [];
}

_Glossary _krdict() => _Glossary({
  '試本': [
    ['그루'],
    ['시본'],
    ['책'],
  ],
  'しほ': [
    ['헛뜻'],
  ],
  '試居': [
    ['보다'],
  ],
  '試道': [
    ['길'],
  ],
});

/// 試本 read しほん is 책 (not 그루); read しもと it is not in the table.
/// しほ (a kana word) and its kanji spelling 試居 are 있다.
final _overrides = MeaningOverrides([
  const MeaningOverride(forms: ['試本'], reading: 'しほん', meaning: '책'),
  const MeaningOverride(
    forms: ['しほ', '試居'],
    reading: 'しほ',
    meaning: '있다, 존재하다',
  ),
  const MeaningOverride(forms: ['試空'], reading: 'しくう', meaning: '하늘'),
  const MeaningOverride(forms: ['シカメ'], reading: 'シカメ', meaning: '사진기'),
], edition: '2026-11-14');

String _json(List<Object?> rows, {Object? format, Object? version}) =>
    jsonEncode({
      'format': format ?? 'shiori-meaning-overrides',
      'version': version ?? 1,
      'edition': '2026-11-14',
      'rows': rows,
    });

void main() {
  group('MeaningOverrides', () {
    test('a spelling with its reading has its meaning', () {
      expect(_overrides.meaningOf('試本', readings: ['しほん']), '책');
      expect(_overrides.meaningOf('試居', readings: ['しほ']), '있다, 존재하다');
      expect(_overrides.meaningOf('しほ', readings: ['しほ']), '있다, 존재하다');
    });

    test('another reading of the spelling has none', () {
      expect(_overrides.meaningOf('試本', readings: ['しもと']), isNull);
      expect(_overrides.meaningOf('試本', readings: ['しもと', 'しほん']), '책');
    });

    test('without readings the spelling alone decides', () {
      expect(_overrides.meaningOf('試本'), '책');
      expect(_overrides.meaningOf('しほ'), '있다, 존재하다');
    });

    test('katakana and hiragana readings are the same reading', () {
      expect(_overrides.meaningOf('試本', readings: ['シホン']), '책');
      expect(_overrides.meaningOf('シカメ', readings: ['しかめ']), '사진기');
      expect(_overrides.meaningOf('シカメ'), '사진기');
    });

    test('a spelling not in the table has none', () {
      expect(_overrides.meaningOf('試道', readings: ['しみち']), isNull);
      expect(_overrides.meaningOf('本'), isNull);
    });

    test('size and edition', () {
      expect(_overrides.length, 4);
      expect(_overrides.edition, '2026-11-14');
      expect(MeaningOverrides.empty.length, 0);
      expect(MeaningOverrides.empty.meaningOf('試本'), isNull);
    });
  });

  group('parseMeaningOverrides', () {
    test('reads the file', () {
      final read = parseMeaningOverrides(
        _json([
          {
            'f': ['試本'],
            'r': 'しほん',
            'm': '책',
          },
          {
            'f': ['しほ', '試居'],
            'r': 'しほ',
            'm': '있다',
          },
        ]),
      );
      expect(read.length, 2);
      expect(read.edition, '2026-11-14');
      expect(read.meaningOf('試居', readings: ['しほ']), '있다');
    });

    final bad = <String, String>{
      'not JSON': '{',
      'not an object': '[]',
      'another format': _json([], format: 'shiori-decks'),
      'another version': _json([], version: 2),
      'no rows': jsonEncode({
        'format': 'shiori-meaning-overrides',
        'version': 1,
        'edition': '2026-11-14',
      }),
      'no forms': _json([
        {'f': <String>[], 'r': 'しほん', 'm': '책'},
      ]),
      'an empty form': _json([
        {
          'f': [''],
          'r': 'しほん',
          'm': '책',
        },
      ]),
      'no reading': _json([
        {
          'f': ['試本'],
          'r': '',
          'm': '책',
        },
      ]),
      'no meaning': _json([
        {
          'f': ['試本'],
          'r': 'しほん',
          'm': ' ',
        },
      ]),
      'an unknown key': _json([
        {
          'f': ['試本'],
          'r': 'しほん',
          'm': '책',
          'x': 1,
        },
      ]),
      'a spelling and reading twice': _json([
        {
          'f': ['試本'],
          'r': 'しほん',
          'm': '책',
        },
        {
          'f': ['試本'],
          'r': 'シホン',
          'm': '서적',
        },
      ]),
    };
    for (final MapEntry(key: why, value: text) in bad.entries) {
      test('refuses a file with $why', () {
        expect(() => parseMeaningOverrides(text), throwsFormatException);
      });
    }
  });

  group('OverriddenKoreanGlossary', () {
    test('a word in the table: its meaning first, as 시오리 보정, the '
        'glossary\'s after it without the same text', () async {
      final krdict = _Glossary({
        '試本': [
          ['그루'],
          ['책'],
          ['시본'],
        ],
      });
      final g = OverriddenKoreanGlossary(krdict, _overrides);

      final senses = await g.lookup('試本', readings: ['しほん'], limit: 5);

      expect([for (final s in senses) s.text], ['책', '그루', '시본']);
      expect(senses.first.source, GlossarySource.shiori);
      expect(senses.first.words, ['책']);
      expect(GlossarySource.shiori.label, '시오리 보정');
    });

    test(
      'a meaning of several words keeps them as the sense\'s words',
      () async {
        final g = OverriddenKoreanGlossary(_krdict(), _overrides);

        final senses = await g.lookup('試居', readings: ['しほ']);

        expect(senses.first.words, ['있다', '존재하다']);
        expect(senses.first.text, '있다, 존재하다');
        expect([for (final s in senses) s.text], ['있다, 존재하다', '보다']);
      },
    );

    test('the limit counts the table\'s meaning', () async {
      final g = OverriddenKoreanGlossary(_krdict(), _overrides);

      final senses = await g.lookup('試本', readings: ['しほん'], limit: 2);

      expect([for (final s in senses) s.text], ['책', '그루']);
    });

    test('the glossary is asked as given', () async {
      final krdict = _krdict();
      final g = OverriddenKoreanGlossary(krdict, _overrides);

      await g.lookup('試本', readings: ['しほん'], limit: 4, pos: PartOfSpeech.noun);

      final call = krdict.calls.single;
      expect(call.headword, '試本');
      expect(call.readings, ['しほん']);
      expect(call.limit, 4);
      expect(call.pos, PartOfSpeech.noun);
    });

    test('a word not in the table, or another reading, is the glossary\'s '
        'answer unchanged', () async {
      final krdict = _krdict();
      final g = OverriddenKoreanGlossary(krdict, _overrides);

      for (final (head, readings) in [
        ('試道', ['しみち']),
        ('試本', ['しもと']),
        ('なし', <String>[]),
      ]) {
        expect(
          await g.lookup(head, readings: readings, limit: 5),
          await krdict.lookup(head, readings: readings, limit: 5),
          reason: head,
        );
      }
    });

    test('the table\'s meaning when the glossary has none', () async {
      final g = OverriddenKoreanGlossary(_krdict(), _overrides);

      final senses = await g.lookup('試空', readings: ['しくう']);

      expect([for (final s in senses) s.text], ['하늘']);
    });

    test('a kana word without readings', () async {
      final g = OverriddenKoreanGlossary(_krdict(), _overrides);

      final senses = await g.lookup('しほ');

      expect([for (final s in senses) s.text], ['있다, 존재하다', '헛뜻']);
    });

    test('an empty table answers as the glossary', () async {
      final krdict = _krdict();
      final g = OverriddenKoreanGlossary(krdict, MeaningOverrides.empty);

      expect(
        await g.lookup('試本', readings: ['しほん']),
        await krdict.lookup('試本', readings: ['しほん']),
      );
    });

    test('read backwards and sources are the glossary\'s', () async {
      final krdict = _krdict();
      final g = OverriddenKoreanGlossary(krdict, _overrides);

      expect(await g.reverseLookup(['しほ']), await krdict.reverseLookup(['しほ']));
      expect(g.sources, krdict.sources);
    });

    test(
      'over a glossary that cannot be read backwards, nothing backwards',
      () async {
        final g = OverriddenKoreanGlossary(const _ForwardOnly(), _overrides);

        expect(await g.reverseLookup(['しほ']), isEmpty);
      },
    );
  });

  group('orderMeaningSenses keeps the table\'s meaning first', () {
    KoreanSense sense(
      String text, [
      GlossarySource s = GlossarySource.krdict,
    ]) => KoreanSense(words: text.split(', '), source: s);

    test('a sense spelling the kanji does not pass it', () {
      // 雪森 spelled in Korean readings is 설삼.
      final ordered = orderMeaningSenses('雪森', [
        sense('눈 덮인 숲', GlossarySource.shiori),
        sense('눈숲'),
        sense('설삼'),
      ]);

      expect([for (final s in ordered) s.text], ['눈 덮인 숲', '설삼', '눈숲']);
    });

    test('a sense used with a negative does not pass it', () {
      final ordered = orderMeaningSenses('試別', [
        sense('따로', GlossarySource.shiori),
        sense('특별히'),
        sense('별로'),
      ], negated: true);

      expect([for (final s in ordered) s.text], ['따로', '별로', '특별히']);
    });

    test('a sense the translation names does not pass it', () {
      final ordered = orderMeaningSenses('試走', [
        sense('달리다', GlossarySource.shiori),
        sense('뛰다'),
        sense('질주하다'),
      ], translation: '아이가 질주했습니다.');

      expect([for (final s in ordered) s.text], ['달리다', '질주하다', '뛰다']);
    });
  });
}
