import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseUrl,
    required this.forceUpdate,
    this.releaseNotes = '',
  });

  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseUrl;
  final bool forceUpdate;
  final String releaseNotes;
}

class UpdateService {
  UpdateService._();

  static const _releaseApi =
      'https://api.github.com/repos/matuu250mati/MILTVPLUS/releases/latest';
  static const _releasePage =
      'https://github.com/matuu250mati/MILTVPLUS/releases/latest';

  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final response = await Dio().get<Map<String, dynamic>>(
        _releaseApi,
        options: Options(
          responseType: ResponseType.json,
          headers: const {'Accept': 'application/vnd.github+json'},
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final data = response.data;
      if (data == null || data['draft'] == true || data['prerelease'] == true) {
        return null;
      }

      final tag = (data['tag_name'] as String? ?? '').trim();
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;
      if (latest.isEmpty || !_isNewer(latest, package.version)) return null;

      final assets = data['assets'] as List<dynamic>? ?? const [];
      String? apkUrl;
      for (final asset in assets) {
        if (asset is Map<String, dynamic> &&
            (asset['name'] as String? ?? '').toLowerCase() == 'miltvplus.apk') {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
      final downloadUrl = apkUrl ?? 'https://github.com/matuu250mati/MILTVPLUS/releases/latest/download/MILTVPLUS.apk';
      final body = (data['body'] as String? ?? '');
      return AppUpdateInfo(
        currentVersion: package.version,
        latestVersion: latest,
        downloadUrl: downloadUrl,
        releaseUrl: data['html_url'] as String? ?? _releasePage,
        forceUpdate: body.toLowerCase().contains('[force-update]'),
        releaseNotes: body.replaceAll('[force-update]', '').trim(),
      );
    } catch (error, stack) {
      debugPrint('MILTVPLUS update check skipped: $error');
      debugPrintStack(stackTrace: stack);
      return null; // Updates must never prevent the app from opening offline.
    }
  }

  static bool _isNewer(String remote, String local) {
    List<int> parse(String value) => value
        .split('+').first
        .split('-').first
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final a = parse(remote);
    final b = parse(local);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av > bv;
    }
    return false;
  }

  /// Downloads the official APK and hands it to Android's package installer.
  /// Android still requires the user to confirm the installation.
  static Future<String> downloadAndOpenInstaller(String url) async {
    final directory = await getTemporaryDirectory();
    final apk = File('${directory.path}/MILTVPLUS-update.apk');
    await Dio().download(
      url,
      apk.path,
      options: Options(
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 3),
        sendTimeout: const Duration(seconds: 20),
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) debugPrint('MILTVPLUS update download: $received / $total');
      },
    );
    if (!await apk.exists() || await apk.length() < 1024 * 1024) {
      throw const HttpException('El APK descargado está vacío o incompleto.');
    }
    final result = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception(result.message.isEmpty
          ? 'Android no pudo abrir el instalador.'
          : result.message);
    }
    return apk.path;
  }
}
