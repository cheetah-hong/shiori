/// Shiori core: models, ports (block slots), capture pipeline and study logic.
///
/// Pure Dart. The app plugs adapters into the ports; this package knows none of them.
library;

// Models
export 'src/models/capture_draft.dart';
export 'src/models/captured_entry.dart';
export 'src/models/column_scale.dart';
export 'src/models/library.dart';
export 'src/models/ocr.dart';
export 'src/models/page_image.dart';
export 'src/models/part_of_speech.dart';
export 'src/models/review.dart';

// Ports: the slots blocks plug into
export 'src/ports/clock.dart';
export 'src/ports/dictionary.dart';
export 'src/ports/entry_corrector.dart';
export 'src/ports/image_source.dart';
export 'src/ports/repositories.dart';
export 'src/ports/review_scheduler.dart';
export 'src/ports/speech.dart';
export 'src/ports/star_meter.dart';
export 'src/ports/text_recognizer.dart';
export 'src/ports/textbook_template.dart';

// Capture: OCR lines → review draft
export 'src/capture/capture_pipeline.dart';
export 'src/capture/correctors/badge_misread_corrector.dart';
export 'src/capture/correctors/confusable_glyph_corrector.dart';
export 'src/capture/correctors/cut_meaning_flagger.dart';
export 'src/capture/correctors/dictionary_candidate_corrector.dart';
export 'src/capture/correctors/dictionary_pair_corrector.dart';
export 'src/capture/correctors/kana_okurigana_corrector.dart';
export 'src/capture/correctors/meaning_punctuation_corrector.dart';
export 'src/capture/correctors/missing_field_flagger.dart';
export 'src/capture/correctors/pos_inference_corrector.dart';
export 'src/capture/correctors/reading_lookalike_corrector.dart';
export 'src/capture/fixture_text_recognizer.dart';
export 'src/capture/learner_edits.dart';
export 'src/capture/star_check.dart';
export 'src/capture/vocab/entry_template.dart';
export 'src/capture/vocab/list_template.dart';
export 'src/capture/template_registry.dart';

// Library and study use cases
export 'src/library/library_service.dart';
export 'src/study/leitner_four_step_scheduler.dart';
export 'src/study/session_builder.dart';
export 'src/study/study_calendar.dart';
export 'src/study/study_service.dart';
export 'src/study/study_session.dart';
export 'src/study/study_settings.dart';

// First storage blocks
export 'src/storage/in_memory_library_repository.dart';
export 'src/storage/in_memory_review_repository.dart';
