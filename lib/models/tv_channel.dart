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
}
