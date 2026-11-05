/// A page photo handed to a `TextRecognizer`.
///
/// For device recognizers [path] is a file path. `FixtureTextRecognizer`
/// treats it as the fixture name (`s140` loads `s140.ja.json` and `s140.ko.json`).
final class PageImage {
  const PageImage(this.path, {this.label});

  final String path;

  /// Optional caption for the UI, for example `샘플 140쪽`.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is PageImage && other.path == path && other.label == label;

  @override
  int get hashCode => Object.hash(path, label);

  @override
  String toString() => 'PageImage($path)';
}
