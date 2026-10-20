import 'dart:convert';

import 'package:flutter/services.dart';
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

    // Keep the server catalog additive: the bundled public-channel snapshot is
    // merged with published Supabase rows and is also available offline.
    final remoteChannels = <ChannelModel>[];
    try {
      final query = _supabase
          .from('channels')
          .select()
          .eq('is_published', true);
      final filteredQuery = expandedCategories.isEmpty
          ? query
          : query.inFilter('category', expandedCategories.toList(growable: false));
      final response = await filteredQuery
          .order('sort_order', ascending: true)
          .order('title', ascending: true);
      remoteChannels.addAll((response as List<dynamic>).map((item) =>
          ChannelModel.fromJson(Map<String, dynamic>.from(item as Map))));
    } catch (_) {
      // Offline mode deliberately continues with the APK-bundled snapshot.
    }

    final snapshotChannels = (await _getBundledRows('channels'))
        .map(ChannelModel.fromJson)
        .toList(growable: false);
    final bundledChannels = await _getBundledChannels();
    final merged = <String, ChannelModel>{};
    for (final channel in [...remoteChannels, ...snapshotChannels, ...bundledChannels]) {
      final urlKey = channel.urlStream.trim().toLowerCase();
      final titleKey = channel.title.trim().toLowerCase();
      final key = urlKey.isNotEmpty ? urlKey : titleKey;
      if (key.isNotEmpty) merged.putIfAbsent(key, () => channel);
    }
    return merged.values.toList(growable: false)
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
  }

  Future<List<Map<String, dynamic>>> _getBundledRows(String table) async {
    try {
      final decoded = jsonDecode(
        await rootBundle.loadString('assets/catalog/catalog_snapshot.json'),
      );
      if (decoded is! Map || decoded[table] is! List) return const [];
      return (decoded[table] as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<ChannelModel>> _getBundledChannels() async {
    String playlist;
    try {
      playlist = await rootBundle.loadString('assets/catalog/iptv.m3u');
    } catch (_) {
      return const [];
    }
    final channels = <ChannelModel>[];
    String? pendingInfo;
    for (final rawLine in playlist.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF')) {
        pendingInfo = line;
        continue;
      }
      if (line.startsWith('#')) continue;
      final uri = Uri.tryParse(line);
      if (pendingInfo == null ||
          uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        pendingInfo = null;
        continue;
      }
      final info = pendingInfo;
      pendingInfo = null;
      final comma = info.lastIndexOf(',');
      final title = comma >= 0 && comma + 1 < info.length
          ? info.substring(comma + 1).trim()
          : 'Canal sin nombre';
      String attribute(String name) {
        final match = RegExp('(?:^|\\s)$name="([^"]*)"').firstMatch(info);
        return match?.group(1)?.trim() ?? '';
      }
      final group = attribute('group-title');
      final logo = attribute('tvg-logo');
      final country = attribute('tvg-country').split(RegExp(r'[,;\s]+')).first;
      final ext = uri.path.toLowerCase();
      channels.add(ChannelModel(
        id: 'bundle-${channels.length}',
        title: title.isEmpty ? 'Canal sin nombre' : title,
        category: group.isEmpty ? 'General' : group,
        logo: logo.isEmpty ? null : logo,
        urlStream: line,
        streamUrls: [line],
        streamFormat: ext.endsWith('.mpd') ? 'dash' : 'hls',
        countryCode: country.length == 2 ? country.toUpperCase() : 'UN',
        sortOrder: channels.length,
        isPublished: true,
      ));
    }
    return channels;
  }

  Future<List<MovieModel>> getMovies() async {
    final remote = <MovieModel>[];
    try {
      final response = await _supabase
          .from('movies')
          .select()
          .eq('is_published', true)
          .order('title', ascending: true);
      remote.addAll((response as List<dynamic>).map((item) =>
          MovieModel.fromJson(Map<String, dynamic>.from(item as Map))));
    } catch (_) {
      // The APK snapshot remains available when the backend is unreachable.
    }
    final bundled = (await _getBundledRows('movies'))
        .map(MovieModel.fromJson)
        .toList(growable: false);
    final merged = <String, MovieModel>{};
    for (final movie in [...remote, ...bundled]) {
      final key = movie.id.isNotEmpty ? movie.id : movie.title.trim().toLowerCase();
      if (key.isNotEmpty) merged.putIfAbsent(key, () => movie);
    }
    // Do not hide published titles just because a stream URL has not been set.
    return merged.values.toList(growable: false)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  Future<List<SeriesModel>> getSeries() async {
    final remote = <SeriesModel>[];
    try {
      final response = await _supabase
          .from('series')
          .select()
          .eq('is_published', true)
          .order('title', ascending: true);
      remote.addAll((response as List<dynamic>).map((item) =>
          SeriesModel.fromJson(Map<String, dynamic>.from(item as Map))));
    } catch (_) {
      // Use the packaged snapshot in offline mode.
    }
    final bundled = (await _getBundledRows('series'))
        .map(SeriesModel.fromJson)
        .toList(growable: false);
    final merged = <String, SeriesModel>{};
    for (final series in [...remote, ...bundled]) {
      final key = series.id.isNotEmpty ? series.id : series.title.trim().toLowerCase();
      if (key.isNotEmpty) merged.putIfAbsent(key, () => series);
    }
    return merged.values.toList(growable: false)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  Future<List<EpisodeModel>> getEpisodes(String seriesId) async {
    final remote = <EpisodeModel>[];
    try {
      final response = await _supabase
          .from('episodes')
          .select()
          .eq('series_id', seriesId)
          .eq('is_published', true)
          .order('season_number', ascending: true)
          .order('episode_number', ascending: true);
      remote.addAll((response as List<dynamic>).map((item) =>
          EpisodeModel.fromJson(Map<String, dynamic>.from(item as Map))));
    } catch (_) {
      // Fall back to episodes bundled with the published catalog snapshot.
    }
    final bundled = (await _getBundledRows('episodes'))
        .where((row) => row['series_id']?.toString() == seriesId)
        .map(EpisodeModel.fromJson)
        .toList(growable: false);
    final merged = <String, EpisodeModel>{};
    for (final episode in [...remote, ...bundled]) {
      final key = episode.id.isNotEmpty
          ? episode.id
          : '${episode.seriesId}-${episode.seasonNumber}-${episode.episodeNumber}';
      merged.putIfAbsent(key, () => episode);
    }
    return merged.values.toList(growable: false)
      ..sort((a, b) {
        final season = a.seasonNumber.compareTo(b.seasonNumber);
        return season != 0 ? season : a.episodeNumber.compareTo(b.episodeNumber);
      });
  }
}
