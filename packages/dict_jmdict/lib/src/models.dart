/// Where the data came from; read from the database's `meta` table.
final class DictionaryInfo {
  const DictionaryInfo(this.values);

  final Map<String, String> values;

  int get schemaVersion => int.tryParse(values['schema_version'] ?? '') ?? 0;

  /// Date in the JMdict file header, for example `2026-11-04`.
  String get jmdictCreated => values['jmdict_created'] ?? '';
  String get sourceSha256 => values['source_sha256'] ?? '';
  int get entryCount => int.tryParse(values['entry_count'] ?? '') ?? 0;

  /// `all` or `common` entries.
  String get entries => values['entries'] ?? '';

  /// `all`, `first` or `none` English glosses.
  String get glosses => values['glosses'] ?? '';
  String get license => values['license'] ?? '';
  String get licenseUrl => values['license_url'] ?? '';
  String get projectUrl => values['project_url'] ?? '';

  /// The notice the EDRDG licence requires the app to show.
  String get attribution => values['attribution'] ?? '';
}
