import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/tv_channel.dart';
import 'channel_cache_store_stub.dart'
    if (dart.library.io) 'channel_cache_store_io.dart' as cache_store;
import 'channel_storage_codec.dart';

/// Durable channel cache. Native platforms use an app-private JSON file so
/// large IPTV playlists do not inflate Android's SharedPreferences XML. Web
/// uses its platform-compatible preferences implementation.
class ChannelStorageService {
  static const _legacyStorageKey = 'miltv_plus_channels_v1';

  Future<List<TvChannel>> load() async {
    final cachedJson = await cache_store.readCache();
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final cachedChannels = ChannelStorageCodec.decode(cachedJson);
        if (cachedChannels.isNotEmpty) return cachedChannels;
        // An empty or unusable cache may still have recoverable legacy entries.
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
    final channels = ChannelStorageCodec.decodeEntries(decodedLegacy);
    if (channels.isNotEmpty) {
      // Preserve legacy entries if the target platform cannot persist the new
      // cache (for example, a browser storage quota has been reached).
      try {
        await save(channels);
        await preferences.remove(_legacyStorageKey);
      } catch (_) {
        // Returning the recovered channels is still better than a blank TV
        // screen; the legacy copy remains available for a later migration.
      }
    }
    return channels;
  }

  Future<void> save(List<TvChannel> channels) async {
    await cache_store.writeCache(ChannelStorageCodec.encode(channels));
  }
}
