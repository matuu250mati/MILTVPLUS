import '../models/tv_channel.dart';

/// Parses standard M3U/M3U8 playlists into channels for MILTVPLUS.
/// Accepts only HTTP(S) stream URLs and ignores malformed rows.
class M3uPlaylistParser {
  const M3uPlaylistParser();

  List<TvChannel> parse(String source) {
    final lines = source.replaceAll('\r', '').split('\n');
    final channels = <TvChannel>[];
    String? pendingName;

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
        continue;
      }

      if (line.startsWith('#')) continue;
      final uri = Uri.tryParse(line);
      if (uri == null ||
          uri.host.isEmpty ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        pendingName = null;
        continue;
      }

      channels.add(TvChannel(
        name: pendingName ?? _fallbackName(uri, channels.length + 1),
        streamUrl: uri.toString(),
      ));
      pendingName = null;
    }

    return List<TvChannel>.unmodifiable(channels);
  }

  String _fallbackName(Uri uri, int index) {
    final path = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    if (path.isNotEmpty && path.toLowerCase().endsWith('.m3u8')) {
      return path.substring(0, path.length - 5);
    }
    return 'Canal $index';
  }
}
