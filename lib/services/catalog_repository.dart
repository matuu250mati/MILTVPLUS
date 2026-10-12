import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

/// Read-only access to the published MILTV PLUS catalog.
/// RLS requires a signed-in Supabase user for catalog queries.
class CatalogRepository {
  const CatalogRepository();

  SupabaseClient? get _client =>
      isSupabaseConfigured ? Supabase.instance.client : null;

  Future<List<Map<String, dynamic>>> channels() =>
      _read('channels', orderBy: 'sort_order');

  Future<List<Map<String, dynamic>>> movies() =>
      _read('movies', orderBy: 'title');

  Future<List<Map<String, dynamic>>> series() =>
      _read('series', orderBy: 'title');

  Future<List<Map<String, dynamic>>> episodes(String seriesId) async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) return [];
    final rows = await client
        .from('episodes')
        .select()
        .eq('series_id', seriesId)
        .eq('is_published', true)
        .order('season_number')
        .order('episode_number');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> _read(
    String table, {
    required String orderBy,
  }) async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) return [];
    final rows = await client
        .from(table)
        .select()
        .eq('is_published', true)
        .order(orderBy);
    return List<Map<String, dynamic>>.from(rows);
  }
}
