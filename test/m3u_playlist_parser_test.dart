import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/services/m3u_playlist_parser.dart';

void main() {
  const parser = M3uPlaylistParser();

  test('imports HTTPS channels and reports HTTP streams as unsupported', () {
    final channels = parser.parse('''
#EXTM3U
#EXTINF:-1 tvg-id="one" tvg-name="Canal Uno" group-title="Argentina",Canal Uno
#EXTVLCOPT:http-user-agent=Example
https://example.com/live/one.m3u8
#EXTINF:-1,Canal Dos
http://example.com/two/index.m3u8?token=abc
''');

    expect(channels, hasLength(1));
    expect(channels.single.name, 'Canal Uno');
    expect(channels.single.streamUrl, 'https://example.com/live/one.m3u8');
    expect(channels.single.groupTitle, 'Argentina');

    final report = parser.parseWithReport('''
#EXTM3U
#EXTINF:-1,HTTPS channel
https://example.com/live/one.m3u8
#EXTINF:-1,HTTP legacy channel
http://example.com/two/index.m3u8?token=abc
''');
    expect(report.totalEntries, 2);
    expect(report.imported, 1);
    expect(report.unsupported, 2);
  });

  test('reports imported, duplicate, incomplete and unsupported entries', () {
    final report = parser.parseWithReport('''
#EXTM3U
#EXTINF:-1,Valid channel
https://example.com/live.m3u8?token=keep
#EXTINF:-1,Duplicate label
https://example.com/live.m3u8?token=keep
#EXTINF:-1,Missing URL
#EXTINF:-1,Invalid scheme
file:///tmp/channel.m3u8
#EXTINF:-1,HTTP legacy
http://example.com/live.m3u8
#EXTINF:-1,Web player
https://www.twitch.tv/example
''');

    expect(report.totalEntries, 6);
    expect(report.imported, 1);
    expect(report.duplicates, 1);
    expect(report.incomplete, 2);
    expect(report.unsupported, 1);
    expect(report.channels.single.streamUrl, 'https://example.com/live.m3u8?token=keep');
    expect(report.imported + report.duplicates + report.incomplete + report.unsupported,
        report.totalEntries);
  });

  test('extracts category, country, and language metadata from M3U', () {
    final channels = parser.parse('''
#EXTM3U
#EXTINF:-1 group-title="Deportes" tvg-country="AR" tvg-language="spa",Canal deportivo
https://example.com/sports.m3u8
''');

    expect(channels, hasLength(1));
    expect(channels.single.groupTitle, 'Deportes');
    expect(channels.single.country, 'AR');
    expect(channels.single.language, 'spa');
  });

  test('ignores non-HTTPS URLs and malformed playlist rows', () {
    final channels = parser.parse('''
#EXTM3U
#EXTINF:-1,Invalid
file:///tmp/channel.m3u8
#EXTINF:-1,Valid
https://example.com/live.m3u8
''');

    expect(channels, hasLength(1));
    expect(channels.single.name, 'Valid');
  });

  test('removes duplicate stream URLs while preserving the first channel label', () {
    final channels = parser.parse('''
#EXTM3U
#EXTINF:-1,Canal Uno
https://example.com/live.m3u8
#EXTINF:-1,Alias duplicado
https://example.com/live.m3u8
#EXTINF:-1,Canal Dos
https://example.com/other.m3u8
''');

    expect(channels, hasLength(2));
    expect(channels[0].name, 'Canal Uno');
    expect(channels[1].name, 'Canal Dos');
  });

  test('deduplicates equivalent host casing and URL fragments', () {
    final channels = parser.parse('''
#EXTM3U
#EXTINF:-1,Original
https://EXAMPLE.com/live/../live.m3u8#first
#EXTINF:-1,Duplicate
https://example.com/live.m3u8#second
''');

    expect(channels, hasLength(1));
    expect(channels.single.name, 'Original');
  });

  test('rejects stream URLs with embedded user information', () {
    final channels = parser.parse('''
#EXTM3U
#EXTINF:-1,Unsafe credential URL
https://user:password@example.com/live.m3u8
#EXTINF:-1,Valid channel
https://example.com/valid.m3u8
''');

    expect(channels, hasLength(1));
    expect(channels.single.name, 'Valid channel');
  });

  test('uses a fallback name when EXTINF has no display name', () {
    final channels = parser.parse('''
#EXTM3U
#EXTINF:-1 tvg-name="News"
https://example.com/news.m3u8
''');

    expect(channels, hasLength(1));
    expect(channels.single.name, 'News');
  });

  test('skips web-player pages that are not direct streams', () {
    final channels = parser.parse('''
#EXTM3U
#EXTINF:-1,YouTube page
https://www.youtube.com/c/todonoticias/live
#EXTINF:-1,Twitch page
https://www.twitch.tv/examplechannel
#EXTINF:-1,Direct HLS
https://cdn.example.org/live/playlist.m3u8
''');

    expect(channels, hasLength(1));
    expect(channels.single.name, 'Direct HLS');
    expect(channels.single.streamUrl, 'https://cdn.example.org/live/playlist.m3u8');
  });

  test('parses tvg-name, logo, id and quoted commas without breaking metadata', () {
    final channels = parser.parse('''
#EXTM3U
#EXTINF:-1 tvg-name="Canal, Noticias" tvg-logo="https://example.com/logo.png" tvg-id="news.ar" tvg-country="AR" group-title="News",Canal, Noticias HD
https://example.com/news.m3u8
''');

    expect(channels, hasLength(1));
    expect(channels.single.name, 'Canal, Noticias');
    expect(channels.single.logoUrl, 'https://example.com/logo.png');
    expect(channels.single.tvgId, 'news.ar');
    expect(channels.single.country, 'AR');
    expect(channels.single.groupTitle, 'News');
    expect(channels.single.liveSection, 'Noticias');
  });

  test('skips web-player URLs instead of treating them as direct streams', () {
    final channels = parser.parse('''
#EXTM3U
#EXTINF:-1,Player page
https://www.twitch.tv/example
#EXTINF:-1,Direct stream
https://example.com/live.m3u8
''');

    expect(channels, hasLength(1));
    expect(channels.single.name, 'Direct stream');
  });
}
