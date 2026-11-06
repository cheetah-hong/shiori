import 'package:shiori/adapters/unpacked_asset.dart';

/// Why a bundled dictionary (JMdict, the Korean glossary) is not open.
enum DictionaryProblem {
  /// The app was built without the asset (development builds).
  missing,

  /// The asset or its edition file is not what it should be: cut short,
  /// damaged, from another build, or a field is missing.
  damaged,

  /// Anything else, such as a file that could not be written.
  failed,
}

/// The kind of problem [error] (thrown while opening a bundled dictionary
/// whose edition file is in the build) is: a mismatch with the edition, or an
/// edition or gzip that does not read, is [DictionaryProblem.damaged];
/// anything else is [DictionaryProblem.failed].
DictionaryProblem dictionaryProblemOf(Object error) => switch (error) {
  UnpackedAssetMismatch() || FormatException() => DictionaryProblem.damaged,
  _ => DictionaryProblem.failed,
};
