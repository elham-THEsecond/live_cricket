import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/channel.dart';
import '../providers/favorites_provider.dart';
import '../providers/stream_provider.dart';
import '../widgets/channel_tile.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/error_widget.dart';
import '../widgets/loading_widget.dart';

class ChannelListScreen extends StatefulWidget {
  const ChannelListScreen({super.key});

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      context.read<StreamsProvider>().filterChannels(value);
    });
  }

  Future<void> _openChannel(Channel channel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.lastChannelKey, channel.id);
    if (!mounted) return;
    Navigator.of(context).pushNamed('/player', arguments: channel);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StreamsProvider>();
    final favorites = context.watch<FavoritesProvider>();

    if (provider.isLoading && provider.allChannels.isEmpty) {
      return const LoadingWidget();
    }
    if (provider.hasError && provider.allChannels.isEmpty) {
      return CustomErrorWidget(
        message: provider.errorMessage ?? 'Something went wrong',
        onRetry: provider.fetchStreams,
      );
    }
    if (provider.isEmpty) {
      return EmptyStateWidget(onRefresh: provider.fetchStreams);
    }

    final channels = _favoritesOnly
        ? provider.channels.where((c) => favorites.isFavorite(c.id)).toList()
        : provider.channels;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.defaultPadding,
            8,
            AppConstants.defaultPadding,
            8,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search channels',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _favoritesOnly ? 'Show all channels' : 'Show favorites',
                onPressed: () =>
                    setState(() => _favoritesOnly = !_favoritesOnly),
                icon: Icon(
                  _favoritesOnly ? Icons.star : Icons.star_border,
                  color: _favoritesOnly ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.refresh,
            child: channels.isEmpty
                ? ListView(
                    // ListView (not Center) so pull-to-refresh still works here.
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                      EmptyStateWidget(onRefresh: provider.fetchStreams),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultPadding,
                    ),
                    itemCount: channels.length,
                    itemBuilder: (context, i) {
                      final channel = channels[i];
                      return ChannelTile(
                        channel: channel,
                        isFavorite: favorites.isFavorite(channel.id),
                        onTap: () => _openChannel(channel),
                        onFavoriteToggle: () =>
                            favorites.toggleFavorite(channel.id),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}