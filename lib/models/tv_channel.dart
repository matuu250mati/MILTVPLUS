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
  /// Genre wins over country so Argentine sports/news stay in their own sections.
  String get liveSection {
    final categoryText = (category ?? '').toLowerCase();
    final group = (groupTitle ?? '').toLowerCase();
    final searchable = '$categoryText $group ${name.toLowerCase()}';

    if (RegExp(r'\b(sport|sports|deporte|deportivo|espn|tyc|bein sports|fox sports|tnt sports|dsports|d sports|deportv|eurosport|nba|nfl|formula 1|f1)\b').hasMatch(searchable)) {
      return 'Deportes';
    }
    if (RegExp(r'\b(news|noticias|news channel|informativo|noticiero)\b').hasMatch(searchable)) {
      return 'Noticias';
    }
    if (RegExp(r'\b(hbo|cinemax|showtime|starz|premium|pay tv|paramount\+|sky cinema|canal\+|max originals)\b').hasMatch(searchable)) {
      return 'Premium / HBO';
    }
    if (RegExp(r'\b(documentary|documentaries|documental|documentales|nature|wildlife)\b').hasMatch(searchable)) {
      return 'Documentales';
    }
    if (RegExp(r'\b(kids|kid|children|childrens|infantil|infantiles|cartoon|nickelodeon|disney junior)\b').hasMatch(searchable)) {
      return 'Infantiles';
    }
    if (RegExp(r'\b(music|música|musica|mtv|vevo)\b').hasMatch(searchable)) {
      return 'Música';
    }
    if (RegExp(r'\b(series|series channel|drama|telenovela)\b').hasMatch(searchable)) {
      return 'Series en vivo';
    }
    if (RegExp(r'\b(movies|movie|películas|peliculas|cinema|cine|film)\b').hasMatch(searchable)) {
      return 'Cine en vivo';
    }
    if (RegExp(r'\b(culture|cultural|cultura|education|educational|educación|educacion|history|historia|arte|arts)\b').hasMatch(searchable)) {
      return 'Cultura y educación';
    }
    if (categoryText.contains('tv argentina') ||
        categoryText == 'argentina' ||
        country?.toLowerCase() == 'ar' ||
        country?.toLowerCase() == 'argentina' ||
        RegExp(r'\b(argentina|telefe|eltrece|el trece|tv pública|tv publica|américa tv|america tv|canal 9|c5n|a24)\b').hasMatch(searchable)) {
      return 'TV Argentina';
    }
    if (RegExp(r'\b(entertainment|entretenimiento|lifestyle|estilo de vida|general)\b').hasMatch(searchable)) {
      return 'Entretenimiento y general';
    }
    if (RegExp(r'\b(religious|religion|religión|religiosa|travel|viajes|weather|clima|shopping|legislative|government)\b').hasMatch(searchable)) {
      return 'Otros temáticos';
    }
    return 'Otros canales';
  }
}
