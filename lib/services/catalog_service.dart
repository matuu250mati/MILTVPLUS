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

  Future<List<ChannelModel>> getChannels({List<String>? categories}) async {
    final response = categories == null || categories.isEmpty
        ? await _supabase
            .from('channels')
            .select()
            .eq('is_published', true)
            .order('sort_order', ascending: true)
            .order('title', ascending: true)
        : await _supabase
            .from('channels')
            .select()
            .eq('is_published', true)
            .inFilter('category', categories)
            .order('sort_order', ascending: true)
            .order('title', ascending: true);

    return (response as List<dynamic>)
        .map((item) => ChannelModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
  }

  Future<List<MovieModel>> getMovies() async {
    final response = await _supabase
        .from('movies')
        .select()
        .eq('is_published', true)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => MovieModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
  }

  Future<List<SeriesModel>> getSeries() async {
    final response = await _supabase
        .from('series')
        .select()
        .eq('is_published', true)
        .order('title', ascending: true);

    return (response as List<dynamic>)
        .map((item) => SeriesModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
  }

  Future<List<EpisodeModel>> getEpisodes(String seriesId) async {
    final response = await _supabase
        .from('episodes')
        .select()
        .eq('series_id', seriesId)
        .eq('is_published', true)
        .order('season_number', ascending: true)
        .order('episode_number', ascending: true);

    return (response as List<dynamic>)
        .map((item) => EpisodeModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
  }
}
