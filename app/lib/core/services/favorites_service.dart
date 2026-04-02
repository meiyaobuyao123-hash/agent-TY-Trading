import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user's favorite/starred market symbols.
/// Uses SharedPreferences for local persistence.
class FavoritesService {
  static const String _key = 'favorite_symbols';

  /// Get all favorite symbols.
  Future<Set<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.toSet();
  }

  /// Toggle a symbol's favorite status. Returns the new favorite state.
  Future<bool> toggleFavorite(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    final set = list.toSet();
    final isFavorite = set.contains(symbol);
    if (isFavorite) {
      set.remove(symbol);
    } else {
      set.add(symbol);
    }
    await prefs.setStringList(_key, set.toList());
    return !isFavorite;
  }

  /// Check if a symbol is favorited.
  Future<bool> isFavorite(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.contains(symbol);
  }
}

/// Provider for the favorites service singleton.
final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  return FavoritesService();
});

/// Notifier that holds the current set of favorites and provides toggle functionality.
class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final service = ref.watch(favoritesServiceProvider);
    return service.getFavorites();
  }

  Future<void> toggle(String symbol) async {
    final service = ref.read(favoritesServiceProvider);
    await service.toggleFavorite(symbol);
    state = AsyncData(await service.getFavorites());
  }
}

/// Provider for the favorites notifier.
final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);
