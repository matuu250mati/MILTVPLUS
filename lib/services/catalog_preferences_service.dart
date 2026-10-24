import 'package:shared_preferences/shared_preferences.dart';

/// Guarda en el dispositivo los favoritos y los "me gusta" del catálogo.
///
/// Cada título se identifica con una clave estable, por ejemplo `movie:<id>`
/// o `series:<id>`, para que películas y series nunca se mezclen.
class CatalogPreferencesService {
  const CatalogPreferencesService();

  static const favoritesStorageKey = 'catalog_favorites_v1';
  static const likesStorageKey = 'catalog_likes_v1';

  Future<bool> isFavorite(String itemKey) => _contains(favoritesStorageKey, itemKey);

  Future<bool> isLiked(String itemKey) => _contains(likesStorageKey, itemKey);

  Future<void> setFavorite(String itemKey, bool value) =>
      _set(favoritesStorageKey, itemKey, value);

  Future<void> setLiked(String itemKey, bool value) =>
      _set(likesStorageKey, itemKey, value);

  Future<Set<String>> favorites() => _read(favoritesStorageKey);

  Future<Set<String>> _read(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(storageKey) ?? const <String>[]).toSet();
  }

  Future<bool> _contains(String storageKey, String itemKey) async {
    final values = await _read(storageKey);
    return values.contains(itemKey);
  }

  Future<void> _set(String storageKey, String itemKey, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final values = (prefs.getStringList(storageKey) ?? const <String>[]).toSet();
    if (value) {
      values.add(itemKey);
    } else {
      values.remove(itemKey);
    }
    await prefs.setStringList(storageKey, values.toList()..sort());
  }
}
