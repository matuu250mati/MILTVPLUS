/// Modelos tipados para el esquema actual de Supabase de MILTV PLUS.
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
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'Sin título',
    synopsis: json['synopsis'] as String?,
    category: json['category'] as String? ?? 'General',
    logo: json['logo'] as String?,
    urlStream: json['url_stream'] as String? ?? '',
    streamFormat: json['stream_format'] as String? ?? 'hls',
    countryCode: json['country_code'] as String? ?? 'AR',
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    isPublished: json['is_published'] as bool? ?? false,
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
  final int? releaseYear;
  final int? durationSeconds;
  final String countryCode;
  final bool isPublished;

  const MovieModel({
    required this.id, required this.title, this.synopsis,
    required this.category, required this.genres, this.logo,
    this.backdropUrl, required this.urlStream, this.releaseYear,
    this.durationSeconds, required this.countryCode,
    required this.isPublished,
  });

  factory MovieModel.fromJson(Map<String, dynamic> json) => MovieModel(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'Sin título',
    synopsis: json['synopsis'] as String?,
    category: json['category'] as String? ?? 'General',
    genres: (json['genres'] as List<dynamic>?)
        ?.map((value) => value.toString()).toList(growable: false) ?? const [],
    logo: json['logo'] as String?,
    backdropUrl: json['backdrop_url'] as String?,
    urlStream: json['url_stream'] as String? ?? '',
    releaseYear: (json['release_year'] as num?)?.toInt(),
    durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
    countryCode: json['country_code'] as String? ?? 'AR',
    isPublished: json['is_published'] as bool? ?? false,
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
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'Sin título',
    synopsis: json['synopsis'] as String?,
    category: json['category'] as String? ?? 'Series',
    genres: (json['genres'] as List<dynamic>?)
        ?.map((value) => value.toString()).toList(growable: false) ?? const [],
    logo: json['logo'] as String?,
    backdropUrl: json['backdrop_url'] as String?,
    releaseYear: (json['release_year'] as num?)?.toInt(),
    countryCode: json['country_code'] as String? ?? 'AR',
    isPublished: json['is_published'] as bool? ?? false,
  );
}
