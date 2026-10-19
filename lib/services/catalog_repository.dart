import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';

/// Read-only access to the published MILTV PLUS catalog.
/// Public reads are limited by RLS to published entries; writes remain server-side.
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
    if (client == null) return [];
    const pageSize = 500;
    final allRows = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += pageSize) {
      final response = await client
          .from('episodes')
          .select()
          .eq('series_id', seriesId)
          .eq('is_published', true)
          .order('season_number')
          .order('episode_number')
          .order('id')
          .range(offset, offset + pageSize - 1);
      final pageRows = List<Map<String, dynamic>>.from(response);
      allRows.addAll(pageRows);
      if (pageRows.length < pageSize) break;
    }
    return allRows;
  }

  Future<List<Map<String, dynamic>>> _read(
    String table, {
    required String orderBy,
  }) async {
    final client = _client;
    if (client == null) return [];
    const pageSize = 500;
    final allRows = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += pageSize) {
      final response = await client
          .from(table)
          .select()
          .eq('is_published', true)
          .order(orderBy)
          .order('id')
          .range(offset, offset + pageSize - 1);
      final pageRows = List<Map<String, dynamic>>.from(response);
      allRows.addAll(pageRows);
      if (pageRows.length < pageSize) break;
    }
    return allRows;
  }
}
