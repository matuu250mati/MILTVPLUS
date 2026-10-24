/// Countries a MILTVPLUS user can pick at sign-up. [languageCode] is the app
/// language that region is expected to use (es / en / pt).
class CountryOption {
  const CountryOption(this.code, this.name, this.languageCode);

  /// ISO 3166-1 alpha-2 code, upper case.
  final String code;
  final String name;
  final String languageCode;

  /// Flag emoji built from the ISO code (regional indicator symbols).
  String get flag => String.fromCharCodes(
        code.codeUnits.map((unit) => 0x1F1E6 + unit - 65),
      );
}

const List<CountryOption> supportedCountries = <CountryOption>[
  CountryOption('AR', 'Argentina', 'es'),
  CountryOption('BO', 'Bolivia', 'es'),
  CountryOption('BR', 'Brasil', 'pt'),
  CountryOption('CA', 'Canadá', 'en'),
  CountryOption('CL', 'Chile', 'es'),
  CountryOption('CO', 'Colombia', 'es'),
  CountryOption('CR', 'Costa Rica', 'es'),
  CountryOption('CU', 'Cuba', 'es'),
  CountryOption('DE', 'Alemania', 'en'),
  CountryOption('DO', 'República Dominicana', 'es'),
  CountryOption('EC', 'Ecuador', 'es'),
  CountryOption('ES', 'España', 'es'),
  CountryOption('FR', 'Francia', 'en'),
  CountryOption('GB', 'Reino Unido', 'en'),
  CountryOption('GT', 'Guatemala', 'es'),
  CountryOption('HN', 'Honduras', 'es'),
  CountryOption('IT', 'Italia', 'en'),
  CountryOption('MX', 'México', 'es'),
  CountryOption('NI', 'Nicaragua', 'es'),
  CountryOption('PA', 'Panamá', 'es'),
  CountryOption('PE', 'Perú', 'es'),
  CountryOption('PR', 'Puerto Rico', 'es'),
  CountryOption('PT', 'Portugal', 'pt'),
  CountryOption('PY', 'Paraguay', 'es'),
  CountryOption('SV', 'El Salvador', 'es'),
  CountryOption('US', 'Estados Unidos', 'en'),
  CountryOption('UY', 'Uruguay', 'es'),
  CountryOption('VE', 'Venezuela', 'es'),
];

/// Looks a country up by ISO code, ignoring case. Returns null if unknown.
CountryOption? countryByCode(String? code) {
  final normalized = (code ?? '').trim().toUpperCase();
  if (normalized.isEmpty) return null;
  for (final country in supportedCountries) {
    if (country.code == normalized) return country;
  }
  return null;
}
