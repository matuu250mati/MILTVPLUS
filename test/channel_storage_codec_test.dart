import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/models/tv_channel.dart';
import 'package:miltv_plus/services/channel_storage_codec.dart';

void main() {
  group('ChannelStorageCodec', () {
    test('round-trips all channel metadata and ordered backup URLs', () {
      const channel = TvChannel(
        name: 'Canal de prueba',
        streamUrl: 'https://primary.example/live.m3u8',
        groupTitle: 'Noticias',
        country: 'AR',
        language: 'es',
        category: 'Noticias',
        logoUrl: 'https://cdn.example/logo.png',
        tvgId: 'test.channel',
        backupStreamUrls: [
          'https://backup-one.example/live.m3u8',
          'https://backup-two.example/live.m3u8',
        ],
      );

      final decoded = ChannelStorageCodec.decode(
        ChannelStorageCodec.encode([channel]),
      );

      expect(decoded, hasLength(1));
      final restored = decoded.single;
      expect(restored.name, channel.name);
      expect(restored.streamUrl, channel.streamUrl);
      expect(restored.groupTitle, channel.groupTitle);
      expect(restored.country, channel.country);
      expect(restored.language, channel.language);
      expect(restored.category, channel.category);
      expect(restored.logoUrl, channel.logoUrl);
      expect(restored.tvgId, channel.tvgId);
      expect(restored.backupStreamUrls, channel.backupStreamUrls);
      expect(restored.streamUrls, [
        channel.streamUrl,
        ...channel.backupStreamUrls,
      ]);
    });

    test('skips invalid records and accepts older records without optional fields', () {
      final decoded = ChannelStorageCodec.decodeEntries([
        null,
        {'name': 'missing URL'},
        {'name': '   ', 'streamUrl': 'https://empty-name.example/live'},
        {
          'name': 'Legacy channel',
          'streamUrl': 'https://legacy.example/live.m3u8',
          'backupStreamUrls': ['https://backup.example/live.m3u8', 42],
        },
      ]);

      expect(decoded, hasLength(1));
      expect(decoded.single.name, 'Legacy channel');
      expect(decoded.single.groupTitle, isNull);
      expect(decoded.single.backupStreamUrls, [
        'https://backup.example/live.m3u8',
      ]);
    });

    test('rejects corrupted JSON instead of silently accepting it', () {
      expect(
        () => ChannelStorageCodec.decode('{not valid json'),
        throwsFormatException,
      );
    });

    test('returns an empty list for valid JSON with the wrong root type', () {
      expect(ChannelStorageCodec.decode(jsonEncode({'name': 'not a list'})), isEmpty);
    });
  });
}
