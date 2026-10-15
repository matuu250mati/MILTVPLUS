import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurePinService {
  SecurePinService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _pinKey = 'adult_access_pin_sha256';
  final FlutterSecureStorage _storage;

  Future<bool> hasPin() async => (await _storage.read(key: _pinKey)) != null;

  Future<void> clearPin() async => _storage.delete(key: _pinKey);

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw ArgumentError('El PIN debe tener entre 4 y 8 números.');
    }
    final digest = sha256.convert(utf8.encode(pin)).toString();
    await _storage.write(key: _pinKey, value: digest);
  }

  Future<bool> verifyPin(String pin) async {
    final saved = await _storage.read(key: _pinKey);
    if (saved == null || !RegExp(r'^\d{4,8}$').hasMatch(pin)) return false;
    final digest = sha256.convert(utf8.encode(pin)).toString();
    return digest == saved;
  }
}
