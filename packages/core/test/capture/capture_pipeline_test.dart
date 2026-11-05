import 'dart:convert';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  final pipeline = standardPipeline();

  test('the fixture recognizer replays both passes of a page', () async {
    final s = await loadScan('s140');
    expect(s.japanese.engine, 'synthetic');
    expect(s.japanese.languages.first, 'ja-JP');
    expect(s.korean.languages.first, 'ko-KR');
    expect(s.japanese.lines, isNotEmpty);
    expect(s.elapsed, greaterThan(Duration.zero));
  });

  test('an unknown fixture is a recognition error', () async {
    expect(
      fixtureRecognizer.recognize(const PageImage('s999')),
      throwsA(isA<TextRecognitionException>()),
    );
  });

  test('malformed fixture JSON is a recognition error', () async {
    final broken = FixtureTextRecognizer(
      (name) async => name.endsWith('.ja.json') ? '[1, 2]' : '{}',
    );
    expect(
      broken.recognize(const PageImage('x')),
      throwsA(isA<TextRecognitionException>()),
    );
  });

  test('OcrScan survives a JSON round trip (native channel payload)', () async {
    final s = await loadScan('s010');
    final again = OcrScan.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>,
    );
    expect(again.japanese.lines.length, s.japanese.lines.length);
    expect(again.korean.lines.first.text, s.korean.lines.first.text);
    expect(again.japanese.lines.first.cy, s.japanese.lines.first.cy);
  });

  test('an old payload with a "star" pass reads; the pass is ignored', () {
    Map<String, Object?> page(String t) => {
      'engine': appleVisionEngine,
      'lines': [
        {'t': t, 'c': 0.5, 'x': 0.1, 'y': 0.2, 'w': 0.1, 'h': 0.02},
      ],
    };
    final scan = OcrScan.fromJson({
      'ja': page('かわ'),
      'ko': page('강'),
      'star': page('★'),
      'turned': 90,
    });
    expect(scan.japanese.lines.single.text, 'かわ');
    expect(scan.korean.lines.single.text, '강');
    expect(scan.turned, 90);
    expect(scan.toJson().keys, unorderedEquals(['ja', 'ko', 'turned']));
    // A broken "star" value is ignored too: nothing reads it any more.
    expect(
      OcrScan.fromJson({
        'ja': page('かわ'),
        'ko': page('강'),
        'star': 1,
      }).japanese.lines,
      hasLength(1),
    );
  });

  test('review flags name the five cells, none for ★', () {
    expect(EntryField.values.map((f) => f.name), [
      'headword',
      'readings',
      'pos',
      'meaning',
      'example',
    ]);
  });

  test(
    'a line with a missing or non-numeric box is rejected, not placed at 0,0',
    () {
      expect(
        () => OcrLine.fromJson(const {'t': 'a', 'x': 0.1, 'y': 0.1, 'w': 0.1}),
        throwsFormatException,
      );
      expect(
        () => OcrLine.fromJson(const {'t': 1, 'x': 0, 'y': 0, 'w': 0, 'h': 0}),
        throwsFormatException,
      );
      expect(
        () => OcrLine.fromJson(const {
          't': 'a',
          'x': 'left',
          'y': 0,
          'w': 0,
          'h': 0,
        }),
        throwsFormatException,
      );
      expect(
        OcrLine.fromJson(const {
          't': 'a',
          'x': 0,
          'y': 0,
          'w': 1,
          'h': 1,
        }).confidence,
        1.0,
      );
      expect(
        OcrPage.fromJson(const {'lines': [], 'langs': 'ja'}).languages,
        isEmpty,
      );
    },
  );

  test('an OcrPage engine that is not a string is rejected', () {
    expect(
      () => OcrPage.fromJson(const {'lines': [], 'engine': 3}),
      throwsFormatException,
    );
  });

  test('OcrPage without lines is rejected', () {
    expect(
      () => OcrPage.fromJson(const {'engine': 'x'}),
      throwsFormatException,
    );
    expect(
      () => OcrScan.fromJson(const {'ja': 1, 'ko': 2}),
      throwsFormatException,
    );
  });

  test(
    'page 10 draft: flags the two unread headwords and marks the correction',
    () async {
      final draft = await pipeline.fromScan(await loadScan('s010'));
      expect(draft.templateId, 'vocab.list');
      expect(draft.entries.length, 12);
      expect(draft.needsReviewCount, 2);
      expect(draft.correctedCount, 1);
      expect(
        draft.entries
            .where(
              (e) => e.statusOf(EntryField.headword) == FieldStatus.needsReview,
            )
            .map((e) => e.no),
        ['0002', '0003'],
      );
      expect(draft.recognitionTime, greaterThan(Duration.zero));
    },
  );

  test('a template can be forced by id', () async {
    final draft = await pipeline.fromScan(
      await loadScan('s140'),
      templateId: 'vocab.list',
    );
    expect(draft.templateId, 'vocab.list');
  });

  test(
    'editing an entry clears the flags of the touched fields only',
    () async {
      final draft = await pipeline.fromScan(await loadScan('s010'));
      final index = draft.entries.indexWhere((e) => e.no == '0003');
      final edited = draft.entries[index].edit(headword: '空');
      expect(edited.statusOf(EntryField.headword), FieldStatus.ok);
      final next = draft.replaceEntry(index, edited);
      expect(next.needsReviewCount, 1);
      expect(next.entries[index].headword, '空');
      expect(
        draft.entries[index].headword,
        isEmpty,
        reason: 'drafts are immutable',
      );
    },
  );

  test('excluding an entry is reflected in the included count', () async {
    final draft = await pipeline.fromScan(await loadScan('s147'));
    final next = draft.replaceEntry(
      0,
      draft.entries[0].copyWith(included: false),
    );
    expect(next.includedCount, draft.entries.length - 1);
  });

  test('every entry-layout word carries its example', () async {
    final draft = await pipeline.fromScan(await loadScan('s140'));
    expect(draft.entries.every((e) => e.example != null), isTrue);
    expect(draft.meta.title, '여행·교통');
  });

  test('CapturedEntry.copyWith can clear nullable fields', () {
    const e = CapturedEntry(
      no: '0001',
      headword: '雨',
      readings: ['あめ'],
      pos: PartOfSpeech.noun,
      meaning: '비',
      example: Example(ja: '雨の日', ko: '비 오는 날'),
    );
    final cleared = e.copyWith(no: null, pos: null, example: null);
    expect((cleared.no, cleared.pos, cleared.example), (null, null, null));
    expect(cleared.edit(pos: PartOfSpeech.verb).pos, PartOfSpeech.verb);
    expect(e.toString(), contains('雨'));
  });
}
