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
  await temporary.writeAsString(contents, flush: true);
  if (await file.exists()) await file.delete();
  await temporary.rename(file.path);
}
