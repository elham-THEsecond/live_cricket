import 'package:flutter/material.dart';

import 'models/channel.dart';
import 'screens/home_screen.dart';
import 'screens/player_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/theme.dart';

class CricketApp extends StatelessWidget {
  const CricketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cricket Streams',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/settings': (_) => const Scaffold(body: SettingsScreen()),
      },
      // The player needs a Channel argument, so it goes through onGenerateRoute.
      onGenerateRoute: (settings) {
        if (settings.name == '/player') {
          final channel = settings.arguments;
          if (channel is! Channel) {
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                body: Center(child: Text('No channel selected')),
              ),
            );
          }
          return MaterialPageRoute<void>(
            builder: (_) => PlayerScreen(channel: channel),
          );
        }
        return null;
      },
    );
  }
}