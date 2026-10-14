import '../models/tv_channel.dart';

/// Parses standard M3U/M3U8 playlists into channels for MILTVPLUS.
/// Accepts only HTTPS stream URLs and ignores malformed rows because Android
/// cleartext traffic is disabled in the application manifest.
class M3uPlaylistParser {
  const M3uPlaylistParser();

  List<TvChannel> parse(String source) {
    final lines = source.replaceAll('\r', '').split('\n');
    final channels = <TvChannel>[];
    final seen = <String>{};
    String? pendingName;
    String? pendingGroupTitle;
    String? pendingCountry;
    String? pendingLanguage;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#EXTM3U')) continue;

      if (line.startsWith('#EXTINF:')) {
        final comma = line.indexOf(',');
        var name = comma >= 0 ? line.substring(comma + 1).trim() : '';
        if (name.isEmpty) {
          final match = RegExp(r'tvg-name="([^"]+)"').firstMatch(line);
          name = match?.group(1)?.trim() ?? '';
        }
        pendingName = name.isEmpty ? 'Canal ${channels.length + 1}' : name;
        pendingGroupTitle = _attribute(line, 'group-title');
        pendingCountry = _attribute(line, 'tvg-country');
        pendingLanguage = _attribute(line, 'tvg-language');
        continue;
      }

      if (line.startsWith('#')) continue;
      final uri = Uri.tryParse(line);
      if (uri == null ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.scheme != 'https' ||
          _isWebPageOnlyHost(uri.host)) {
        // Web-player pages (for example, YouTube or Twitch channel pages) are
        // not direct media streams and cannot be opened by video_player.
        pendingName = null;
        continue;
      }

      final streamUrl = uri.toString();
      // Fragments, host casing, and dot-segments do not identify different media.
      // Preserve the original URL for playback but deduplicate by canonical identity.
      if (seen.add(_streamIdentity(uri))) {
        channels.add(TvChannel(
          name: pendingName ?? _fallbackName(uri, channels.length + 1),
          streamUrl: streamUrl,
          groupTitle: _nonEmpty(pendingGroupTitle),
          country: _nonEmpty(pendingCountry),
          language: _nonEmpty(pendingLanguage),
        ));
      }
      pendingName = null;
      pendingGroupTitle = null;
      pendingCountry = null;
      pendingLanguage = null;
    }

    return List<TvChannel>.unmodifiable(channels);
  }

  String? _attribute(String line, String name) {
    final match = RegExp('(?:^|\\s)$name="([^"]*)"').firstMatch(line);
    return match?.group(1)?.trim();
  }

  String? _nonEmpty(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  String _streamIdentity(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final isDefaultPort = (scheme == 'https' && uri.port == 443) ||
        (scheme == 'http' && uri.port == 80);
    return uri
        .replace(
          scheme: scheme,
          host: host,
          port: isDefaultPort ? null : (uri.hasPort ? uri.port : null),
          path: uri.normalizePath().path,
          fragment: '',
        )
        .toString();
  }

  bool _isWebPageOnlyHost(String host) {
    final normalized = host.toLowerCase();
    const hosts = <String>{
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'youtu.be',
      'twitch.tv',
      'www.twitch.tv',
      'facebook.com',
      'www.facebook.com',
      'fb.watch',
      'vimeo.com',
      'www.vimeo.com',
      'dailymotion.com',
      'www.dailymotion.com',
      'tiktok.com',
      'www.tiktok.com',
      'instagram.com',
      'www.instagram.com',
    };
    return hosts.contains(normalized);
  }

  String _fallbackName(Uri uri, int index) {
    final path = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    if (path.isNotEmpty && path.toLowerCase().endsWith('.m3u8')) {
      return path.substring(0, path.length - 5);
    }
    return 'Canal $index';
  }
}
