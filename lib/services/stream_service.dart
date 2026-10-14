class StreamService {
  const StreamService();

  /// Accepts HTTPS media endpoints, including signed/tokenized provider URLs
  /// that do not expose a .m3u8 suffix. Android cleartext traffic is disabled,
  /// so HTTP streams are rejected before they reach the native player.
  bool isSupportedHlsUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
    return uri.scheme == 'https';
  }
}
