/// Which way a page was read: the row template of the known word books, or
/// the general extractor, and why.
library;

/// `CaptureDraft.templateId` of pages read by the general extractor.
const String generalTemplateId = 'general';

enum CaptureRoute {
  /// The row template (number, headword, reading, POS, meaning per row).
  template,

  /// The layout-free general extractor.
  general,
}

/// Why a page took its route.
enum RouteReason {
  /// The row template fits the page on every check.
  fits,

  /// Fewer than three numbered rows or entries: not a word-book page.
  noRows,

  /// Two rows carry the same number: rows were shifted.
  duplicateNumbers,

  /// Too many rows without a meaning.
  missingMeanings,

  /// Too many kanji headwords without a reading.
  missingReadings,

  /// Too many rows without a headword.
  missingHeadwords,

  /// Word numbers in a column do not count up.
  numberOrder,

  /// The column positions could not be measured on the page.
  columnsNotMeasured,
}

/// What the row template made of a page, measured before any corrector ran.
final class TemplateFit {
  const TemplateFit({
    required this.entries,
    required this.numberedRows,
    required this.duplicateNumbers,
    required this.missingMeanings,
    required this.missingReadings,
    required this.missingHeadwords,
    required this.numberOrder,
    required this.columnsMeasured,
  });

  /// Rows the template returned.
  final int entries;

  /// Word numbers read on the page.
  final int numberedRows;

  /// Rows whose number an earlier row already has.
  final int duplicateNumbers;

  /// Rows with an empty meaning cell.
  final int missingMeanings;

  /// Rows whose headword has kanji but whose reading cell is empty.
  final int missingReadings;

  /// Rows with an empty headword cell.
  final int missingHeadwords;

  /// Share of neighbouring numbers in a column that count up by 1 to 3
  /// (a skipped number or two is a misread, not a shift); 1 with fewer than
  /// two numbers in every column.
  final double numberOrder;

  /// The template measured the page's column positions.
  final bool columnsMeasured;

  @override
  bool operator ==(Object other) =>
      other is TemplateFit &&
      other.entries == entries &&
      other.numberedRows == numberedRows &&
      other.duplicateNumbers == duplicateNumbers &&
      other.missingMeanings == missingMeanings &&
      other.missingReadings == missingReadings &&
      other.missingHeadwords == missingHeadwords &&
      other.numberOrder == numberOrder &&
      other.columnsMeasured == columnsMeasured;

  @override
  int get hashCode => Object.hash(
    entries,
    numberedRows,
    duplicateNumbers,
    missingMeanings,
    missingReadings,
    missingHeadwords,
    numberOrder,
    columnsMeasured,
  );

  @override
  String toString() =>
      'TemplateFit(rows $entries, numbers $numberedRows, dup $duplicateNumbers, '
      'no meaning $missingMeanings, no reading $missingReadings, '
      'no headword $missingHeadwords, order ${numberOrder.toStringAsFixed(2)}, '
      'columns ${columnsMeasured ? 'measured' : 'default'})';
}

/// The route of one page, with the numbers it was decided on.
final class RouteDecision {
  const RouteDecision({
    required this.route,
    required this.reasons,
    required this.fit,
  });

  final CaptureRoute route;

  /// [RouteReason.fits] alone for the template; every failed check for the
  /// general extractor.
  final List<RouteReason> reasons;
  final TemplateFit fit;

  /// One line for the review screen (`범용 추출 · 번호 겹침 2 · 빈 뜻 7/18`).
  String get summary => [
    route == CaptureRoute.template ? '가로줄 틀' : '범용 추출',
    for (final r in reasons) _label(r),
  ].join(' · ');

  String _label(RouteReason r) => switch (r) {
    RouteReason.fits => '번호 ${fit.numberedRows}줄이 틀에 맞음',
    RouteReason.noRows => '단어장 번호 줄 없음',
    RouteReason.duplicateNumbers => '번호 겹침 ${fit.duplicateNumbers}',
    RouteReason.missingMeanings => '빈 뜻 ${fit.missingMeanings}/${fit.entries}',
    RouteReason.missingReadings => '빈 읽기 ${fit.missingReadings}/${fit.entries}',
    RouteReason.missingHeadwords =>
      '빈 표제어 ${fit.missingHeadwords}/${fit.entries}',
    RouteReason.numberOrder => '번호 순서 어긋남',
    RouteReason.columnsNotMeasured => '칸 위치를 재지 못함',
  };

  @override
  bool operator ==(Object other) =>
      other is RouteDecision &&
      other.route == route &&
      other.fit == fit &&
      other.reasons.length == reasons.length &&
      [
        for (var i = 0; i < reasons.length; i++) other.reasons[i] == reasons[i],
      ].every((same) => same);

  @override
  int get hashCode => Object.hash(route, fit, Object.hashAll(reasons));

  @override
  String toString() => 'RouteDecision(${route.name}: $summary)';
}
