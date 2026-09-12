import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config/constants.dart';
import 'providers/favorites_provider.dart';
import 'providers/stream_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final baseUrl =
      prefs.getString(AppConstants.apiBaseUrlKey) ?? AppConstants.apiBaseUrl;

  final favorites = FavoritesProvider();
  await favorites.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StreamsProvider(baseUrl: baseUrl)),
        ChangeNotifierProvider.value(value: favorites),
      ],
      child: const CricketApp(),
    ),
  );
}