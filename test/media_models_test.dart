import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/models/media_models.dart';

void main() {
  test('parses a published episode with provider playback URL', () {
    final episode = EpisodeModel.fromJson({
      'id': 'episode-1',
      'series_id': 'series-1',
      'title': 'Capítulo 1',
      'synopsis': 'Inicio de la historia',
      'season_number': 2,
      'episode_number': 1,
      'url_stream': 'https://media.example.org/episode-1.m3u8',
      'duration_seconds': 2400,
      'is_published': true,
    });

    expect(episode.id, 'episode-1');
    expect(episode.seriesId, 'series-1');
    expect(episode.title, 'Capítulo 1');
    expect(episode.seasonNumber, 2);
    expect(episode.episodeNumber, 1);
    expect(episode.urlStream, 'https://media.example.org/episode-1.m3u8');
    expect(episode.durationSeconds, 2400);
    expect(episode.isPublished, isTrue);
  });

  test('uses safe defaults for optional episode metadata', () {
    final episode = EpisodeModel.fromJson({
      'series_id': 'series-2',
      'title': 'Episodio sin metadatos',
      'url_stream': 'https://media.example.org/episode.m3u8',
    });

    expect(episode.seasonNumber, 1);
    expect(episode.episodeNumber, 1);
    expect(episode.synopsis, isNull);
    expect(episode.durationSeconds, isNull);
    expect(episode.isPublished, isFalse);
  });
  test('parses the published channel category used by live-TV filters', () {
    final channel = ChannelModel.fromJson({
      'id': 'channel-1',
      'title': 'TyC Sports',
      'category': 'Deportes',
      'url_stream': 'https://media.example.org/live.m3u8',
      'is_published': true,
      'sort_order': 4,
    });

    expect(channel.title, 'TyC Sports');
    expect(channel.category, 'Deportes');
    expect(channel.urlStream, 'https://media.example.org/live.m3u8');
    expect(channel.isPublished, isTrue);
  });

}
