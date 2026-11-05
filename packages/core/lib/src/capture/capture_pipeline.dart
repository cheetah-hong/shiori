import 'package:shiori_core/src/capture/correctors/badge_misread_corrector.dart';
import 'package:shiori_core/src/capture/correctors/confusable_glyph_corrector.dart';
import 'package:shiori_core/src/capture/correctors/cut_meaning_flagger.dart';
import 'package:shiori_core/src/capture/correctors/dictionary_candidate_corrector.dart';
import 'package:shiori_core/src/capture/correctors/dictionary_pair_corrector.dart';
import 'package:shiori_core/src/capture/correctors/kana_okurigana_corrector.dart';
import 'package:shiori_core/src/capture/correctors/meaning_punctuation_corrector.dart';
import 'package:shiori_core/src/capture/correctors/missing_field_flagger.dart';
import 'package:shiori_core/src/capture/correctors/pos_inference_corrector.dart';
import 'package:shiori_core/src/capture/correctors/reading_lookalike_corrector.dart';
import 'package:shiori_core/src/capture/scan_preparation.dart';
import 'package:shiori_core/src/capture/vocab/entry_template.dart';
import 'package:shiori_core/src/capture/vocab/list_template.dart';
import 'package:shiori_core/src/capture/template_registry.dart';
import 'package:shiori_core/src/models/capture_draft.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/ocr.dart';
import 'package:shiori_core/src/ports/dictionary.dart';
import 'package:shiori_core/src/ports/entry_corrector.dart';

/// OCR scan → line clean-up → template → corrector chain → review draft.
///
/// Recognition (`TextRecognizer`) is a separate step so the caller can show
/// progress and choose which recognizer block to use.
final class CapturePipeline {
  CapturePipeline({
    required this.templates,
    required List<EntryCorrector> correctors,
  }) : correctors = List.unmodifiable(correctors);

  /// The blocks the reference scores were measured with.
  factory CapturePipeline.standard({
    Dictionary dictionary = const EmptyDictionary(),
  }) => CapturePipeline(
    templates: TemplateRegistry(const [
      ListPageTemplate(),
      EntryPageTemplate(),
    ]),
    correctors: standardCorrectors(dictionary),
  );

  final TemplateRegistry templates;
  final List<EntryCorrector> correctors;

  /// Parses [scan] with the detected template, or with [templateId] when given.
  Future<CaptureDraft> fromScan(OcrScan scan, {String? templateId}) async {
    final prepared = prepareScan(scan);
    final template =
        (templateId == null ? null : templates.byId(templateId)) ??
        templates.detect(prepared);
    final result = template.parse(prepared);
    final entries = <CapturedEntry>[];
    for (final raw in result.entries) {
      var entry = raw;
      for (final corrector in correctors) {
        entry = await corrector.correct(entry);
      }
      entries.add(entry);
    }
    return CaptureDraft(
      templateId: template.id,
      meta: result.meta,
      entries: List.unmodifiable(entries),
      recognitionTime: scan.elapsed,
    );
  }
}

/// Order matters: fix glyphs first (the POS guess needs the fixed headword),
/// then offer dictionary candidates for unread headwords, then check the read
/// ones against the dictionary (which may undo a rule), flag last.
///
/// The glyph fixes for ML Kit's slips (`のリかえる`, badge `8`, `싸다. 포장하다`)
/// never change an Apple Vision result, so they run for every engine.
List<EntryCorrector> standardCorrectors(Dictionary dictionary) => [
  const ConfusableGlyphCorrector(),
  const KanaOkuriganaCorrector(),
  const ReadingLookalikeCorrector(),
  const BadgeMisreadCorrector(),
  const MeaningPunctuationCorrector(),
  const PosInferenceCorrector(),
  const CutMeaningFlagger(),
  DictionaryCandidateCorrector(dictionary),
  DictionaryPairCorrector(dictionary),
  const MissingFieldFlagger(),
];
