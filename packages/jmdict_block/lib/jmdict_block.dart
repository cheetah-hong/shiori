/// The JMdict dictionary block: [JmdictDictionaryAdapter] plugs dict_jmdict
/// into the core `Dictionary` port, [JmdictLexiconAdapter] into `Lexicon`
/// (the word extractor's port).
///
/// Data: JMdict by the Electronic Dictionary Research and Development Group,
/// CC BY-SA 4.0. Apps must show [DictionaryInfo.attribution].
library;

export 'package:dict_jmdict/dict_jmdict.dart'
    show
        DictionaryInfo,
        FormEntry,
        JmdictDictionary,
        JmdictFormatException,
        WordClass;

export 'src/jmdict_dictionary_adapter.dart';
export 'src/jmdict_lexicon_adapter.dart';
