class StreamService {
  const StreamService();

  bool isSupportedHlsUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    return (uri.scheme == 'https' || uri.scheme == 'http') &&
        (uri.path.toLowerCase().endsWith('.m3u8') ||
            uri.queryParameters.containsKey('m3u8'));
  }
}
