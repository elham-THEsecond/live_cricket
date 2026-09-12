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

class _PlayerScreenState extends State<PlayerScreen> {
  late Player _player;
  late VideoController _videoController;

  int _currentStreamIndex = 0;
  bool _isLoading = true;
  bool _isStalled = false;
  String? _errorMessage;

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
    await _player.open(Media(_currentStream.url,
        httpHeaders: _headersFor(_currentStream)));
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
      return;
    }

    setState(() {
      _currentStreamIndex++;
      _isLoading = true;
      _errorMessage = null;
      _isStalled = false;
    });
    await _player.open(Media(_currentStream.url,
        httpHeaders: _headersFor(_currentStream)));
  }

  Future<void> _selectStream(int index) async {
    if (index == _currentStreamIndex) return;
    setState(() {
      _currentStreamIndex = index;
      _isLoading = true;
      _errorMessage = null;
      _lastFailoverAt = null;
    });
    await _player.open(Media(_currentStream.url,
        httpHeaders: _headersFor(_currentStream)));
  }

  void _showSourceSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.channel.streams.length,
          itemBuilder: (context, i) {
            final stream = widget.channel.streams[i];
            final selected = i == _currentStreamIndex;
            return ListTile(
              leading: Icon(
                selected ? Icons.play_circle : Icons.play_circle_outline,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
              title: Text('Source ${i + 1}'),
              subtitle: Text(
                stream.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Playback',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // Volume
              Row(children: [
                const Icon(Icons.volume_up, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _player.state.volume.clamp(0.0, 1.0),
                    onChanged: (v) => _player.setVolume(v),
                  ),
                ),
              ]),
              // Speed
              Row(children: [
                const Icon(Icons.speed, color: Colors.white),
                const SizedBox(width: 8),
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
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
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
        body: Stack(
          children: [
            Positioned.fill(
              child: Video(
                controller: _videoController,
                controls: NoVideoControls,
              ),
            ),
            if (_errorMessage != null) _errorView(_errorMessage!),
            if (_isLoading && _errorMessage == null)
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _overlay(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(String message) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text('Stream error',
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              // Manual retry must not be swallowed by the failover cooldown.
              onPressed: () {
                _lastFailoverAt = null;
                _switchToNextStream();
              },
              child: const Text('Try next source'),
            ),
          ],
        ),
      );

  Widget _overlay() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                countryFlag(widget.channel.country),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  widget.channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Source ${_currentStreamIndex + 1}/${widget.channel.streams.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              if (_isLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ],
              if (_isStalled) ...[
                const SizedBox(width: 8),
                const Icon(Icons.hourglass_bottom,
                    color: Colors.orange, size: 16),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
              ],
            ],
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Settings',
          onPressed: _showSettingsSheet,
          icon: const Icon(Icons.tune, color: Colors.white),
          style: IconButton.styleFrom(backgroundColor: Colors.black54),
        ),
        IconButton(
          tooltip: 'Sources',
          onPressed: _showSourceSelector,
          icon: const Icon(Icons.library_books, color: Colors.white),
          style: IconButton.styleFrom(backgroundColor: Colors.black54),
        ),
        IconButton(
          tooltip: 'Close player',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.white),
          style: IconButton.styleFrom(backgroundColor: Colors.black54),
        ),
      ],
    );
  }
}
