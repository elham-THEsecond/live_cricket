import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/channel.dart';
import '../models/stream_url.dart';
import '../utils/country_flags.dart';
import '../utils/theme.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;

  const PlayerScreen({super.key, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late BetterPlayerController _controller;
  int _currentStreamIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  // The plugin reposts `exception` from its video-value listener on every tick
  // while the error is latched, and the event carries no source identity — so a
  // stale repeat after a switch would otherwise advance a second time and skip
  // a working source. Ignore failovers arriving immediately after the previous
  // one. Nothing is lost: the reposting means a genuinely dead source is
  // reported again once this window passes.
  static const Duration _failoverCooldown = Duration(seconds: 1);
  DateTime? _lastFailoverAt;

  Channel get _channel => widget.channel;
  StreamUrl get _currentStream => _channel.streams[_currentStreamIndex];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _setupPlayer(_currentStream);
  }

  Map<String, String> _headersFor(StreamUrl stream) => {
        if (stream.referrer.isNotEmpty) 'Referer': stream.referrer,
        if (stream.userAgent.isNotEmpty) 'User-Agent': stream.userAgent,
        'Accept': '*/*',
      };

  void _setupPlayer(StreamUrl stream) {
    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        autoPlay: true,
        looping: false,
        // We do our own landscape lock and keep the overlay in the same route,
        // so better_player must not push its own fullscreen route on top.
        fullScreenByDefault: false,
        allowedScreenSleep: false,
        fit: BoxFit.contain,
        placeholder: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        errorBuilder: (context, errorMessage) => _errorView(errorMessage),
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enablePlayPause: true,
          enableFullscreen: true,
          enableSkips: false,
          enableProgressBar: false,
          enableProgressBarDrag: false,
          enableAudioTracks: true,
          enableSubtitles: false,
          enablePip: true,
          enableOverflowMenu: true,
          overflowMenuIconsColor: Colors.white,
          overflowMenuCustomItems: [
            BetterPlayerOverflowMenuItem(
              Icons.high_quality,
              'Source ${_currentStreamIndex + 1}/${_channel.streams.length}',
              _showSourceSelector,
            ),
          ],
        ),
      ),
      betterPlayerDataSource: BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        stream.url,
        liveStream: true,
        headers: _headersFor(stream),
        useAsmsTracks: true,
        useAsmsSubtitles: true,
      ),
    );

    _controller.addEventsListener(_onPlayerEvent);
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;
    switch (event.betterPlayerEventType) {
      // better_player reports failures as `exception`; there is no `error` case.
      case BetterPlayerEventType.exception:
        _switchToNextStream();
        break;
      // No reset on `setupDataSource`: our own failover calls it, so clearing
      // the cooldown there would re-open the window the cooldown exists to
      // close. It expires on its own, which is exactly when a genuinely dead
      // new source starts being re-reported.
      case BetterPlayerEventType.play:
      case BetterPlayerEventType.initialized:
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
        break;
      default:
        break;
    }
  }

  void _switchToNextStream() {
    final now = DateTime.now();
    if (_lastFailoverAt != null &&
        now.difference(_lastFailoverAt!) < _failoverCooldown) {
      return;
    }
    _lastFailoverAt = now;

    if (_currentStreamIndex >= _channel.streams.length - 1) {
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
    });
    _controller.setupDataSource(
      BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        _currentStream.url,
        liveStream: true,
        headers: _headersFor(_currentStream),
        useAsmsTracks: true,
        useAsmsSubtitles: true,
      ),
    );
  }

  void _selectStream(int index) {
    if (index == _currentStreamIndex) return;
    setState(() {
      _currentStreamIndex = index;
      _isLoading = true;
      _errorMessage = null;
      _lastFailoverAt = null;
    });
    _controller.setupDataSource(
      BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        _currentStream.url,
        liveStream: true,
        headers: _headersFor(_currentStream),
        useAsmsTracks: true,
        useAsmsSubtitles: true,
      ),
    );
  }

  void _showSourceSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _channel.streams.length,
          itemBuilder: (context, i) {
            final stream = _channel.streams[i];
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

  Widget _errorView(String? message) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text('Stream error', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              message ?? '',
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

  @override
  void dispose() {
    _controller.dispose();
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
            Positioned.fill(child: BetterPlayer(controller: _controller)),
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
                countryFlag(_channel.country),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  _channel.name,
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
                'Source ${_currentStreamIndex + 1}/${_channel.streams.length}',
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
              if (_errorMessage != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
              ],
            ],
          ),
        ),
        const Spacer(),
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