import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/stream_provider.dart';
import '../utils/theme.dart';
import 'channel_list_screen.dart';
import 'settings_screen.dart';

/// Apple-style home: fixed large-title header (the way the iOS TV app keeps
/// its masthead), and a translucent tab bar the lists scroll underneath.
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
      backgroundColor: AppColors.background,
      extendBody: true, // body paints under the tab bar; bar blurs it
      bottomNavigationBar: _TabBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, count, provider),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: const [ChannelListScreen(), SettingsScreen()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, int count, StreamsProvider provider) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cricket Streams',
                  style: textTheme.displayLarge, // 34 bold, tight tracking
                ),
                if (count > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$count channels · ${_updatedLabel(provider.lastFetchTime)}',
                      style: textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          _RefreshButton(
            isLoading: provider.isLoading,
            onPressed: provider.refresh,
          ),
        ],
      ),
    );
  }

  String _updatedLabel(DateTime? time) {
    if (time == null) return 'not loaded';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Circular glass refresh button — responds on pointer-down, spring-scale.
class _RefreshButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _RefreshButton({required this.isLoading, required this.onPressed});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    reverseDuration: const Duration(milliseconds: 160),
    value: 1.0,
  );

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scale on touch-down, not on tap: the press is the feedback.
    return GestureDetector(
      onTapDown: (_) => _scale.forward(),
      onTapCancel: () => _scale.reverse(),
      onTapUp: (_) => _scale.reverse(),
      child: ScaleTransition(
        scale: _scale.drive(
          Tween(begin: 1.0, end: 0.9).chain(CurveTween(curve: Curves.easeOut)),
        ),
        child: Glass.container(
          radius: 20,
          child: SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              tooltip: 'Refresh streams',
              onPressed: widget.isLoading ? null : widget.onPressed,
              icon: widget.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textBody,
                      ),
                    )
                  : const Icon(
                      Icons.refresh,
                      size: 22,
                      color: AppColors.textBody,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS tab bar: blurred material, content scrolls underneath, accent on the
/// selected tab, no pill indicator.
class _TabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _TabBar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xD9000000), // near-solid so labels stay legible
            border: Border(
              top: BorderSide(color: AppColors.separator, width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                height: 56,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                indicatorColor: Colors.transparent, // iOS uses tint, not a pill
                iconTheme: WidgetStateProperty.resolveWith(
                  (states) => IconThemeData(
                    color: states.contains(WidgetState.selected)
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                ),
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: states.contains(WidgetState.selected)
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: onChanged,
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
            ),
          ),
        ),
      ),
    );
  }
}
