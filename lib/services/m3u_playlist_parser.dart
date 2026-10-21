import '../models/tv_channel.dart';

/// A diagnostic result for a playlist import. Counts refer to #EXTINF entries,
/// not to streams that have been proven to play successfully.
class M3uParseReport {
  const M3uParseReport({
    required this.channels,
    required this.totalEntries,
    required this.imported,
    required this.duplicates,
    required this.incomplete,
    required this.unsupported,
  });

  final List<TvChannel> channels;
  final int totalEntries;
  final int imported;
  final int duplicates;
  final int incomplete;
  final int unsupported;
}

class M3uPlaylistParser {
  const M3uPlaylistParser();

  List<TvChannel> parse(String source) => parseWithReport(source).channels;

  M3uParseReport parseWithReport(String source) {
    final lines = source.replaceAll('\r', '').split('\n');
    final channels = <TvChannel>[];
    final seen = <String>{};
    var total = 0;
    var duplicates = 0;
    var incomplete = 0;
    var unsupported = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXTINF:')) continue;
      total++;
      final comma = _findUnquotedComma(line);
      final metadata = comma < 0
          ? line.substring('#EXTINF:'.length)
          : line.substring('#EXTINF:'.length, comma);
      final displayName = comma < 0 ? '' : line.substring(comma + 1).trim();
      final attributes = _attributes(metadata);
      final tvgName = (attributes['tvg-name'] ?? '').trim();
      final name = tvgName.isNotEmpty ? tvgName : displayName;

      String? streamUrl;
      for (var j = i + 1; j < lines.length; j++) {
        final candidate = lines[j].trim();
        if (candidate.isEmpty) continue;
        if (candidate.startsWith('#EXTINF:')) break;
        if (candidate.startsWith('#')) continue;
        streamUrl = candidate;
        i = j;
        break;
      }

      if (streamUrl == null || name.isEmpty) {
        incomplete++;
        continue;
      }

      final uri = Uri.tryParse(streamUrl);
      if (uri == null || !uri.hasAuthority || uri.userInfo.isNotEmpty ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        incomplete++;
        continue;
      }
      if (_isWebPageOnlyHost(uri.host)) {
        unsupported++;
        continue;
      }

      if (!seen.add(_streamIdentity(uri))) {
        duplicates++;
        continue;
      }

      channels.add(TvChannel(
        name: name,
        streamUrl: streamUrl,
        groupTitle: _nonEmpty(attributes['group-title']),
        country: _nonEmpty(attributes['tvg-country']),
        language: _nonEmpty(attributes['tvg-language']),
        logoUrl: _nonEmpty(attributes['tvg-logo']),
        tvgId: _nonEmpty(attributes['tvg-id']),
      ));
    }

    return M3uParseReport(
      channels: List<TvChannel>.unmodifiable(channels),
      totalEntries: total,
      imported: channels.length,
      duplicates: duplicates,
      incomplete: incomplete,
      unsupported: unsupported,
    );
  }

  int _findUnquotedComma(String line) {
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      if (line[i] == '"') {
        quoted = !quoted;
      } else if (line[i] == ',' && !quoted) {
        return i;
      }
    }
    return -1;
  }

  Map<String, String> _attributes(String metadata) {
    final values = <String, String>{};
    final regex = RegExp(r'([\w-]+)\s*=\s*"([^"]*)"');
    for (final match in regex.allMatches(metadata)) {
      final key = match.group(1);
      final value = match.group(2);
      if (key != null && value != null) values[key] = value;
    }
    return values;
  }

  String? _nonEmpty(String? value) {
    final result = value?.trim() ?? '';
    return result.isEmpty ? null : result;
  }

  String _streamIdentity(Uri uri) => uri.replace(
    scheme: uri.scheme.toLowerCase(),
    host: uri.host.toLowerCase(),
    path: uri.normalizePath().path,
    fragment: '',
  ).toString();

  bool _isWebPageOnlyHost(String host) {
    const hosts = <String>{
      'youtube.com', 'www.youtube.com', 'm.youtube.com', 'youtu.be',
      'twitch.tv', 'www.twitch.tv', 'facebook.com', 'www.facebook.com',
      'fb.watch', 'vimeo.com', 'www.vimeo.com', 'dailymotion.com',
      'www.dailymotion.com', 'tiktok.com', 'www.tiktok.com',
      'instagram.com', 'www.instagram.com',
    };
    return hosts.contains(host.toLowerCase());
  }
}
