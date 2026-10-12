// Modelo para Canales en Vivo
class Channel {
  final int id;
  final String name;
  final String? logoUrl;
  final String streamUrl;
  final String? category;

  Channel({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.streamUrl,
    this.category,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'],
      name: json['name'],
      logoUrl: json['logo_url'],
      streamUrl: json['stream_url'],
      category: json['category'],
    );
  }
}

// Modelo para Películas
class Movie {
  final int id;
  final String title;
  final String? posterUrl;
  final String? backdropUrl;
  final String? synopsis;
  final String streamUrl;
  final String? duration;
  final int? year;
  final String? category;

  Movie({
    required this.id,
    required this.title,
    this.posterUrl,
    this.backdropUrl,
    this.synopsis,
    required this.streamUrl,
    this.duration,
    this.year,
    this.category,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'],
      title: json['title'],
      posterUrl: json['poster_url'],
      backdropUrl: json['backdrop_url'],
      synopsis: json['synopsis'],
      streamUrl: json['stream_url'],
      duration: json['duration'],
      year: json['year'],
      category: json['category'],
    );
  }
}

// Modelo para Series
class Series {
  final int id;
  final String title;
  final String? posterUrl;
  final String? synopsis;
  final List<String>? genres;

  Series({
    required this.id,
    required this.title,
    this.posterUrl,
    this.synopsis,
    this.genres,
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: json['id'],
      title: json['title'],
      posterUrl: json['poster_url'],
      synopsis: json['synopsis'],
      genres: json['genres'] != null ? List<String>.from(json['genres']) : null,
    );
  }
}
