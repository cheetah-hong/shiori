import 'package:shiori_core/src/capture/correctors/confusable_glyph_corrector.dart';
import 'package:shiori_core/src/capture/correctors/dictionary_candidate_corrector.dart';
import 'package:shiori_core/src/capture/correctors/kana_okurigana_corrector.dart';
import 'package:shiori_core/src/capture/correctors/missing_field_flagger.dart';
import 'package:shiori_core/src/capture/vocab/entry_template.dart';
import 'package:shiori_core/src/capture/vocab/list_template.dart';
import 'package:shiori_core/src/capture/template_registry.dart';
import 'package:shiori_core/src/models/capture_draft.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/ocr.dart';
import 'package:shiori_core/src/ports/dictionary.dart';
import 'package:shiori_core/src/ports/entry_corrector.dart';

/// OCR scan → template → corrector chain → review draft.
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
    final template =
        (templateId == null ? null : templates.byId(templateId)) ??
        templates.detect(scan);
    final result = template.parse(scan);
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

/// Order matters: fix glyphs first, then offer dictionary candidates, flag last.
List<EntryCorrector> standardCorrectors(Dictionary dictionary) => [
  const ConfusableGlyphCorrector(),
  const KanaOkuriganaCorrector(),
  DictionaryCandidateCorrector(dictionary),
  const MissingFieldFlagger(),
];
