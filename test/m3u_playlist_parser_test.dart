import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/services/m3u_playlist_parser.dart';

void main() {
  const parser = M3uPlaylistParser();

  test('parses named channels and skips metadata lines', () {
    final channels = parser.parse('''
#EXTM3U
#EXTINF:-1 tvg-id="one" tvg-name="Canal Uno" group-title="Argentina",Canal Uno
#EXTVLCOPT:http-user-agent=Example
https://example.com/live/one.m3u8
#EXTINF:-1,Canal Dos
http://example.com/two/index.m3u8?token=abc
''');

    expect(channels, hasLength(2));
    expect(channels[0].name, 'Canal Uno');
    expect(channels[0].streamUrl, 'https://example.com/live/one.m3u8');
    expect(channels[1].name, 'Canal Dos');
    expect(channels[1].streamUrl, 'http://example.com/two/index.m3u8?token=abc');
  });

  test('ignores non-http URLs and malformed playlist rows', () {
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

  test('uses a fallback name when EXTINF has no display name', () {
    final channels = parser.parse('''
#EXTM3U
#EXTINF:-1 tvg-name="News"
https://example.com/news.m3u8
''');

    expect(channels, hasLength(1));
    expect(channels.single.name, 'News');
  });
}
