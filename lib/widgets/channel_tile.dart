import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../utils/country_flags.dart';
import '../utils/theme.dart';

/// iOS-style channel cell: elevated surface, bold name, secondary subtitle,
/// instant press-down scale (feedback on touch-down, not release).
class ChannelTile extends StatefulWidget {
  final Channel channel;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const ChannelTile({
    super.key,
    required this.channel,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  @override
  State<ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<ChannelTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100), // press snap
    reverseDuration: const Duration(milliseconds: 180), // spring settle
    value: 1.0,
  );

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sources = widget.channel.streams.length;
    final reduced = MediaQuery.of(context).disableAnimations;

    return GestureDetector(
      onTapDown: (_) => _scale.forward(),
      onTapCancel: () => _scale.reverse(),
      onTapUp: (_) => _scale.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale.drive(
          Tween(begin: 1.0, end: 0.97).chain(CurveTween(curve: Curves.easeOut)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SizedBox(
            height: 76,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _logo(),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textBody,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${countryFlag(widget.channel.country)} ${widget.channel.country} · '
                        '$sources ${sources == 1 ? 'source' : 'sources'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onFavoriteToggle,
                  tooltip: widget.isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  icon: AnimatedSwitcher(
                    // High-frequency action: near-imperceptible scale+fade beat.
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 140),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.8, end: 1.0).animate(
                          CurveTween(
                            curve: Curves.easeOutCubic,
                          ).animate(animation),
                        ),
                        child: child,
                      ),
                    ),
                    child: Icon(
                      widget.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      key: ValueKey(widget.isFavorite),
                      size: 26,
                      color: widget.isFavorite
                          ? AppColors.primary
                          : AppColors.textFaint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    const fallback = CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.cellElevated,
      child: Icon(Icons.tv_outlined, color: AppColors.textMuted),
    );

    if (widget.channel.logo.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: widget.channel.logo,
      width: 44,
      height: 44,
      fit: BoxFit.contain,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}
