import 'dart:convert';

import 'package:dio/dio.dart';

/// Reads quality variants from an HLS master playlist when the provider exposes them.
class HlsVariantService {
  HlsVariantService({Dio? dio}) : _dio = dio ?? Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      responseType: ResponseType.plain,
      headers: const {'Accept': 'application/vnd.apple.mpegurl, application/x-mpegURL, */*'},
    ),
  );

  final Dio _dio;

  Future<List<HlsVariant>> loadVariants(String source) async {
    final uri = Uri.tryParse(source.trim());
    if (uri == null || !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.userInfo.isNotEmpty) {
      return const [];
    }
    try {
      final response = await _dio.get<String>(uri.toString()).timeout(
        const Duration(seconds: 5),
      );
      final body = response.data;
      if (body == null || body.length > 1024 * 1024 ||
          !body.trimLeft().startsWith('#EXTM3U')) {
        return const [];
      }
      final lines = const LineSplitter().convert(body);
      final variants = <HlsVariant>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
        final attributes = line.substring('#EXT-X-STREAM-INF:'.length);
        final resolution = RegExp(r'RESOLUTION=(\d+)x(\d+)', caseSensitive: false).firstMatch(attributes);
        final bandwidth = RegExp(r'BANDWIDTH=(\d+)', caseSensitive: false).firstMatch(attributes);
        String? candidate;
        for (var j = i + 1; j < lines.length; j++) {
          final next = lines[j].trim();
          if (next.isEmpty || next.startsWith('#')) continue;
          candidate = uri.resolve(next).toString();
          i = j;
          break;
        }
        if (candidate == null) continue;
        final resolved = Uri.tryParse(candidate);
        if (resolved == null || !resolved.hasAuthority ||
            (resolved.scheme != 'https' && resolved.scheme != 'http') ||
            resolved.userInfo.isNotEmpty) continue;
        final height = int.tryParse(resolution?.group(2) ?? '');
        final width = int.tryParse(resolution?.group(1) ?? '');
        variants.add(HlsVariant(
          url: candidate,
          label: height == null ? 'Auto' : '${height}p',
          height: height,
          width: width,
          bandwidth: int.tryParse(bandwidth?.group(1) ?? ''),
        ));
      }
      final unique = <String, HlsVariant>{};
      for (final variant in variants) {
        unique.putIfAbsent(variant.url, () => variant);
      }
      final result = unique.values.toList()
        ..sort((a, b) => (a.height ?? 0).compareTo(b.height ?? 0));
      return result;
    } catch (_) {
      return const [];
    }
  }
}

class HlsVariant {
  const HlsVariant({
    required this.url,
    required this.label,
    this.height,
    this.width,
    this.bandwidth,
  });

  final String url;
  final String label;
  final int? height;
  final int? width;
  final int? bandwidth;
}
