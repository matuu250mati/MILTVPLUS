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

  Future<List<ChannelModel>> getChannels() async {
    final response = await _supabase
        .from('channels')
        .select()
        .eq('is_published', true)
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
