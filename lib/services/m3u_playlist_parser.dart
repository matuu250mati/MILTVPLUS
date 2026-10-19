import '../models/tv_channel.dart';

class M3uPlaylistParser {
  const M3uPlaylistParser();

  List<TvChannel> parse(String source) {
    final lines = source.replaceAll('\r', '').split('\n');
    final channels = <TvChannel>[];
    final byChannelIdentity = <String, int>{};
    final seenUrlsByChannel = <String, Set<String>>{};
    final channelIndexByUrl = <String, int>{};

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXTINF:')) continue;
      final comma = _findUnquotedComma(line);
      final metadata = comma < 0 ? line.substring('#EXTINF:'.length) : line.substring('#EXTINF:'.length, comma);
      final displayName = comma < 0 ? '' : line.substring(comma + 1).trim();
      final attributes = _attributes(metadata);
      final tvgName = (attributes['tvg-name'] ?? '').trim();
      final name = tvgName.isNotEmpty ? tvgName : (displayName.isNotEmpty ? displayName : 'Canal ${channels.length + 1}');

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

      if (streamUrl == null) continue;
      final uri = Uri.tryParse(streamUrl);
      if (uri == null || !uri.hasAuthority || uri.userInfo.isNotEmpty ||
          !['http', 'https'].contains(uri.scheme.toLowerCase()) || _isWebPageOnlyHost(uri.host) || name.trim().isEmpty) {
        continue;
      }
      final groupTitle = _nonEmpty(attributes['group-title']);
      final country = _nonEmpty(attributes['tvg-country']);
      final tvgId = _nonEmpty(attributes['tvg-id']);
      final identity = tvgId != null && tvgId.isNotEmpty
          ? 'id:${tvgId.toLowerCase()}|${(groupTitle ?? '').toLowerCase()}'
          : 'name:${name.trim().toLowerCase()}|${(groupTitle ?? '').toLowerCase()}|${(country ?? '').toLowerCase()}';
      final normalizedUrl = _streamIdentity(uri);
      final urlOwnerIndex = channelIndexByUrl[normalizedUrl];
      if (urlOwnerIndex != null && byChannelIdentity[identity] == null) continue;
      final existingIndex = byChannelIdentity[identity];
      if (existingIndex != null) {
        final seen = seenUrlsByChannel[identity]!;
        if (seen.add(normalizedUrl)) {
          final existing = channels[existingIndex];
          channels[existingIndex] = TvChannel(
            name: existing.name,
            streamUrl: existing.streamUrl,
            groupTitle: existing.groupTitle ?? groupTitle,
            country: existing.country ?? country,
            language: existing.language ?? _nonEmpty(attributes['tvg-language']),
            category: existing.category,
            logoUrl: existing.logoUrl ?? _nonEmpty(attributes['tvg-logo']),
            tvgId: existing.tvgId ?? tvgId,
            backupStreamUrls: [...existing.backupStreamUrls, streamUrl]
                .where((url) => url != existing.streamUrl)
                .toSet()
                .toList(growable: false),
          );
          channelIndexByUrl[normalizedUrl] = existingIndex;
        }
        continue;
      }

      byChannelIdentity[identity] = channels.length;
      seenUrlsByChannel[identity] = {normalizedUrl};
      channelIndexByUrl[normalizedUrl] = channels.length;
      channels.add(TvChannel(
        name: name,
        streamUrl: streamUrl,
        groupTitle: groupTitle,
        country: country,
        language: _nonEmpty(attributes['tvg-language']),
        logoUrl: _nonEmpty(attributes['tvg-logo']),
        tvgId: tvgId,
      ));
    }
    return List<TvChannel>.unmodifiable(channels);
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
