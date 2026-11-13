/// Shiori core: models, ports (block slots), word capture and study logic.
///
/// Pure Dart. The app plugs adapters into the ports; this package knows none of them.
library;

// Models
export 'src/models/capture_draft.dart';
export 'src/models/captured_entry.dart';
export 'src/models/evidence.dart';
export 'src/models/library.dart';
export 'src/models/ocr.dart';
export 'src/models/page_image.dart';
export 'src/models/part_of_speech.dart';
export 'src/models/review.dart';
export 'src/models/study_mode.dart';
export 'src/models/study_preferences.dart';
export 'src/models/study_setting_keys.dart';
export 'src/models/word_key.dart';

// Ports: the slots blocks plug into
export 'src/ports/backup_keeper.dart';
export 'src/ports/backup_store.dart';
export 'src/ports/clock.dart';
export 'src/ports/example_sentences.dart';
export 'src/ports/fallback_glossary.dart';
export 'src/ports/hidden_word_repository.dart';
export 'src/ports/lexicon.dart';
export 'src/ports/image_source.dart';
export 'src/ports/korean_glossary.dart';
export 'src/ports/meaning_overrides.dart';
export 'src/ports/repositories.dart';
export 'src/ports/review_scheduler.dart';
export 'src/ports/speech.dart';
export 'src/ports/study_preferences_repository.dart';
export 'src/ports/text_recognizer.dart';

// Capture: the review screen's edits, recorded OCR
export 'src/capture/evidence_edits.dart';
export 'src/capture/fixture_text_recognizer.dart';
export 'src/capture/learner_edits.dart';

// Word extraction that does not depend on a page layout
export 'src/extract/extracted_word.dart';
export 'src/extract/fragment.dart';
export 'src/extract/general_extractor.dart';
export 'src/extract/latin_debris.dart'
    show latinDebrisRemovedNote, latinDebrisUnsureNote;
export 'src/extract/meaning_senses.dart';
export 'src/extract/page_draft.dart';

// Backup files (설정 › 백업)
export 'src/backup/backup_codec.dart';
export 'src/backup/backup_data.dart';
export 'src/backup/backup_service.dart';

// Library and study use cases
export 'src/decks/builtin_deck.dart';
export 'src/decks/deck_draft.dart';
export 'src/library/library_service.dart';
export 'src/library/word_edit.dart';
export 'src/library/word_fill.dart';
export 'src/library/word_search.dart';
export 'src/study/card_example.dart';
export 'src/study/choice_maker.dart';
export 'src/study/leitner_four_step_scheduler.dart';
export 'src/study/review_reminders.dart';
export 'src/study/session_builder.dart';
export 'src/study/session_size.dart';
export 'src/study/study_calendar.dart';
export 'src/study/study_service.dart';
export 'src/study/study_session.dart';
export 'src/study/study_settings.dart';
export 'src/study/study_week.dart';

// First storage blocks
export 'src/storage/in_memory_library_repository.dart';
export 'src/storage/in_memory_review_repository.dart';
export 'src/storage/in_memory_study_preferences_repository.dart';
