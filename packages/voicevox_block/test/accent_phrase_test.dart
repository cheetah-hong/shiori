import 'dart:convert';

import 'package:test/test.dart';
import 'package:voicevox_block/voicevox_block.dart';

import 'support/fake_ops.dart';

void main() {
  test('reads the engine JSON and writes it back unchanged', () {
    final p = phrase(['ハ', 'シ', 'デ'], 1);
    expect(p.moraTexts, ['ハ', 'シ', 'デ']);
    expect(p.accent, 1);
    final again = AccentPhrase.listFromJson(AccentPhrase.listToJson([p]));
    expect(again.single.toJson(), p.toJson());
    expect(p.toJson()['is_interrogative'], isFalse);
  });

  test('withAccent changes only the accent and leaves the original', () {
    final p = phrase(['ハ', 'シ', 'デ'], 1);
    final q = p.withAccent(3);
    expect(q.accent, 3);
    expect(p.accent, 1);
    expect(q.moraTexts, p.moraTexts);
    expect((q.toJson()['moras']! as List).length, 3);
  });

  test('a phrase without moras or accent is refused', () {
    expect(
      () => AccentPhrase.fromJson({'moras': <Object?>[], 'accent': 1}),
      throwsFormatException,
    );
    expect(
      () => AccentPhrase.fromJson({
        'moras': [
          {'text': 'ハ'},
        ],
      }),
      throwsFormatException,
    );
    expect(() => AccentPhrase.listFromJson('{}'), throwsFormatException);
    expect(
      () => AccentPhrase.listFromJson(jsonEncode([1, 2])),
      throwsFormatException,
    );
  });
}
