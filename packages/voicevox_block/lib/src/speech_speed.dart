import 'dart:convert';

/// Speed of every sound the app makes: the engine default (1.0), ordinary
/// speaking speed. The calm narration voice (VOICEVOX Nemo) is slow enough at
/// it; the earlier character voice was said at 0.85.
const speechSpeedScale = 1.0;

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
