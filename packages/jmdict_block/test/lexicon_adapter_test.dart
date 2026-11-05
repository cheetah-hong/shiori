import 'dart:io';

import 'package:jmdict_block/jmdict_block.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'support/mini.dart';

JmdictLexiconAdapter _openLexicon() {
  final db = sqlite3.openInMemory()
    ..execute(File(miniFixturePath).readAsStringSync());
  return JmdictLexiconAdapter(JmdictDictionary.fromDatabase(db));
}

void main() {
  late JmdictLexiconAdapter lexicon;
  setUp(() => lexicon = _openLexicon());
  tearDown(() => lexicon.jmdict.close());

  test(
    'forms come back as core entries with POS codes and priority bits',
    () async {
      final found = await lexicon.lookup(['勉強', 'テレビ', '静か', '無いもの']);

      expect(found.keys.toSet(), {'勉強', 'テレビ', '静か'});
      final benkyou = found['勉強']!.single;
      expect(benkyou.id, 1512670);
      expect(benkyou.readings, ['べんきょう']);
      expect(benkyou.partsOfSpeech, containsAll(['n', 'vs']));
      expect(benkyou.isCommon, isTrue);
      expect(benkyou.nf, 3);
      expect(found['静か']!.single.partsOfSpeech, ['adj-na']);
      expect(found['テレビ']!.single.writtenInKana, isTrue);
    },
  );

  test(
    'a kana particle is written in kana; the number 二 read に is not',
    () async {
      final ni = (await lexicon.lookup(['に']))['に']!;

      expect(
        ni.firstWhere((e) => e.partsOfSpeech.contains('prt')).writtenInKana,
        isTrue,
      );
      expect(ni.firstWhere((e) => e.id == 1461140).writtenInKana, isFalse);
    },
  );

  test('the word extractor runs on the adapter', () async {
    final result = await GeneralExtractor(lexicon: lexicon).extract(
      const OcrScan(
        japanese: OcrPage(
          lines: [
            OcrLine(text: '勉強', x: 0.2, y: 0.3, width: 0.04, height: 0.02),
          ],
        ),
        korean: OcrPage(
          lines: [
            OcrLine(text: '공부', x: 0.5, y: 0.3, width: 0.04, height: 0.02),
          ],
        ),
      ),
    );

    final word = result.words.single;
    expect(word.headword, '勉強');
    expect(word.readings, ['べんきょう']);
    expect(word.readingSource, FieldSource.dictionary);
    expect(word.partsOfSpeech, contains('vs'));
    expect(word.meaning, '공부');
  });
}
