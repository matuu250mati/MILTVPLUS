import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/services/catalog_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('guarda y quita favoritos sin mezclar películas y series', () async {
    const service = CatalogPreferencesService();

    await service.setFavorite('movie:1', true);
    await service.setFavorite('series:1', true);

    expect(await service.isFavorite('movie:1'), isTrue);
    expect(await service.isFavorite('series:1'), isTrue);
    expect(await service.isFavorite('movie:2'), isFalse);

    await service.setFavorite('movie:1', false);

    expect(await service.isFavorite('movie:1'), isFalse);
    expect(await service.favorites(), <String>{'series:1'});
  });

  test('los me gusta son independientes de los favoritos', () async {
    const service = CatalogPreferencesService();

    await service.setLiked('movie:1', true);

    expect(await service.isLiked('movie:1'), isTrue);
    expect(await service.isFavorite('movie:1'), isFalse);
  });
}
