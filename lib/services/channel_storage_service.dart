import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tv_channel.dart';

/// Durable local playlist storage. Uses a JSON file instead of a giant
/// SharedPreferences XML entry so large playlists remain practical on Android TV.
class ChannelStorageService {
  static const _storageKey = 'miltv_plus_channels_v1';
  static const _fileName = 'miltvplus_channels_v1.json';

  Future<File> _storageFile() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}/$_fileName');
  }

  Future<List<TvChannel>> load() async {
    final file = await _storageFile();
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          return _decodeChannels(decoded);
        }
      } on FormatException {
        // Recover from an interrupted/corrupt file by trying the legacy store.
      } on FileSystemException {
        // Fall through to the legacy store; don't delete anything automatically.
      }
    }

    // One-time migration: preserve existing installs' SharedPreferences data.
    final preferences = await SharedPreferences.getInstance();
    final legacy = preferences.getStringList(_storageKey) ?? const <String>[];
    final channels = <TvChannel>[];
    for (final entry in legacy) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is Map) {
          channels.addAll(_decodeChannels([decoded]));
        }
      } on FormatException {
        // Ignore only the malformed row; retain all other recoverable entries.
      }
    }
    if (legacy.isNotEmpty) {
      await save(channels);
      // Keep the legacy copy until a later version confirms the migration.
    }
    return channels;
  }

  List<TvChannel> _decodeChannels(List<dynamic> rows) {
    final channels = <TvChannel>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final decoded = Map<String, dynamic>.from(row);
      final name = decoded['name'];
      final url = decoded['streamUrl'];
      if (name is! String || url is! String ||
          name.trim().isEmpty || url.trim().isEmpty) {
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
    final file = await _storageFile();
    final encoded = channels.map((channel) => {
      'name': channel.name,
      'streamUrl': channel.streamUrl,
      'groupTitle': channel.groupTitle,
      'country': channel.country,
      'language': channel.language,
      'category': channel.category,
      'logoUrl': channel.logoUrl,
      'tvgId': channel.tvgId,
      'backupStreamUrls': channel.backupStreamUrls,
    }).toList(growable: false);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(encoded), flush: true);
    // Atomic replacement prevents a failed import from overwriting a valid list.
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }
}
