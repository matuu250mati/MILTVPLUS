import 'dart:convert';

import '../models/tv_channel.dart';

/// Pure JSON codec for the durable channel cache.
///
/// Kept separate from platform storage so serialization and recovery rules can
/// be tested without invoking filesystem or browser preference plugins.
class ChannelStorageCodec {
  const ChannelStorageCodec._();

  static String encode(List<TvChannel> channels) {
    final entries = channels
        .map((channel) => {
              'name': channel.name,
              'streamUrl': channel.streamUrl,
              'groupTitle': channel.groupTitle,
              'country': channel.country,
              'language': channel.language,
              'category': channel.category,
              'logoUrl': channel.logoUrl,
              'tvgId': channel.tvgId,
              'backupStreamUrls': channel.backupStreamUrls,
            })
        .toList(growable: false);
    return jsonEncode(entries);
  }

  /// Decodes valid channel entries and ignores malformed records.
  ///
  /// Invalid JSON intentionally throws [FormatException], allowing callers to
  /// fall back to older persisted data rather than silently accepting damage.
  static List<TvChannel> decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) return const <TvChannel>[];
    return decodeEntries(decoded);
  }

  /// Decodes entries already parsed from the legacy preferences format.
  static List<TvChannel> decodeEntries(Iterable<dynamic> entries) {
    final channels = <TvChannel>[];
    for (final decoded in entries) {
      if (decoded is! Map) continue;
      final name = decoded['name'];
      final url = decoded['streamUrl'];
      if (name is! String ||
          url is! String ||
          name.trim().isEmpty ||
          url.trim().isEmpty) {
        continue;
      }
      channels.add(TvChannel(
        name: name,
        streamUrl: url,
        groupTitle: decoded['groupTitle'] is String ? decoded['groupTitle'] as String : null,
        country: decoded['country'] is String ? decoded['country'] as String : null,
        language: decoded['language'] is String ? decoded['language'] as String : null,
        category: decoded['category'] is String ? decoded['category'] as String : null,
        logoUrl: decoded['logoUrl'] is String ? decoded['logoUrl'] as String : null,
        tvgId: decoded['tvgId'] is String ? decoded['tvgId'] as String : null,
        backupStreamUrls: decoded['backupStreamUrls'] is List
            ? (decoded['backupStreamUrls'] as List).whereType<String>().toList(growable: false)
            : const [],
      ));
    }
    return channels;
  }
}
