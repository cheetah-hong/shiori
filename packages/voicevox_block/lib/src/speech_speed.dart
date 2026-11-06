import 'dart:convert';

/// Speed of every sound the app makes. The engine default (1.0) is ordinary
/// speaking speed, the same as the recorded audio of other learning apps, but
/// it sounded too fast for a learner hearing a new word, so words and example
/// sentences are said a little slower.
const speechSpeedScale = 0.85;

/// [queryJson] (an audio query of the engine) with its speed set to [scale].
/// Throws [FormatException] when it is not an object with a `speedScale`
/// number: a changed engine format must not quietly play at the old speed.
String withSpeedScale(String queryJson, double scale) {
  final Object? query;
  try {
    query = jsonDecode(queryJson);
  } on FormatException {
    throw const FormatException('audio query: not JSON');
  }
  if (query is! Map<String, Object?> || query['speedScale'] is! num) {
    throw const FormatException('audio query: no speedScale');
  }
  return jsonEncode({...query, 'speedScale': scale});
}
