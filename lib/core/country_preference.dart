import 'package:shared_preferences/shared_preferences.dart';

import 'country_catalog.dart';

/// Stores the country the user chose, so Live TV can open already filtered
/// to it. Every call is best effort: a storage failure never blocks the app.
class CountryPreference {
  const CountryPreference._();

  static const String _key = 'miltv_country_code';

  static Future<String?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      return countryByCode(code)?.code;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String? code) async {
    final country = countryByCode(code);
    if (country == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, country.code);
    } catch (_) {
      // Ignore: the preference is a convenience, not a requirement.
    }
  }

  /// Copies the `country` saved in the account metadata to this device.
  static Future<void> syncFromMetadata(Map<String, dynamic>? metadata) async {
    final value = metadata?['country'];
    if (value is String) await save(value);
  }
}
