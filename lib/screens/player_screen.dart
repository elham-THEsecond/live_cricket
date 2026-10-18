import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/channel.dart';
import '../models/stream_url.dart';
import '../utils/country_flags.dart';
import '../utils/theme.dart';

/// Fullscreen-ish player screen for one channel.
///
/// Uses media_kit (libmpv): real audio/video track switching, playback speed,
/// volume, and stall-aware auto-failover between the channel's sources.
class PlayerScreen extends StatefulWidget {
  final Channel channel;

  const PlayerScreen({super.key, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late Player _player;
  late VideoController _videoController;

  int _currentStreamIndex = 0;
  bool _isLoading = true;
  bool _isStalled = false;
  String? _errorMessage;

  // Chrome fade: the overlay follows the finger (any tap animates the same
  // controller from its current position — interruptible by design).
  late final AnimationController _chrome = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    // Exit faster than enter: chrome that lingers while hiding feels stuck.
    reverseDuration: const Duration(milliseconds: 120),
    value: 1.0,
  );
  bool _chromeHidden = false;

  // Stall detector: if playback neither progresses nor completes within
  // [stallTimeout] of starting (or after a buffering pause), the source is
  // dead/slow on this connection — fail over instead of waiting forever.
  static const Duration _stallTimeout = Duration(seconds: 10);
  Timer? _stallTimer;

  // Failover cooldown mirrors the old better_player guard: media_kit can emit
  // multiple errors for one failure; we don't want to skip two sources for one
  // dead stream.
  static const Duration _failoverCooldown = Duration(seconds: 2);
  DateTime? _lastFailoverAt;

  StreamUrl get _currentStream => widget.channel.streams[_currentStreamIndex];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    MediaKit.ensureInitialized();
    _player = Player();
    await _player.open(
      Media(_currentStream.url, httpHeaders: _headersFor(_currentStream)),
    );
    _videoController = VideoController(_player);

    _player.stream.completed.listen((_) {});
    _player.stream.error.listen((e) {
      if (!mounted) return;
      _switchToNextStream();
    });
    _player.stream.position.listen((_) {});
    _player.stream.buffering.listen((b) {
      if (!mounted) return;
      _isStalled = b;
      if (b) {
        _startStallTimer();
      } else {
        _cancelStallTimer();
      }
      setState(() {});
    });
    _player.stream.playing.listen((p) {
      if (!mounted) return;
      if (p) {
        // Causal haptic: the stream just came alive, same frame as the
        // loading overlay disappears.
        if (_isLoading) HapticFeedback.lightImpact();
        _isLoading = false;
        _cancelStallTimer();
      }
      setState(() {});
    });

    if (!mounted) return;
    setState(() {});
  }

  Map<String, String> _headersFor(StreamUrl stream) => {
    if (stream.referrer.isNotEmpty) 'Referer': stream.referrer,
    if (stream.userAgent.isNotEmpty) 'User-Agent': stream.userAgent,
    'Accept': '*/*',
  };

  void _startStallTimer() {
    _cancelStallTimer();
    _stallTimer = Timer(_stallTimeout, () {
      if (!mounted) return;
      _switchToNextStream();
    });
  }

  void _cancelStallTimer() {
    _stallTimer?.cancel();
    _stallTimer = null;
  }

  Future<void> _switchToNextStream() async {
    final now = DateTime.now();
    if (_lastFailoverAt != null &&
        now.difference(_lastFailoverAt!) < _failoverCooldown) {
      return;
    }
    _lastFailoverAt = now;

    if (_currentStreamIndex >= widget.channel.streams.length - 1) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'All sources failed. Channel may be offline.';
      });
      // Error feedback: one meaningful beat, only on the final failure.
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _currentStreamIndex++;
      _isLoading = true;
      _errorMessage = null;
      _isStalled = false;
    });
    await _player.open(
      Media(_currentStream.url, httpHeaders: _headersFor(_currentStream)),
    );
  }

  Future<void> _selectStream(int index) async {
    if (index == _currentStreamIndex) return;
    setState(() {
      _currentStreamIndex = index;
      _isLoading = true;
      _errorMessage = null;
      _lastFailoverAt = null;
    });
    await _player.open(
      Media(_currentStream.url, httpHeaders: _headersFor(_currentStream)),
    );
  }

  void _toggleChrome() {
    setState(() {
      _chromeHidden = !_chromeHidden;
      // Animate from the current value, never the target: mid-flight taps
      // reverse without a jump.
      _chromeHidden ? _chrome.reverse() : _chrome.forward();
    });
  }

  void _showSourceSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          itemCount: widget.channel.streams.length,
          itemBuilder: (context, i) {
            final stream = widget.channel.streams[i];
            final selected = i == _currentStreamIndex;
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(
                selected
                    ? Icons.play_circle_rounded
                    : Icons.play_circle_outline_rounded,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
              title: Text('Source ${i + 1}'),
              subtitle: Text(
                stream.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _selectStream(i);
              },
            );
          },
        ),
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Playback', style: Glass.titleStyle),
              const SizedBox(height: 12),
              // Volume
              Row(
                children: [
                  const Icon(
                    Icons.volume_up_rounded,
                    color: AppColors.textBody,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Slider(
                      value: _player.state.volume.clamp(0.0, 1.0),
                      onChanged: (v) => _player.setVolume(v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Speed
              Row(
                children: [
                  const Icon(
                    Icons.speed_rounded,
                    color: AppColors.textBody,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [0.5, 1.0, 1.5, 2.0].map((s) {
                        final active = (_player.state.rate - s).abs() < 0.01;
                        return ChoiceChip(
                          label: Text('${s}x'),
                          selected: active,
                          onSelected: (_) => _player.setRate(s),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _chrome.dispose();
    _cancelStallTimer();
    _player.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleChrome,
          child: Stack(
            children: [
              Positioned.fill(
                child: Video(
                  controller: _videoController,
                  controls: NoVideoControls,
                ),
              ),
              // Always mounted so the error fades in/out instead of popping
              // over the video; IgnorePointer keeps the hidden view inert.
              IgnorePointer(
                ignoring: _errorMessage == null,
                child: AnimatedOpacity(
                  opacity: _errorMessage != null ? 1.0 : 0.0,
                  duration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: _errorView(
                    _errorMessage ??
                        'All sources failed. '
                            'Channel may be offline.',
                  ),
                ),
              ),
              if (_isLoading && _errorMessage == null)
                const IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              // Chrome rides the same shared controller. The error view stays
              // visible separately: a mode where the story must not hide.
              if (_errorMessage == null) _chromeOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chromeOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 12,
      right: 12,
      child: FadeTransition(opacity: _chrome, child: _overlay()),
    );
  }

  Widget _errorView(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 44,
          ),
          const SizedBox(height: 16),
          const Text(
            'Stream error',
            style: TextStyle(
              color: AppColors.textBody,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Glass.container(
            radius: 12,
            child: TextButton.icon(
              // Manual retry must not be swallowed by the failover cooldown.
              onPressed: () {
                _lastFailoverAt = null;
                _switchToNextStream();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text('Try next source'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _overlay() {
    return Row(
      children: [
        Expanded(
          child: Glass.container(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  countryFlag(widget.channel.country),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textBody,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Source ${_currentStreamIndex + 1}/${widget.channel.streams.length}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                if (_isStalled)
                  const Icon(
                    Icons.hourglass_bottom_rounded,
                    color: Color(0xFFFFD60A),
                    size: 16,
                  ),
                if (_errorMessage != null)
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFFD60A),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Glass.circle(
          child: IconButton(
            tooltip: 'Settings',
            onPressed: _showSettingsSheet,
            icon: const Icon(
              Icons.tune_rounded,
              color: AppColors.textBody,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Glass.circle(
          child: IconButton(
            tooltip: 'Sources',
            onPressed: _showSourceSelector,
            icon: const Icon(
              Icons.swap_horiz_rounded,
              color: AppColors.textBody,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Glass.circle(
          child: IconButton(
            tooltip: 'Close player',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textBody,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}
