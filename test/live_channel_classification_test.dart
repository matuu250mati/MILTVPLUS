import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/models/tv_channel.dart';

void main() {
  group('TvChannel.liveSection classification', () {
    test('recognizes international sports from noncanonical categories', () {
      const channel = TvChannel(
        name: 'ESPN Internacional',
        streamUrl: 'https://streams.example.test/espn.m3u8',
        category: 'International Sports',
      );

      expect(channel.liveSection, 'Deportes');
    });

    test('recognizes Argentine sports from group metadata', () {
      const channel = TvChannel(
        name: 'Canal de eventos',
        streamUrl: 'https://streams.example.test/events.m3u8',
        category: 'General',
        groupTitle: 'Deportes Argentina',
        country: 'AR',
      );

      expect(channel.liveSection, 'Deportes');
    });

    test('retains Argentine broadcaster classification with broad category', () {
      const channel = TvChannel(
        name: 'Telefe',
        streamUrl: 'https://streams.example.test/telefe.m3u8',
        category: 'General',
        country: 'AR',
      );

      expect(channel.liveSection, 'TV Argentina');
    });
  });
}
