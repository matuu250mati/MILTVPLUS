import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/models/media_models.dart';
import 'package:miltv_plus/models/tv_channel.dart';

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

  test('groups sports before Argentine country classification', () {
    const channel = TvChannel(
      name: 'TyC Sports',
      streamUrl: 'https://media.example.org/live.m3u8',
      country: 'AR',
      category: 'TV Argentina',
    );
    expect(channel.liveSection, 'Deportes');
  });

  test('classifies news and culture as distinct canonical live-TV sections', () {
    const news = TvChannel(
      name: 'Canal de Noticias',
      streamUrl: 'https://media.example.org/news.m3u8',
      groupTitle: 'News',
    );
    const culture = TvChannel(
      name: 'Cultura TV',
      streamUrl: 'https://media.example.org/culture.m3u8',
      groupTitle: 'Culture',
    );
    expect(news.liveSection, 'Noticias');
    expect(culture.liveSection, 'Cultura/Documentales');
  });

  test('classifies authorized HBO streams as HBO/Cine, not VOD movies', () {
    const channel = TvChannel(
      name: 'HBO',
      streamUrl: 'https://media.example.org/hbo.m3u8',
      groupTitle: 'Movies',
    );
    expect(channel.liveSection, 'HBO/Cine');
  });

  test('keeps Argentine general channels in the Argentina section', () {
    const channel = TvChannel(
      name: 'Telefe',
      streamUrl: 'https://media.example.org/telefe.m3u8',
      country: 'AR',
      groupTitle: 'General',
    );
    expect(channel.liveSection, 'TV Argentina');
  });

  test('honors canonical genre categories even when the country is Argentina', () {
    const sports = TvChannel(
      name: 'Canal deportivo',
      streamUrl: 'https://media.example.org/sports.m3u8',
      country: 'AR',
      category: 'Deportes',
    );
    const news = TvChannel(
      name: 'Canal informativo',
      streamUrl: 'https://media.example.org/news.m3u8',
      country: 'Argentina',
      category: 'Noticias',
    );
    const culture = TvChannel(
      name: 'Canal cultural',
      streamUrl: 'https://media.example.org/culture.m3u8',
      country: 'AR',
      category: 'Cultura/Documentales',
    );
    const hbo = TvChannel(
      name: 'HBO',
      streamUrl: 'https://media.example.org/hbo.m3u8',
      country: 'AR',
      category: 'HBO/Cine',
    );

    expect(sports.liveSection, 'Deportes');
    expect(news.liveSection, 'Noticias');
    expect(culture.liveSection, 'Cultura/Documentales');
    expect(hbo.liveSection, 'HBO/Cine');
  });
}
