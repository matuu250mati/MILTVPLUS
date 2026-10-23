import 'package:shared_preferences/shared_preferences.dart';

const _cacheKey = 'miltv_plus_channels_cache_json_v1';

/// Browser/non-IO fallback. Keep the web target free of dart:io imports.
Future<String?> readCache() async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.getString(_cacheKey);
}

Future<void> writeCache(String contents) async {
  final preferences = await SharedPreferences.getInstance();
  final saved = await preferences.setString(_cacheKey, contents);
  if (!saved) {
    throw StateError('No se pudo guardar la caché de canales en este dispositivo.');
  }
}
