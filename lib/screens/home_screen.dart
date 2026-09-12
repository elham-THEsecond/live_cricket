import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/stream_provider.dart';
import 'channel_list_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StreamsProvider>();
      if (provider.state == StreamState.idle) provider.fetchStreams();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StreamsProvider>();
    final count = provider.allChannels.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cricket Streams'),
        actions: [
          IconButton(
            tooltip: 'Refresh streams',
            onPressed: provider.isLoading ? null : provider.refresh,
            icon: provider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
        bottom: count == 0
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$count channels · ${_updatedLabel(provider.lastFetchTime)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
      ),
      body: IndexedStack(
        index: _index,
        children: const [ChannelListScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.live_tv_outlined),
            selectedIcon: Icon(Icons.live_tv),
            label: 'Channels',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  String _updatedLabel(DateTime? time) {
    if (time == null) return 'not updated yet';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return 'updated $h:$m';
  }
}