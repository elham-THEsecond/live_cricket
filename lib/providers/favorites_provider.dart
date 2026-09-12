import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

class FavoritesProvider extends ChangeNotifier {
  Set<String> _favorites = {};
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(AppConstants.favoritesKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _favorites = decoded.whereType<String>().toSet();
        notifyListeners();
      }
    } on FormatException {
      // Corrupt prefs: start clean rather than crash on launch.
      _favorites = {};
    }
  }

  Future<void> toggleFavorite(String channelId) async {
    if (!_favorites.remove(channelId)) _favorites.add(channelId);
    notifyListeners();
    await _prefs?.setString(
      AppConstants.favoritesKey,
      jsonEncode(_favorites.toList()),
    );
  }

  bool isFavorite(String channelId) => _favorites.contains(channelId);

  List<String> getFavorites() => _favorites.toList();
}