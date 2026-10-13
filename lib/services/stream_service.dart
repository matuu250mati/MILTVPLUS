class StreamService {
  const StreamService();

  /// Accepts HTTP(S) media endpoints, including signed/tokenized provider URLs
  /// that do not expose a .m3u8 suffix. Actual playback support is confirmed
  /// when the native player initializes the stream.
  bool isSupportedHlsUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
    return uri.scheme == 'https' || uri.scheme == 'http';
  }
}
