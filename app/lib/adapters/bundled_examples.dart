import 'dart:convert';
import 'dart:io';

import 'package:example_block/example_block.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shiori/adapters/dictionary_problem.dart';
import 'package:shiori/adapters/unpacked_asset.dart';
import 'package:shiori_core/shiori_core.dart';

/// gzip of the example sentence SQLite file (tools/dict/build_examples.py).
const examplesAsset = 'assets/dict/examples.sqlite.gz';

/// Which data the asset holds: JSON written next to it by the same script.
const examplesEditionAsset = 'assets/dict/examples.edition.json';

/// Where the asset is unpacked inside the app cache folder.
const examplesFileName = 'examples.sqlite';

/// The edition file that was unpacked, kept next to the SQLite file.
const examplesMarkerName = 'examples.sqlite.edition';

/// The sentences inside the example asset (shown on the 정보 screen).
final class ExamplesEdition {
  const ExamplesEdition({
    required this.builtOn,
    required this.edition,
    required this.license,
    required this.licenseUrl,
    required this.url,
    required this.attribution,
  });

  /// Throws [FormatException] when a field is missing.
  factory ExamplesEdition.fromJson(Map<String, Object?> json) {
    String field(Map<String, Object?> from, String key) => switch (from[key]) {
      final String v when v.isNotEmpty => v,
      _ => throw FormatException('examples edition: no $key'),
    };
    final source = switch (json['sources']) {
      [final Map<String, Object?> s, ...] => s,
      _ => throw const FormatException('examples edition: no sources'),
    };
    return ExamplesEdition(
      builtOn: field(json, 'built_on'),
      edition: field(source, 'edition'),
      license: field(source, 'license'),
      licenseUrl: field(source, 'license_url'),
      url: field(source, 'url'),
      attribution: field(json, 'attribution'),
    );
  }

  /// Day the asset was built.
  final String builtOn;

  /// Day of the Tatoeba export the sentences are from.
  final String edition;

  final String license;
  final String licenseUrl;

  /// Tatoeba's site.
  final String url;

  /// The credit line the licence asks for.
  final String attribution;
}

/// The example sentences the app runs with, or nothing and why.
final class BundledExamples {
  const BundledExamples.opened(TatoebaExamples this.examples, this.edition)
    : problem = null,
      problemKind = null;

  const BundledExamples.unavailable(
    String this.problem, {
    this.problemKind = DictionaryProblem.missing,
  }) : examples = null,
       edition = null;

  final TatoebaExamples? examples;
  final ExamplesEdition? edition;

  /// Why there are no sentences (for the log and the 정보 screen).
  final String? problem;

  /// What kind of problem [problem] is; null when the sentences are open.
  final DictionaryProblem? problemKind;

  bool get isAvailable => examples != null;

  /// The block for the example slot.
  ExampleSentences get sentences => examples ?? const EmptyExampleSentences();

  void close() => examples?.close();
}

/// Unpacks the bundled example sentences into [supportDirectory] when their
/// edition changed, then opens them (checked against the edition's sizes and
/// sha256, as the dictionaries are). Never throws: without the asset (a
/// debug build may not have it; a release build always does,
/// tools/dict/asset_check.py --release) or with a damaged one, one log line
/// and [BundledExamples.unavailable]: cards then show only page examples.
Future<BundledExamples> openBundledExamples({
  required AssetBundle bundle,
  required Future<Directory> Function() supportDirectory,
  void Function(String message) log = _log,
}) async {
  BundledExamples without(Object error, DictionaryProblem kind) {
    final problem = '$error'.split('\n').first;
    log('not available: $problem');
    return BundledExamples.unavailable(problem, problemKind: kind);
  }

  final String editionText;
  try {
    editionText = await bundle.loadString(examplesEditionAsset, cache: false);
  } on Object catch (error) {
    return without(error, DictionaryProblem.missing);
  }
  try {
    final edition = switch (jsonDecode(editionText)) {
      final Map<String, Object?> json => ExamplesEdition.fromJson(json),
      _ => throw const FormatException('examples edition: not a JSON object'),
    };
    final opened = await openUnpackedAsset(
      bundle: bundle,
      gzipAsset: examplesAsset,
      editionText: editionText,
      dir: await supportDirectory(),
      fileName: examplesFileName,
      markerName: examplesMarkerName,
      expected: AssetDigest.fromEditionText(editionText),
      open: (file) => TatoebaExamples.open(file.path),
      log: log,
    );
    return BundledExamples.opened(opened.value, edition);
  } on Object catch (error) {
    return without(error, dictionaryProblemOf(error));
  }
}

/// [openBundledExamples] with the app's asset bundle and cache folder.
Future<BundledExamples> openAppExamples() => openBundledExamples(
  bundle: rootBundle,
  supportDirectory: getApplicationCacheDirectory,
);

void _log(String message) => debugPrint('[shiori] examples: $message');
