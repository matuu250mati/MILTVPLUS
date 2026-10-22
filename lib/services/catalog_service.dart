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

  /// Fetches every matching row in stable 500-row pages. PostgREST applies a
  /// server-side row cap, so a single select can silently omit larger catalogs.
  Future<List<Map<String, dynamic>>> _readAllPages(
    Future<List<Map<String, dynamic>>> Function(int from, int to) loadPage,
  ) async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final page = await loadPage(from, from + pageSize - 1);
      rows.addAll(page);
      if (page.length < pageSize) break;
      from += pageSize;
    }
    return rows;
  }


  /// User-submitted items become visible to everyone only after moderation approves them.
  Future<List<Map<String, dynamic>>> getApprovedSubmissions(String mediaType) async {
    final response = await _readAllPages((from, to) => _supabase
        .from('content_submissions')
        .select('title, description, stream_url, poster_url, duration_seconds, series_title, season_number, episode_number, media_type')
        .eq('moderation_status', 'approved')
        .eq('media_type', mediaType)
        .order('created_at', ascending: false)
        .order('id', ascending: true)
        .range(from, to));

    return response;
  }

  Future<List<ChannelModel>> getChannels({List<String>? categories}) async {
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

    final response = await _readAllPages((from, to) {
      final query = _supabase
          .from('channels')
          .select()
          .eq('is_published', true);
      final filteredQuery = expandedCategories.isEmpty
          ? query
          : query.inFilter('category', expandedCategories.toList(growable: false));
      return filteredQuery
          .order('sort_order', ascending: true)
          .order('title', ascending: true)
          .order('id', ascending: true)
          .range(from, to);
    });

    return response
        .map((item) => ChannelModel.fromJson(item))
        .toList(growable: false);
  }

  Future<List<MovieModel>> getMovies() async {
    final response = await _readAllPages((from, to) => _supabase
        .from('movies')
        .select()
        .eq('is_published', true)
        .order('title', ascending: true)
        .order('id', ascending: true)
        .range(from, to));

    // Keep every published metadata row in the catalog, even when its owner
    // has not attached an authorized playback URL yet. The UI marks those items
    // as unavailable instead of silently hiding them from the user's catalog.
    final movies = (response as List<dynamic>)
        .map((item) => MovieModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: true);
    movies.sort((a, b) => a.title.trim().toLowerCase().compareTo(
          b.title.trim().toLowerCase(),
        ));
    return List<MovieModel>.unmodifiable(movies);
  }

  Future<List<SeriesModel>> getSeries() async {
    final response = await _readAllPages((from, to) => _supabase
        .from('series')
        .select()
        .eq('is_published', true)
        .order('title', ascending: true)
        .order('id', ascending: true)
        .range(from, to));

    final series = (response as List<dynamic>)
        .map((item) => SeriesModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: true);
    series.sort((a, b) => a.title.trim().toLowerCase().compareTo(
          b.title.trim().toLowerCase(),
        ));
    return List<SeriesModel>.unmodifiable(series);
  }

  Future<List<EpisodeModel>> getEpisodes(String seriesId) async {
    final response = await _readAllPages((from, to) => _supabase
        .from('episodes')
        .select()
        .eq('series_id', seriesId)
        .eq('is_published', true)
        .order('season_number', ascending: true)
        .order('episode_number', ascending: true)
        .order('id', ascending: true)
        .range(from, to));

    return (response as List<dynamic>)
        .map((item) => EpisodeModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
  }
}
