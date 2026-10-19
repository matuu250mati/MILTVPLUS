import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/models/tv_channel.dart';
import 'package:miltv_plus/services/m3u_playlist_parser.dart';
import 'package:miltv_plus/services/stream_service.dart';

void main() {
  const service = StreamService();

  group('StreamService.isSupportedHlsUrl', () {
    test('accepts direct HLS URLs', () {
      expect(
        service.isSupportedHlsUrl('https://media.example/live/index.m3u8'),
        isTrue,
      );
    });

    test('accepts tokenized provider endpoints without an m3u8 suffix', () {
      expect(
        service.isSupportedHlsUrl(
          'https://provider.example/live/channel/123?token=temporary-token',
        ),
        isTrue,
      );
    });

    test('rejects cleartext HTTP because Android blocks it', () {
      expect(service.isSupportedHlsUrl('http://media.example/live.m3u8'), isFalse);
    });

    test('rejects unsupported schemes and missing hosts', () {
      expect(service.isSupportedHlsUrl('ftp://media.example/live.m3u8'), isFalse);
      expect(service.isSupportedHlsUrl('/live/index.m3u8'), isFalse);
      expect(service.isSupportedHlsUrl('https:///live/index.m3u8'), isFalse);
    });

    test('rejects embedded credentials', () {
      expect(
        service.isSupportedHlsUrl(
          'https://user:password@media.example/live/index.m3u8',
        ),
        isFalse,
      );
    });
  });
  m3uParserTests();
}

void m3uParserTests() {
  const parser = M3uPlaylistParser();

  group('M3uPlaylistParser HTTPS policy', () {
    test('keeps safe HTTP/HTTPS candidates and filters credential URLs', () {
      const playlist = '''
#EXTM3U
#EXTINF:-1,HTTPS News
https://stream.example/news/index.m3u8
#EXTINF:-1,HTTP Legacy
http://legacy.example/live.m3u8
#EXTINF:-1,Credential URL
https://user:pass@stream.example/private.m3u8
''';
      final channels = parser.parse(playlist);

      expect(channels, hasLength(2));
      expect(channels.first, isA<TvChannel>());
      expect(channels.first.name, 'HTTPS News');
      expect(channels.first.streamUrl, 'https://stream.example/news/index.m3u8');
      expect(channels.last.name, 'HTTP Legacy');
      expect(channels.last.streamUrl, 'http://legacy.example/live.m3u8');
    });

    test('deduplicates stream URLs that differ only by fragment', () {
      const playlist = '''
#EXTM3U
#EXTINF:-1,Channel A
https://stream.example/live.m3u8#first
#EXTINF:-1,Channel A duplicate
https://stream.example/live.m3u8#second
''';
      expect(parser.parse(playlist), hasLength(1));
    });
  });
}
