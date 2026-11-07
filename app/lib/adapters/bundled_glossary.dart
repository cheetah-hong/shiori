import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:krdict_block/krdict_block.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shiori/adapters/dictionary_problem.dart';
import 'package:shiori/adapters/unpacked_asset.dart';
import 'package:shiori_core/shiori_core.dart';

/// gzip of the Korean glossary SQLite file (tools/dict/build_ko_glossary.py).
const glossaryAsset = 'assets/dict/ko-glossary.sqlite.gz';

/// Which data the asset holds: JSON written next to it by the same script.
const glossaryEditionAsset = 'assets/dict/ko-glossary.edition.json';

/// Where the asset is unpacked inside the app cache folder.
const glossaryFileName = 'ko-glossary.sqlite';

/// The edition file that was unpacked, kept next to the SQLite file.
const glossaryMarkerName = 'ko-glossary.sqlite.edition';

/// gzip of the Wiktionary fallback glossary (tools/dict/build_wikt_glossary.py):
/// meanings of words the Basic Korean Dictionary has none for.
const wiktGlossaryAsset = 'assets/dict/wikt-glossary.sqlite.gz';

/// The fallback asset's edition file, written next to it by the same script.
const wiktGlossaryEditionAsset = 'assets/dict/wikt-glossary.edition.json';

/// Where the fallback asset is unpacked inside the app cache folder.
const wiktGlossaryFileName = 'wikt-glossary.sqlite';

/// The fallback edition file that was unpacked, kept next to its SQLite file.
const wiktGlossaryMarkerName = 'wikt-glossary.sqlite.edition';

/// The data inside the glossary asset (shown on the 정보 screen).
final class GlossaryEdition {
  const GlossaryEdition({
    required this.variant,
    required this.builtOn,
    required this.sources,
  });

  /// Throws [FormatException] when a field is missing or a source is unknown.
  factory GlossaryEdition.fromJson(Map<String, Object?> json) {
    String field(Map<String, Object?> from, String key) => switch (from[key]) {
      final String v when v.isNotEmpty => v,
      _ => throw FormatException('glossary edition: no $key'),
    };
    final sources = switch (json['sources']) {
      final List<Object?> list when list.isNotEmpty => [
        for (final s in list)
          switch (s) {
            final Map<String, Object?> m => GlossarySourceInfo(
              source: _sourceNamed(field(m, 'source')),
              publisher: field(m, 'publisher'),
              license: field(m, 'license'),
              licenseUrl: field(m, 'license_url'),
              edition: field(m, 'edition'),
            ),
            _ => throw const FormatException('glossary edition: bad source'),
          },
      ],
      _ => throw const FormatException('glossary edition: no sources'),
    };
    return GlossaryEdition(
      variant: field(json, 'variant'),
      builtOn: field(json, 'built_on'),
      sources: List.unmodifiable(sources),
    );
  }

  /// `lean`: Korean words only, no definitions.
  final String variant;

  /// Day the asset was built.
  final String builtOn;

  /// Each dictionary in the asset with its edition date and licence.
  final List<GlossarySourceInfo> sources;
}

GlossarySource _sourceNamed(String name) => GlossarySource.values.firstWhere(
  (s) => s.name == name,
  orElse: () => throw FormatException('glossary edition: unknown source $name'),
);

/// The Korean glossary the app runs with, or nothing and why.
final class BundledGlossary {
  const BundledGlossary.opened(
    KrdictGlossary this.krdict,
    this.edition, {
    this.wiktionary,
    this.wiktionaryEdition,
    this.wiktionaryProblem,
    this.wiktionaryProblemKind,
  }) : problem = null,
       problemKind = null;

  const BundledGlossary.unavailable(
    String this.problem, {
    this.problemKind = DictionaryProblem.missing,
  }) : krdict = null,
       edition = null,
       wiktionary = null,
       wiktionaryEdition = null,
       wiktionaryProblem = null,
       wiktionaryProblemKind = null;

  final KrdictGlossary? krdict;
  final GlossaryEdition? edition;

  /// The Wiktionary fallback glossary (meanings the Basic Korean Dictionary
  /// has none for), or null without its asset.
  final KrdictGlossary? wiktionary;
  final GlossaryEdition? wiktionaryEdition;

  /// Why there is no fallback glossary (for the log).
  final String? wiktionaryProblem;

  /// What kind of problem [wiktionaryProblem] is (the 정보 screen tells a
  /// build without the asset from a damaged one); null when it is open.
  final DictionaryProblem? wiktionaryProblemKind;

  /// Why there is no glossary (for the log and the 정보 screen).
  final String? problem;

  /// What kind of problem [problem] is; null when the data is open.
  final DictionaryProblem? problemKind;

  bool get isAvailable => krdict != null;

  /// The block for the glossary slot.
  KoreanGlossary get glossary => krdict ?? const EmptyKoreanGlossary();

  void close() {
    krdict?.close();
    wiktionary?.close();
  }
}

/// Unpacks the bundled Korean glossary into [supportDirectory] when its
/// edition changed, then opens it (as `openBundledDictionary` does for
/// JMdict, checked against the edition's sizes and sha256). Never throws: any
/// failure is logged and answered with [BundledGlossary.unavailable] (meaning
/// cells are then never filled), sorted as in `openBundledDictionary`.
Future<BundledGlossary> openBundledGlossary({
  required AssetBundle bundle,
  required Future<Directory> Function() supportDirectory,
  void Function(String message) log = _log,
}) async {
  final String editionText;
  try {
    editionText = await bundle.loadString(glossaryEditionAsset, cache: false);
  } on Object catch (error) {
    log('not in this build: $error');
    return BundledGlossary.unavailable('$error');
  }
  try {
    final edition = switch (jsonDecode(editionText)) {
      final Map<String, Object?> json => GlossaryEdition.fromJson(json),
      _ => throw const FormatException('glossary edition: not a JSON object'),
    };
    final opened = await openUnpackedAsset(
      bundle: bundle,
      gzipAsset: glossaryAsset,
      editionText: editionText,
      dir: await supportDirectory(),
      fileName: glossaryFileName,
      markerName: glossaryMarkerName,
      expected: AssetDigest.fromEditionText(editionText),
      open: (file) => KrdictGlossary.open(file.path),
      log: log,
    );
    if (opened.unpacked) {
      log(
        'unpacked ${edition.variant}, '
        '${[for (final s in edition.sources) '${s.source.name} ${s.edition}'].join(', ')}',
      );
    }
    final fallback = await _openWiktionary(bundle, supportDirectory, log);
    return BundledGlossary.opened(
      opened.value,
      edition,
      wiktionary: fallback.glossary,
      wiktionaryEdition: fallback.edition,
      wiktionaryProblem: fallback.problem,
      wiktionaryProblemKind: fallback.kind,
    );
  } on Object catch (error, stack) {
    log('not available: $error\n$stack');
    return BundledGlossary.unavailable(
      '$error',
      problemKind: dictionaryProblemOf(error),
    );
  }
}

/// The fallback glossary opened, or why not.
typedef _Fallback = ({
  KrdictGlossary? glossary,
  GlossaryEdition? edition,
  String? problem,
  DictionaryProblem? kind,
});

/// The Wiktionary fallback glossary, unpacked and opened like the glossary;
/// without it (a debug build may not have it, a release build always does:
/// tools/dict/asset_check.py --release) one log line and no fallback.
Future<_Fallback> _openWiktionary(
  AssetBundle bundle,
  Future<Directory> Function() supportDirectory,
  void Function(String message) log,
) async {
  _Fallback without(Object error, DictionaryProblem kind) {
    final problem = '$error'.split('\n').first;
    log('wiktionary not available: $problem');
    return (glossary: null, edition: null, problem: problem, kind: kind);
  }

  final String editionText;
  try {
    editionText = await bundle.loadString(
      wiktGlossaryEditionAsset,
      cache: false,
    );
  } on Object catch (error) {
    return without(error, DictionaryProblem.missing);
  }
  try {
    final edition = switch (jsonDecode(editionText)) {
      final Map<String, Object?> json => GlossaryEdition.fromJson(json),
      _ => throw const FormatException('wiktionary edition: not a JSON object'),
    };
    final opened = await openUnpackedAsset(
      bundle: bundle,
      gzipAsset: wiktGlossaryAsset,
      editionText: editionText,
      dir: await supportDirectory(),
      fileName: wiktGlossaryFileName,
      markerName: wiktGlossaryMarkerName,
      expected: AssetDigest.fromEditionText(editionText),
      open: (file) => KrdictGlossary.open(file.path),
      log: log,
    );
    if (opened.unpacked) log('unpacked wiktionary ${edition.builtOn}');
    return (
      glossary: opened.value,
      edition: edition,
      problem: null,
      kind: null,
    );
  } on Object catch (error) {
    return without(error, dictionaryProblemOf(error));
  }
}

/// [openBundledGlossary] with the app's asset bundle and cache folder (a
/// file made again from the asset, so it stays out of device backups).
Future<BundledGlossary> openAppGlossary() => openBundledGlossary(
  bundle: rootBundle,
  supportDirectory: getApplicationCacheDirectory,
);

void _log(String message) => debugPrint('[shiori] glossary: $message');
