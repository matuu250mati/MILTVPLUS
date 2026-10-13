import 'dart:convert';

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
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('Ingresá una URL HTTP(S) válida para la lista M3U.');
    }

    final response = await _dio.get<ResponseBody>(uri.toString());
    final responseBody = response.data;
    if (responseBody == null) {
      throw const FormatException('La respuesta no contiene una lista M3U.');
    }

    const maxPlaylistBytes = 20 * 1024 * 1024;
    final bytes = <int>[];
    await for (final chunk in responseBody.stream) {
      if (bytes.length + chunk.length > maxPlaylistBytes) {
        throw const FormatException('La lista supera el límite de 20 MB.');
      }
      bytes.addAll(chunk);
    }
    final body = utf8.decode(bytes, allowMalformed: true);
    if (body.trim().isEmpty) {
      throw const FormatException('La lista recibida está vacía.');
    }

    final channels = _parser.parse(body);
    if (channels.isEmpty) {
      throw const FormatException(
        'La URL respondió, pero no se encontraron señales HTTP(S) en formato M3U.',
      );
    }
    return channels;
  }
}
