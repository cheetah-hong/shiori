/// How the column positions of a page were scaled (rule 6).
library;

/// Where a page's column scale came from.
enum ColumnScaleSource {
  /// Measured from the reading column (number → kana cell distance).
  reading,

  /// Measured from the POS badge column: no reading column was read.
  badge,

  /// Fewer than two rows had a cell in either column: the default 1.0.
  tooFewRows,

  /// The measured scale was implausible (a misread, not a page crop): the
  /// default 1.0.
  outOfRange,
}

/// Horizontal scale of a page's columns and how it was found.
///
/// 1.0 is the frame the column offsets were set on (a photo of the open
/// book). A default scale means the columns could not be measured on this
/// page, so they may sit off when the image is framed differently.
final class ColumnScale {
  const ColumnScale(this.value, this.source);

  final double value;
  final ColumnScaleSource source;

  /// The columns were not measured: [value] is the default 1.0.
  bool get isDefault =>
      source == ColumnScaleSource.tooFewRows ||
      source == ColumnScaleSource.outOfRange;

  @override
  bool operator ==(Object other) =>
      other is ColumnScale && other.value == value && other.source == source;

  @override
  int get hashCode => Object.hash(value, source);

  @override
  String toString() => 'ColumnScale($value, ${source.name})';
}
