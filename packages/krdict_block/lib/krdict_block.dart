/// The Korean meaning block: [KrdictGlossary] implements the core
/// `KoreanGlossary` port over the SQLite file built by
/// tools/dict/build_ko_glossary.py.
///
/// Data: 한국어기초사전 (Basic Korean Dictionary) by the National Institute of
/// Korean Language, CC BY-SA 2.0 KR. Apps must show
/// `GlossarySourceInfo.attribution` for every entry of [KrdictGlossary.sources].
library;

export 'src/keys.dart' show pairKey;
export 'src/krdict_glossary.dart';
