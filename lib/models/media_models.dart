// Modelos tipados para el esquema actual de Supabase de MILTV PLUS.

String _stringValue(Map<String, dynamic> json, String key, [String fallback = '']) {
  final value = json[key];
  return value is String ? value : fallback;
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String && value.trim().isNotEmpty ? value : null;
}

int? _nullableInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

int _intValue(Map<String, dynamic> json, String key, [int fallback = 0]) =>
    _nullableInt(json, key) ?? fallback;

bool _boolValue(Map<String, dynamic> json, String key, [bool fallback = false]) {
  final value = json[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case 't':
      case '1':
        return true;
      case 'false':
      case 'f':
      case '0':
        return false;
    }
  }
  return fallback;
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! List) return const [];
  return List<String>.unmodifiable(raw
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty));
}

List<String> _streamUrlList(Map<String, dynamic> json, String fallback) {
  final urls = <String>[];
  final raw = json['stream_urls'];
  if (raw is List) {
    for (final value in raw) {
      if (value is! String) continue;
      final url = value.trim();
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }
  }
  final single = fallback.trim();
  if (single.isNotEmpty && !urls.contains(single)) urls.add(single);
  return List<String>.unmodifiable(urls);
}

class ChannelModel {
  final String id;
  final String title;
  final String? synopsis;
  final String category;
  final String? logo;
  final String urlStream;
  final String streamFormat;
  final String countryCode;
  final int sortOrder;
  final bool isPublished;

  const ChannelModel({
    required this.id, required this.title, this.synopsis,
    required this.category, this.logo, required this.urlStream,
    required this.streamFormat, required this.countryCode,
    required this.sortOrder, required this.isPublished,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json) => ChannelModel(
    id: _stringValue(json, 'id'),
    title: _stringValue(json, 'title', 'Sin título'),
    synopsis: _nullableString(json, 'synopsis'),
    category: _stringValue(json, 'category', 'General'),
    logo: _nullableString(json, 'logo'),
    urlStream: _stringValue(json, 'url_stream'),
    streamFormat: _stringValue(json, 'stream_format', 'hls'),
    countryCode: _stringValue(json, 'country_code', 'AR'),
    sortOrder: _intValue(json, 'sort_order'),
    isPublished: _boolValue(json, 'is_published'),
  );
}

class MovieModel {
  final String id;
  final String title;
  final String? synopsis;
  final String category;
  final List<String> genres;
  final String? logo;
  final String? backdropUrl;
  final String urlStream;
  final List<String> streamUrls;
  final int? releaseYear;
  final int? durationSeconds;
  final String countryCode;
  final bool isPublished;

  const MovieModel({
    required this.id, required this.title, this.synopsis,
    required this.category, required this.genres, this.logo,
    this.backdropUrl, required this.urlStream, this.streamUrls = const [], this.releaseYear,
    this.durationSeconds, required this.countryCode,
    required this.isPublished,
  });

  factory MovieModel.fromJson(Map<String, dynamic> json) => MovieModel(
    id: _stringValue(json, 'id'),
    title: _stringValue(json, 'title', 'Sin título'),
    synopsis: _nullableString(json, 'synopsis'),
    category: _stringValue(json, 'category', 'General'),
    genres: _stringList(json, 'genres'),
    logo: _nullableString(json, 'logo'),
    backdropUrl: _nullableString(json, 'backdrop_url'),
    urlStream: _stringValue(json, 'url_stream'),
    streamUrls: _streamUrlList(json, _stringValue(json, 'url_stream')),
    releaseYear: _nullableInt(json, 'release_year'),
    durationSeconds: _nullableInt(json, 'duration_seconds'),
    countryCode: _stringValue(json, 'country_code', 'AR'),
    isPublished: _boolValue(json, 'is_published'),
  );
}

class SeriesModel {
  final String id;
  final String title;
  final String? synopsis;
  final String category;
  final List<String> genres;
  final String? logo;
  final String? backdropUrl;
  final int? releaseYear;
  final String countryCode;
  final bool isPublished;

  const SeriesModel({
    required this.id, required this.title, this.synopsis,
    required this.category, required this.genres, this.logo,
    this.backdropUrl, this.releaseYear, required this.countryCode,
    required this.isPublished,
  });

  factory SeriesModel.fromJson(Map<String, dynamic> json) => SeriesModel(
    id: _stringValue(json, 'id'),
    title: _stringValue(json, 'title', 'Sin título'),
    synopsis: _nullableString(json, 'synopsis'),
    category: _stringValue(json, 'category', 'Series'),
    genres: _stringList(json, 'genres'),
    logo: _nullableString(json, 'logo'),
    backdropUrl: _nullableString(json, 'backdrop_url'),
    releaseYear: _nullableInt(json, 'release_year'),
    countryCode: _stringValue(json, 'country_code', 'AR'),
    isPublished: _boolValue(json, 'is_published'),
  );
}


/// A published episode available from the provider's episodes table.
class EpisodeModel {
  final String id;
  final String seriesId;
  final String title;
  final String? synopsis;
  final int seasonNumber;
  final int episodeNumber;
  final String urlStream;
  final List<String> streamUrls;
  final int? durationSeconds;
  final bool isPublished;

  const EpisodeModel({
    required this.id,
    required this.seriesId,
    required this.title,
    this.synopsis,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.urlStream,
    this.streamUrls = const [],
    this.durationSeconds,
    required this.isPublished,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json) => EpisodeModel(
        id: _stringValue(json, 'id'),
        seriesId: _stringValue(json, 'series_id'),
        title: _stringValue(json, 'title', 'Episodio'),
        synopsis: _nullableString(json, 'synopsis'),
        seasonNumber: _intValue(json, 'season_number', 1),
        episodeNumber: _intValue(json, 'episode_number', 1),
        urlStream: _stringValue(json, 'url_stream'),
        streamUrls: _streamUrlList(json, _stringValue(json, 'url_stream')),
        durationSeconds: _nullableInt(json, 'duration_seconds'),
        isPublished: _boolValue(json, 'is_published'),
      );
}
