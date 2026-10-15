import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/tv_channel.dart';
import 'm3u_playlist_parser.dart';

/// Downloads and parses a user-provided M3U/M3U8 playlist.
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

  Future<List<TvChannel>> importFromUrl(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.scheme != 'https') {
      throw const FormatException('Ingresá una URL HTTPS válida para la lista M3U.');
    }

    final response = await _dio.get<ResponseBody>(uri.toString());
    final responseBody = response.data;
    if (responseBody == null) {
      throw const FormatException('La respuesta no contiene una lista M3U.');
    }

    // Global IPTV playlists can exceed 20 MB. A strict 20 MB ceiling made
    // the repository playlist fail before the UI could show any channels.
    const maxPlaylistBytes = 50 * 1024 * 1024;
    final bytes = BytesBuilder(copy: false);
    var receivedBytes = 0;
    await for (final chunk in responseBody.stream) {
      receivedBytes += chunk.length;
      if (receivedBytes > maxPlaylistBytes) {
        throw const FormatException('La lista supera el límite seguro de 50 MB.');
      }
      bytes.add(chunk);
    }
    final body = utf8.decode(bytes.takeBytes(), allowMalformed: true);
    if (body.trim().isEmpty) {
      throw const FormatException('La lista recibida está vacía.');
    }

    final channels = _parser.parse(body);
    if (channels.isEmpty) {
      throw const FormatException(
        'La URL respondió, pero no se encontraron señales HTTPS en formato M3U.',
      );
    }
    return channels;
  }
}
