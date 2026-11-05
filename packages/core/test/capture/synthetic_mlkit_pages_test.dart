// One test per ML Kit slip built into the synthetic ML Kit pages
// (tools/synthetic/make_pages.py, m011 and m140), so each rule is checked by name.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  final pipeline = standardPipeline();
  final drafts = <String, CaptureDraft>{};

  setUpAll(() async {
    for (final page in ['m011', 'm140']) {
      drafts[page] = await pipeline.fromScan(
        await syntheticMlKit.loadScan(page),
      );
    }
  });

  CapturedEntry word(String page, String no) =>
      drafts[page]!.entries.singleWhere((e) => e.no == no);

  List<String> codes(CapturedEntry e) => [for (final i in e.issues) i.code];

  group('list layout (m011)', () {
    test('every row is found, in order', () {
      expect(drafts['m011']!.entries.map((e) => e.no), [
        for (var n = 13; n <= 24; n++) n.toString().padLeft(4, '0'),
      ]);
    });

    test('0 read as O or D and the checkbox read as O after the number', () {
      expect(word('m011', '0014').headword, '山');
      expect(word('m011', '0018').headword, '力');
      expect(word('m011', '0021').headword, '指');
    });

    test('a ★ glued to the reading or read as * still marks the word', () {
      expect(word('m011', '0015').readings, ['かわ']);
      expect(word('m011', '0015').important, isTrue);
      expect(word('m011', '0019').important, isTrue);
    });

    test('a ★ that was not returned cannot be recovered', () {
      expect(word('m011', '0013').important, isFalse);
    });

    test('a glyph glued after the reading is dropped', () {
      expect(word('m011', '0017').readings, ['ひかる']);
    });

    test(
      'POS: badge 8 is 동, a glued badge is split, a missing one is guessed',
      () {
        final blow = word('m011', '0023');
        expect((blow.pos, blow.meaning), (PartOfSpeech.verb, '불다'));
        expect(codes(blow), ['pos:corrected']);
        final star = word('m011', '0019');
        expect((star.pos, star.meaning), (PartOfSpeech.noun, '별'));
        final shine = word('m011', '0017');
        expect((shine.pos, shine.meaning), (PartOfSpeech.verb, '빛나다'));
        expect(shine.statusOf(EntryField.pos), FieldStatus.inferred);
      },
    );

    test('a period between Korean words is a comma', () {
      expect(word('m011', '0016').meaning, '석양, 저녁 해');
    });

    test('low-confidence garbage is not glued to the meaning', () {
      final nose = word('m011', '0022');
      expect((nose.pos, nose.meaning), (PartOfSpeech.noun, '코'));
    });

    test('a numbered row keeps a kana word whose dash was not returned', () {
      final e = word('m011', '0024');
      expect(e.headword, 'のんびり');
      expect(e.readings, isEmpty);
      expect(codes(e), isNot(contains('readings:missing')));
    });

    test('a meaning cut after its comma is flagged for review', () {
      final e = word('m011', '0024');
      expect(e.meaning, '느긋하게,');
      expect(e.statusOf(EntryField.meaning), FieldStatus.suspect);
      expect(e.needsReview, isTrue);
    });
  });

  group('entry layout (m140)', () {
    test(
      'entries whose number line was not returned are found and numbered',
      () {
        expect(drafts['m140']!.entries.map((e) => e.no), [
          for (var n = 1211; n <= 1216; n++) '$n',
        ]);
        expect(word('m140', '1212').headword, '切符');
        expect(word('m140', '1216').readings, ['おりる']);
      },
    );

    test('a katakana リ in a hiragana reading is fixed and shown', () {
      final e = word('m140', '1211');
      expect(e.readings, ['のりかえる']);
      expect(e.statusOf(EntryField.readings), FieldStatus.corrected);
    });

    test('every example and translation is read', () {
      for (final e in drafts['m140']!.entries) {
        expect(e.example, isNotNull, reason: e.no);
        expect(e.example!.ja, isNot(contains('己乙')), reason: e.no);
        expect(e.example!.ko, isNot(contains('굽행')), reason: e.no);
      }
    });

    test('long furigana lines are not part of the sentence', () {
      expect(word('m140', '1213').example!.ja, '飛行機は予定より三十分早く空港に到着しました。');
    });

    test('a stray glyph glued in front keeps the sentence in the example', () {
      expect(word('m140', '1214').example!.ja, startsWith('送朝の高速道路'));
    });

    test('a translation starting left of the column is kept', () {
      expect(word('m140', '1216').example!.ko, '잊은 물건이 없도록 조심해서 내려 주세요.');
    });

    test('| before the headword is checkbox noise', () {
      expect(word('m140', '1215').headword, '揺れる');
    });

    test(
      'a look-alike kanji in the headword passes unflagged (silent error)',
      () {
        final e = word('m140', '1216');
        expect(e.headword, '陸りる');
        expect(e.isFlagged, isFalse);
      },
    );

    test('page meta from the footer', () {
      expect(
        drafts['m140']!.meta,
        const PageMeta(day: 20, title: '여행·교통', page: 140),
      );
    });
  });
}
