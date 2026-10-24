import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/core/country_catalog.dart';

void main() {
  test('country codes are unique, upper case ISO-2', () {
    final codes = supportedCountries.map((country) => country.code).toList();
    expect(codes.toSet().length, codes.length);
    for (final code in codes) {
      expect(RegExp(r'^[A-Z]{2}$').hasMatch(code), isTrue, reason: code);
    }
  });

  test('countryByCode ignores case and rejects unknown values', () {
    expect(countryByCode('pe')?.name, 'Perú');
    expect(countryByCode(' ar ')?.code, 'AR');
    expect(countryByCode('ZZ'), isNull);
    expect(countryByCode(null), isNull);
    expect(countryByCode(''), isNull);
  });

  test('flags are built from the ISO code', () {
    expect(countryByCode('AR')!.flag, '🇦🇷');
    expect(countryByCode('PE')!.flag, '🇵🇪');
    expect(countryByCode('US')!.flag, '🇺🇸');
  });

  test('regions map to the expected app language', () {
    expect(countryByCode('PE')!.languageCode, 'es');
    expect(countryByCode('US')!.languageCode, 'en');
    expect(countryByCode('BR')!.languageCode, 'pt');
    for (final country in supportedCountries) {
      expect(const ['es', 'en', 'pt'], contains(country.languageCode));
    }
  });
}
