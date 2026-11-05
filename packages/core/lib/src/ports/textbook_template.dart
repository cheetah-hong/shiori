import 'package:shiori_core/src/models/capture_draft.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/ocr.dart';

/// Block slot: knows the layout of one kind of textbook page.
///
/// First blocks: `ListPageTemplate` (A, N5·N4 lists) and
/// `EntryPageTemplate` (B, N3 entries with examples).
abstract interface class TextbookTemplate {
  /// Stable id stored with drafts and textbooks, for example `vocab.list`.
  String get id;

  /// Name shown to the learner, for example `목록형 (N5·N4)`.
  String get label;

  /// Default title for a new textbook created from this layout.
  String get suggestedTextbookTitle;

  /// How well [scan] fits this layout: 0 = not this layout, 1 = certain.
  /// `TemplateRegistry` picks the highest score; ties go to the first registered.
  double match(OcrScan scan);

  /// Raw entries (before correctors) and page metadata.
  TemplateResult parse(OcrScan scan);
}

final class TemplateResult {
  const TemplateResult({required this.entries, required this.meta});

  final List<CapturedEntry> entries;
  final PageMeta meta;
}
