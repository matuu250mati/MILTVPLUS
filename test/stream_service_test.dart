import 'package:flutter_test/flutter_test.dart';
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
}
