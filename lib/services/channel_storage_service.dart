import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/tv_channel.dart';

class ChannelStorageService {
  static const _storageKey = 'miltv_plus_channels_v1';

  Future<List<TvChannel>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getStringList(_storageKey) ?? const <String>[];
    final channels = <TvChannel>[];
    for (final entry in saved) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is Map<String, dynamic>) {
          final name = decoded['name'];
          final url = decoded['streamUrl'];
          if (name is String && url is String && name.trim().isNotEmpty && url.trim().isNotEmpty) {
            channels.add(TvChannel(name: name, streamUrl: url));
          }
        }
      } on FormatException {
        // Ignore malformed saved entries and keep loading the remaining channels.
      }
    }
    return channels;
  }

  Future<void> save(List<TvChannel> channels) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = channels
        .map((channel) => jsonEncode({
              'name': channel.name,
              'streamUrl': channel.streamUrl,
            }))
        .toList(growable: false);
    await preferences.setStringList(_storageKey, encoded);
  }
}
