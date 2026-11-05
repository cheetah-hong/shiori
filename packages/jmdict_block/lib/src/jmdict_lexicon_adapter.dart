import 'package:dict_jmdict/dict_jmdict.dart' as jm;
import 'package:shiori_core/shiori_core.dart';

/// The core `Lexicon` port over a JMdict SQLite file (dict_jmdict): every
/// form of a call in a few indexed queries.
final class JmdictLexiconAdapter implements Lexicon {
  JmdictLexiconAdapter(this.jmdict);

  final jm.JmdictDictionary jmdict;

  @override
  Future<Map<String, List<LexiconEntry>>> lookup(
    Iterable<String> forms,
  ) async => {
    for (final MapEntry(key: form, value: entries)
        in jmdict.lookupForms(forms).entries)
      form: [for (final e in entries) _entry(e)],
  };

  static LexiconEntry _entry(jm.FormEntry e) => LexiconEntry(
    id: e.entryId,
    form: e.form,
    readings: e.readings,
    kanjiForms: e.kanjiForms,
    partsOfSpeech: e.partsOfSpeech,
    priority: e.priority.bits,
    nf: e.priority.nf,
    usuallyKana: e.usuallyKana,
  );
}
