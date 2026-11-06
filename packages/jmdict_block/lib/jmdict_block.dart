/// The JMdict dictionary block: [JmdictLexiconAdapter] plugs dict_jmdict
/// into the core `Lexicon` port (the word extractor's dictionary facts).
///
/// Data: JMdict by the Electronic Dictionary Research and Development Group,
/// CC BY-SA 4.0. Apps must show [DictionaryInfo.attribution].
library;

export 'package:dict_jmdict/dict_jmdict.dart'
    show DictionaryInfo, FormEntry, JmdictDictionary, JmdictFormatException;

export 'src/jmdict_lexicon_adapter.dart';
