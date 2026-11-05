/// JMdict lookups in pure Dart: headword candidates by reading, headword and
/// reading pair checks, and suggestions for OCR glyph confusions.
///
/// Data: JMdict by the Electronic Dictionary Research and Development Group,
/// CC BY-SA 4.0. Apps must show [DictionaryInfo.attribution].
library;

export 'src/confusables.dart'
    show
        confusableInKanji,
        confusableWhole,
        areConfusable,
        glyphEdits,
        glyphVariants;
export 'src/jmdict_dictionary.dart'
    show
        DictionaryWord,
        JmdictDictionary,
        JmdictFormatException,
        jmdictSchemaVersion;
export 'src/kana.dart' show hasKanji, isKanaOnly, toHiragana, toKatakana;
export 'src/models.dart'
    show
        DictionaryInfo,
        GlyphEdit,
        GlyphEditKind,
        HeadwordCandidate,
        HeadwordSuggestion,
        PairCheck,
        PairMatch,
        SuggestionBasis,
        WordClass,
        wordClassesOf;
export 'src/priority.dart' show Priority, PriorityTag;
