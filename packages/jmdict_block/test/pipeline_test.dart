// The core capture pipeline with the JMdict block plugged in, over the
// synthetic pages. Only JMdict test data and made-up pages are used.
import 'dart:io';

import 'package:jmdict_block/jmdict_block.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/mini.dart';

void main() {
  late JmdictDictionaryAdapter dict;
  late CaptureDraft page;

  setUpAll(() async {
    dict = openMiniAdapter();
    const recognizer = FixtureTextRecognizer(_read);
    page = await CapturePipeline.standard(
      dictionary: dict,
    ).fromScan(await recognizer.recognize(const PageImage('s010')));
  });
  tearDownAll(() => dict.close());

  CapturedEntry word(String no) => page.entries.singleWhere((e) => e.no == no);

  test('unread headwords get the right word as the first candidate', () {
    expect(word('0002').headword, isEmpty);
    expect(word('0002').headwordCandidates.first, '日');
    expect(word('0003').headword, isEmpty);
    expect(word('0003').headwordCandidates.first, '空');
  });

  test('the learner still picks: unread headwords stay flagged', () {
    for (final no in ['0002', '0003']) {
      expect(word(no).statusOf(EntryField.headword), FieldStatus.needsReview);
    }
  });
}

Future<String> _read(String name) => File('$syntheticDir/$name').readAsString();
