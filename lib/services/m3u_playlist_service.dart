import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/tv_channel.dart';
import 'm3u_playlist_parser.dart';

/// Downloads and diagnoses a user-provided M3U/M3U8 playlist.
class M3uPlaylistService {
  M3uPlaylistService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              maxRedirects: 5,
              responseType: ResponseType.stream,
              followRedirects: true,
              validateStatus: (status) => status != null && status >= 200 && status < 300,
            ));

  final Dio _dio;
  final M3uPlaylistParser _parser = const M3uPlaylistParser();

  /// Compatibility method retained for existing callers.
  Future<List<TvChannel>> importFromUrl(String value) async =>
      (await importReportFromUrl(value)).channels;

  Future<M3uParseReport> importReportFromUrl(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty ||
        uri.scheme != 'https') {
      throw const FormatException('Ingresá una URL HTTPS válida para la lista M3U.');
    }

    final response = await _dio.get<ResponseBody>(uri.toString());
    final responseBody = response.data;
    if (responseBody == null) {
      throw const FormatException('La respuesta no contiene una lista M3U.');
    }

    const maxPlaylistBytes = 120 * 1024 * 1024;
    var receivedBytes = 0;

    // Count bytes while forwarding chunks to the UTF-8 line decoder. The
    // parser retains channel records, not the entire raw playlist in memory.
    Stream<List<int>> limitedChunks() async* {
      await for (final chunk in responseBody.stream) {
        receivedBytes += chunk.length;
        if (receivedBytes > maxPlaylistBytes) {
          throw const FormatException('La lista supera el límite configurado de 120 MB.');
        }
        yield chunk;
      }
    }

    final lines = const LineSplitter().bind(
      Utf8Decoder(allowMalformed: true).bind(limitedChunks()),
    );
    final report = await _parser.parseStream(lines);
    if (receivedBytes == 0 || report.totalEntries == 0) {
      throw const FormatException('La respuesta no contiene entradas #EXTINF de una lista M3U.');
    }
    return report;
  }
}
