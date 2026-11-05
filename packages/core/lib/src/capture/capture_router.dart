/// Per page: the row template when it clearly fits, the general extractor
/// otherwise (docs/extraction.md, 9).
library;

import 'package:shiori_core/src/capture/capture_pipeline.dart';
import 'package:shiori_core/src/capture/template_evidence.dart';
import 'package:shiori_core/src/capture/vocab/anchors.dart';
import 'package:shiori_core/src/extract/general_extractor.dart';
import 'package:shiori_core/src/models/capture_draft.dart';
import 'package:shiori_core/src/models/capture_route.dart';
import 'package:shiori_core/src/models/ocr.dart';
import 'package:shiori_core/src/ports/textbook_template.dart';

/// At least this many numbered rows and entries: a word-book page.
const int routeMinRows = 3;

/// At most this share of rows may have no meaning (a cut or unread one).
const double routeMaxMissingMeaningShare = 0.15;

/// At most this share of kanji headwords may have no reading.
const double routeMaxMissingReadingShare = 0.05;

/// At most this share of rows may have no headword. An unread headword
/// alone does not shift a row (ML Kit misses printed numerals: 4 of 15 on a
/// recorded page), so the bar is a third.
const double routeMaxMissingHeadwordShare = 1 / 3;

/// At least this share of neighbouring numbers must count up by 1 to 3.
const double routeMinNumberOrder = 0.8;

/// Numbers whose x differ by less than this sit in one column (as the
/// template's own number columns).
const double _columnTolerance = 0.12;

/// The largest step between neighbouring numbers that still counts up.
const int _maxNumberStep = 3;

/// The route for a page the row template made [fit] of. Every check must
/// pass for the template; a doubtful page goes to the general extractor.
RouteDecision chooseRoute(TemplateFit fit) {
  if (fit.entries < routeMinRows || fit.numberedRows < routeMinRows) {
    return RouteDecision(
      route: CaptureRoute.general,
      reasons: const [RouteReason.noRows],
      fit: fit,
    );
  }
  double share(int n) => n / fit.entries;
  final reasons = [
    if (fit.duplicateNumbers > 0) RouteReason.duplicateNumbers,
    if (share(fit.missingMeanings) > routeMaxMissingMeaningShare)
      RouteReason.missingMeanings,
    if (share(fit.missingReadings) > routeMaxMissingReadingShare)
      RouteReason.missingReadings,
    if (share(fit.missingHeadwords) > routeMaxMissingHeadwordShare)
      RouteReason.missingHeadwords,
    if (fit.numberOrder < routeMinNumberOrder) RouteReason.numberOrder,
    if (!fit.columnsMeasured) RouteReason.columnsNotMeasured,
  ];
  return RouteDecision(
    route: reasons.isEmpty ? CaptureRoute.template : CaptureRoute.general,
    reasons: reasons.isEmpty ? const [RouteReason.fits] : reasons,
    fit: fit,
  );
}

/// What the row template made of [prepared]: its raw rows (before the
/// correctors, so a filled-in meaning does not hide a shifted row) and the
/// word numbers on the page.
TemplateFit measureTemplateFit(OcrScan prepared, TemplateResult result) {
  final rows = result.entries;
  final seen = <String>{};
  var duplicates = 0;
  for (final e in rows) {
    final no = e.no;
    if (no != null && !seen.add(no)) duplicates++;
  }
  final numbered = [
    for (final a in findAnchors(prepared.japanese.lines))
      if (a.no case final no?) (x: a.line.x, cy: a.line.cy, no: int.parse(no)),
  ];
  return TemplateFit(
    entries: rows.length,
    numberedRows: numbered.length,
    duplicateNumbers: duplicates,
    missingMeanings: rows.where((e) => e.meaning.trim().isEmpty).length,
    missingReadings: rows
        .where((e) => e.readings.isEmpty && e.headword.runes.any(_isKanji))
        .length,
    missingHeadwords: rows.where((e) => e.headword.trim().isEmpty).length,
    numberOrder: _numberOrder(numbered),
    columnsMeasured: !(result.columnScale?.isDefault ?? true),
  );
}

double _numberOrder(List<({double x, double cy, int no})> numbers) {
  final byX = [...numbers]..sort((a, b) => a.x.compareTo(b.x));
  final columns = <List<({double x, double cy, int no})>>[];
  for (final n in byX) {
    if (columns.isNotEmpty && n.x - columns.last.first.x < _columnTolerance) {
      columns.last.add(n);
    } else {
      columns.add([n]);
    }
  }
  var pairs = 0, ok = 0;
  for (final column in columns) {
    column.sort((a, b) => a.cy.compareTo(b.cy));
    for (var i = 1; i < column.length; i++) {
      pairs++;
      final step = column[i].no - column[i - 1].no;
      if (step >= 1 && step <= _maxNumberStep) ok++;
    }
  }
  return pairs == 0 ? 1 : ok / pairs;
}

bool _isKanji(int c) => (c >= 0x4E00 && c <= 0x9FFF) || c == 0x3005;

/// OCR scan → route → review draft.
///
/// The row template parses every page first (a few ms); its rows decide the
/// route. Template pages come out with the values [template] gives them,
/// plus the evidence of each cell (from [general]'s lexicon and glosses); the
/// others go through [general], minus the headwords the learner already
/// has.
final class CaptureRouter {
  CaptureRouter({required this.template, required this.general});

  final CapturePipeline template;
  final GeneralExtractor general;

  /// [knownHeadwords]: every headword in the learner's library (hidden words
  /// too). Only the general extractor leaves them out; a template page
  /// captured again updates its words instead. [lookupKnown] gives them
  /// only when a page goes to the general extractor (the library is not
  /// read for template pages); its headwords are added to [knownHeadwords].
  Future<CaptureDraft> fromScan(
    OcrScan scan, {
    Set<String> knownHeadwords = const {},
    Future<Set<String>> Function()? lookupKnown,
  }) async {
    final attempt = template.attempt(scan);
    final decision = chooseRoute(
      measureTemplateFit(attempt.prepared, attempt.result),
    );
    if (decision.route == CaptureRoute.template) {
      final draft = await template.finish(scan, attempt);
      // Evidence only: the template's values and flags stay as they are.
      return draft.copyWith(
        route: decision,
        entries: await withTemplateEvidence(
          draft.entries,
          lexicon: general.lexicon,
          glosses: general.koreanGlosses,
          page: attempt.prepared,
        ),
      );
    }
    final known = lookupKnown == null
        ? knownHeadwords
        : {...knownHeadwords, ...await lookupKnown()};
    final extraction = await general.extract(scan, knownHeadwords: known);
    return CaptureDraft(
      templateId: generalTemplateId,
      meta: attempt.result.meta,
      entries: List.unmodifiable([
        for (final w in extraction.words)
          w.toCapturedEntry(fragments: extraction.fragments),
      ]),
      recognitionTime: scan.elapsed,
      route: decision,
      unpaired: extraction.unpaired,
      skippedKnown: extraction.skippedKnown,
    );
  }
}
