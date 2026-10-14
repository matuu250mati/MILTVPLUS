class TvChannel {
  const TvChannel({
    required this.name,
    required this.streamUrl,
    this.groupTitle,
    this.country,
    this.language,
    this.category,
  });

  final String name;
  final String streamUrl;

  /// Category metadata from M3U EXTINF attributes, when provided by the source.
  final String? groupTitle;
  final String? country;
  final String? language;

  /// Canonical category from the Supabase channels catalog, if available.
  final String? category;

  /// Broad, user-facing section for the unified live-TV screen.
  /// Genre takes precedence over country metadata so sports/news/culture/HBO
  /// channels do not get hidden inside the Argentine general-TV section.
  String get liveSection {
    final categoryText = (category ?? '').trim();
    final normalizedCategory = categoryText.toLowerCase();

    // Canonical genre labels are authoritative for genre-specific channels.
    const canonicalGenres = {
      'deportes': 'Deportes',
      'noticias': 'Noticias',
      'cultura/documentales': 'Cultura/Documentales',
      'hbo/cine': 'HBO/Cine',
    };
    if (canonicalGenres.containsKey(normalizedCategory)) {
      return canonicalGenres[normalizedCategory]!;
    }

    final group = (groupTitle ?? '').toLowerCase();
    final searchable = '$categoryText $group ' + name.toLowerCase();

    // Classification fallback is for the unified TV view. Category-specific
    // screens must filter by the stored category field, without these guesses.
    if (RegExp(r'\b(news|noticias|informativo|noticiero|c5n|a24|cnn)\b')
        .hasMatch(searchable)) {
      return 'Noticias';
    }
    if (RegExp(
      r'\b(documentary|documentaries|documental|documentales|culture|cultural|cultura|education|educación|history|historia|arte|arts|encuentro|pakapaka)\b',
    ).hasMatch(searchable)) {
      return 'Cultura/Documentales';
    }
    if (RegExp(
      r'\b(hbo|cinemax|showtime|starz|premium|paramount\+|sky cinema|canal\+|cine|cinema|film|películas|peliculas)\b',
    ).hasMatch(searchable)) {
      return 'HBO/Cine';
    }
    if (RegExp(
      r'\b(sport|sports|deporte|deportivo|espn|tyc|fox sports|tnt sports|dsports|deportv|eurosport|nba|nfl|formula 1|f1)\b',
    ).hasMatch(searchable)) {
      return 'Deportes';
    }
    if (RegExp(
      r'\b(kids|children|infantil|cartoon|nickelodeon|disney junior)\b',
    ).hasMatch(searchable)) {
      return 'Infantiles';
    }
    if (RegExp(r'\b(music|música|musica|mtv|vevo)\b').hasMatch(searchable)) {
      return 'Música';
    }

    // TV Argentina is the country/general fallback, after genre recognition.
    if (normalizedCategory == 'tv argentina' ||
        normalizedCategory == 'argentina' ||
        country?.toLowerCase() == 'ar' ||
        country?.toLowerCase() == 'argentina' ||
        RegExp(
          r'\b(argentina|telefe|eltrece|el trece|tv pública|tv publica|américa tv|america tv|canal 9)\b',
        ).hasMatch(searchable)) {
      return 'TV Argentina';
    }
    if (RegExp(r'\b(series|drama|telenovela)\b').hasMatch(searchable)) {
      return 'Series en vivo';
    }
    if (RegExp(
      r'\b(entertainment|entretenimiento|lifestyle|general)\b',
    ).hasMatch(searchable)) {
      return 'Entretenimiento y general';
    }
    return 'Otros canales';
  }
}
