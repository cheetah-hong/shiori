/// The JMdict dictionary block: [JmdictDictionaryAdapter] plugs dict_jmdict
/// into the core `Dictionary` port.
///
/// Data: JMdict by the Electronic Dictionary Research and Development Group,
/// CC BY-SA 4.0. Apps must show [DictionaryInfo.attribution].
library;

export 'package:dict_jmdict/dict_jmdict.dart'
    show DictionaryInfo, JmdictDictionary, JmdictFormatException, WordClass;

export 'src/jmdict_dictionary_adapter.dart';
