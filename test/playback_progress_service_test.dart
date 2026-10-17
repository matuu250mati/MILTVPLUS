import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miltv_plus/services/playback_progress_service.dart';

void main() {
  const service = PlaybackProgressService();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlaybackProgressService', () {
    test('does not expose the source URL in its storage key', () {
      const url = 'https://provider.example/movie/secret-token/index.m3u8';
      final key = PlaybackProgressService.keyFor(
        title: 'Película de prueba',
        streamUrl: url,
      );

      expect(key, startsWith('miltvplus_vod_progress_'));
      expect(key, isNot(contains(url)));
      expect(key, hasLength('miltvplus_vod_progress_'.length + 64));
    });

    test('saves and loads a valid resume position', () async {
      final key = PlaybackProgressService.keyFor(
        title: 'Película',
        streamUrl: 'https://media.example/movie.m3u8',
      );

      await service.save(
        key: key,
        position: const Duration(minutes: 12, seconds: 15),
        duration: const Duration(minutes: 90),
      );

      expect(
        await service.load(
          key: key,
          duration: const Duration(minutes: 90),
        ),
        const Duration(minutes: 12, seconds: 15),
      );
    });

    test('clears progress close to the end instead of resuming credits', () async {
      final key = PlaybackProgressService.keyFor(
        title: 'Película',
        streamUrl: 'https://media.example/movie.m3u8',
      );

      await service.save(
        key: key,
        position: const Duration(minutes: 89, seconds: 40),
        duration: const Duration(minutes: 90),
      );

      expect(
        await service.load(
          key: key,
          duration: const Duration(minutes: 90),
        ),
        isNull,
      );
    });

    test('does not resume a position below the minimum threshold', () async {
      final key = PlaybackProgressService.keyFor(
        title: 'Película',
        streamUrl: 'https://media.example/movie.m3u8',
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(key, const Duration(seconds: 5).inMilliseconds);

      expect(
        await service.load(
          key: key,
          duration: const Duration(minutes: 90),
        ),
        isNull,
      );
    });
  });
}
