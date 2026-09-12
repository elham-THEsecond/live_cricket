import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // Backend URL — change this for your setup.
  // 10.0.2.2 maps to the host's localhost from the Android emulator;
  // use your machine's LAN IP for a real device.
  static const String apiBaseUrl = 'http://10.0.2.2:8000';

  static const String streamsEndpoint = '/api/streams';
  static const String refreshEndpoint = '/api/refresh';

  // Player
  static const Duration streamErrorTimeout = Duration(seconds: 15);
  static const int maxRetries = 3;

  // UI
  static const double channelTileHeight = 72.0;
  static const double defaultPadding = 16.0;
  static const BorderRadius defaultBorderRadius =
      BorderRadius.all(Radius.circular(12));

  // SharedPreferences keys
  static const String lastChannelKey = 'last_watched_channel';
  static const String favoritesKey = 'favorite_channels';
  static const String themeKey = 'theme_mode';
  static const String apiBaseUrlKey = 'api_base_url';
}