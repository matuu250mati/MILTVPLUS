class TvChannel {
  const TvChannel({
    required this.name,
    required this.streamUrl,
    this.groupTitle,
    this.country,
    this.language,
  });

  final String name;
  final String streamUrl;

  /// Category metadata from M3U EXTINF attributes, when provided by the source.
  final String? groupTitle;
  final String? country;
  final String? language;
}
