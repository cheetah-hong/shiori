/// JMdict lookups in pure Dart: every entry spelled as a set of forms, in
/// one call (the word extractor's dictionary facts).
///
/// Data: JMdict by the Electronic Dictionary Research and Development Group,
/// CC BY-SA 4.0. Apps must show [DictionaryInfo.attribution].
library;

export 'src/form_lookup.dart' show FormEntry;
export 'src/jmdict_dictionary.dart'
    show JmdictDictionary, JmdictFormatException, jmdictSchemaVersion;
export 'src/models.dart' show DictionaryInfo;
export 'src/priority.dart' show Priority, PriorityTag;
