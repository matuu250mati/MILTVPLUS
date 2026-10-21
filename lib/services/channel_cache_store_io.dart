import 'dart:io';

import 'package:path_provider/path_provider.dart';

const _fileName = 'miltv_plus_channels_v1.json';

Future<String?> readCache() async {
  try {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/$_fileName');
    if (!await file.exists()) return null;
    return await file.readAsString();
  } on FileSystemException {
    return null;
  }
}

Future<void> writeCache(String contents) async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final file = File('${directory.path}/$_fileName');
  final temporary = File('${file.path}.tmp');
  final backup = File('${file.path}.bak');
  await temporary.writeAsString(contents, flush: true);

  if (await backup.exists()) await backup.delete();
  final hadPreviousCache = await file.exists();
  if (hadPreviousCache) await file.rename(backup.path);
  try {
    await temporary.rename(file.path);
    if (await backup.exists()) await backup.delete();
  } catch (_) {
    // Restore the previous cache if replacing it failed.
    if (!await file.exists() && await backup.exists()) {
      await backup.rename(file.path);
    }
    rethrow;
  }
}
