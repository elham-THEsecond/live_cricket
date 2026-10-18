import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/channel.dart';
import '../providers/favorites_provider.dart';
import '../providers/stream_provider.dart';
import '../utils/theme.dart';
import '../widgets/channel_tile.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/error_widget.dart';
import '../widgets/loading_widget.dart';

/// Channels list with an iOS-style search field and sliding segmented
/// control (All / Favorites).
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

    late final Widget body;
    if (provider.isLoading && provider.allChannels.isEmpty) {
      body = const KeyedSubtree(key: ValueKey('loading'), child: LoadingWidget());
    } else if (provider.hasError && provider.allChannels.isEmpty) {
      body = KeyedSubtree(
        key: const ValueKey('error'),
        child: CustomErrorWidget(
          message: provider.errorMessage ?? 'Something went wrong',
          onRetry: provider.fetchStreams,
        ),
      );
    } else if (provider.isEmpty) {
      body = KeyedSubtree(
        key: const ValueKey('empty'),
        child: EmptyStateWidget(onRefresh: provider.fetchStreams),
      );
    } else {
      final channels = _favoritesOnly
          ? provider.channels.where((c) => favorites.isFavorite(c.id)).toList()
          : provider.channels;
      body = KeyedSubtree(
        key: const ValueKey('content'),
        child: _contentList(context, provider, favorites, channels),
      );
    }

    return AnimatedSwitcher(
      // Honor the OS's reduce-motion setting with an instant swap; otherwise
      // fade only — a slide on a data list reads as bounce.
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: body,
    );
  }

  Widget _contentList(
    BuildContext context,
    StreamsProvider provider,
    FavoritesProvider favorites,
    List<Channel> channels,
  ) {
    // Space the list clears so content ends above the floating tab bar.
    const bottomClearance = 24.0 + 56.0 + 24.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: CupertinoSearchTextField(
            controller: _searchController,
            placeholder: 'Search channels',
            style: const TextStyle(color: AppColors.textBody, fontSize: 16),
            placeholderStyle: const TextStyle(
              color: AppColors.textFaint,
              fontSize: 16,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: CupertinoSlidingSegmentedControl<bool>(
            groupValue: _favoritesOnly,
            onValueChanged: (v) => setState(() => _favoritesOnly = v ?? false),
            thumbColor: AppColors.cellElevated,
            backgroundColor: AppColors.surface,
            children: const {
              false: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: Text('All', style: TextStyle(fontSize: 14, color: AppColors.textBody)),
              ),
              true: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: Text('Favorites', style: TextStyle(fontSize: 14, color: AppColors.textBody)),
              ),
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.cellElevated,
            onRefresh: provider.refresh,
            child: channels.isEmpty
                ? ListView(
                    // ListView (not Center) so pull-to-refresh still works here.
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                      EmptyStateWidget(onRefresh: provider.fetchStreams),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, bottomClearance),
                    itemCount: channels.length,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (context, i) {
                      final channel = channels[i];
                      return ChannelTile(
                        channel: channel,
                        isFavorite: favorites.isFavorite(channel.id),
                        onTap: () => _openChannel(channel),
                        onFavoriteToggle: () {
                          // Same frame as the star swap — one causal beat.
                          HapticFeedback.selectionClick();
                          favorites.toggleFavorite(channel.id);
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
