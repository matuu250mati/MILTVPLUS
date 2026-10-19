import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/media_models.dart';

/// Lecturas de catálogo publicadas. No usa service_role en el cliente.
class CatalogService {
  CatalogService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase {
    if (!isSupabaseConfigured) {
      throw StateError(
        'Supabase no está configurado. Revisá SUPABASE_URL y SUPABASE_ANON_KEY.',
      );
    }
    return _client ?? Supabase.instance.client;
  }


  /// User-submitted items become visible to everyone only after moderation approves them.
  Future<List<Map<String, dynamic>>> getApprovedSubmissions(String mediaType) async {
    final response = await _supabase
        .from('content_submissions')
        .select('title, description, stream_url, poster_url, duration_seconds, series_title, season_number, episode_number, media_type')
        .eq('moderation_status', 'approved')
        .eq('media_type', mediaType)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<List<ChannelModel>> getChannels({List<String>? categories, int? limit}) async {
    // Database category values are not always canonical: existing providers
    // use English labels, lowercase values, or broad categories such as
    // "General". Expand known aliases so the UI's canonical genre filter
    // does not discard valid published channels before name-based detection.
    final expandedCategories = <String>{};
    for (final category in categories ?? const <String>[]) {
      final normalized = category.trim().toLowerCase();
      switch (normalized) {
        case 'deportes':
        case 'sports':
        case 'sport':
          expandedCategories.addAll([
            category, 'Deportes', 'deportes', 'Sports', 'sports', 'Sport', 'sport',
          ]);
          break;
        case 'noticias':
        case 'news':
          expandedCategories.addAll([
            category, 'Noticias', 'noticias', 'News', 'news',
          ]);
          break;
        case 'cultura/documentales':
        case 'culture':
        case 'documentary':
          expandedCategories.addAll([
            category, 'Cultura/Documentales', 'culture', 'Culture',
            'documentary', 'Documentary', 'documentaries', 'Documentaries',
            'education', 'Education',
          ]);
          break;
        case 'hbo/cine':
        case 'movies':
        case 'cinema':
          expandedCategories.addAll([
            category, 'HBO/Cine', 'movies', 'Movies', 'cinema', 'Cinema',
            'film', 'Film', 'films', 'Films',
          ]);
          break;
        case 'tv argentina':
        case 'argentina':
          expandedCategories.addAll([
            category, 'TV Argentina', 'Argentina', 'argentina',
          ]);
          break;
        default:
          if (category.trim().isNotEmpty) expandedCategories.add(category.trim());
      }
      // Include generic database buckets as candidates. TvChannel.liveSection
      // performs the final classification from category, group and channel
      // name; otherwise a sports/news channel stored as "General" is never
      // returned by Supabase and cannot be classified by the UI.
      expandedCategories.addAll([
        'General',
        'general',
        'Entretenimiento y general',
        'entretenimiento y general',
        'Otros canales',
        'otros canales',
      ]);
    }

    // Supabase/PostgREST may cap a response at 1,000 rows. Fetch in stable,
    // bounded pages so the app does not silently hide most of the live catalog.
    const maxPageSize = 500;
    final rowLimit = limit != null && limit > 0 ? limit : null;
    final allRows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final remaining = rowLimit == null ? maxPageSize : rowLimit - allRows.length;
      if (remaining <= 0) break;
      final pageSize = remaining < maxPageSize ? remaining : maxPageSize;
      final query = _supabase
          .from('channels')
          .select()
          .eq('is_published', true);
      final filteredQuery = expandedCategories.isEmpty
          ? query
          : query.inFilter('category', expandedCategories.toList(growable: false));
      final response = await filteredQuery
          .order('sort_order', ascending: true)
          .order('title', ascending: true)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      final pageRows = List<Map<String, dynamic>>.from(response as List<dynamic>);
      allRows.addAll(pageRows);
      if (pageRows.length < pageSize) break;
      offset += pageRows.length;
    }

    return allRows
        .map((item) => ChannelModel.fromJson(item))
        .toList(growable: false);
  }

  Future<List<MovieModel>> getMovies({int? limit}) async {
    // Keep every published movie in the catalog, even when playback URLs
    // have not been supplied yet. Paginate to avoid PostgREST's row cap.
    const maxPageSize = 500;
    final rowLimit = limit != null && limit > 0 ? limit : null;
    final allRows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final remaining = rowLimit == null ? maxPageSize : rowLimit - allRows.length;
      if (remaining <= 0) break;
      final pageSize = remaining < maxPageSize ? remaining : maxPageSize;
      final response = await _supabase
          .from('movies')
          .select()
          .eq('is_published', true)
          .order('title', ascending: true)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      final pageRows = List<Map<String, dynamic>>.from(response as List<dynamic>);
      allRows.addAll(pageRows);
      if (pageRows.length < pageSize) break;
      offset += pageRows.length;
    }
    return allRows
        .map((item) => MovieModel.fromJson(item))
        .toList(growable: false);
  }

  Future<List<SeriesModel>> getSeries({int? limit}) async {
    const maxPageSize = 500;
    final rowLimit = limit != null && limit > 0 ? limit : null;
    final allRows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final remaining = rowLimit == null ? maxPageSize : rowLimit - allRows.length;
      if (remaining <= 0) break;
      final pageSize = remaining < maxPageSize ? remaining : maxPageSize;
      final response = await _supabase
          .from('series')
          .select()
          .eq('is_published', true)
          .order('title', ascending: true)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      final pageRows = List<Map<String, dynamic>>.from(response as List<dynamic>);
      allRows.addAll(pageRows);
      if (pageRows.length < pageSize) break;
      offset += pageRows.length;
    }
    return allRows
        .map((item) => SeriesModel.fromJson(item))
        .toList(growable: false);
  }

  Future<List<EpisodeModel>> getEpisodes(String seriesId) async {
    const pageSize = 500;
    final allRows = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += pageSize) {
      final response = await _supabase
          .from('episodes')
          .select()
          .eq('series_id', seriesId)
          .eq('is_published', true)
          .order('season_number', ascending: true)
          .order('episode_number', ascending: true)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      final pageRows = List<Map<String, dynamic>>.from(response as List<dynamic>);
      allRows.addAll(pageRows);
      if (pageRows.length < pageSize) break;
    }
    return allRows
        .map((item) => EpisodeModel.fromJson(item))
        .toList(growable: false);
  }
}
