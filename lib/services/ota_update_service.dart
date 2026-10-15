import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class OtaUpdateInfo {
  const OtaUpdateInfo({
    required this.message,
    this.updateAvailable = false,
    this.mandatory = false,
    this.currentVersion = '',
    this.latestVersion = '',
    this.sizeBytes = 0,
  });

  final String message;
  final bool updateAvailable;
  final bool mandatory;
  final String currentVersion;
  final String latestVersion;
  final int sizeBytes;

  String get formattedSize {
    if (sizeBytes <= 0) return 'Tamaño no publicado';
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class OtaUpdateResult {
  const OtaUpdateResult({
    required this.message,
    this.updateAvailable = false,
    this.installerOpened = false,
  });

  final String message;
  final bool updateAvailable;
  final bool installerOpened;
}

/// Manual, user-triggered Android OTA. It never installs silently.
class OtaUpdateService {
  OtaUpdateService({Dio? dio}) : _dio = dio ?? Dio(_options);

  static const _owner = 'matuu250mati';
  static const _repo = 'MILTVPLUS';
  static const _releaseApi =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';
  static const _apkUrl =
      'https://github.com/$_owner/$_repo/releases/latest/download/app-release.apk';
  static const _checksumUrl =
      'https://github.com/$_owner/$_repo/releases/latest/download/app-release.apk.sha256';
  static const _apkMime = 'application/vnd.android.package-archive';

  static final BaseOptions _options = BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(minutes: 5),
    sendTimeout: const Duration(seconds: 20),
    headers: const {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'MILTVPLUS-Android-Updater',
    },
    followRedirects: true,
    maxRedirects: 5,
  );

  final Dio _dio;

  /// Reads release metadata without downloading or opening the installer.
  /// A release is mandatory only when its description explicitly contains
  /// MILTVPLUS-REQUIRED-UPDATE: true.
  Future<OtaUpdateInfo> checkForUpdate() async {
    if (!Platform.isAndroid) {
      return const OtaUpdateInfo(message: 'La actualización automática solo está disponible en Android.');
    }
    try {
      final response = await _dio.get<dynamic>(_releaseApi);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const OtaUpdateInfo(message: 'Respuesta de versión no válida.');
      }
      final tag = data['tag_name'];
      if (tag is! String || tag.trim().isEmpty) {
        return const OtaUpdateInfo(message: 'La versión publicada no tiene una etiqueta válida.');
      }
      final package = await PackageInfo.fromPlatform();
      final latest = _normalizeVersion(tag);
      final installed = _normalizeVersion(package.version);
      if (latest == null || installed == null) {
        return const OtaUpdateInfo(message: 'No se pudieron comparar las versiones.');
      }
      final assets = data['assets'];
      var sizeBytes = 0;
      if (assets is List) {
        for (final asset in assets) {
          if (asset is Map<String, dynamic> &&
              asset['name'] == 'app-release.apk' &&
              asset['size'] is num) {
            sizeBytes = (asset['size'] as num).toInt();
            break;
          }
        }
      }
      final body = data['body'] is String ? data['body'] as String : '';
      final mandatory = RegExp(
        r'MILTVPLUS-REQUIRED-UPDATE:\s*true',
        caseSensitive: false,
      ).hasMatch(body);
      final available = _compareVersions(latest, installed) > 0;
      return OtaUpdateInfo(
        updateAvailable: available,
        mandatory: available && mandatory,
        currentVersion: package.version,
        latestVersion: tag,
        sizeBytes: sizeBytes,
        message: available ? 'Hay una versión nueva disponible.' : 'MILTVPLUS está actualizado.',
      );
    } catch (_) {
      return const OtaUpdateInfo(message: 'No se pudo consultar la versión publicada.');
    }
  }

  Future<OtaUpdateResult> checkAndInstall() async {
    if (!Platform.isAndroid) {
      return const OtaUpdateResult(
        message: 'La actualización OTA solo está disponible en Android.',
      );
    }

    try {
      final releaseResponse = await _dio.get<dynamic>(_releaseApi);
      final data = releaseResponse.data;
      if (data is! Map<String, dynamic>) {
        return const OtaUpdateResult(
          message: 'GitHub devolvió una respuesta de versión no válida.',
        );
      }

      final tag = data['tag_name'];
      if (tag is! String || tag.trim().isEmpty) {
        return const OtaUpdateResult(
          message: 'La última Release no tiene una versión válida.',
        );
      }

      final package = await PackageInfo.fromPlatform();
      final latestVersion = _normalizeVersion(tag);
      final installedVersion = _normalizeVersion(package.version);
      if (latestVersion == null || installedVersion == null) {
        return const OtaUpdateResult(
          message: 'No se pudo interpretar la versión instalada o publicada.',
        );
      }

      if (_compareVersions(latestVersion, installedVersion) <= 0) {
        return OtaUpdateResult(
          message: 'MILTVPLUS está actualizado (versión ${package.version}).',
        );
      }

      final directory = await getTemporaryDirectory();
      final apkFile = File('${directory.path}/miltvplus-update.apk');
      if (await apkFile.exists()) await apkFile.delete();

      final checksumResponse = await _dio.get<String>(
        _checksumUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final expectedHash = _readChecksum(checksumResponse.data ?? '');
      if (expectedHash == null) {
        return const OtaUpdateResult(
          message: 'La Release no incluye un SHA-256 válido; se canceló la instalación.',
        );
      }

      final downloadResponse = await _dio.download(
        _apkUrl,
        apkFile.path,
        deleteOnError: true,
        options: Options(
          headers: const {'Accept': 'application/octet-stream'},
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      if (downloadResponse.statusCode != HttpStatus.ok ||
          !await apkFile.exists() ||
          await apkFile.length() < 1024 * 1024) {
        if (await apkFile.exists()) await apkFile.delete();
        return const OtaUpdateResult(
          message: 'La descarga del APK quedó incompleta o la Release no está publicada.',
        );
      }

      // Refuse insecure redirects, even if the original URL used HTTPS.
      if (downloadResponse.redirects.any(
        (redirect) => redirect.location.scheme != 'https',
      )) {
        await apkFile.delete();
        return const OtaUpdateResult(
          message: 'La descarga intentó usar una redirección insegura.',
        );
      }

      final header = await apkFile.openRead(0, 4).fold<List<int>>(
        <int>[],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      if (header.length < 4 ||
          header[0] != 0x50 ||
          header[1] != 0x4b) {
        await apkFile.delete();
        return const OtaUpdateResult(
          message: 'El archivo recibido no parece ser un APK válido.',
        );
      }

      // Stream the checksum instead of loading a 50+ MB APK into memory.
      final actualHash = (await sha256.bind(apkFile.openRead()).first).toString();
      if (actualHash.toLowerCase() != expectedHash) {
        await apkFile.delete();
        return const OtaUpdateResult(
          message: 'El SHA-256 no coincide. Por seguridad, no se instalará este archivo.',
        );
      }

      final openResult = await OpenFilex.open(apkFile.path, type: _apkMime);
      if (openResult.type != ResultType.done) {
        return OtaUpdateResult(
          message: 'APK verificado, pero Android no abrió el instalador: ${openResult.message}',
          updateAvailable: true,
        );
      }

      return const OtaUpdateResult(
        message: 'APK verificado. Confirmá la instalación en el instalador de Android.',
        updateAvailable: true,
        installerOpened: true,
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == HttpStatus.notFound) {
        return const OtaUpdateResult(
          message: 'Todavía no hay una Release OTA publicada con app-release.apk y su SHA-256.',
        );
      }
      return const OtaUpdateResult(
        message: 'No se pudo consultar o descargar la actualización. Revisá Internet e intentá otra vez.',
      );
    } on FileSystemException {
      return const OtaUpdateResult(
        message: 'No se pudo guardar el APK temporal en el dispositivo.',
      );
    } catch (_) {
      return const OtaUpdateResult(
        message: 'Ocurrió un error al comprobar la actualización.',
      );
    }
  }

  String? _readChecksum(String content) {
    final match = RegExp(r'^[a-fA-F0-9]{64}').firstMatch(content.trim());
    return match?.group(0)?.toLowerCase();
  }

  List<int>? _normalizeVersion(String version) {
    final match = RegExp(r'v?(\d+(?:\.\d+){1,3})').firstMatch(version.trim());
    if (match == null) return null;
    return match.group(1)!.split('.').map(int.parse).toList();
  }

  int _compareVersions(List<int> left, List<int> right) {
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final a = i < left.length ? left[i] : 0;
      final b = i < right.length ? right[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }
}
