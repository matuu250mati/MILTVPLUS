import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/tv_channel.dart';
import 'channel_cache_store_stub.dart'
    if (dart.library.io) 'channel_cache_store_io.dart' as cache_store;

/// Durable channel cache. Native platforms use an app-private JSON file so
/// large IPTV playlists do not inflate Android's SharedPreferences XML. Web
/// uses its platform-compatible preferences implementation.
class ChannelStorageService {
  static const _legacyStorageKey = 'miltv_plus_channels_v1';

  Future<List<TvChannel>> load() async {
    final cachedJson = await cache_store.readCache();
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedJson);
        if (decoded is List) return _decodeChannels(decoded);
      } on FormatException {
        // Recover from a damaged cache using the legacy preference entries.
      }
    }

    // One-time migration from the previous SharedPreferences string-list.
    final preferences = await SharedPreferences.getInstance();
    final legacy = preferences.getStringList(_legacyStorageKey) ?? const <String>[];
    final decodedLegacy = <dynamic>[];
    for (final entry in legacy) {
      try {
        final value = jsonDecode(entry);
        if (value is Map) decodedLegacy.add(value);
      } on FormatException {
        // Ignore one damaged entry without discarding the remaining channels.
      }
    }
    final channels = _decodeChannels(decodedLegacy);
    if (channels.isNotEmpty) {
      // Preserve the old entries unless the new cache was written successfully.
      await save(channels);
      await preferences.remove(_legacyStorageKey);
    }
    return channels;
  }

  List<TvChannel> _decodeChannels(List<dynamic> entries) {
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

  Future<void> save(List<TvChannel> channels) async {
    final encoded = channels
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
    await cache_store.writeCache(jsonEncode(encoded));
  }
}
