// E7: words already in the learner's lists are skipped and counted.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

/// A sentence with 学校 and 走る, and its translation.
OcrScan _sentencePage() => scan(
  ja: [line('学校まで走った。', 0.10, 0.10, c: 1.0)],
  ko: [line('학교까지 달렸다.', 0.55, 0.10, c: 1.0)],
);

CaptureRouter _router() => CaptureRouter(
  template: templatePipeline(),
  general: GeneralExtractor(lexicon: testLexicon()),
);

void main() {
  test('the extractor leaves a known sentence word out and names it', () async {
    final r = await GeneralExtractor(
      lexicon: testLexicon(),
    ).extract(_sentencePage(), knownHeadwords: {'学校'});

    expect(r.words.map((w) => w.headword), isNot(contains('学校')));
    expect(r.words.map((w) => w.headword), contains('走る'));
    expect(r.skippedKnown, ['学校']);
  });

  test(
    'the routed draft carries the skipped words for the review summary',
    () async {
      final draft = await _router().fromScan(
        _sentencePage(),
        knownHeadwords: {'学校'},
      );

      expect(draft.route!.route, CaptureRoute.general);
      expect(draft.entries.map((e) => e.headword), isNot(contains('学校')));
      expect(draft.skippedKnown, ['学校']);
    },
  );

  test('nothing known: nothing skipped', () async {
    final draft = await _router().fromScan(_sentencePage());

    expect(draft.entries.map((e) => e.headword), contains('学校'));
    expect(draft.skippedKnown, isEmpty);
  });

  test('a word met twice on the page is skipped once', () async {
    final r = await GeneralExtractor(lexicon: testLexicon()).extract(
      scan(
        ja: [
          line('学校まで走った。', 0.10, 0.10, c: 1.0),
          line('学校で読んだ。', 0.10, 0.20, c: 1.0),
        ],
      ),
      knownHeadwords: {'学校'},
    );

    expect(r.skippedKnown, ['学校']);
  });

  test(
    'row-template pages are not filtered (saving again updates them)',
    () async {
      final page = await synthetic.loadScan('s010');
      final first = (await templatePipeline().fromScan(
        page,
      )).entries.firstWhere((e) => e.headword.isNotEmpty).headword;
      final s010 = await syntheticRouter().fromScan(
        page,
        knownHeadwords: {first},
      );

      expect(s010.route!.route, CaptureRoute.template);
      expect(s010.entries.map((e) => e.headword), contains(first));
      expect(s010.skippedKnown, isEmpty);
    },
  );
}
